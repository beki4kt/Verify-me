"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nonEmpty = nonEmpty;
exports.titleCase = titleCase;
exports.ethiopianLocalDate = ethiopianLocalDate;
exports.completedStatus = completedStatus;
exports.referencesMatch = referencesMatch;
exports.safeRaw = safeRaw;
exports.extractNewCbeToken = extractNewCbeToken;
exports.isLegacyCbeReference = isLegacyCbeReference;
exports.extractLegacyCbeUrlData = extractLegacyCbeUrlData;
function nonEmpty(value) {
    const text = String(value ?? "").replace(/\s+/g, " ").trim();
    return text ? text : null;
}
function titleCase(value) {
    if (!value)
        return null;
    return value
        .toLowerCase()
        .replace(/\b\p{L}/gu, (character) => character.toUpperCase());
}
/** Provider timestamps without offsets are Ethiopian local time (UTC+3). */
function ethiopianLocalDate(value) {
    const text = nonEmpty(value);
    if (!text)
        return null;
    let match = text.match(/^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$/);
    if (match) {
        const [, day, month, year, hour, minute, second = "00"] = match;
        return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
    }
    match = text.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[, ]+\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$/i);
    if (match) {
        const [, year, month, day, rawHour, minute, second = "00", meridiem] = match;
        let hour = Number(rawHour);
        if (meridiem) {
            hour %= 12;
            if (meridiem.toUpperCase() === "PM")
                hour += 12;
        }
        return validIso(`${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}T${String(hour).padStart(2, "0")}:${minute}:${second}+03:00`);
    }
    // ISO-shaped provider values without an explicit offset are Ethiopian local
    // time, regardless of the operating system timezone of the CHEKMI server.
    match = text.match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/);
    if (match) {
        const [, year, month, day, hour, minute, second = "00"] = match;
        return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
    }
    return validIso(text);
}
function validIso(value) {
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? null : date.toISOString();
}
function completedStatus(value) {
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
function referencesMatch(left, right) {
    const normalize = (value) => String(value ?? "")
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, "");
    const normalizedLeft = normalize(left);
    const normalizedRight = normalize(right);
    return Boolean(normalizedLeft && normalizedLeft === normalizedRight);
}
/** Keep evidence useful without storing multi-megabyte PDF/base64 fields. */
function safeRaw(raw) {
    const copy = { ...raw };
    delete copy.base64Data;
    delete copy.pdf;
    return copy;
}
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
//# sourceMappingURL=receiptFormat.js.map