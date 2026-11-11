import axios from "axios";
import { configuredTimeout, ownedVerifierConfiguration, validateProviderUrl } from "./ownedVerifier/common";
import { OwnedVerifierError, type Provider, type OwnedVerificationResult } from "./ownedVerifier/types";
import type { OwnedVerifierInput } from "./ownedVerifier";
import { normalizeVeritas, veritasRequest } from "./veritasProtocol";
export { normalizeVeritas, veritasRequest } from "./veritasProtocol";
const DEFAULT_API_URL = "https://verifyapi.leulzenebe.pro";

export function verifierConfiguration(env: NodeJS.ProcessEnv = process.env) {
  const engine = (env.CHEKMI_VERIFICATION_ENGINE || "owned").trim().toLowerCase();
  if (engine === "owned") return { engine, ...ownedVerifierConfiguration(env) };
  if (engine !== "veritas") return { engine: "invalid", configured: false, mode: "invalid" };
  let validUrl = false;
  try {
    const url = new URL(env.VERITAS_API_URL || DEFAULT_API_URL);
    validUrl = url.protocol === "https:" && !url.username && !url.password && !url.search && !url.hash;
  } catch { /* A malformed URL makes readiness fail. */ }
  return {
    engine, mode: "transaction-id", configured: Boolean(env.VERITAS_API_KEY?.trim()) && validUrl,
    imageVerification: false,
  };
}

export async function verifyWithVeritas(provider: Provider, input: OwnedVerifierInput): Promise<OwnedVerificationResult> {
  const key = process.env.VERITAS_API_KEY?.trim();
  if (!key) throw new OwnedVerifierError("Veritas is not configured on the server.", "VERITAS_NOT_CONFIGURED", 503, false);
  const base = validateProviderUrl(process.env.VERITAS_API_URL || DEFAULT_API_URL, "VERITAS_API_URL");
  if (base.search || base.hash) throw new OwnedVerifierError("Invalid Veritas server URL.", "VERITAS_NOT_CONFIGURED", 503, false);
  const request = veritasRequest(provider, input);
  try {
    const response = await axios.post(`${base.toString().replace(/\/$/, "")}${request.path}`, request.body, {
      headers: { "x-api-key": key, "Content-Type": "application/json", Accept: "application/json" },
      timeout: configuredTimeout(), maxContentLength: 1_000_000,
      maxRedirects: 0, validateStatus: () => true,
    });
    if (response.status === 401 || response.status === 403) throw new OwnedVerifierError("The Veritas API key or verification access needs attention in the server settings.", "VERITAS_ACCESS_DENIED", 503, false);
    if (response.status === 402) throw new OwnedVerifierError("The Veritas verification allowance is exhausted. Check the subscription balance.", "VERITAS_CREDITS_EXHAUSTED", 503, false);
    if (response.status === 429) throw new OwnedVerifierError("Veritas is rate limiting verification. Please retry shortly.", "VERITAS_RATE_LIMIT", 429, true);
    if (response.status >= 500 || (response.status >= 300 && response.status < 400)) throw new OwnedVerifierError("Veritas is temporarily unavailable. Please retry shortly.", "VERITAS_UNAVAILABLE", 503, true);
    if (response.status < 200 || response.status >= 300) return { ok: false, provider, error: "Veritas could not find or validate this payment reference." };
    return normalizeVeritas(provider, request.reference, response.data);
  } catch (error) {
    if (error instanceof OwnedVerifierError) throw error;
    // Axios errors contain request headers: never log or expose the raw error.
    throw new OwnedVerifierError("Could not reach Veritas. Please retry shortly.", "VERITAS_UNAVAILABLE", 503, true);
  }
}
