import express from "express";
import cors from "cors";
import { verifyRouter } from "./routes/verifyRoute";
import { requestLogger, requireProductionHttps, verificationRateLimit } from "./productionMiddleware";

const app = express();
const PORT = Number(process.env.PORT) || 3000;
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || "")
  .split(",").map((origin) => origin.trim()).filter(Boolean);

app.set("trust proxy", 1);
app.use(requestLogger);
app.use(requireProductionHttps);
app.use(cors({
  origin(origin, callback) {
    if (!origin || process.env.NODE_ENV !== "production") return callback(null, true);
    return callback(null, allowedOrigins.includes(origin));
  },
  methods: ["GET", "POST"],
  allowedHeaders: ["Content-Type", "Authorization", "x-api-key", "x-request-id"],
}));
// Base64 expands a compressed receipt by roughly 33%. The application and
// database still enforce a strict 1.5 MB decoded-image ceiling.
app.use(express.json({ limit: "3mb" }));

// Verification routes (mounted at /api → /api/verify, /api/verify/:provider)
app.use("/api", verificationRateLimit, verifyRouter);

// Liveness probe.
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.get("/ready", (_req, res) => {
  const configured = Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.VERIFIER_UPSTREAM_KEY);
  res.status(configured ? 200 : 503).json({ status: configured ? "ready" : "not_ready", timestamp: new Date().toISOString() });
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
  console.log(`CHEKMI API running on http://0.0.0.0:${PORT}`);
  console.log(`  upstream: ${process.env.VERIFIER_BASE_URL || "https://verifyapi.leulzenebe.pro"}`);
  console.log(`  api-key gate: ${gate}`);
});

export default app;
