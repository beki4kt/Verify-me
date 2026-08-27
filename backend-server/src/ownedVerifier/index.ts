import { verifyCbeOwned } from "./cbe";
import {
  verifyAbyssiniaOwned,
  verifyCbeBirrOwned,
  verifyDashenOwned,
  verifyMpesaOwned,
} from "./otherProviders";
import { verifyTelebirrOwned } from "./telebirr";
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

export async function verifyWithOwnedRoute(
  provider: Provider,
  input: OwnedVerifierInput,
): Promise<OwnedVerificationResult> {
  const reference = (input.reference ?? input.receiptNumber ?? "").trim();
  switch (provider) {
    case "telebirr":
      return verifyTelebirrOwned(reference);
    case "cbe":
      return verifyCbeOwned(reference, input.suffix);
    case "cbebirr": {
      const phone = (input.phoneNumber ?? "")
        .replace(/[\s()+-]/g, "")
        .replace(/^0/, "251");
      return verifyCbeBirrOwned(reference, phone);
    }
    case "dashen":
      return verifyDashenOwned(reference);
    case "abyssinia":
      return verifyAbyssiniaOwned(reference, input.suffix ?? "");
    case "mpesa":
      return verifyMpesaOwned(reference);
  }
}
