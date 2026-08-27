import { OwnedVerifierError } from "./types";
export declare const DEFAULT_TIMEOUT_MS = 20000;
export declare const MAX_PROVIDER_RESPONSE_BYTES: number;
export declare function configuredTimeout(): number;
export declare function envFlag(name: string): boolean;
export declare function ownedVerifierConfiguration(env?: NodeJS.ProcessEnv): {
    configured: boolean;
    mode: string;
    directEthiopianEgressRequired: boolean;
    relays: {
        telebirr: boolean;
        cbe: boolean;
        mpesa: boolean;
    };
    newCbeDirectConfigured: boolean;
};
export declare function shouldUseDirectProvider(): boolean;
export declare function shouldUseProviderRelays(): boolean;
export declare function providerUrl(envName: string, officialUrl: string): string;
export declare function validateProviderUrl(value: string, label: string): URL;
export declare function appendPath(base: string, path: string): string;
export declare function relayUrl(rawUrl: string, params: Record<string, string>, label: string): string;
export declare function numberFrom(value: unknown): number | null;
export declare function nonEmpty(value: unknown): string | null;
export declare function titleCase(value: string | null): string | null;
/** Provider timestamps without offsets are Ethiopian local time (UTC+3). */
export declare function ethiopianLocalDate(value: unknown): string | null;
export declare function completedStatus(value: unknown): boolean;
export declare function referencesMatch(left: unknown, right: unknown): boolean;
/** Keep evidence useful without storing multi-megabyte PDF/base64 fields. */
export declare function safeRaw(raw: Record<string, unknown>): Record<string, unknown>;
export declare function toOwnedVerifierError(error: unknown, providerLabel: string): OwnedVerifierError;
//# sourceMappingURL=common.d.ts.map