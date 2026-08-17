export declare function normalizeAccount(value: unknown): string;
/**
 * Provider APIs sometimes mask the leading account digits. We require at
 * least six stable characters and accept exact or suffix-equivalent matches.
 */
export declare function matchesReceivingAccount(configuredAccount: unknown, verifiedAccount: unknown, minimumStableCharacters?: number): boolean;
/**
 * Abyssinia verifies the credit account through a five-digit suffix supplied
 * with the upstream request, but its normalized success payload does not
 * return receiverAccount. The suffix must therefore come from the tenant's
 * server-side configuration, never from Flutter input.
 */
export declare function authoritativeAbyssiniaSuffix(configuredAccount: unknown): string | null;
export type TransactionFreshnessResult = {
    ok: true;
    transactionDate: Date;
} | {
    ok: false;
    code: "TRANSACTION_DATE_MISSING" | "TRANSACTION_DATE_INVALID" | "TRANSACTION_TOO_OLD" | "TRANSACTION_DATE_IN_FUTURE";
    message: string;
};
export declare function validateTransactionFreshness(providerDate: unknown, options?: {
    now?: Date;
    maxAgeMinutes?: number;
    maxFutureSkewMinutes?: number;
}): TransactionFreshnessResult;
export declare function positiveAmount(value: unknown): number | null;
//# sourceMappingURL=paymentSecurity.d.ts.map