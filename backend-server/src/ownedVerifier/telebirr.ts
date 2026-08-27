import axios from "axios";
import * as cheerio from "cheerio";

import {
  appendPath,
  completedStatus,
  configuredTimeout,
  ethiopianLocalDate,
  MAX_PROVIDER_RESPONSE_BYTES,
  nonEmpty,
  numberFrom,
  providerUrl,
  referencesMatch,
  relayUrl,
  safeRaw,
  shouldUseDirectProvider,
  shouldUseProviderRelays,
  toOwnedVerifierError,
} from "./common";
import {
  OwnedVerificationData,
  OwnedVerificationResult,
  OwnedVerifierError,
} from "./types";

interface TelebirrReceipt {
  payerName: string | null;
  payerTelebirrNo: string | null;
  creditedPartyName: string | null;
  creditedPartyAccountNo: string | null;
  transactionStatus: string | null;
  receiptNo: string | null;
  paymentDate: string | null;
  settledAmount: string | null;
  serviceFee: string | null;
  serviceFeeVAT: string | null;
  totalPaidAmount: string | null;
  bankName: string | null;
  customerNote: string | null;
}

function cleanLabel(value: string): string {
  return value.replace(/\s+/g, " ").trim().toLowerCase();
}

/** Parse the public Ethio Telecom receipt table without logging payer data. */
export function parseTelebirrHtml(html: string): TelebirrReceipt {
  const $ = cheerio.load(html);
  const rows = $("tr")
    .toArray()
    .map((row) =>
      $(row)
        .find("td")
        .toArray()
        .map((cell) => $(cell).text().replace(/\s+/g, " ").trim()),
    )
    .filter((cells) => cells.length > 0);

  const valueFor = (...labels: string[]): string | null => {
    const lowered = labels.map(cleanLabel);
    for (const cells of rows) {
      for (let index = 0; index < cells.length; index++) {
        const cell = cleanLabel(cells[index] ?? "");
        if (!lowered.some((label) => cell.includes(label))) continue;
        for (let valueIndex = index + 1; valueIndex < cells.length; valueIndex++) {
          const candidate = nonEmpty(cells[valueIndex]);
          if (candidate) return candidate;
        }
      }
    }
    return null;
  };

  const receiptNo =
    valueFor("receipt no", "receipt number") ??
    nonEmpty(
      html.match(
        /(?:Receipt\s*(?:No\.?|Number))[^A-Z0-9]*([A-Z0-9]{8,32})/i,
      )?.[1],
    );
  const paymentDate =
    valueFor("payment date") ??
    nonEmpty(html.match(/(\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}:\d{2})/)?.[1]);
  const settledAmount =
    valueFor("settled amount") ??
    nonEmpty(
      html.match(/Settled\s+Amount.*?([\d,]+(?:\.\d+)?\s*Birr)/is)?.[1],
    );
  const serviceFee = valueFor("service fee", "service charge");
  const serviceFeeVAT = valueFor("service fee vat", "service fee v.a.t");
  let creditedPartyName = valueFor("credited party name");
  let creditedPartyAccountNo = valueFor(
    "credited party account no",
    "credited party account number",
  );
  const bankAccount = valueFor("bank account number");
  let bankName: string | null = null;
  if (bankAccount) {
    bankName = creditedPartyName;
    const match = bankAccount.match(/([+\d][\d\s-]{5,})\s+(.+)/);
    if (match) {
      creditedPartyAccountNo = nonEmpty(match[1]);
      creditedPartyName = nonEmpty(match[2]);
    } else {
      creditedPartyAccountNo = bankAccount;
    }
  }

  return {
    payerName: valueFor("payer name"),
    payerTelebirrNo: valueFor("payer telebirr no", "payer phone"),
    creditedPartyName,
    creditedPartyAccountNo,
    transactionStatus: valueFor("transaction status"),
    receiptNo,
    paymentDate,
    settledAmount,
    serviceFee,
    serviceFeeVAT,
    totalPaidAmount: valueFor("total paid amount"),
    bankName,
    customerNote: valueFor("customer note"),
  };
}

function parseRelayPayload(payload: unknown): TelebirrReceipt | null {
  if (!payload || typeof payload !== "object") return null;
  const envelope = payload as Record<string, unknown>;
  if (envelope.success === false) return null;
  const raw =
    envelope.data && typeof envelope.data === "object"
      ? (envelope.data as Record<string, unknown>)
      : envelope;
  return {
    payerName: nonEmpty(raw.payerName),
    payerTelebirrNo: nonEmpty(raw.payerTelebirrNo),
    creditedPartyName: nonEmpty(raw.creditedPartyName),
    creditedPartyAccountNo: nonEmpty(raw.creditedPartyAccountNo),
    transactionStatus: nonEmpty(raw.transactionStatus),
    receiptNo: nonEmpty(raw.receiptNo),
    paymentDate: nonEmpty(raw.paymentDate),
    settledAmount: nonEmpty(raw.settledAmount),
    serviceFee: nonEmpty(raw.serviceFee),
    serviceFeeVAT: nonEmpty(raw.serviceFeeVAT),
    totalPaidAmount: nonEmpty(raw.totalPaidAmount),
    bankName: nonEmpty(raw.bankName),
    customerNote: nonEmpty(raw.customerNote),
  };
}

