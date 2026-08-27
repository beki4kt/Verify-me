"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractNewCbeToken = extractNewCbeToken;
exports.isLegacyCbeReference = isLegacyCbeReference;
exports.extractLegacyCbeUrlData = extractLegacyCbeUrlData;
exports.parseCbeText = parseCbeText;
exports.parseCbePdf = parseCbePdf;
exports.verifyCbeOwned = verifyCbeOwned;
const axios_1 = __importDefault(require("axios"));
const pdf_parse_1 = __importDefault(require("pdf-parse"));
const common_1 = require("./common");
const types_1 = require("./types");
const LEGACY_REFERENCE = /^FT[A-Z0-9]{10}$/i;
const LEGACY_COMBINED_ID = /^(FT[A-Z0-9]{10})(\d{8})$/i;
const NEW_CBE_URL = /^https?:\/\/mbreciept\.cbe\.com\.et\/([A-Za-z0-9-]+)\/?$/i;
const NEW_CBE_TOKEN = /^[A-Za-z0-9-]{15,80}$/;
function extractNewCbeToken(input) {
    const trimmed = input.trim();
    const urlMatch = trimmed.match(NEW_CBE_URL);
    if (urlMatch)
        return urlMatch[1] ?? null;
    if (!trimmed.toUpperCase().startsWith("FT") && NEW_CBE_TOKEN.test(trimmed)) {
        return trimmed;
    }
    return null;
}
function isLegacyCbeReference(input) {
    return LEGACY_REFERENCE.test(input.trim());
}
function extractLegacyCbeUrlData(input) {
    try {
        const url = new URL(input.trim());
        if (url.hostname.toLowerCase() !== "apps.cbe.com.et")
            return null;
        if (url.port && url.port !== "100")
            return null;
        const match = url.searchParams.get("id")?.trim().match(LEGACY_COMBINED_ID);
        if (!match)
            return null;
        return { reference: (match[1] ?? "").toUpperCase(), suffix: match[2] ?? "" };
    }
    catch {
        return null;
    }
}
function parseCbeText(rawText) {
    const text = rawText.replace(/\s+/g, " ").trim();
    const accounts = [
        ...text.matchAll(/Account\s*:?\s*([A-Z0-9]?\*{3,}\d{4,}|[A-Z0-9]{6,})/gi),
    ];
    const payerName = (0, common_1.nonEmpty)(text.match(/Payer\s*:?\s*(.*?)\s+Account/i)?.[1]);
    const receiverName = (0, common_1.nonEmpty)(text.match(/Receiver\s*:?\s*(.*?)\s+Account/i)?.[1]);
    const amount = (0, common_1.numberFrom)(text.match(/Transferred Amount\s*:?\s*([\d,]+(?:\.\d{1,2})?)\s*ETB/i)?.[1]);
    const date = (0, common_1.ethiopianLocalDate)(text.match(/Payment Date\s*&\s*Time\s*:?\s*(\d{4}[/-]\d{2}[/-]\d{2}[, ]+\s*\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)/i)?.[1]);
    const reference = (0, common_1.nonEmpty)(text.match(/Reference No\.?\s*\(VAT Invoice No\)\s*:?\s*([A-Z0-9-]+)/i)?.[1]);
    const reason = (0, common_1.nonEmpty)(text.match(/Reason\s*\/\s*Type of service\s*:?\s*(.*?)\s+Transferred Amount/i)?.[1]);
    return {
        payerName: (0, common_1.titleCase)(payerName),
        payerAccount: (0, common_1.nonEmpty)(accounts[0]?.[1]),
        receiverName: (0, common_1.titleCase)(receiverName),
        receiverAccount: (0, common_1.nonEmpty)(accounts[1]?.[1]),
        amount,
        date,
        reference,
        reason,
        raw: {
            payerName,
            payerAccount: (0, common_1.nonEmpty)(accounts[0]?.[1]),
            receiverName,
            receiverAccount: (0, common_1.nonEmpty)(accounts[1]?.[1]),
            amount,
            date,
            reference,
            reason,
        },
    };
}
async function parseCbePdf(buffer) {
    const parsed = await (0, pdf_parse_1.default)(buffer);
    return parseCbeText(parsed.text);
}
function mapNewReceipt(payload) {
    if (!payload || typeof payload !== "object")
        return null;
    const envelope = payload;
    if (envelope.success === false)
        return null;
    const raw = envelope.data && typeof envelope.data === "object"
        ? envelope.data
        : envelope;
    const dateTimes = Array.isArray(raw.dateTimes) ? raw.dateTimes : [];
    const paymentDetails = Array.isArray(raw.paymentDetails)
        ? raw.paymentDetails.map(String)
        : [];
    return {
        payerName: (0, common_1.nonEmpty)(raw.debitAccountHolder),
        payerAccount: (0, common_1.nonEmpty)(raw.debitAccountNo),
        receiverName: (0, common_1.nonEmpty)(raw.creditAccountHolder),
        receiverAccount: (0, common_1.nonEmpty)(raw.creditAccountNo),
        amount: (0, common_1.numberFrom)(raw.amountCredited),
        date: (0, common_1.ethiopianLocalDate)(dateTimes[0]),
        reference: (0, common_1.nonEmpty)(raw.id),
        reason: (0, common_1.nonEmpty)(paymentDetails.join(" ")),
        raw: (0, common_1.safeRaw)(raw),
    };
}
function normalizeCbe(submittedReference, receipt) {
    if (receipt.amount === null ||
        receipt.amount <= 0 ||
        !receipt.date ||
        !receipt.reference ||
        !receipt.payerName ||
        !receipt.receiverName ||
        !receipt.receiverAccount) {
        return {
            ok: false,
            provider: "cbe",
            error: "CBE receipt is missing required verified fields.",
            code: "RECEIPT_MISMATCH",
        };
    }
    return {
        ok: true,
        provider: "cbe",
        data: {
            reference: receipt.reference || submittedReference,
            amount: receipt.amount,
            currency: "ETB",
            payerName: receipt.payerName,
            payerAccount: receipt.payerAccount,
            receiverName: receipt.receiverName,
            receiverAccount: receipt.receiverAccount,
            txnDate: receipt.date,
            status: "completed",
            statusText: "completed",
            reason: receipt.reason,
            raw: receipt.raw,
        },
    };
}
function cbeRelayConfiguration() {
    const url = process.env.CBE_PROXY_URL?.trim() || "";
    const key = process.env.CBE_PROXY_KEY?.trim() || "";
    if (!url || !key) {
        throw new types_1.OwnedVerifierError("CBE relay mode requires CBE_PROXY_URL and CBE_PROXY_KEY.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    return { url, key };
}
async function fetchLegacyDirect(combinedId) {
    const base = (0, common_1.providerUrl)("CBE_LEGACY_RECEIPT_URL", "https://apps.cbe.com.et:100/");
    const url = new URL(base);
    url.searchParams.set("id", combinedId);
    const response = await axios_1.default.get(url.toString(), {
        responseType: "arraybuffer",
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    return parseCbePdf(Buffer.from(response.data));
}
async function fetchLegacyRelay(combinedId) {
    const relay = cbeRelayConfiguration();
    const url = (0, common_1.relayUrl)(relay.url, { type: "legacy", id: combinedId, key: relay.key }, "CBE_PROXY_URL");
    const response = await axios_1.default.get(url, {
        responseType: "arraybuffer",
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    return parseCbePdf(Buffer.from(response.data));
}
async function fetchNewDirect(token) {
    const appId = process.env.CBE_APP_ID?.trim();
    const appVersion = process.env.CBE_APP_VERSION?.trim();
    if (!appId || !appVersion) {
        throw new types_1.OwnedVerifierError("Direct new-format CBE verification requires CBE_APP_ID and CBE_APP_VERSION.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    const base = (0, common_1.providerUrl)("CBE_NEW_RECEIPT_BASE_URL", "https://mb.cbe.com.et/api/v1/transactions/public/transaction-detail");
    const response = await axios_1.default.get(`${base.replace(/\/$/, "")}/${encodeURIComponent(token)}`, {
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: {
            Accept: "application/json",
            Origin: "https://mbreciept.cbe.com.et",
            Referer: "https://mbreciept.cbe.com.et/",
            "User-Agent": "CHEKMI-Verifier/1.0",
            "x-app-id": appId,
            "x-app-version": appVersion,
        },
    });
    return mapNewReceipt(response.data);
}
async function fetchNewRelay(token) {
    const relay = cbeRelayConfiguration();
    const url = (0, common_1.relayUrl)(relay.url, { type: "new", token, key: relay.key }, "CBE_PROXY_URL");
    const response = await axios_1.default.get(url, {
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    return mapNewReceipt(response.data);
}
async function verifyCbeOwned(rawReference, rawSuffix) {
    const submittedReference = rawReference.trim();
    const embeddedLegacy = extractLegacyCbeUrlData(submittedReference);
    const newToken = extractNewCbeToken(submittedReference);
    const reference = embeddedLegacy?.reference ?? submittedReference.toUpperCase();
    const suffix = (rawSuffix?.trim() || embeddedLegacy?.suffix || "").trim();
    if (!newToken && (!LEGACY_REFERENCE.test(reference) || !/^\d{8}$/.test(suffix))) {
        return {
            ok: false,
            provider: "cbe",
            error: "Legacy CBE verification requires an FT reference and 8-digit account suffix.",
            code: "INVALID_REFERENCE",
        };
    }
    let lastError = null;
    const tryDirect = (0, common_1.shouldUseDirectProvider)();
    const tryRelay = (0, common_1.shouldUseProviderRelays)();
    if (tryDirect) {
        try {
            const receipt = newToken
                ? await fetchNewDirect(newToken)
                : await fetchLegacyDirect(`${reference}${suffix}`);
            if (receipt) {
                if (!newToken && !(0, common_1.referencesMatch)(reference, receipt.reference)) {
                    return {
                        ok: false,
                        provider: "cbe",
                        error: "CBE returned a different receipt reference.",
                        code: "REFERENCE_MISMATCH",
                    };
                }
                return normalizeCbe(reference, receipt);
            }
        }
        catch (error) {
            lastError = (0, common_1.toOwnedVerifierError)(error, "CBE");
        }
    }
    if (tryRelay) {
        try {
            const receipt = newToken
                ? await fetchNewRelay(newToken)
                : await fetchLegacyRelay(`${reference}${suffix}`);
            if (receipt) {
                if (!newToken && !(0, common_1.referencesMatch)(reference, receipt.reference)) {
                    return {
                        ok: false,
                        provider: "cbe",
                        error: "CBE returned a different receipt reference.",
                        code: "REFERENCE_MISMATCH",
                    };
                }
                return normalizeCbe(reference, receipt);
            }
        }
        catch (error) {
            lastError = (0, common_1.toOwnedVerifierError)(error, "CBE relay");
        }
    }
    if (lastError)
        throw lastError;
    return {
        ok: false,
        provider: "cbe",
        error: "CBE receipt was not found or was incomplete.",
        code: "RECEIPT_NOT_FOUND",
    };
}
//# sourceMappingURL=cbe.js.map