export type VerifierMode = "live" | "fixtures";

export interface FixtureVerificationResult {
  ok: boolean;
  provider: string;
  data?: Record<string, unknown>;
  error?: string;
}

export class FixtureProviderUnavailableError extends Error {}

export function resolveVerifierMode(
  env: NodeJS.ProcessEnv = process.env,
): VerifierMode {
  const rawMode = (env.CHEKMI_VERIFIER_MODE || "live").trim().toLowerCase();
  if (rawMode !== "live" && rawMode !== "fixtures") {
    throw new Error("CHEKMI_VERIFIER_MODE must be live or fixtures.");
  }

  const deploymentEnvironment = (
    env.CHEKMI_ENV ||
    env.NODE_ENV ||
    "development"
  ).trim().toLowerCase();
  if (rawMode === "fixtures" && deploymentEnvironment === "production") {
    throw new Error(
      "CHEKMI verifier fixtures are forbidden in the production environment.",
    );
  }
  return rawMode;
}

export function fixtureVerification(params: {
  provider: string;
  reference: string;
  expectedAmount: number;
  receivingAccount: string;
  now?: Date;
}): FixtureVerificationResult {
  const reference = params.reference.trim().toUpperCase();
  const now = params.now ?? new Date();
  const baseData = {
    fixture: true,
    reference,
    amount: params.expectedAmount,
    currency: "ETB",
    receiverAccount: params.receivingAccount,
    receiverName: "CHEKMI Staging Restaurant",
    payerAccount: "+251911222333",
    payerName: "Staging Customer",
    txnDate: now.toISOString(),
    status: "completed",
  };

  switch (reference) {
    case "CHEKMI-OK":
      return { ok: true, provider: params.provider, data: baseData };
    case "CHEKMI-TIP":
      return {
        ok: true,
        provider: params.provider,
        data: { ...baseData, amount: params.expectedAmount + 100 },
      };
    case "CHEKMI-UNDERPAID":
      return {
        ok: true,
        provider: params.provider,
        data: {
          ...baseData,
          amount: Math.max(0.01, params.expectedAmount * 0.75),
        },
      };
    case "CHEKMI-WRONG-DEST":
      return {
        ok: true,
        provider: params.provider,
        data: { ...baseData, receiverAccount: "000000999999" },
      };
    case "CHEKMI-STALE":
      return {
        ok: true,
        provider: params.provider,
        data: {
          ...baseData,
          txnDate: new Date(now.valueOf() - 48 * 60 * 60 * 1000).toISOString(),
        },
      };
    case "CHEKMI-NOT-FOUND":
      return {
        ok: false,
        provider: params.provider,
        error: "The staging transaction reference was not found.",
      };
    case "CHEKMI-OUTAGE":
      throw new FixtureProviderUnavailableError(
        "Simulated staging provider outage.",
      );
    default:
      return {
        ok: false,
        provider: params.provider,
        error:
          "Unknown staging fixture reference. Use CHEKMI-OK, CHEKMI-TIP, CHEKMI-UNDERPAID, CHEKMI-WRONG-DEST, CHEKMI-STALE, CHEKMI-NOT-FOUND, or CHEKMI-OUTAGE.",
      };
  }
}
