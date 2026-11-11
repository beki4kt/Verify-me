"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.providerLookupRouter = void 0;
const node_crypto_1 = require("node:crypto");
const express_1 = require("express");
const ownedVerifier_1 = require("../ownedVerifier");
const veritasVerifier_1 = require("../veritasVerifier");
exports.providerLookupRouter = (0, express_1.Router)();
const providers = new Set(["telebirr", "cbe", "cbebirr", "dashen", "abyssinia", "mpesa"]);
exports.providerLookupRouter.post("/internal/provider-lookup", async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    const expected = process.env.CHEKMI_INTERNAL_LOOKUP_KEY?.trim() || "";
    const supplied = req.header("x-chekmi-lookup-key") || "";
    const a = Buffer.from(expected);
    const b = Buffer.from(supplied);
    if (!expected || a.length !== b.length || !(0, node_crypto_1.timingSafeEqual)(a, b)) {
        res.status(401).json({ ok: false, code: "ACCESS_DENIED", error: "Lookup access denied." });
        return;
    }
    if ((0, veritasVerifier_1.verifierConfiguration)().engine !== "owned") {
        res.status(503).json({ ok: false, code: "VERIFIER_CONFIGURATION_ERROR", error: "Owned verification is not selected." });
        return;
    }
    const body = req.body;
    const provider = body?.provider;
    const reference = body?.reference;
    if (typeof provider !== "string" || !providers.has(provider) ||
        typeof reference !== "string" || !reference.trim() || reference.length > 256 ||
        (body?.suffix !== undefined && (typeof body.suffix !== "string" || body.suffix.length > 8)) ||
        (body?.phoneNumber !== undefined && (typeof body.phoneNumber !== "string" || body.phoneNumber.length > 16))) {
        res.status(400).json({ ok: false, code: "INVALID_LOOKUP", error: "Invalid provider lookup." });
        return;
    }
    try {
        const result = await (0, ownedVerifier_1.verifyWithOwnedRoute)(provider, {
            reference, suffix: body?.suffix,
            phoneNumber: body?.phoneNumber,
        });
        res.status(200).json(result);
    }
    catch (error) {
        if (error instanceof ownedVerifier_1.OwnedVerifierError) {
            res.status(error.status).json({ ok: false, code: error.code, error: error.message, retryable: error.retryable });
            return;
        }
        res.status(503).json({ ok: false, code: "PROVIDER_UNAVAILABLE", error: "Provider lookup is unavailable.", retryable: true });
    }
});
//# sourceMappingURL=providerLookupRoute.js.map