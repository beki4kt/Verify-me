import axios from "axios";
import pdfParse from "pdf-parse";

import {
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
  titleCase,
  toOwnedVerifierError,
} from "./common";
import {
  OwnedVerificationResult,
  OwnedVerifierError,
  Provider,
} from "./types";

function failed(
  provider: Provider,
  error: string,
  code = "RECEIPT_MISMATCH",
): OwnedVerificationResult {
  return { ok: false, provider, error, code };
}

function rowValue(raw: Record<string, unknown>, ...keys: string[]): unknown {
  for (const key of keys) {
    if (raw[key] !== undefined && raw[key] !== null) return raw[key];
  }
  return null;
}

export async function verifyAbyssiniaOwned(
  rawReference: string,
  rawSuffix: string,
): Promise<OwnedVerificationResult> {
  const reference = rawReference.trim().toUpperCase();
  const suffix = rawSuffix.trim();
  if (!/^FT[A-Z0-9]{10}$/.test(reference) || !/^\d{5}$/.test(suffix)) {
    return failed(
      "abyssinia",
      "Abyssinia verification requires an FT reference and 5-digit account suffix.",
      "INVALID_REFERENCE",
    );
  }
  try {
    const base = providerUrl(
      "ABYSSINIA_RECEIPT_BASE_URL",
      "https://cs.bankofabyssinia.com/api/onlineSlip/getDetails/",
    );
    const url = new URL(base);
    url.searchParams.set("id", `${reference}${suffix}`);
    const response = await axios.get<unknown>(url.toString(), {
      timeout: configuredTimeout(),
      maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
      headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    if (!response.data || typeof response.data !== "object") {
      return failed("abyssinia", "Abyssinia returned an invalid receipt response.");
    }
    const envelope = response.data as Record<string, unknown>;
    const header = envelope.header as Record<string, unknown> | undefined;
    const rows = Array.isArray(envelope.body) ? envelope.body : [];
    if (String(header?.status ?? "").toLowerCase() !== "success" || !rows[0]) {
      return failed(
        "abyssinia",
        "Abyssinia receipt was not found.",
        "RECEIPT_NOT_FOUND",
      );
    }
    const raw = rows[0] as Record<string, unknown>;
    const amount = numberFrom(
      rowValue(raw, "Transferred Amount", "Total Amount including VAT"),
    );
    const txnDate = ethiopianLocalDate(rowValue(raw, "Transaction Date"));
    const returnedReference = nonEmpty(
      rowValue(raw, "Transaction Reference", "Payment Reference"),
    );
    if (
      amount === null ||
      amount <= 0 ||
      !txnDate ||
      !returnedReference ||
      !referencesMatch(reference, returnedReference)
    ) {
      return failed("abyssinia", "Abyssinia receipt is missing required fields.");
    }
    return {
      ok: true,
      provider: "abyssinia",
      data: {
        reference: returnedReference,
        amount,
        currency: "ETB",
        payerName: nonEmpty(rowValue(raw, "Payer's Name", "Source Account Name")),
        payerAccount: nonEmpty(rowValue(raw, "Source Account", "Payer's Account")),
        receiverName: nonEmpty(rowValue(raw, "Receiver's Name", "Beneficiary Name")),
        receiverAccount: nonEmpty(
          rowValue(raw, "Receiver's Account", "Beneficiary Account"),
        ),
        txnDate,
        status: "completed",
        statusText: "completed",
        reason: nonEmpty(rowValue(raw, "Narrative", "Transaction Type")),
        raw: safeRaw(raw),
      },
    };
  } catch (error) {
    throw toOwnedVerifierError(error, "Abyssinia");
  }
}

interface DashenReceipt {
  senderName: string | null;
  senderAccount: string | null;
  receiverName: string | null;
  receiverAccount: string | null;
  phone: string | null;
  reference: string | null;
  date: string | null;
  amount: number | null;
  total: number | null;
  raw: Record<string, unknown>;
}

export function parseDashenText(rawText: string): DashenReceipt {
  const text = rawText.replace(/\s+/g, " ").trim();
  const amount = numberFrom(
    text.match(/Transaction\s*Amount\s*(?:ETB|Birr)?\s*:?\s*([\d,]+\.?\d*)/i)?.[1],
  );
  const total = numberFrom(
    text.match(/Total\s*(?:ETB|Birr)?\s*:?\s*([\d,]+\.?\d*)/i)?.[1],
  );
  const raw = {
    senderName: nonEmpty(
      text.match(/Sender\s*Name\s*:?\s*(.*?)\s+(?:Sender\s*Account|Account)/i)?.[1],
    ),
    senderAccount: nonEmpty(
      text.match(/Sender\s*Account\s*(?:Number)?\s*:?\s*([A-Z0-9*-]+)/i)?.[1],
    ),
    receiverName: nonEmpty(
      text.match(/Receiver\s*Name\s*:?\s*(.*?)\s+(?:Receiver\s*Account|Phone|Institution)/i)?.[1],
    ),
    receiverAccount: nonEmpty(
      text.match(/Receiver\s*Account\s*(?:Number)?\s*:?\s*([A-Z0-9*+-]+)/i)?.[1],
    ),
    phone: nonEmpty(
      text.match(/Phone\s*(?:No\.?|Number)?\s*:?\s*([+\d\s-]{9,})/i)?.[1],
    ),
    reference: nonEmpty(
      text.match(/Transaction\s*Reference\s*:?\s*([A-Z0-9-]+)/i)?.[1],
    ),
    date: ethiopianLocalDate(
      text.match(
        /Transaction\s*Date\s*(?:&\s*Time)?\s*:?\s*([\d/\-,: ]+(?:AM|PM)?)/i,
      )?.[1],
    ),
    amount,
    total,
  };
  return {
    senderName: titleCase(raw.senderName),
    senderAccount: raw.senderAccount,
    receiverName: titleCase(raw.receiverName),
    receiverAccount: raw.receiverAccount,
    phone: raw.phone,
    reference: raw.reference,
    date: raw.date,
    amount,
    total,
    raw,
  };
}

export async function parseDashenPdf(buffer: Buffer): Promise<DashenReceipt> {
  const parsed = await pdfParse(buffer);
  return parseDashenText(parsed.text);
}

export async function verifyDashenOwned(
  rawReference: string,
): Promise<OwnedVerificationResult> {
  const reference = rawReference.trim().toUpperCase();
  if (!/^[A-Z0-9-]{8,32}$/.test(reference)) {
    return failed("dashen", "Invalid Dashen receipt reference.", "INVALID_REFERENCE");
  }
  try {
    const base = providerUrl(
      "DASHEN_RECEIPT_BASE_URL",
      "https://receipt.dashensuperapp.com/receipt",
    );
    const response = await axios.get<ArrayBuffer>(
      `${base.replace(/\/$/, "")}/${encodeURIComponent(reference)}`,
      {
        responseType: "arraybuffer",
        timeout: configuredTimeout(),
        maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
        headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
      },
    );
    const receipt = await parseDashenPdf(Buffer.from(response.data));
    if (
      receipt.amount === null ||
      receipt.amount <= 0 ||
      !receipt.date ||
      !receipt.reference ||
      !referencesMatch(reference, receipt.reference)
    ) {
      return failed("dashen", "Dashen receipt is missing required verified fields.");
    }
    return {
      ok: true,
      provider: "dashen",
      data: {
        reference: receipt.reference,
        amount: receipt.amount,
        totalAmount: receipt.total,
        currency: "ETB",
        payerName: receipt.senderName,
        payerAccount: receipt.senderAccount,
        receiverName: receipt.receiverName,
        receiverAccount: receipt.receiverAccount ?? receipt.phone,
        txnDate: receipt.date,
        status: "completed",
        statusText: "completed",
        raw: receipt.raw,
      },
    };
  } catch (error) {
    throw toOwnedVerifierError(error, "Dashen");
  }
}

interface WalletPdfReceipt {
  payerName: string | null;
  payerAccount: string | null;
  receiverName: string | null;
  receiverAccount: string | null;
  transactionId: string | null;
  receiptNo: string | null;
  date: string | null;
  amount: number | null;
  serviceFee: number | null;
  vat: number | null;
  status: string | null;
  raw: Record<string, unknown>;
}

interface CbeBirrReceipt {
  payerName: string | null;
  payerAccount: string | null;
  receiverName: string | null;
  receiverAccount: string | null;
  orderId: string | null;
  reference: string | null;
  receiptNo: string | null;
  date: string | null;
  amount: number | null;
  paidAmount: number | null;
  serviceFee: number | null;
  vat: number | null;
  totalPaidAmount: number | null;
  status: string | null;
  reason: string | null;
  paymentChannel: string | null;
  raw: Record<string, unknown>;
}

/** CBE Birr has its own receipt layout; it is not an M-Pesa wallet PDF. */
export function parseCbeBirrText(rawText: string): CbeBirrReceipt {
  const text = rawText.replace(/\s+/g, " ").trim();
  const receiptRow = text.match(
    /([A-Z0-9]{8,32})\s*(20\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s*([\d,.]+)/i,
  );
  const financialRow = text.match(
    /([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)\s+Paid amount/i,
  );
  const payerName = nonEmpty(
    text.match(/Customer Name\s*:?[\s]*?(.*?)(?=\s+(?:Debit Account|Credit Account))/i)?.[1] ??
      text.match(/Sub city:\s*([A-Z][A-Z ]+?)(?=\s+Wereda\/kebele:)/i)?.[1],
  );
  const payerAccount = nonEmpty(
    text.match(/Debit Account\s*(Org Account|.*?)(?=\s+Credit Account)/i)?.[1],
  );
  const receiverAccount = nonEmpty(
    text.match(/Credit Account\s*(.*?)(?=\s+Receiver Name)/i)?.[1],
  );
  const receiverName = nonEmpty(
    text.match(/Receiver Name\s*(.*?)(?=\s+Order ID)/i)?.[1],
  );
  const orderId = nonEmpty(text.match(/Order ID\s*([A-Z0-9-]+)/i)?.[1]);
  const status = nonEmpty(
    text.match(/Transaction Status\s*([A-Za-z ]+?)(?=\s+(?:Reference|Transaction Details|Receipt Number))/i)?.[1],
  );
  const reference = nonEmpty(
    text.match(/Reference[\s:]*(.*?)(?=\s*(?:Transaction Details|Receipt Number|Commercial Bank))/i)?.[1],
  );
  const receiptNo = nonEmpty(receiptRow?.[1]);
  const date = ethiopianLocalDate(receiptRow?.[2]);
  const amount = numberFrom(receiptRow?.[3]);
  const paidAmount = numberFrom(financialRow?.[1]);
  const serviceFee = numberFrom(financialRow?.[2]);
  const vat = numberFrom(financialRow?.[3]);
  const totalPaidAmount = numberFrom(financialRow?.[4]);
  const paymentDetails = text.match(
    /Payment Channel\s+(.*?)\s+(.*?)\s+([A-Z][A-Z0-9 ]+?)(?=\s|$)/i,
  );
  const reason = nonEmpty(paymentDetails?.[2]);
  const paymentChannel = nonEmpty(paymentDetails?.[3]);
  const raw = {
    payerName,
    payerAccount,
    receiverName,
    receiverAccount,
    orderId,
    reference,
    receiptNo,
    date,
    amount,
    paidAmount,
    serviceFee,
    vat,
    totalPaidAmount,
    status,
    reason,
    paymentChannel,
  };
  return {
    ...raw,
    payerName: titleCase(payerName),
    receiverName: titleCase(receiverName),
    raw,
  };
}

export async function parseCbeBirrPdf(buffer: Buffer): Promise<CbeBirrReceipt> {
  const parsed = await pdfParse(buffer);
  return parseCbeBirrText(parsed.text);
}

export function parseWalletText(rawText: string): WalletPdfReceipt {
  const text = rawText.replace(/\s+/g, " ").trim();
  const payerName = nonEmpty(
    text.match(/PAYER NAME\s+(.*?)\s+(?:PAYER PHONE|\+?251|09\d)/i)?.[1],
  );
  const payerAccount = nonEmpty(
    text.match(/PAYER (?:PHONE NUMBER|ACCOUNT)\s+([+\d*]+)/i)?.[1],
  );
  const receiverName = nonEmpty(
    text.match(/RECEIVER NAME\s+(.*?)(?=\s+(?:RECEIVER NUMBER|RECEIVER ACCOUNT|\/))/i)?.[1],
  );
  const receiverAccount = nonEmpty(
    text.match(/RECEIVER (?:NUMBER|ACCOUNT)\s+([+\d*]+)/i)?.[1],
  );
  const transactionId = nonEmpty(
    text.match(/TRANSACTION ID\s+([A-Z0-9-]+)/i)?.[1],
  );
  const receiptNo = nonEmpty(
    text.match(/RECEIPT NO.*?([A-Z0-9]{8,32})(?=\s*20\d{2}|\s)/i)?.[1],
  );
  const amount = numberFrom(
    text.match(/(?:PAID AMOUNT|TOTAL)\s+([\d,]+\.\d{2})/i)?.[1],
  );
  const serviceFee = numberFrom(
    text.match(/([\d,]+\.\d{2})\s*Birr\s*\/\s*SERVICE FEE/i)?.[1],
  );
  const vat = numberFrom(
    text.match(/SERVICE FEE\s*\/\s*([\d,]+\.\d{2})\s*.*?15% VAT/i)?.[1],
  );
  const date = ethiopianLocalDate(
    text.match(/(20\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)/)?.[1],
  );
  const status = nonEmpty(
    text.match(/TRANSACTION STATUS\s+([A-Za-z ]+?)(?=\s+[A-Z][A-Z ]{3,}|$)/i)?.[1],
  );
  const raw = {
    payerName,
    payerAccount,
    receiverName,
    receiverAccount,
    transactionId,
    receiptNo,
    date,
    amount,
    serviceFee,
    vat,
    status,
  };
  return {
    payerName: titleCase(payerName),
    payerAccount,
    receiverName: titleCase(receiverName),
    receiverAccount,
    transactionId,
    receiptNo,
    date,
    amount,
    serviceFee,
    vat,
    status,
    raw,
  };
}

export async function parseWalletPdf(buffer: Buffer): Promise<WalletPdfReceipt> {
  const parsed = await pdfParse(buffer);
  return parseWalletText(parsed.text);
}

function normalizeWalletPdf(
  provider: "mpesa",
  submittedReference: string,
  receipt: WalletPdfReceipt,
): OwnedVerificationResult {
  const returnedReference = receipt.receiptNo ?? receipt.transactionId;
  const referenceMatchesReceipt =
    referencesMatch(submittedReference, receipt.receiptNo) ||
    referencesMatch(submittedReference, receipt.transactionId);
  if (
    receipt.amount === null ||
    receipt.amount <= 0 ||
    !receipt.date ||
    !receipt.receiverAccount ||
    !returnedReference ||
    !referenceMatchesReceipt ||
    (receipt.status && !completedStatus(receipt.status))
  ) {
    return failed(provider, "M-Pesa receipt is missing required verified fields.");
  }
  return {
    ok: true,
    provider,
    data: {
      reference: returnedReference,
      amount: receipt.amount,
      currency: "ETB",
      payerName: receipt.payerName,
      payerAccount: receipt.payerAccount,
      payerPhone: receipt.payerAccount,
      receiverName: receipt.receiverName,
      receiverAccount: receipt.receiverAccount,
      txnDate: receipt.date,
      status: "completed",
      statusText: receipt.status ?? "completed",
      serviceFee: receipt.serviceFee,
      serviceFeeVAT: receipt.vat,
      raw: receipt.raw,
    },
  };
}

function normalizeCbeBirr(
  submittedReference: string,
  receipt: CbeBirrReceipt,
): OwnedVerificationResult {
  if (
    receipt.amount === null ||
    receipt.amount <= 0 ||
    !receipt.date ||
    !receipt.receiverAccount ||
    !receipt.receiptNo ||
    !referencesMatch(submittedReference, receipt.receiptNo) ||
    !receipt.status ||
    !completedStatus(receipt.status)
  ) {
    return failed(
      "cbebirr",
      "CBE Birr receipt is missing required verified fields.",
    );
  }
  return {
    ok: true,
    provider: "cbebirr",
    data: {
      reference: receipt.receiptNo,
      amount: receipt.amount,
      totalAmount: receipt.totalPaidAmount,
      currency: "ETB",
      payerName: receipt.payerName,
      payerAccount: receipt.payerAccount,
      receiverName: receipt.receiverName,
      receiverAccount: receipt.receiverAccount,
      txnDate: receipt.date,
      status: "completed",
      statusText: receipt.status,
      serviceFee: receipt.serviceFee,
      serviceFeeVAT: receipt.vat,
      reason: receipt.reason,
      raw: receipt.raw,
    },
  };
}

export async function verifyCbeBirrOwned(
  rawReference: string,
  phoneNumber: string,
): Promise<OwnedVerificationResult> {
  const reference = rawReference.trim().toUpperCase();
  if (!/^[A-Z0-9-]{8,32}$/.test(reference) || !/^251[97]\d{8}$/.test(phoneNumber)) {
    return failed(
      "cbebirr",
      "CBE Birr requires a valid receipt number and Ethiopian phone number.",
      "INVALID_REFERENCE",
    );
  }
  try {
    const base = providerUrl(
      "CBEBIRR_RECEIPT_BASE_URL",
      "https://cbepay1.cbe.com.et/aureceipt",
    );
    const url = new URL(base);
    url.searchParams.set("TID", reference);
    url.searchParams.set("PH", phoneNumber);
    const response = await axios.get<ArrayBuffer>(url.toString(), {
      responseType: "arraybuffer",
      timeout: configuredTimeout(),
      maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
      headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    return normalizeCbeBirr(
      reference,
      await parseCbeBirrPdf(Buffer.from(response.data)),
    );
  } catch (error) {
    throw toOwnedVerifierError(error, "CBE Birr");
  }
}

async function fetchMpesaPayload(
  reference: string,
  useRelay: boolean,
): Promise<Record<string, unknown>> {
  let url: URL;
  if (useRelay) {
    const proxyUrl = process.env.MPESA_PROXY_URL?.trim() || "";
    const proxyKey = process.env.MPESA_PROXY_KEY?.trim() || "";
    if (!proxyUrl || !proxyKey) {
      throw new OwnedVerifierError(
        "M-Pesa relay mode requires MPESA_PROXY_URL and MPESA_PROXY_KEY.",
        "VERIFIER_CONFIGURATION_ERROR",
        503,
        false,
      );
    }
    url = new URL(
      relayUrl(proxyUrl, { reference, key: proxyKey }, "MPESA_PROXY_URL"),
    );
  } else {
    url = new URL(
      providerUrl(
        "MPESA_RECEIPT_URL",
        "https://m-pesabusiness.safaricom.et/api/receipt/getReceipt",
      ),
    );
    url.searchParams.set("trxNo", reference);
  }
  const response = await axios.get<unknown>(url.toString(), {
    timeout: configuredTimeout(),
    maxContentLength: MAX_PROVIDER_RESPONSE_BYTES,
    headers: {
      Accept: "application/json",
      Referer: "https://m-pesabusiness.safaricom.et/",
      "User-Agent": "CHEKMI-Verifier/1.0",
    },
  });
  if (!response.data || typeof response.data !== "object") {
    throw new OwnedVerifierError("M-Pesa returned an invalid response.");
  }
  return response.data as Record<string, unknown>;
}

export async function verifyMpesaOwned(
  rawReference: string,
): Promise<OwnedVerificationResult> {
  const reference = rawReference.trim().toUpperCase();
  if (!/^[A-Z0-9-]{6,32}$/.test(reference)) {
    return failed("mpesa", "Invalid M-Pesa receipt reference.", "INVALID_REFERENCE");
  }
  let lastError: OwnedVerifierError | null = null;
  for (const useRelay of [
    ...(shouldUseDirectProvider() ? [false] : []),
    ...(shouldUseProviderRelays() ? [true] : []),
  ]) {
    try {
      const payload = await fetchMpesaPayload(reference, useRelay);
      if (String(payload.responseCode) !== "0" || !nonEmpty(payload.base64Data)) {
        continue;
      }
      const pdf = Buffer.from(String(payload.base64Data), "base64");
      if (pdf.length === 0 || pdf.length > MAX_PROVIDER_RESPONSE_BYTES) {
        return failed("mpesa", "M-Pesa returned an invalid receipt document.");
      }
      return normalizeWalletPdf("mpesa", reference, await parseWalletPdf(pdf));
    } catch (error) {
      lastError = toOwnedVerifierError(error, useRelay ? "M-Pesa relay" : "M-Pesa");
    }
  }
  if (lastError) throw lastError;
  return failed("mpesa", "M-Pesa receipt was not found.", "RECEIPT_NOT_FOUND");
}
