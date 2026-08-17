"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeAccount = normalizeAccount;
exports.matchesReceivingAccount = matchesReceivingAccount;
exports.authoritativeAbyssiniaSuffix = authoritativeAbyssiniaSuffix;
exports.validateTransactionFreshness = validateTransactionFreshness;
exports.positiveAmount = positiveAmount;
function normalizeAccount(value) {
    const normalized = String(value ?? "")
        .toLowerCase()
        .replace(/[^a-z0-9]/g, "");
    // Ethiopian mobile wallets commonly return the same account as 09...,
    // 9..., or +2519.... Canonicalize only phone-shaped values; bank account
    // numbers keep their original digits.
    if (/^09\d{8}$/.test(normalized))
        return `251${normalized.slice(1)}`;
    if (/^9\d{8}$/.test(normalized))
        return `251${normalized}`;
    return normalized;
}
/**
 * Provider APIs sometimes mask the leading account digits. We require at
 * least six stable characters and accept exact or suffix-equivalent matches.
 */
function matchesReceivingAccount(configuredAccount, verifiedAccount, minimumStableCharacters = 6) {
    const configured = normalizeAccount(configuredAccount);
    const verified = normalizeAccount(verifiedAccount);
    if (configured.length < minimumStableCharacters ||
        verified.length < minimumStableCharacters)
        return false;
    return (configured === verified ||
        configured.endsWith(verified) ||
        verified.endsWith(configured));
}
/**
 * Abyssinia verifies the credit account through a five-digit suffix supplied
 * with the upstream request, but its normalized success payload does not
 * return receiverAccount. The suffix must therefore come from the tenant's
 * server-side configuration, never from Flutter input.
 */
function authoritativeAbyssiniaSuffix(configuredAccount) {
    const digits = String(configuredAccount ?? "").replace(/\D/g, "");
    return digits.length >= 5 ? digits.slice(-5) : null;
}
function validateTransactionFreshness(providerDate, options = {}) {
    if (providerDate === null || providerDate === undefined || String(providerDate).trim() === "") {
        return {
            ok: false,
            code: "TRANSACTION_DATE_MISSING",
            message: "The provider did not return a transaction date.",
        };
    }
    const transactionDate = new Date(String(providerDate));
    if (Number.isNaN(transactionDate.valueOf())) {
        return {
            ok: false,
            code: "TRANSACTION_DATE_INVALID",
            message: "The provider returned an invalid transaction date.",
        };
    }
    const now = options.now ?? new Date();
    const maxAgeMinutes = options.maxAgeMinutes ?? 24 * 60;
    const maxFutureSkewMinutes = options.maxFutureSkewMinutes ?? 10;
    const ageMs = now.valueOf() - transactionDate.valueOf();
    if (ageMs > maxAgeMinutes * 60000) {
        return {
            ok: false,
            code: "TRANSACTION_TOO_OLD",
            message: `The payment is older than the allowed ${maxAgeMinutes}-minute verification window.`,
        };
    }
    if (ageMs < -maxFutureSkewMinutes * 60000) {
        return {
            ok: false,
            code: "TRANSACTION_DATE_IN_FUTURE",
            message: "The provider transaction date is unexpectedly in the future.",
        };
    }
    return { ok: true, transactionDate };
}
function positiveAmount(value) {
    const parsed = typeof value === "number" ? value : Number(value);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}
//# sourceMappingURL=paymentSecurity.js.map