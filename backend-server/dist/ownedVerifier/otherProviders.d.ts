import { OwnedVerificationResult } from "./types";
export declare function verifyAbyssiniaOwned(rawReference: string, rawSuffix: string): Promise<OwnedVerificationResult>;
interface DashenReceipt {
    senderName: string | null;
    senderAccount: string | null;
    receiverName: string | null;
    receiverAccount: string | null;
    phone: string | null;
    reference: string | null;
    date: string | null;
    amount: number | null;
    total: number | null;
    raw: Record<string, unknown>;
}
export declare function parseDashenText(rawText: string): DashenReceipt;
export declare function parseDashenPdf(buffer: Buffer): Promise<DashenReceipt>;
export declare function verifyDashenOwned(rawReference: string): Promise<OwnedVerificationResult>;
interface WalletPdfReceipt {
    payerName: string | null;
    payerAccount: string | null;
    receiverName: string | null;
    receiverAccount: string | null;
    transactionId: string | null;
    receiptNo: string | null;
    date: string | null;
    amount: number | null;
    serviceFee: number | null;
    vat: number | null;
    status: string | null;
    raw: Record<string, unknown>;
}
interface CbeBirrReceipt {
    payerName: string | null;
    payerAccount: string | null;
    receiverName: string | null;
    receiverAccount: string | null;
    orderId: string | null;
    reference: string | null;
    receiptNo: string | null;
    date: string | null;
    amount: number | null;
    paidAmount: number | null;
    serviceFee: number | null;
    vat: number | null;
    totalPaidAmount: number | null;
    status: string | null;
    reason: string | null;
    paymentChannel: string | null;
    raw: Record<string, unknown>;
}
/** CBE Birr has its own receipt layout; it is not an M-Pesa wallet PDF. */
export declare function parseCbeBirrText(rawText: string): CbeBirrReceipt;
export declare function parseCbeBirrPdf(buffer: Buffer): Promise<CbeBirrReceipt>;
export declare function parseWalletText(rawText: string): WalletPdfReceipt;
export declare function parseWalletPdf(buffer: Buffer): Promise<WalletPdfReceipt>;
export declare function verifyCbeBirrOwned(rawReference: string, phoneNumber: string): Promise<OwnedVerificationResult>;
export declare function verifyMpesaOwned(rawReference: string): Promise<OwnedVerificationResult>;
export {};
//# sourceMappingURL=otherProviders.d.ts.map