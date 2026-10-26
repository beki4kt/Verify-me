export declare function nonEmpty(value: unknown): string | null;
export declare function titleCase(value: string | null): string | null;
/** Provider timestamps without offsets are Ethiopian local time (UTC+3). */
export declare function ethiopianLocalDate(value: unknown): string | null;
export declare function completedStatus(value: unknown): boolean;
export declare function referencesMatch(left: unknown, right: unknown): boolean;
/** Keep evidence useful without storing multi-megabyte PDF/base64 fields. */
export declare function safeRaw(raw: Record<string, unknown>): Record<string, unknown>;
export declare function extractNewCbeToken(input: string): string | null;
export declare function isLegacyCbeReference(input: string): boolean;
export declare function extractLegacyCbeUrlData(input: string): {
    reference: string;
    suffix: string;
} | null;
//# sourceMappingURL=receiptFormat.d.ts.map