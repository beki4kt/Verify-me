import axios from "axios";
import pdfParse from "pdf-parse";

import {
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
  titleCase,
  toOwnedVerifierError,
} from "./common";
import {
  OwnedVerificationResult,
  OwnedVerifierError,
} from "./types";

const LEGACY_REFERENCE = /^FT[A-Z0-9]{10}$/i;
const LEGACY_COMBINED_ID = /^(FT[A-Z0-9]{10})(\d{8})$/i;
const NEW_CBE_URL = /^https?:\/\/mbreciept\.cbe\.com\.et\/([A-Za-z0-9-]+)\/?$/i;
const NEW_CBE_TOKEN = /^[A-Za-z0-9-]{15,80}$/;

interface CbeReceipt {
  payerName: string | null;
  payerAccount: string | null;
  receiverName: string | null;
  receiverAccount: string | null;
  amount: number | null;
  date: string | null;
  reference: string | null;
  reason: string | null;
  raw: Record<string, unknown>;
}

export function extractNewCbeToken(input: string): string | null {
  const trimmed = input.trim();
  const urlMatch = trimmed.match(NEW_CBE_URL);
  if (urlMatch) return urlMatch[1] ?? null;
  if (!trimmed.toUpperCase().startsWith("FT") && NEW_CBE_TOKEN.test(trimmed)) {
    return trimmed;
  }
  return null;
}

export function isLegacyCbeReference(input: string): boolean {
  return LEGACY_REFERENCE.test(input.trim());
}

export function extractLegacyCbeUrlData(
  input: string,
): { reference: string; suffix: string } | null {
  try {
    const url = new URL(input.trim());
    if (url.hostname.toLowerCase() !== "apps.cbe.com.et") return null;
    if (url.port && url.port !== "100") return null;
    const match = url.searchParams.get("id")?.trim().match(LEGACY_COMBINED_ID);
    if (!match) return null;
    return { reference: (match[1] ?? "").toUpperCase(), suffix: match[2] ?? "" };
  } catch {
    return null;
  }
}

export function parseCbeText(rawText: string): CbeReceipt {
  const text = rawText.replace(/\s+/g, " ").trim();
  const accounts = [
    ...text.matchAll(/Account\s*:?\s*([A-Z0-9]?\*{3,}\d{4,}|[A-Z0-9]{6,})/gi),
  ];
  const payerName = nonEmpty(text.match(/Payer\s*:?\s*(.*?)\s+Account/i)?.[1]);
  const receiverName = nonEmpty(
    text.match(/Receiver\s*:?\s*(.*?)\s+Account/i)?.[1],
  );
  const amount = numberFrom(
    text.match(/Transferred Amount\s*:?\s*([\d,]+(?:\.\d{1,2})?)\s*ETB/i)?.[1],
  );
  const date = ethiopianLocalDate(
    text.match(
      /Payment Date\s*&\s*Time\s*:?\s*(\d{4}[/-]\d{2}[/-]\d{2}[, ]+\s*\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)/i,
    )?.[1],
  );
  const reference = nonEmpty(
    text.match(/Reference No\.?\s*\(VAT Invoice No\)\s*:?\s*([A-Z0-9-]+)/i)?.[1],
  );
  const reason = nonEmpty(
    text.match(/Reason\s*\/\s*Type of service\s*:?\s*(.*?)\s+Transferred Amount/i)?.[1],
  );
  return {
    payerName: titleCase(payerName),
    payerAccount: nonEmpty(accounts[0]?.[1]),
    receiverName: titleCase(receiverName),
    receiverAccount: nonEmpty(accounts[1]?.[1]),
    amount,
    date,
    reference,
    reason,
    raw: {
      payerName,
      payerAccount: nonEmpty(accounts[0]?.[1]),
      receiverName,
      receiverAccount: nonEmpty(accounts[1]?.[1]),
      amount,
      date,
      reference,
      reason,
    },
  };
}

export async function parseCbePdf(buffer: Buffer): Promise<CbeReceipt> {
  const parsed = await pdfParse(buffer);
  return parseCbeText(parsed.text);
}

function mapNewReceipt(payload: unknown): CbeReceipt | null {
  if (!payload || typeof payload !== "object") return null;
  const envelope = payload as Record<string, unknown>;
  if (envelope.success === false) return null;
  const raw =
    envelope.data && typeof envelope.data === "object"
      ? (envelope.data as Record<string, unknown>)
      : envelope;
  const dateTimes = Array.isArray(raw.dateTimes) ? raw.dateTimes : [];
  const paymentDetails = Array.isArray(raw.paymentDetails)
    ? raw.paymentDetails.map(String)
    : [];
  return {
    payerName: nonEmpty(raw.debitAccountHolder),
    payerAccount: nonEmpty(raw.debitAccountNo),
    receiverName: nonEmpty(raw.creditAccountHolder),
    receiverAccount: nonEmpty(raw.creditAccountNo),
    amount: numberFrom(raw.amountCredited),
    date: ethiopianLocalDate(dateTimes[0]),
    reference: nonEmpty(raw.id),
    reason: nonEmpty(paymentDetails.join(" ")),
    raw: safeRaw(raw),
  };
}

