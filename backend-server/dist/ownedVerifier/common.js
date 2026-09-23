"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.safeRaw = exports.referencesMatch = exports.completedStatus = exports.ethiopianLocalDate = exports.titleCase = exports.nonEmpty = exports.MAX_PROVIDER_RESPONSE_BYTES = exports.DEFAULT_TIMEOUT_MS = void 0;
exports.configuredTimeout = configuredTimeout;
exports.envFlag = envFlag;
exports.ownedVerifierConfiguration = ownedVerifierConfiguration;
exports.shouldUseDirectProvider = shouldUseDirectProvider;
exports.shouldUseProviderRelays = shouldUseProviderRelays;
exports.providerUrl = providerUrl;
exports.validateProviderUrl = validateProviderUrl;
exports.appendPath = appendPath;
exports.relayUrl = relayUrl;
exports.numberFrom = numberFrom;
exports.toOwnedVerifierError = toOwnedVerifierError;
const axios_1 = __importDefault(require("axios"));
const types_1 = require("./types");
exports.DEFAULT_TIMEOUT_MS = 20000;
exports.MAX_PROVIDER_RESPONSE_BYTES = 6 * 1024 * 1024;
function configuredTimeout() {
    const parsed = Number(process.env.PROVIDER_TIMEOUT_MS);
    return Number.isFinite(parsed) && parsed >= 1000 && parsed <= 90000
        ? parsed
        : exports.DEFAULT_TIMEOUT_MS;
}
function envFlag(name) {
    return process.env[name]?.trim().toLowerCase() === "true";
}
function egressMode() {
    const mode = (process.env.CHEKMI_PROVIDER_EGRESS || "direct")
        .trim()
        .toLowerCase();
    if (mode === "direct" || mode === "auto" || mode === "proxy")
        return mode;
    throw new types_1.OwnedVerifierError("CHEKMI_PROVIDER_EGRESS must be direct, auto, or proxy.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
}
function ownedVerifierConfiguration(env = process.env) {
    const rawMode = (env.CHEKMI_PROVIDER_EGRESS || "direct").trim().toLowerCase();
    const validMode = rawMode === "direct" || rawMode === "auto" || rawMode === "proxy";
    const mode = validMode ? rawMode : "invalid";
    return {
        configured: validMode,
        mode,
        directEthiopianEgressRequired: rawMode !== "proxy",
        relays: {
            telebirr: Boolean((env.TELEBIRR_PROXY_URLS || env.FALLBACK_PROXIES)?.trim() &&
                env.TELEBIRR_PROXY_KEY?.trim()),
            cbe: Boolean(env.CBE_PROXY_URL?.trim() && env.CBE_PROXY_KEY?.trim()),
            mpesa: Boolean(env.MPESA_PROXY_URL?.trim() && env.MPESA_PROXY_KEY?.trim()),
        },
        newCbeDirectConfigured: Boolean(env.CBE_APP_ID?.trim() && env.CBE_APP_VERSION?.trim()),
        legacyCbeEnabled: env.CBE_LEGACY_ENABLED?.trim().toLowerCase() !== "false",
    };
}
function shouldUseDirectProvider() {
    return egressMode() !== "proxy" && !envFlag("SKIP_PRIMARY_VERIFICATION");
}
function shouldUseProviderRelays() {
    const mode = egressMode();
    return mode === "auto" || mode === "proxy" || envFlag("SKIP_PRIMARY_VERIFICATION");
}
function providerUrl(envName, officialUrl) {
    const configured = process.env[envName]?.trim();
    const value = configured || officialUrl;
    validateProviderUrl(value, envName);
    return value;
}
function validateProviderUrl(value, label) {
    let url;
    try {
        url = new URL(value);
    }
    catch {
        throw new types_1.OwnedVerifierError(`${label} must be an absolute URL.`, "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    const isLocal = new Set(["localhost", "127.0.0.1", "::1"]).has(url.hostname.toLowerCase());
    if (url.protocol !== "https:" &&
        !(process.env.NODE_ENV !== "production" && isLocal)) {
        throw new types_1.OwnedVerifierError(`${label} must use HTTPS in production.`, "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    if (url.username || url.password) {
        throw new types_1.OwnedVerifierError(`${label} cannot contain credentials.`, "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    return url;
}
function appendPath(base, path) {
    return `${base.replace(/\/$/, "")}/${encodeURIComponent(path)}`;
}
function relayUrl(rawUrl, params, label) {
    const url = validateProviderUrl(rawUrl, label);
    for (const [key, value] of Object.entries(params)) {
        url.searchParams.set(key, value);
    }
    return url.toString();
}
function numberFrom(value) {
    if (value === null || value === undefined)
        return null;
    const cleaned = String(value).replace(/[^\d.-]/g, "");
    if (!cleaned)
        return null;
    const parsed = Number(cleaned);
    return Number.isFinite(parsed) ? parsed : null;
}
var receiptFormat_1 = require("../receiptFormat");
Object.defineProperty(exports, "nonEmpty", { enumerable: true, get: function () { return receiptFormat_1.nonEmpty; } });
Object.defineProperty(exports, "titleCase", { enumerable: true, get: function () { return receiptFormat_1.titleCase; } });
Object.defineProperty(exports, "ethiopianLocalDate", { enumerable: true, get: function () { return receiptFormat_1.ethiopianLocalDate; } });
Object.defineProperty(exports, "completedStatus", { enumerable: true, get: function () { return receiptFormat_1.completedStatus; } });
Object.defineProperty(exports, "referencesMatch", { enumerable: true, get: function () { return receiptFormat_1.referencesMatch; } });
Object.defineProperty(exports, "safeRaw", { enumerable: true, get: function () { return receiptFormat_1.safeRaw; } });
function toOwnedVerifierError(error, providerLabel) {
    if (error instanceof types_1.OwnedVerifierError)
        return error;
    if (axios_1.default.isAxiosError(error)) {
        const axiosError = error;
        const status = axiosError.response?.status;
        if (status === 429) {
            return new types_1.OwnedVerifierError(`${providerLabel} rate limit reached.`, "PROVIDER_RATE_LIMIT", 429, true);
        }
        if (status === 404) {
            return new types_1.OwnedVerifierError(`${providerLabel} receipt was not found.`, "RECEIPT_NOT_FOUND", 404, false);
        }
        return new types_1.OwnedVerifierError(`${providerLabel} receipt service is unavailable.`, "PROVIDER_UNAVAILABLE", 502, true);
    }
    return new types_1.OwnedVerifierError(`${providerLabel} verification failed.`, "PROVIDER_ERROR", 502, true);
}
//# sourceMappingURL=common.js.map