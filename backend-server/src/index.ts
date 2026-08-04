import express from "express";
import cors from "cors";
import { verifyRouter } from "./routes/verifyRoute";

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json({ limit: "1mb" }));

// Verification routes (mounted at /api → /api/verify, /api/verify/:provider)
app.use("/api", verifyRouter);

// Liveness probe.
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// 404 → JSON (no HTML fallbacks).
app.use((req, res) => {
  res.status(404).json({ success: false, error: `Not found: ${req.method} ${req.path}`, code: "NOT_FOUND" });
});

// Global error handler.
app.use(((err, _req, res, _next) => {
  console.error("[server] unhandled error:", err);
  res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
}) as express.ErrorRequestHandler);

app.listen(PORT, "0.0.0.0", () => {
  const gate = process.env.VERIFY_API_KEY ? "ON" : "OFF (dev)";
  console.log(`Verify-me API running on http://0.0.0.0:${PORT}`);
  console.log(`  upstream: ${process.env.VERIFIER_BASE_URL || "https://verifyapi.leulzenebe.pro"}`);
  console.log(`  api-key gate: ${gate}`);
});

export default app;
