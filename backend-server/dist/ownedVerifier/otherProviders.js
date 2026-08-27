"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyAbyssiniaOwned = verifyAbyssiniaOwned;
exports.parseDashenText = parseDashenText;
exports.parseDashenPdf = parseDashenPdf;
exports.verifyDashenOwned = verifyDashenOwned;
exports.parseCbeBirrText = parseCbeBirrText;
exports.parseCbeBirrPdf = parseCbeBirrPdf;
exports.parseWalletText = parseWalletText;
exports.parseWalletPdf = parseWalletPdf;
exports.verifyCbeBirrOwned = verifyCbeBirrOwned;
exports.verifyMpesaOwned = verifyMpesaOwned;
const axios_1 = __importDefault(require("axios"));
const pdf_parse_1 = __importDefault(require("pdf-parse"));
const common_1 = require("./common");
const types_1 = require("./types");
function failed(provider, error, code = "RECEIPT_MISMATCH") {
    return { ok: false, provider, error, code };
}
function rowValue(raw, ...keys) {
    for (const key of keys) {
        if (raw[key] !== undefined && raw[key] !== null)
            return raw[key];
    }
    return null;
}
async function verifyAbyssiniaOwned(rawReference, rawSuffix) {
    const reference = rawReference.trim().toUpperCase();
    const suffix = rawSuffix.trim();
    if (!/^FT[A-Z0-9]{10}$/.test(reference) || !/^\d{5}$/.test(suffix)) {
        return failed("abyssinia", "Abyssinia verification requires an FT reference and 5-digit account suffix.", "INVALID_REFERENCE");
    }
    try {
        const base = (0, common_1.providerUrl)("ABYSSINIA_RECEIPT_BASE_URL", "https://cs.bankofabyssinia.com/api/onlineSlip/getDetails/");
        const url = new URL(base);
        url.searchParams.set("id", `${reference}${suffix}`);
        const response = await axios_1.default.get(url.toString(), {
            timeout: (0, common_1.configuredTimeout)(),
            maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
            headers: { Accept: "application/json", "User-Agent": "CHEKMI-Verifier/1.0" },
        });
        if (!response.data || typeof response.data !== "object") {
            return failed("abyssinia", "Abyssinia returned an invalid receipt response.");
        }
        const envelope = response.data;
        const header = envelope.header;
        const rows = Array.isArray(envelope.body) ? envelope.body : [];
        if (String(header?.status ?? "").toLowerCase() !== "success" || !rows[0]) {
            return failed("abyssinia", "Abyssinia receipt was not found.", "RECEIPT_NOT_FOUND");
        }
        const raw = rows[0];
        const amount = (0, common_1.numberFrom)(rowValue(raw, "Transferred Amount", "Total Amount including VAT"));
        const txnDate = (0, common_1.ethiopianLocalDate)(rowValue(raw, "Transaction Date"));
        const returnedReference = (0, common_1.nonEmpty)(rowValue(raw, "Transaction Reference", "Payment Reference"));
        if (amount === null ||
            amount <= 0 ||
            !txnDate ||
            !returnedReference ||
            !(0, common_1.referencesMatch)(reference, returnedReference)) {
            return failed("abyssinia", "Abyssinia receipt is missing required fields.");
        }
        return {
            ok: true,
            provider: "abyssinia",
            data: {
                reference: returnedReference,
                amount,
                currency: "ETB",
                payerName: (0, common_1.nonEmpty)(rowValue(raw, "Payer's Name", "Source Account Name")),
                payerAccount: (0, common_1.nonEmpty)(rowValue(raw, "Source Account", "Payer's Account")),
                receiverName: (0, common_1.nonEmpty)(rowValue(raw, "Receiver's Name", "Beneficiary Name")),
                receiverAccount: (0, common_1.nonEmpty)(rowValue(raw, "Receiver's Account", "Beneficiary Account")),
                txnDate,
                status: "completed",
                statusText: "completed",
                reason: (0, common_1.nonEmpty)(rowValue(raw, "Narrative", "Transaction Type")),
                raw: (0, common_1.safeRaw)(raw),
            },
        };
    }
    catch (error) {
        throw (0, common_1.toOwnedVerifierError)(error, "Abyssinia");
    }
}
function parseDashenText(rawText) {
    const text = rawText.replace(/\s+/g, " ").trim();
    const amount = (0, common_1.numberFrom)(text.match(/Transaction\s*Amount\s*(?:ETB|Birr)?\s*:?\s*([\d,]+\.?\d*)/i)?.[1]);
    const total = (0, common_1.numberFrom)(text.match(/Total\s*(?:ETB|Birr)?\s*:?\s*([\d,]+\.?\d*)/i)?.[1]);
    const raw = {
        senderName: (0, common_1.nonEmpty)(text.match(/Sender\s*Name\s*:?\s*(.*?)\s+(?:Sender\s*Account|Account)/i)?.[1]),
        senderAccount: (0, common_1.nonEmpty)(text.match(/Sender\s*Account\s*(?:Number)?\s*:?\s*([A-Z0-9*-]+)/i)?.[1]),
        receiverName: (0, common_1.nonEmpty)(text.match(/Receiver\s*Name\s*:?\s*(.*?)\s+(?:Receiver\s*Account|Phone|Institution)/i)?.[1]),
        receiverAccount: (0, common_1.nonEmpty)(text.match(/Receiver\s*Account\s*(?:Number)?\s*:?\s*([A-Z0-9*+-]+)/i)?.[1]),
        phone: (0, common_1.nonEmpty)(text.match(/Phone\s*(?:No\.?|Number)?\s*:?\s*([+\d\s-]{9,})/i)?.[1]),
        reference: (0, common_1.nonEmpty)(text.match(/Transaction\s*Reference\s*:?\s*([A-Z0-9-]+)/i)?.[1]),
        date: (0, common_1.ethiopianLocalDate)(text.match(/Transaction\s*Date\s*(?:&\s*Time)?\s*:?\s*([\d/\-,: ]+(?:AM|PM)?)/i)?.[1]),
        amount,
        total,
    };
    return {
        senderName: (0, common_1.titleCase)(raw.senderName),
        senderAccount: raw.senderAccount,
        receiverName: (0, common_1.titleCase)(raw.receiverName),
        receiverAccount: raw.receiverAccount,
        phone: raw.phone,
        reference: raw.reference,
        date: raw.date,
        amount,
        total,
        raw,
    };
}
async function parseDashenPdf(buffer) {
    const parsed = await (0, pdf_parse_1.default)(buffer);
    return parseDashenText(parsed.text);
}
async function verifyDashenOwned(rawReference) {
    const reference = rawReference.trim().toUpperCase();
    if (!/^[A-Z0-9-]{8,32}$/.test(reference)) {
        return failed("dashen", "Invalid Dashen receipt reference.", "INVALID_REFERENCE");
    }
    try {
        const base = (0, common_1.providerUrl)("DASHEN_RECEIPT_BASE_URL", "https://receipt.dashensuperapp.com/receipt");
        const response = await axios_1.default.get(`${base.replace(/\/$/, "")}/${encodeURIComponent(reference)}`, {
            responseType: "arraybuffer",
            timeout: (0, common_1.configuredTimeout)(),
            maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
            headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
        });
        const receipt = await parseDashenPdf(Buffer.from(response.data));
        if (receipt.amount === null ||
            receipt.amount <= 0 ||
            !receipt.date ||
            !receipt.reference ||
            !(0, common_1.referencesMatch)(reference, receipt.reference)) {
            return failed("dashen", "Dashen receipt is missing required verified fields.");
        }
        return {
            ok: true,
            provider: "dashen",
            data: {
                reference: receipt.reference,
                amount: receipt.amount,
                totalAmount: receipt.total,
                currency: "ETB",
                payerName: receipt.senderName,
                payerAccount: receipt.senderAccount,
                receiverName: receipt.receiverName,
                receiverAccount: receipt.receiverAccount ?? receipt.phone,
                txnDate: receipt.date,
                status: "completed",
                statusText: "completed",
                raw: receipt.raw,
            },
        };
    }
    catch (error) {
        throw (0, common_1.toOwnedVerifierError)(error, "Dashen");
    }
}
/** CBE Birr has its own receipt layout; it is not an M-Pesa wallet PDF. */
function parseCbeBirrText(rawText) {
    const text = rawText.replace(/\s+/g, " ").trim();
    const receiptRow = text.match(/([A-Z0-9]{8,32})\s*(20\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s*([\d,.]+)/i);
    const financialRow = text.match(/([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)\s+Paid amount/i);
    const payerName = (0, common_1.nonEmpty)(text.match(/Customer Name\s*:?[\s]*?(.*?)(?=\s+(?:Debit Account|Credit Account))/i)?.[1] ??
        text.match(/Sub city:\s*([A-Z][A-Z ]+?)(?=\s+Wereda\/kebele:)/i)?.[1]);
    const payerAccount = (0, common_1.nonEmpty)(text.match(/Debit Account\s*(Org Account|.*?)(?=\s+Credit Account)/i)?.[1]);
    const receiverAccount = (0, common_1.nonEmpty)(text.match(/Credit Account\s*(.*?)(?=\s+Receiver Name)/i)?.[1]);
    const receiverName = (0, common_1.nonEmpty)(text.match(/Receiver Name\s*(.*?)(?=\s+Order ID)/i)?.[1]);
    const orderId = (0, common_1.nonEmpty)(text.match(/Order ID\s*([A-Z0-9-]+)/i)?.[1]);
    const status = (0, common_1.nonEmpty)(text.match(/Transaction Status\s*([A-Za-z ]+?)(?=\s+(?:Reference|Transaction Details|Receipt Number))/i)?.[1]);
    const reference = (0, common_1.nonEmpty)(text.match(/Reference[\s:]*(.*?)(?=\s*(?:Transaction Details|Receipt Number|Commercial Bank))/i)?.[1]);
    const receiptNo = (0, common_1.nonEmpty)(receiptRow?.[1]);
    const date = (0, common_1.ethiopianLocalDate)(receiptRow?.[2]);
    const amount = (0, common_1.numberFrom)(receiptRow?.[3]);
    const paidAmount = (0, common_1.numberFrom)(financialRow?.[1]);
    const serviceFee = (0, common_1.numberFrom)(financialRow?.[2]);
    const vat = (0, common_1.numberFrom)(financialRow?.[3]);
    const totalPaidAmount = (0, common_1.numberFrom)(financialRow?.[4]);
    const paymentDetails = text.match(/Payment Channel\s+(.*?)\s+(.*?)\s+([A-Z][A-Z0-9 ]+?)(?=\s|$)/i);
    const reason = (0, common_1.nonEmpty)(paymentDetails?.[2]);
    const paymentChannel = (0, common_1.nonEmpty)(paymentDetails?.[3]);
    const raw = {
        payerName,
        payerAccount,
        receiverName,
        receiverAccount,
        orderId,
        reference,
        receiptNo,
        date,
        amount,
        paidAmount,
        serviceFee,
        vat,
        totalPaidAmount,
        status,
        reason,
        paymentChannel,
    };
    return {
        ...raw,
        payerName: (0, common_1.titleCase)(payerName),
        receiverName: (0, common_1.titleCase)(receiverName),
        raw,
    };
}
async function parseCbeBirrPdf(buffer) {
    const parsed = await (0, pdf_parse_1.default)(buffer);
    return parseCbeBirrText(parsed.text);
}
function parseWalletText(rawText) {
    const text = rawText.replace(/\s+/g, " ").trim();
    const payerName = (0, common_1.nonEmpty)(text.match(/PAYER NAME\s+(.*?)\s+(?:PAYER PHONE|\+?251|09\d)/i)?.[1]);
    const payerAccount = (0, common_1.nonEmpty)(text.match(/PAYER (?:PHONE NUMBER|ACCOUNT)\s+([+\d*]+)/i)?.[1]);
    const receiverName = (0, common_1.nonEmpty)(text.match(/RECEIVER NAME\s+(.*?)(?=\s+(?:RECEIVER NUMBER|RECEIVER ACCOUNT|\/))/i)?.[1]);
    const receiverAccount = (0, common_1.nonEmpty)(text.match(/RECEIVER (?:NUMBER|ACCOUNT)\s+([+\d*]+)/i)?.[1]);
    const transactionId = (0, common_1.nonEmpty)(text.match(/TRANSACTION ID\s+([A-Z0-9-]+)/i)?.[1]);
    const receiptNo = (0, common_1.nonEmpty)(text.match(/RECEIPT NO.*?([A-Z0-9]{8,32})(?=\s*20\d{2}|\s)/i)?.[1]);
    const amount = (0, common_1.numberFrom)(text.match(/(?:PAID AMOUNT|TOTAL)\s+([\d,]+\.\d{2})/i)?.[1]);
    const serviceFee = (0, common_1.numberFrom)(text.match(/([\d,]+\.\d{2})\s*Birr\s*\/\s*SERVICE FEE/i)?.[1]);
    const vat = (0, common_1.numberFrom)(text.match(/SERVICE FEE\s*\/\s*([\d,]+\.\d{2})\s*.*?15% VAT/i)?.[1]);
    const date = (0, common_1.ethiopianLocalDate)(text.match(/(20\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)/)?.[1]);
    const status = (0, common_1.nonEmpty)(text.match(/TRANSACTION STATUS\s+([A-Za-z ]+?)(?=\s+[A-Z][A-Z ]{3,}|$)/i)?.[1]);
    const raw = {
        payerName,
        payerAccount,
        receiverName,
        receiverAccount,
        transactionId,
        receiptNo,
        date,
        amount,
        serviceFee,
        vat,
        status,
    };
    return {
        payerName: (0, common_1.titleCase)(payerName),
        payerAccount,
        receiverName: (0, common_1.titleCase)(receiverName),
        receiverAccount,
        transactionId,
        receiptNo,
        date,
        amount,
        serviceFee,
        vat,
        status,
        raw,
    };
}
async function parseWalletPdf(buffer) {
    const parsed = await (0, pdf_parse_1.default)(buffer);
    return parseWalletText(parsed.text);
}
function normalizeWalletPdf(provider, submittedReference, receipt) {
    const returnedReference = receipt.receiptNo ?? receipt.transactionId;
    const referenceMatchesReceipt = (0, common_1.referencesMatch)(submittedReference, receipt.receiptNo) ||
        (0, common_1.referencesMatch)(submittedReference, receipt.transactionId);
    if (receipt.amount === null ||
        receipt.amount <= 0 ||
        !receipt.date ||
        !receipt.receiverAccount ||
        !returnedReference ||
        !referenceMatchesReceipt ||
        (receipt.status && !(0, common_1.completedStatus)(receipt.status))) {
        return failed(provider, "M-Pesa receipt is missing required verified fields.");
    }
    return {
        ok: true,
        provider,
        data: {
            reference: returnedReference,
            amount: receipt.amount,
            currency: "ETB",
            payerName: receipt.payerName,
            payerAccount: receipt.payerAccount,
            payerPhone: receipt.payerAccount,
            receiverName: receipt.receiverName,
            receiverAccount: receipt.receiverAccount,
            txnDate: receipt.date,
            status: "completed",
            statusText: receipt.status ?? "completed",
            serviceFee: receipt.serviceFee,
            serviceFeeVAT: receipt.vat,
            raw: receipt.raw,
        },
    };
}
function normalizeCbeBirr(submittedReference, receipt) {
    if (receipt.amount === null ||
        receipt.amount <= 0 ||
        !receipt.date ||
        !receipt.receiverAccount ||
        !receipt.receiptNo ||
        !(0, common_1.referencesMatch)(submittedReference, receipt.receiptNo) ||
        !receipt.status ||
        !(0, common_1.completedStatus)(receipt.status)) {
        return failed("cbebirr", "CBE Birr receipt is missing required verified fields.");
    }
    return {
        ok: true,
        provider: "cbebirr",
        data: {
            reference: receipt.receiptNo,
            amount: receipt.amount,
            totalAmount: receipt.totalPaidAmount,
            currency: "ETB",
            payerName: receipt.payerName,
            payerAccount: receipt.payerAccount,
            receiverName: receipt.receiverName,
            receiverAccount: receipt.receiverAccount,
            txnDate: receipt.date,
            status: "completed",
            statusText: receipt.status,
            serviceFee: receipt.serviceFee,
            serviceFeeVAT: receipt.vat,
            reason: receipt.reason,
            raw: receipt.raw,
        },
    };
}
async function verifyCbeBirrOwned(rawReference, phoneNumber) {
    const reference = rawReference.trim().toUpperCase();
    if (!/^[A-Z0-9-]{8,32}$/.test(reference) || !/^251[97]\d{8}$/.test(phoneNumber)) {
        return failed("cbebirr", "CBE Birr requires a valid receipt number and Ethiopian phone number.", "INVALID_REFERENCE");
    }
    try {
        const base = (0, common_1.providerUrl)("CBEBIRR_RECEIPT_BASE_URL", "https://cbepay1.cbe.com.et/aureceipt");
        const url = new URL(base);
        url.searchParams.set("TID", reference);
        url.searchParams.set("PH", phoneNumber);
        const response = await axios_1.default.get(url.toString(), {
            responseType: "arraybuffer",
            timeout: (0, common_1.configuredTimeout)(),
            maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
            headers: { Accept: "application/pdf", "User-Agent": "CHEKMI-Verifier/1.0" },
        });
        return normalizeCbeBirr(reference, await parseCbeBirrPdf(Buffer.from(response.data)));
    }
    catch (error) {
        throw (0, common_1.toOwnedVerifierError)(error, "CBE Birr");
    }
}
async function fetchMpesaPayload(reference, useRelay) {
    let url;
    if (useRelay) {
        const proxyUrl = process.env.MPESA_PROXY_URL?.trim() || "";
        const proxyKey = process.env.MPESA_PROXY_KEY?.trim() || "";
        if (!proxyUrl || !proxyKey) {
            throw new types_1.OwnedVerifierError("M-Pesa relay mode requires MPESA_PROXY_URL and MPESA_PROXY_KEY.", "VERIFIER_CONFIGURATION_ERROR", 503, false);
        }
        url = new URL((0, common_1.relayUrl)(proxyUrl, { reference, key: proxyKey }, "MPESA_PROXY_URL"));
    }
    else {
        url = new URL((0, common_1.providerUrl)("MPESA_RECEIPT_URL", "https://m-pesabusiness.safaricom.et/api/receipt/getReceipt"));
        url.searchParams.set("trxNo", reference);
    }
    const response = await axios_1.default.get(url.toString(), {
        timeout: (0, common_1.configuredTimeout)(),
        maxContentLength: common_1.MAX_PROVIDER_RESPONSE_BYTES,
        headers: {
            Accept: "application/json",
            Referer: "https://m-pesabusiness.safaricom.et/",
            "User-Agent": "CHEKMI-Verifier/1.0",
        },
    });
    if (!response.data || typeof response.data !== "object") {
        throw new types_1.OwnedVerifierError("M-Pesa returned an invalid response.");
    }
    return response.data;
}
async function verifyMpesaOwned(rawReference) {
    const reference = rawReference.trim().toUpperCase();
    if (!/^[A-Z0-9-]{6,32}$/.test(reference)) {
        return failed("mpesa", "Invalid M-Pesa receipt reference.", "INVALID_REFERENCE");
    }
    let lastError = null;
    for (const useRelay of [
        ...((0, common_1.shouldUseDirectProvider)() ? [false] : []),
        ...((0, common_1.shouldUseProviderRelays)() ? [true] : []),
    ]) {
        try {
            const payload = await fetchMpesaPayload(reference, useRelay);
            if (String(payload.responseCode) !== "0" || !(0, common_1.nonEmpty)(payload.base64Data)) {
                continue;
            }
            const pdf = Buffer.from(String(payload.base64Data), "base64");
            if (pdf.length === 0 || pdf.length > common_1.MAX_PROVIDER_RESPONSE_BYTES) {
                return failed("mpesa", "M-Pesa returned an invalid receipt document.");
            }
            return normalizeWalletPdf("mpesa", reference, await parseWalletPdf(pdf));
        }
        catch (error) {
            lastError = (0, common_1.toOwnedVerifierError)(error, useRelay ? "M-Pesa relay" : "M-Pesa");
        }
    }
    if (lastError)
        throw lastError;
    return failed("mpesa", "M-Pesa receipt was not found.", "RECEIPT_NOT_FOUND");
}
//# sourceMappingURL=otherProviders.js.map