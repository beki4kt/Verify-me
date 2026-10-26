import { OwnedVerificationResult } from "./types";
export { extractNewCbeToken, isLegacyCbeReference, extractLegacyCbeUrlData } from "../receiptFormat";
interface CbeReceipt {
    payerName: string | null;
    payerAccount: string | null;
    receiverName: string | null;
    receiverAccount: string | null;
    amount: number | null;
    date: string | null;
    reference: string | null;
    reason: string | null;
    raw: Record<string, unknown>;
}
export declare function parseCbeText(rawText: string): CbeReceipt;
export declare function parseCbePdf(buffer: Buffer): Promise<CbeReceipt>;
export declare function verifyCbeOwned(rawReference: string, rawSuffix?: string): Promise<OwnedVerificationResult>;
//# sourceMappingURL=cbe.d.ts.map