function normalizeTelebirr(
  submittedReference: string,
  receipt: TelebirrReceipt,
): OwnedVerificationResult {
  const amount = numberFrom(receipt.settledAmount);
  const date = ethiopianLocalDate(receipt.paymentDate);
  const status = receipt.transactionStatus;
  const reference = receipt.receiptNo ?? submittedReference;
  if (
    amount === null ||
    amount <= 0 ||
    !date ||
    !receipt.payerName ||
    !receipt.creditedPartyName ||
    !receipt.creditedPartyAccountNo ||
    !referencesMatch(submittedReference, reference) ||
    !completedStatus(status)
  ) {
    return {
      ok: false,
      provider: "telebirr",
      error: status || "Telebirr receipt is missing required verified fields.",
      code: "RECEIPT_MISMATCH",
    };
  }
  const totalAmount = numberFrom(receipt.totalPaidAmount);
  const data: OwnedVerificationData = {
    reference,
    amount,
    totalAmount,
    currency: "ETB",
    payerName: receipt.payerName,
    payerPhone: receipt.payerTelebirrNo,
    payerAccount: receipt.payerTelebirrNo,
    receiverName: receipt.creditedPartyName,
    receiverAccount: receipt.creditedPartyAccountNo,
    txnDate: date,
    status: "completed",
    statusText: status,
    serviceFee: numberFrom(receipt.serviceFee),
    serviceFeeVAT: numberFrom(receipt.serviceFeeVAT),
    bankName: receipt.bankName,
    raw: safeRaw({ ...receipt }),
  };
  return { ok: true, provider: "telebirr", data };
}

async function directReceipt(reference: string): Promise<TelebirrReceipt | null> {
  const base = providerUrl(
    "TELEBIRR_RECEIPT_BASE_URL",
    "https://transactioninfo.ethiotelecom.et/receipt",
  );
  const response = await axios.get<string>(appendPath(base, reference), {
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: {
      Accept: "text/html,application/xhtml+xml",
      "User-Agent": "CHEKMI-Verifier/1.0",
    },
  });
  return parseTelebirrHtml(response.data);
}

function relayDescriptors(): string[] {
  return (
    process.env.TELEBIRR_PROXY_URLS ??
    process.env.FALLBACK_PROXIES ??
    ""
  )
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

async function relayReceipt(
  reference: string,
  rawRelay: string,
): Promise<TelebirrReceipt | null> {
  const key = process.env.TELEBIRR_PROXY_KEY?.trim() || "";
  if (!key) {
    throw new OwnedVerifierError(
      "TELEBIRR_PROXY_KEY is required for relay mode.",
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  const url = relayUrl(
    rawRelay,
    { reference, key },
    "TELEBIRR_PROXY_URLS",
  );
  const response = await axios.get<unknown>(url, {
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
  });
  if (typeof response.data === "string") {
    try {
      return parseRelayPayload(JSON.parse(response.data));
    } catch {
      return parseTelebirrHtml(response.data);
    }
  }
  return parseRelayPayload(response.data);
}

export async function verifyTelebirrOwned(
  rawReference: string,
): Promise<OwnedVerificationResult> {
  const reference = rawReference.trim().toUpperCase();
  if (!/^[A-Z0-9-]{8,32}$/.test(reference)) {
    return {
      ok: false,
      provider: "telebirr",
      error: "Invalid Telebirr receipt reference.",
      code: "INVALID_REFERENCE",
    };
  }

  let lastTransportError: OwnedVerifierError | null = null;
  if (shouldUseDirectProvider()) {
    try {
      const receipt = await directReceipt(reference);
      if (receipt) {
        const normalized = normalizeTelebirr(reference, receipt);
        if (normalized.ok) return normalized;
      }
    } catch (error) {
      lastTransportError = toOwnedVerifierError(error, "Telebirr");
    }
  }

  if (shouldUseProviderRelays()) {
    const relays = relayDescriptors();
    if (relays.length === 0) {
      throw new OwnedVerifierError(
        "Telebirr relay mode requires TELEBIRR_PROXY_URLS.",
        "VERIFIER_CONFIGURATION_ERROR",
        503,
        false,
      );
    }
    for (const relay of relays) {
      try {
        const receipt = await relayReceipt(reference, relay);
        if (!receipt) continue;
        const normalized = normalizeTelebirr(reference, receipt);
        if (normalized.ok) return normalized;
      } catch (error) {
        lastTransportError = toOwnedVerifierError(error, "Telebirr relay");
      }
    }
  }

  if (lastTransportError) throw lastTransportError;
  return {
    ok: false,
    provider: "telebirr",
    error: "Telebirr receipt was not found or was incomplete.",
    code: "RECEIPT_NOT_FOUND",
  };
}
