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

export function nonEmpty(value: unknown): string | null {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text ? text : null;
}

export function titleCase(value: string | null): string | null {
  if (!value) return null;
  return value
    .toLowerCase()
    .replace(/\b\p{L}/gu, (character) => character.toUpperCase());
}

/** Provider timestamps without offsets are Ethiopian local time (UTC+3). */
export function ethiopianLocalDate(value: unknown): string | null {
  const text = nonEmpty(value);
  if (!text) return null;

  let match = text.match(
    /^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$/,
  );
  if (match) {
    const [, day, month, year, hour, minute, second = "00"] = match;
    return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
  }

  match = text.match(
    /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[, ]+\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$/i,
  );
  if (match) {
    const [, year, month, day, rawHour, minute, second = "00", meridiem] = match;
    let hour = Number(rawHour);
    if (meridiem) {
      hour %= 12;
      if (meridiem.toUpperCase() === "PM") hour += 12;
    }
    return validIso(
      `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}T${String(hour).padStart(2, "0")}:${minute}:${second}+03:00`,
    );
  }

  // ISO-shaped provider values without an explicit offset are Ethiopian local
  // time, regardless of the operating system timezone of the CHEKMI server.
  match = text.match(
    /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/,
  );
  if (match) {
    const [, year, month, day, hour, minute, second = "00"] = match;
    return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
  }

  return validIso(text);
}

function validIso(value: string): string | null {
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? null : date.toISOString();
}

export function completedStatus(value: unknown): boolean {
  const normalized = String(value ?? "")
    .toLowerCase()
    .replace(/[^a-z]+/g, " ")
    .trim();
  return new Set([
    "success",
    "successful",
    "completed",
    "complete",
    "settled",
    "paid",
    "transaction successful",
    "transaction completed",
    "transaction completed successfully",
    "payment successful",
    "payment completed",
  ]).has(normalized);
}

export function referencesMatch(left: unknown, right: unknown): boolean {
  const normalize = (value: unknown) =>
    String(value ?? "")
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, "");
  const normalizedLeft = normalize(left);
  const normalizedRight = normalize(right);
  return Boolean(normalizedLeft && normalizedLeft === normalizedRight);
}

/** Keep evidence useful without storing multi-megabyte PDF/base64 fields. */
export function safeRaw(raw: Record<string, unknown>): Record<string, unknown> {
  const copy = { ...raw };
  delete copy.base64Data;
  delete copy.pdf;
  return copy;
}

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
