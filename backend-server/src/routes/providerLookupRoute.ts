import { timingSafeEqual } from "node:crypto";
import { Router } from "express";
import { verifyWithOwnedRoute, OwnedVerifierError, type Provider } from "../ownedVerifier";
import { verifierConfiguration } from "../veritasVerifier";

export const providerLookupRouter = Router();
const providers = new Set<Provider>(["telebirr", "cbe", "cbebirr", "dashen", "abyssinia", "mpesa"]);

providerLookupRouter.post("/internal/provider-lookup", async (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  const expected = process.env.CHEKMI_INTERNAL_LOOKUP_KEY?.trim() || "";
  const supplied = req.header("x-chekmi-lookup-key") || "";
  const a = Buffer.from(expected);
  const b = Buffer.from(supplied);
  if (!expected || a.length !== b.length || !timingSafeEqual(a, b)) {
    res.status(401).json({ ok: false, code: "ACCESS_DENIED", error: "Lookup access denied." });
    return;
  }
  if (verifierConfiguration().engine !== "owned") {
    res.status(503).json({ ok: false, code: "VERIFIER_CONFIGURATION_ERROR", error: "Owned verification is not selected." });
    return;
  }
  const body = req.body as Record<string, unknown> | undefined;
  const provider = body?.provider;
  const reference = body?.reference;
  if (typeof provider !== "string" || !providers.has(provider as Provider) ||
      typeof reference !== "string" || !reference.trim() || reference.length > 256 ||
      (body?.suffix !== undefined && (typeof body.suffix !== "string" || body.suffix.length > 8)) ||
      (body?.phoneNumber !== undefined && (typeof body.phoneNumber !== "string" || body.phoneNumber.length > 16))) {
    res.status(400).json({ ok: false, code: "INVALID_LOOKUP", error: "Invalid provider lookup." });
    return;
  }
  try {
    const result = await verifyWithOwnedRoute(provider as Provider, {
      reference, suffix: body?.suffix as string | undefined,
      phoneNumber: body?.phoneNumber as string | undefined,
    });
    res.status(200).json(result);
  } catch (error) {
    if (error instanceof OwnedVerifierError) {
      res.status(error.status).json({ ok: false, code: error.code, error: error.message, retryable: error.retryable });
      return;
    }
    res.status(503).json({ ok: false, code: "PROVIDER_UNAVAILABLE", error: "Provider lookup is unavailable.", retryable: true });
  }
});
