export type Provider =
  | "telebirr"
  | "cbe"
  | "cbebirr"
  | "dashen"
  | "abyssinia"
  | "mpesa";

export interface OwnedVerificationData {
  reference: string;
  amount: number;
  currency: string;
  payerName?: string | null;
  payerAccount?: string | null;
  payerPhone?: string | null;
  receiverName?: string | null;
  receiverAccount?: string | null;
  txnDate?: string | null;
  status?: string | null;
  statusText?: string | null;
  serviceFee?: number | null;
  serviceFeeVAT?: number | null;
  totalAmount?: number | null;
  reason?: string | null;
  bankName?: string | null;
  raw: Record<string, unknown>;
}

export type OwnedVerificationResult =
  | {
      ok: true;
      provider: Provider;
      data: OwnedVerificationData;
    }
  | {
      ok: false;
      provider: Provider;
      error: string;
      code?: string;
      retryable?: boolean;
    };

export class OwnedVerifierError extends Error {
  constructor(
    message: string,
    readonly code = "PROVIDER_UNAVAILABLE",
    readonly status = 502,
    readonly retryable = true,
  ) {
    super(message);
    this.name = "OwnedVerifierError";
  }
}
