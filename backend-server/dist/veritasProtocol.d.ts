import type { OwnedVerificationResult, Provider } from "./ownedVerifier/types";
import type { OwnedVerifierInput } from "./ownedVerifier";
export declare function veritasRequest(provider: Provider, input: OwnedVerifierInput): {
    path: string;
    body: Record<string, string>;
    reference: string;
};
export declare function normalizeVeritas(provider: Provider, submitted: string, payload: unknown): OwnedVerificationResult;
//# sourceMappingURL=veritasProtocol.d.ts.map