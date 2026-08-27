"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseTelebirrHtml = parseTelebirrHtml;
exports.verifyTelebirrOwned = verifyTelebirrOwned;
const axios_1 = __importDefault(require("axios"));
const cheerio = __importStar(require("cheerio"));
const common_1 = require("./common");
const types_1 = require("./types");
function cleanLabel(value) {
    return value.replace(/\s+/g, " ").trim().toLowerCase();
}
/** Parse the public Ethio Telecom receipt table without logging payer data. */
function parseTelebirrHtml(html) {
    const $ = cheerio.load(html);
    const rows = $("tr")
        .toArray()
        .map((row) => $(row)
        .find("td")
        .toArray()
        .map((cell) => $(cell).text().replace(/\s+/g, " ").trim()))
        .filter((cells) => cells.length > 0);
    const valueFor = (...labels) => {
        const lowered = labels.map(cleanLabel);
        for (const cells of rows) {
            for (let index = 0; index < cells.length; index++) {
                const cell = cleanLabel(cells[index] ?? "");
                if (!lowered.some((label) => cell.includes(label)))
                    continue;
                for (let valueIndex = index + 1; valueIndex < cells.length; valueIndex++) {
                    const candidate = (0, common_1.nonEmpty)(cells[valueIndex]);
                    if (candidate)
                        return candidate;
                }
            }
        }
        return null;
    };
    const receiptNo = valueFor("receipt no", "receipt number") ??
        (0, common_1.nonEmpty)(html.match(/(?:Receipt\s*(?:No\.?|Number))[^A-Z0-9]*([A-Z0-9]{8,32})/i)?.[1]);
    const paymentDate = valueFor("payment date") ??
        (0, common_1.nonEmpty)(html.match(/(\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}:\d{2})/)?.[1]);
    const settledAmount = valueFor("settled amount") ??
        (0, common_1.nonEmpty)(html.match(/Settled\s+Amount.*?([\d,]+(?:\.\d+)?\s*Birr)/is)?.[1]);
    const serviceFee = valueFor("service fee", "service charge");
    const serviceFeeVAT = valueFor("service fee vat", "service fee v.a.t");
    let creditedPartyName = valueFor("credited party name");
    let creditedPartyAccountNo = valueFor("credited party account no", "credited party account number");
    const bankAccount = valueFor("bank account number");
    let bankName = null;
    if (bankAccount) {
        bankName = creditedPartyName;
        const match = bankAccount.match(/([+\d][\d\s-]{5,})\s+(.+)/);
        if (match) {
            creditedPartyAccountNo = (0, common_1.nonEmpty)(match[1]);
            creditedPartyName = (0, common_1.nonEmpty)(match[2]);
        }
        else {
            creditedPartyAccountNo = bankAccount;
        }
    }
    return {
        payerName: valueFor("payer name"),
        payerTelebirrNo: valueFor("payer telebirr no", "payer phone"),
        creditedPartyName,
        creditedPartyAccountNo,
        transactionStatus: valueFor("transaction status"),
        receiptNo,
        paymentDate,
        settledAmount,
        serviceFee,
        serviceFeeVAT,
        totalPaidAmount: valueFor("total paid amount"),
        bankName,
        customerNote: valueFor("customer note"),
    };
}
function parseRelayPayload(payload) {
    if (!payload || typeof payload !== "object")
        return null;
    const envelope = payload;
    if (envelope.success === false)
        return null;
    const raw = envelope.data && typeof envelope.data === "object"
        ? envelope.data
        : envelope;
    return {
        payerName: (0, common_1.nonEmpty)(raw.payerName),
        payerTelebirrNo: (0, common_1.nonEmpty)(raw.payerTelebirrNo),
        creditedPartyName: (0, common_1.nonEmpty)(raw.creditedPartyName),
        creditedPartyAccountNo: (0, common_1.nonEmpty)(raw.creditedPartyAccountNo),
        transactionStatus: (0, common_1.nonEmpty)(raw.transactionStatus),
        receiptNo: (0, common_1.nonEmpty)(raw.receiptNo),
        paymentDate: (0, common_1.nonEmpty)(raw.paymentDate),
        settledAmount: (0, common_1.nonEmpty)(raw.settledAmount),
        serviceFee: (0, common_1.nonEmpty)(raw.serviceFee),
        serviceFeeVAT: (0, common_1.nonEmpty)(raw.serviceFeeVAT),
        totalPaidAmount: (0, common_1.nonEmpty)(raw.totalPaidAmount),
        bankName: (0, common_1.nonEmpty)(raw.bankName),
        customerNote: (0, common_1.nonEmpty)(raw.customerNote),
    };
}
function normalizeTelebirr(submittedReference, receipt) {
    const amount = (0, common_1.numberFrom)(receipt.settledAmount);
    const date = (0, common_1.ethiopianLocalDate)(receipt.paymentDate);
    const status = receipt.transactionStatus;
    const reference = receipt.receiptNo ?? submittedReference;
    if (amount === null ||
        amount <= 0 ||
        !date ||
        !receipt.payerName ||
        !receipt.creditedPartyName ||
        !receipt.creditedPartyAccountNo ||
        !(0, common_1.referencesMatch)(submittedReference, reference) ||
        !(0, common_1.completedStatus)(status)) {
        return {
            ok: false,
            provider: "telebirr",
            error: status || "Telebirr receipt is missing required verified fields.",
            code: "RECEIPT_MISMATCH",
        };
    }
    const totalAmount = (0, common_1.numberFrom)(receipt.totalPaidAmount);
    const data = {
        reference,
        amount,
        totalAmount,
        currency: "ETB",
        payerName: receipt.payerName,
        payerPhone: receipt.payerTelebirrNo,
        payerAccount: receipt.payerTelebirrNo,
        receiverName: receipt.creditedPartyName,
        receiverAccount: receipt.creditedPartyAccountNo,
        txnDate: date,
        status: "completed",
        statusText: status,
        serviceFee: (0, common_1.numberFrom)(receipt.serviceFee),
        serviceFeeVAT: (0, common_1.numberFrom)(receipt.serviceFeeVAT),
        bankName: receipt.bankName,
        raw: (0, common_1.safeRaw)({ ...receipt }),
    };
    return { ok: true, provider: "telebirr", data };
}
async function directReceipt(reference) {
    const base = (0, common_1.providerUrl)("TELEBIRR_RECEIPT_BASE_URL", "https://transactioninfo.ethiotelecom.et/receipt");
    const response = await axios_1.default.get((0, common_1.appendPath)(base, reference), {
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: {
            Accept: "text/html,application/xhtml+xml",
            "User-Agent": "CHEKMI-Verifier/1.0",
        },
    });
    return parseTelebirrHtml(response.data);
}
function relayDescriptors() {
    return (process.env.TELEBIRR_PROXY_URLS ??
        process.env.FALLBACK_PROXIES ??
        "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
}
async function relayReceipt(reference, rawRelay) {
    const key = process.env.TELEBIRR_PROXY_KEY?.trim() || "";
    if (!key) {
        throw new types_1.OwnedVerifierError("TELEBIRR_PROXY_KEY is required for relay mode.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
    }
    const url = (0, common_1.relayUrl)(rawRelay, { reference, key }, "TELEBIRR_PROXY_URLS");
    const response = await axios_1.default.get(url, {
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
    });
    if (typeof response.data === "string") {
        try {
            return parseRelayPayload(JSON.parse(response.data));
        }
        catch {
            return parseTelebirrHtml(response.data);
        }
    }
    return parseRelayPayload(response.data);
}
async function verifyTelebirrOwned(rawReference) {
    const reference = rawReference.trim().toUpperCase();
    if (!/^[A-Z0-9-]{8,32}$/.test(reference)) {
        return {
            ok: false,
            provider: "telebirr",
            error: "Invalid Telebirr receipt reference.",
            code: "INVALID_REFERENCE",
        };
    }
    let lastTransportError = null;
    if ((0, common_1.shouldUseDirectProvider)()) {
        try {
            const receipt = await directReceipt(reference);
            if (receipt) {
                const normalized = normalizeTelebirr(reference, receipt);
                if (normalized.ok)
                    return normalized;
            }
        }
        catch (error) {
            lastTransportError = (0, common_1.toOwnedVerifierError)(error, "Telebirr");
        }
    }
    if ((0, common_1.shouldUseProviderRelays)()) {
        const relays = relayDescriptors();
        if (relays.length === 0) {
            throw new types_1.OwnedVerifierError("Telebirr relay mode requires TELEBIRR_PROXY_URLS.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
        }
        for (const relay of relays) {
            try {
                const receipt = await relayReceipt(reference, relay);
                if (!receipt)
                    continue;
                const normalized = normalizeTelebirr(reference, receipt);
                if (normalized.ok)
                    return normalized;
            }
            catch (error) {
                lastTransportError = (0, common_1.toOwnedVerifierError)(error, "Telebirr relay");
            }
        }
    }
    if (lastTransportError)
        throw lastTransportError;
    return {
        ok: false,
        provider: "telebirr",
        error: "Telebirr receipt was not found or was incomplete.",
        code: "RECEIPT_NOT_FOUND",
    };
}
//# sourceMappingURL=telebirr.js.map