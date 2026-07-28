import { Router, Request, Response } from "express";
import { VerifierClient, VerifierError, RateLimitError } from "@creofam/verifier";

export const verifyRouter = Router();

// Initialize the SDK client
const verifier = new VerifierClient({
  baseUrl: "https://verifyapi.leulzenebe.pro"
});


verifyRouter.post("/verify", async (req: Request, res: Response) => {
  try {
    const { provider, reference, suffix, amount } = req.body;

    // Validate required fields
    if (!provider || !reference) {
      return res.status(400).json({
        success: false,
        error: "Missing required fields: provider and reference are required",
      });
    }

    // Validate provider
    const validProviders = ["CBE", "Telebirr", "Dashen", "BankOfAbyssinia", "MPesa"];
    if (!validProviders.includes(provider)) {
      return res.status(400).json({
        success: false,
        error: "Invalid provider. Must be one of: " + validProviders.join(", "),
      });
    }

    console.log("[VERIFY] Processing verification for " + provider + ": " + reference);

    // Build verification request
    const verificationRequest: any = {
      provider,
      reference,
    };
    if (suffix) verificationRequest.suffix = suffix;

    // Call the SDK
    const verificationResult = await verifier.verify(verificationRequest);

    console.log("[VERIFY] SDK result:", JSON.stringify(verificationResult));

    // Fraud detection checks
    const fraudDetected = !verificationResult.verified;
    const underpaymentDetected =
      amount && parseFloat(verificationResult.amount) < amount;

    // TODO: Log to database (Supabase/PostgreSQL)
    // await db.insert('verifications').values({ ... });

    return res.status(200).json({
      success: true,
      data: {
        verified: verificationResult.verified,
        transactionId: verificationResult.transactionId || null,
        amount: verificationResult.amount || null,
        currency: verificationResult.currency || "ETB",
        receiver: verificationResult.receiver || null,
        timestamp: verificationResult.timestamp || null,
        provider,
        reference,
        fraudDetected,
        underpaymentDetected,
      },
    });
  } catch (error) {
    console.error("[VERIFY] Error:", error);

    // Handle SDK errors
    if (error instanceof VerifierError) {
      return res.status(502).json({
        success: false,
        error: "Verification failed: " + error.message,
        code: "VERIFIER_ERROR",
      });
    }

    if (error instanceof RateLimitError) {
      return res.status(429).json({
        success: false,
        error: "Rate limit exceeded. Please try again later.",
        code: "RATE_LIMIT",
      });
    }

    return res.status(500).json({
      success: false,
      error: "Internal server error",
      message: error instanceof Error ? error.message : "Unknown error",
      code: "INTERNAL_ERROR",
    });
  }
});
