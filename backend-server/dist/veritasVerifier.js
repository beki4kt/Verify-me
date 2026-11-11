"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.veritasRequest = exports.normalizeVeritas = void 0;
exports.verifierConfiguration = verifierConfiguration;
exports.verifyWithVeritas = verifyWithVeritas;
const axios_1 = __importDefault(require("axios"));
const common_1 = require("./ownedVerifier/common");
const types_1 = require("./ownedVerifier/types");
const veritasProtocol_1 = require("./veritasProtocol");
var veritasProtocol_2 = require("./veritasProtocol");
Object.defineProperty(exports, "normalizeVeritas", { enumerable: true, get: function () { return veritasProtocol_2.normalizeVeritas; } });
Object.defineProperty(exports, "veritasRequest", { enumerable: true, get: function () { return veritasProtocol_2.veritasRequest; } });
const DEFAULT_API_URL = "https://verifyapi.leulzenebe.pro";
function verifierConfiguration(env = process.env) {
    const engine = (env.CHEKMI_VERIFICATION_ENGINE || "owned").trim().toLowerCase();
    if (engine === "owned")
        return { engine, ...(0, common_1.ownedVerifierConfiguration)(env) };
    if (engine !== "veritas")
        return { engine: "invalid", configured: false, mode: "invalid" };
    let validUrl = false;
    try {
        const url = new URL(env.VERITAS_API_URL || DEFAULT_API_URL);
        validUrl = url.protocol === "https:" && !url.username && !url.password && !url.search && !url.hash;
    }
    catch { /* A malformed URL makes readiness fail. */ }
    return {
        engine, mode: "transaction-id", configured: Boolean(env.VERITAS_API_KEY?.trim()) && validUrl,
        imageVerification: false,
    };
}
async function verifyWithVeritas(provider, input) {
    const key = process.env.VERITAS_API_KEY?.trim();
    if (!key)
        throw new types_1.OwnedVerifierError("Veritas is not configured on the server.", "VERITAS_NOT_CONFIGURED", 503, false);
    const base = (0, common_1.validateProviderUrl)(process.env.VERITAS_API_URL || DEFAULT_API_URL, "VERITAS_API_URL");
    if (base.search || base.hash)
        throw new types_1.OwnedVerifierError("Invalid Veritas server URL.", "VERITAS_NOT_CONFIGURED", 503, false);
    const request = (0, veritasProtocol_1.veritasRequest)(provider, input);
    try {
        const response = await axios_1.default.post(`${base.toString().replace(/\/$/, "")}${request.path}`, request.body, {
            headers: { "x-api-key": key, "Content-Type": "application/json", Accept: "application/json" },
            timeout: (0, common_1.configuredTimeout)(), maxContentLength: 1000000,
            maxRedirects: 0, validateStatus: () => true,
        });
        if (response.status === 401 || response.status === 403)
            throw new types_1.OwnedVerifierError("The Veritas API key or verification access needs attention in the server settings.", "VERITAS_ACCESS_DENIED", 503, false);
        if (response.status === 402)
            throw new types_1.OwnedVerifierError("The Veritas verification allowance is exhausted. Check the subscription balance.", "VERITAS_CREDITS_EXHAUSTED", 503, false);
        if (response.status === 429)
            throw new types_1.OwnedVerifierError("Veritas is rate limiting verification. Please retry shortly.", "VERITAS_RATE_LIMIT", 429, true);
        if (response.status >= 500 || (response.status >= 300 && response.status < 400))
            throw new types_1.OwnedVerifierError("Veritas is temporarily unavailable. Please retry shortly.", "VERITAS_UNAVAILABLE", 503, true);
        if (response.status < 200 || response.status >= 300)
            return { ok: false, provider, error: "Veritas could not find or validate this payment reference." };
        return (0, veritasProtocol_1.normalizeVeritas)(provider, request.reference, response.data);
    }
    catch (error) {
        if (error instanceof types_1.OwnedVerifierError)
            throw error;
        // Axios errors contain request headers: never log or expose the raw error.
        throw new types_1.OwnedVerifierError("Could not reach Veritas. Please retry shortly.", "VERITAS_UNAVAILABLE", 503, true);
    }
}
//# sourceMappingURL=veritasVerifier.js.map