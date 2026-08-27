export type VerifierMode = "live" | "fixtures";
export interface FixtureVerificationResult {
    ok: boolean;
    provider: string;
    data?: Record<string, unknown>;
    error?: string;
}
export declare class FixtureProviderUnavailableError extends Error {
}
export declare function resolveVerifierMode(env?: NodeJS.ProcessEnv): VerifierMode;
export declare function fixtureVerification(params: {
    provider: string;
    reference: string;
    expectedAmount: number;
    receivingAccount: string;
    now?: Date;
}): FixtureVerificationResult;
//# sourceMappingURL=verificationFixtures.d.ts.map