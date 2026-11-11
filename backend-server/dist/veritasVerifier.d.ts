import { type Provider, type OwnedVerificationResult } from "./ownedVerifier/types";
import type { OwnedVerifierInput } from "./ownedVerifier";
export { normalizeVeritas, veritasRequest } from "./veritasProtocol";
export declare function verifierConfiguration(env?: NodeJS.ProcessEnv): {
    configured: boolean;
    mode: string;
    directEthiopianEgressRequired: boolean;
    relays: {
        telebirr: boolean;
        cbe: boolean;
        mpesa: boolean;
    };
    newCbeDirectConfigured: boolean;
    legacyCbeEnabled: boolean;
    engine: string;
    imageVerification?: undefined;
} | {
    engine: string;
    configured: boolean;
    mode: string;
    imageVerification?: undefined;
} | {
    engine: string;
    mode: string;
    configured: boolean;
    imageVerification: boolean;
};
export declare function verifyWithVeritas(provider: Provider, input: OwnedVerifierInput): Promise<OwnedVerificationResult>;
//# sourceMappingURL=veritasVerifier.d.ts.map