function normalizeCbe(
  submittedReference: string,
  receipt: CbeReceipt,
): OwnedVerificationResult {
  if (
    receipt.amount === null ||
    receipt.amount <= 0 ||
    !receipt.date ||
    !receipt.reference ||
    !receipt.payerName ||
    !receipt.receiverName ||
    !receipt.receiverAccount
  ) {
    return {
      ok: false,
      provider: "cbe",
      error: "CBE receipt is missing required verified fields.",
      code: "RECEIPT_MISMATCH",
    };
  }
  return {
    ok: true,
    provider: "cbe",
    data: {
      reference: receipt.reference || submittedReference,
      amount: receipt.amount,
      currency: "ETB",
      payerName: receipt.payerName,
      payerAccount: receipt.payerAccount,
      receiverName: receipt.receiverName,
      receiverAccount: receipt.receiverAccount,
      txnDate: receipt.date,
      status: "completed",
      statusText: "completed",
      reason: receipt.reason,
      raw: receipt.raw,
    },
  };
}

function cbeRelayConfiguration(): { url: string; key: string } {
  const url = process.env.CBE_PROXY_URL?.trim() || "";
  const key = process.env.CBE_PROXY_KEY?.trim() || "";
  if (!url || !key) {
    throw new OwnedVerifierError(
      "CBE relay mode requires CBE_PROXY_URL and CBE_PROXY_KEY.",
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  return { url, key };
}

async function fetchLegacyDirect(combinedId: string): Promise<CbeReceipt> {
  const base = providerUrl(
    "CBE_LEGACY_RECEIPT_URL",
    "https://apps.cbe.com.et:100/",
  );
  const url = new URL(base);
  url.searchParams.set("id", combinedId);
  const response = await axios.get<ArrayBuffer>(url.toString(), {
    responseType: "arraybuffer",
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
  });
  return parseCbePdf(Buffer.from(response.data));
}

async function fetchLegacyRelay(combinedId: string): Promise<CbeReceipt> {
  const relay = cbeRelayConfiguration();
  const url = relayUrl(
    relay.url,
    { type: "legacy", id: combinedId, key: relay.key },
    "CBE_PROXY_URL",
  );
  const response = await axios.get<ArrayBuffer>(url, {
    responseType: "arraybuffer",
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
  });
  return parseCbePdf(Buffer.from(response.data));
}

async function fetchNewDirect(token: string): Promise<CbeReceipt | null> {
  const appId = process.env.CBE_APP_ID?.trim();
  const appVersion = process.env.CBE_APP_VERSION?.trim();
  if (!appId || !appVersion) {
    throw new OwnedVerifierError(
      "Direct new-format CBE verification requires CBE_APP_ID and CBE_APP_VERSION.",
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  const base = providerUrl(
    "CBE_NEW_RECEIPT_BASE_URL",
    "https://mb.cbe.com.et/api/v1/transactions/public/transaction-detail",
  );
  const response = await axios.get<unknown>(
    `${base.replace(/\/$/, "")}/${encodeURIComponent(token)}`,
    {
      timeout: configuredTimeout(),
      maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
      headers: {
        Accept: "application/json",
        Origin: "https://mbreciept.cbe.com.et",
        Referer: "https://mbreciept.cbe.com.et/",
        "User-Agent": "CHEKMI-Verifier/1.0",
        "x-app-id": appId,
        "x-app-version": appVersion,
      },
    },
  );
  return mapNewReceipt(response.data);
}

async function fetchNewRelay(token: string): Promise<CbeReceipt | null> {
  const relay = cbeRelayConfiguration();
  const url = relayUrl(
    relay.url,
    { type: "new", token, key: relay.key },
    "CBE_PROXY_URL",
  );
  const response = await axios.get<unknown>(url, {
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
  });
  return mapNewReceipt(response.data);
}

export async function verifyCbeOwned(
  rawReference: string,
  rawSuffix?: string,
): Promise<OwnedVerificationResult> {
  const submittedReference = rawReference.trim();
  const embeddedLegacy = extractLegacyCbeUrlData(submittedReference);
  const newToken = extractNewCbeToken(submittedReference);
  const reference = embeddedLegacy?.reference ?? submittedReference.toUpperCase();
  const suffix = (rawSuffix?.trim() || embeddedLegacy?.suffix || "").trim();
  if (!newToken && (!LEGACY_REFERENCE.test(reference) || !/^\d{8}$/.test(suffix))) {
    return {
      ok: false,
      provider: "cbe",
      error: "Legacy CBE verification requires an FT reference and 8-digit account suffix.",
      code: "INVALID_REFERENCE",
    };
  }

  let lastError: OwnedVerifierError | null = null;
  const tryDirect = shouldUseDirectProvider();
  const tryRelay = shouldUseProviderRelays();
  if (tryDirect) {
    try {
      const receipt = newToken
        ? await fetchNewDirect(newToken)
        : await fetchLegacyDirect(`${reference}${suffix}`);
      if (receipt) {
        if (!newToken && !referencesMatch(reference, receipt.reference)) {
          return {
            ok: false,
            provider: "cbe",
            error: "CBE returned a different receipt reference.",
            code: "REFERENCE_MISMATCH",
          };
        }
        return normalizeCbe(reference, receipt);
      }
    } catch (error) {
      lastError = toOwnedVerifierError(error, "CBE");
    }
  }
  if (tryRelay) {
    try {
      const receipt = newToken
        ? await fetchNewRelay(newToken)
        : await fetchLegacyRelay(`${reference}${suffix}`);
      if (receipt) {
        if (!newToken && !referencesMatch(reference, receipt.reference)) {
          return {
            ok: false,
            provider: "cbe",
            error: "CBE returned a different receipt reference.",
            code: "REFERENCE_MISMATCH",
          };
        }
        return normalizeCbe(reference, receipt);
      }
    } catch (error) {
      lastError = toOwnedVerifierError(error, "CBE relay");
    }
  }
  if (lastError) throw lastError;
  return {
    ok: false,
    provider: "cbe",
    error: "CBE receipt was not found or was incomplete.",
    code: "RECEIPT_NOT_FOUND",
  };
}
