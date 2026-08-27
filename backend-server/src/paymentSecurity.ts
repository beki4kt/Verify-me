export function normalizeAccount(value: unknown): string {
  const normalized = String(value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
  // Ethiopian mobile wallets commonly return the same account as 09...,
  // 9..., or +2519.... Canonicalize only phone-shaped values; bank account
  // numbers keep their original digits.
  if (/^0[79]\d{8}$/.test(normalized)) return `251${normalized.slice(1)}`;
  if (/^[79]\d{8}$/.test(normalized)) return `251${normalized}`;
  return normalized;
}

/**
 * Provider APIs sometimes mask the leading account digits. We require at
 * least six stable characters and accept exact or suffix-equivalent matches.
 */
export function matchesReceivingAccount(
  configuredAccount: unknown,
  verifiedAccount: unknown,
  minimumStableCharacters = 6,
): boolean {
  const configured = normalizeAccount(configuredAccount);
  const verified = normalizeAccount(verifiedAccount);
  if (
    configured.length < minimumStableCharacters ||
    verified.length < minimumStableCharacters
  ) return false;
  return (
    configured === verified ||
    configured.endsWith(verified) ||
    verified.endsWith(configured)
  );
}

/** Match CBE's first-character plus final-four account mask. */
export function matchesCbeReceivingAccount(
  configuredAccount: unknown,
  verifiedAccount: unknown,
): boolean {
  const configured = normalizeAccount(configuredAccount);
  const rawVerified = String(verifiedAccount ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9*]/g, "");
  if (!rawVerified.includes("*")) {
    return matchesReceivingAccount(configuredAccount, verifiedAccount);
  }
  const match = rawVerified.match(/^([a-z0-9])\*+([a-z0-9]{4})$/);
  if (!match || configured.length < 8) return false;
  return configured.startsWith(match[1] ?? "") && configured.endsWith(match[2] ?? "");
}

/**
 * Abyssinia verifies the credit account through a five-digit suffix supplied
 * with the upstream request, but its normalized success payload does not
 * return receiverAccount. The suffix must therefore come from the tenant's
 * server-side configuration, never from Flutter input.
 */
export function authoritativeAbyssiniaSuffix(
  configuredAccount: unknown,
): string | null {
  return authoritativeAccountSuffix(configuredAccount, 5);
}

/**
 * Provider lookup parameters must be derived from the authenticated tenant's
 * configured receiving account, never supplied by a waiter client.
 */
export function authoritativeAccountSuffix(
  configuredAccount: unknown,
  length: number,
): string | null {
  if (!Number.isInteger(length) || length <= 0) return null;
  const digits = String(configuredAccount ?? "").replace(/\D/g, "");
  return digits.length >= length ? digits.slice(-length) : null;
}

export function authoritativeEthiopianPhone(
  configuredAccount: unknown,
): string | null {
  const normalized = normalizeAccount(configuredAccount);
  return /^251[79]\d{8}$/.test(normalized) ? normalized : null;
}

export type TransactionFreshnessResult =
  | { ok: true; transactionDate: Date }
  | {
      ok: false;
      code:
        | "TRANSACTION_DATE_MISSING"
        | "TRANSACTION_DATE_INVALID"
        | "TRANSACTION_TOO_OLD"
        | "TRANSACTION_DATE_IN_FUTURE";
      message: string;
    };

export function validateTransactionFreshness(
  providerDate: unknown,
  options: {
    now?: Date;
    maxAgeMinutes?: number;
    maxFutureSkewMinutes?: number;
  } = {},
): TransactionFreshnessResult {
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

  if (ageMs > maxAgeMinutes * 60_000) {
    return {
      ok: false,
      code: "TRANSACTION_TOO_OLD",
      message: `The payment is older than the allowed ${maxAgeMinutes}-minute verification window.`,
    };
  }
  if (ageMs < -maxFutureSkewMinutes * 60_000) {
    return {
      ok: false,
      code: "TRANSACTION_DATE_IN_FUTURE",
      message: "The provider transaction date is unexpectedly in the future.",
    };
  }
  return { ok: true, transactionDate };
}

export function positiveAmount(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}
