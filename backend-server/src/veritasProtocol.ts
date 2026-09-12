import { completedStatus, ethiopianLocalDate, extractLegacyCbeUrlData, extractNewCbeToken, nonEmpty, referencesMatch, safeRaw } from "./receiptFormat";
import type { OwnedVerificationResult, Provider } from "./ownedVerifier/types";
import type { OwnedVerifierInput } from "./ownedVerifier";

type Json = Record<string, unknown>;
const object = (value: unknown): Json | null =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Json : null;

// Whitelist the ID lookup fields. A photo, staff token, amount, or business
// reference must never be forwarded to Veritas's image or commerce endpoints.
export function veritasRequest(provider: Provider, input: OwnedVerifierInput) {
  let reference = (input.reference ?? input.receiptNumber ?? "").trim();
  if (provider === "cbe") reference = extractLegacyCbeUrlData(reference)?.reference ?? reference;
  if (provider !== "cbe" || !extractNewCbeToken(reference)) reference = reference.toUpperCase();
  const body: Record<string, string> = provider === "cbebirr"
    ? { receiptNumber: reference, phoneNumber: (input.phoneNumber ?? "").replace(/[\s()+-]/g, "").replace(/^0/, "251") }
    : { reference };
  if (provider === "cbe" && input.suffix) body.accountSuffix = input.suffix;
  if (provider === "abyssinia") body.suffix = input.suffix ?? "";
  return { path: `/verify-${provider}`, body, reference };
}

function field(raw: Json, ...keys: string[]): unknown {
  for (const key of keys) if (raw[key] !== null && raw[key] !== undefined) return raw[key];
  return null;
}

// Accept monetary numbers and provider-formatted ETB values, not arbitrary text
// with a number embedded in it. Never substitute the submitted amount.
function money(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string") return null;
  const text = value.trim().replace(/^(?:ETB|Birr)\s*/i, "").replace(/\s*(?:ETB|Birr)$/i, "").trim();
  if (!/^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$/.test(text)) return null;
  const amount = Number(text.replace(/,/g, ""));
  return Number.isFinite(amount) ? amount : null;
}

export function normalizeVeritas(provider: Provider, submitted: string, payload: unknown): OwnedVerificationResult {
  const fail = (error: string): OwnedVerificationResult => ({ ok: false, provider, error, code: "NOT_VERIFIED" });
  let raw = object(payload);
  if (!raw) return fail("Veritas returned an invalid receipt response.");
  let explicitSuccess = false;
  // Provider envelopes differ: Telebirr is data-wrapped, Abyssinia can have
  // two wrappers, while CBE/Dashen/M-Pesa can return fields at the top level.
  for (let depth = 0; depth < 4; depth++) {
    if (raw.success === false || raw.verified === false || raw.ok === false || raw.error) {
      return fail("Veritas could not verify this transaction. Check the reference and provider.");
    }
    explicitSuccess ||= raw.success === true || raw.verified === true;
    const nested = object(raw.data);
    if (!nested) break;
    raw = nested;
  }
  const header = object(raw.header);
  if (header) {
    if (!completedStatus(header.status)) return fail("Veritas returned an unsuccessful bank response.");
    const row = Array.isArray(raw.body) ? object(raw.body[0]) : null;
    if (!row) return fail("Veritas returned no receipt details.");
    raw = row;
    explicitSuccess = true;
  }
  // CBE Birr's `reference` is free-form payment text; receiptNumber is the ID.
  // M-Pesa exposes both a transaction ID and a receipt number.
  const reference = nonEmpty(provider === "cbebirr" ? raw.receiptNumber
    : provider === "mpesa" ? field(raw, "transactionId", "receiptNo", "receiptNumber")
    : field(raw, "reference", "receiptNo", "receiptNumber", "transactionReference", "id", "Transaction Reference", "Payment Reference"));
  const amount = money(field(raw, "settledAmount", "transferredAmount", "transactionAmount", "amountCredited", "amount", "Transferred Amount"));
  const dateTimes = Array.isArray(raw.dateTimes) ? raw.dateTimes : [];
  const txnDate = ethiopianLocalDate(field(raw, "txnDate", "paymentDate", "transactionDate", "date", "Transaction Date") ?? dateTimes[0]);
  const status = nonEmpty(field(raw, "transactionStatus", "status", "statusText"));
  if ((status && !completedStatus(status)) || (provider === "telebirr" && !completedStatus(status))) {
    return fail("The provider has not confirmed a completed payment.");
  }
  if (!explicitSuccess && !completedStatus(status)) return fail("Veritas did not confirm verification.");
  const lookupReference = provider === "cbe" ? extractLegacyCbeUrlData(submitted)?.reference ?? submitted : submitted;
  const matchesReference = referencesMatch(lookupReference, reference)
    || (provider === "mpesa" && referencesMatch(lookupReference, raw.receiptNo));
  if (!reference || (!(provider === "cbe" && extractNewCbeToken(lookupReference)) && !matchesReference)) {
    return fail("The returned bank reference does not match this payment.");
  }
  if (amount === null || amount <= 0 || !txnDate) return fail("Veritas returned incomplete payment amount or date details.");
  const currency = nonEmpty(raw.currency)?.toUpperCase() ?? "ETB";
  if (currency !== "ETB" && currency !== "BIRR") return fail("This payment is not denominated in ETB.");
  return { ok: true, provider, data: {
    reference, amount, currency: "ETB", txnDate,
    status: "completed", statusText: status,
    receiverAccount: nonEmpty(field(raw, "receiverAccount", "receiverAccountNumber", "creditedPartyAccountNo", "creditAccount", "creditAccountNo", "phoneNo", "Receiver's Account", "Beneficiary Account")),
    receiverName: nonEmpty(field(raw, "receiverName", "receiver", "creditedPartyName", "creditAccountHolder", "Receiver's Name", "Beneficiary Name")),
    payerAccount: nonEmpty(field(raw, "payerAccount", "payerTelebirrNo", "senderAccountNumber", "senderAccount", "debitAccount", "debitAccountNo", "Source Account", "Payer's Account")),
    payerName: nonEmpty(field(raw, "payerName", "payer", "customerName", "senderName", "debitAccountHolder", "Payer's Name", "Source Account Name")),
    totalAmount: money(field(raw, "totalPaidAmount", "totalAmount", "total")),
    serviceFee: money(field(raw, "serviceFee", "serviceCharge")),
    raw: safeRaw(raw),
  } };
}
