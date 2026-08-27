import { OwnedVerificationResult, Provider } from "./types";
export * from "./cbe";
export * from "./common";
export * from "./otherProviders";
export * from "./telebirr";
export * from "./types";
export interface OwnedVerifierInput {
    reference?: string;
    suffix?: string;
    phoneNumber?: string;
    receiptNumber?: string;
}
export declare function verifyWithOwnedRoute(provider: Provider, input: OwnedVerifierInput): Promise<OwnedVerificationResult>;
//# sourceMappingURL=index.d.ts.map