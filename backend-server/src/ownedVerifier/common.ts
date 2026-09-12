import axios, { AxiosError } from "axios";

import { OwnedVerifierError } from "./types";

export const DEFAULT_TIMEOUT_MS = 20_000;
export const MAX_PROVIDER_RESPONSE_BYTES = 6 * 1024 * 1024;

export function configuredTimeout(): number {
  const parsed = Number(process.env.PROVIDER_TIMEOUT_MS);
  return Number.isFinite(parsed) && parsed >= 1_000 && parsed <= 90_000
    ? parsed
    : DEFAULT_TIMEOUT_MS;
}

export function envFlag(name: string): boolean {
  return process.env[name]?.trim().toLowerCase() === "true";
}

function egressMode(): "direct" | "auto" | "proxy" {
  const mode = (process.env.CHEKMI_PROVIDER_EGRESS || "direct")
    .trim()
    .toLowerCase();
  if (mode === "direct" || mode === "auto" || mode === "proxy") return mode;
  throw new OwnedVerifierError(
    "CHEKMI_PROVIDER_EGRESS must be direct, auto, or proxy.",
    "VERIFIER_CONFIGURATION_ERROR",
    503,
    false,
  );
}

export function ownedVerifierConfiguration(env: NodeJS.ProcessEnv = process.env) {
  const rawMode = (env.CHEKMI_PROVIDER_EGRESS || "direct").trim().toLowerCase();
  const validMode = rawMode === "direct" || rawMode === "auto" || rawMode === "proxy";
  const mode = validMode ? rawMode : "invalid";
  return {
    configured: validMode,
    mode,
    directEthiopianEgressRequired: rawMode !== "proxy",
    relays: {
      telebirr: Boolean(
        (env.TELEBIRR_PROXY_URLS || env.FALLBACK_PROXIES)?.trim() &&
          env.TELEBIRR_PROXY_KEY?.trim(),
      ),
      cbe: Boolean(env.CBE_PROXY_URL?.trim() && env.CBE_PROXY_KEY?.trim()),
      mpesa: Boolean(env.MPESA_PROXY_URL?.trim() && env.MPESA_PROXY_KEY?.trim()),
    },
    newCbeDirectConfigured: Boolean(
      env.CBE_APP_ID?.trim() && env.CBE_APP_VERSION?.trim(),
    ),
    legacyCbeEnabled: env.CBE_LEGACY_ENABLED?.trim().toLowerCase() !== "false",
  };
}

export function shouldUseDirectProvider(): boolean {
  return egressMode() !== "proxy" && !envFlag("SKIP_PRIMARY_VERIFICATION");
}

export function shouldUseProviderRelays(): boolean {
  const mode = egressMode();
  return mode === "auto" || mode === "proxy" || envFlag("SKIP_PRIMARY_VERIFICATION");
}

export function providerUrl(envName: string, officialUrl: string): string {
  const configured = process.env[envName]?.trim();
  const value = configured || officialUrl;
  validateProviderUrl(value, envName);
  return value;
}

export function validateProviderUrl(value: string, label: string): URL {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new OwnedVerifierError(
      `${label} must be an absolute URL.`,
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  const isLocal = new Set(["localhost", "127.0.0.1", "::1"]).has(
    url.hostname.toLowerCase(),
  );
  if (
    url.protocol !== "https:" &&
    !(process.env.NODE_ENV !== "production" && isLocal)
  ) {
    throw new OwnedVerifierError(
      `${label} must use HTTPS in production.`,
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  if (url.username || url.password) {
    throw new OwnedVerifierError(
      `${label} cannot contain credentials.`,
      "VERIFIER_CONFIGURATION_ERROR",
      503,
      false,
    );
  }
  return url;
}

export function appendPath(base: string, path: string): string {
  return `${base.replace(/\/$/, "")}/${encodeURIComponent(path)}`;
}

export function relayUrl(
  rawUrl: string,
  params: Record<string, string>,
  label: string,
): string {
  const url = validateProviderUrl(rawUrl, label);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }
  return url.toString();
}

export function numberFrom(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const cleaned = String(value).replace(/[^\d.-]/g, "");
  if (!cleaned) return null;
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

export { nonEmpty, titleCase, ethiopianLocalDate, completedStatus, referencesMatch, safeRaw } from "../receiptFormat";

export function toOwnedVerifierError(
  error: unknown,
  providerLabel: string,
): OwnedVerifierError {
  if (error instanceof OwnedVerifierError) return error;
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError;
    const status = axiosError.response?.status;
    if (status === 429) {
      return new OwnedVerifierError(
        `${providerLabel} rate limit reached.`,
        "PROVIDER_RATE_LIMIT",
        429,
        true,
      );
    }
    if (status === 404) {
      return new OwnedVerifierError(
        `${providerLabel} receipt was not found.`,
        "RECEIPT_NOT_FOUND",
        404,
        false,
      );
    }
    return new OwnedVerifierError(
      `${providerLabel} receipt service is unavailable.`,
      "PROVIDER_UNAVAILABLE",
      502,
      true,
    );
  }
  return new OwnedVerifierError(
    `${providerLabel} verification failed.`,
    "PROVIDER_ERROR",
    502,
    true,
  );
}
