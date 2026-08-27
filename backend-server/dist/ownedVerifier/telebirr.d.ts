import { OwnedVerificationResult } from "./types";
interface TelebirrReceipt {
    payerName: string | null;
    payerTelebirrNo: string | null;
    creditedPartyName: string | null;
    creditedPartyAccountNo: string | null;
    transactionStatus: string | null;
    receiptNo: string | null;
    paymentDate: string | null;
    settledAmount: string | null;
    serviceFee: string | null;
    serviceFeeVAT: string | null;
    totalPaidAmount: string | null;
    bankName: string | null;
    customerNote: string | null;
}
/** Parse the public Ethio Telecom receipt table without logging payer data. */
export declare function parseTelebirrHtml(html: string): TelebirrReceipt;
export declare function verifyTelebirrOwned(rawReference: string): Promise<OwnedVerificationResult>;
export {};
//# sourceMappingURL=telebirr.d.ts.map