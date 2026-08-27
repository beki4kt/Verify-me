"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const verifyRoute_1 = require("./routes/verifyRoute");
const operatorRoute_1 = require("./routes/operatorRoute");
const productionMiddleware_1 = require("./productionMiddleware");
const ownedVerifier_1 = require("./ownedVerifier");
const app = (0, express_1.default)();
const PORT = Number(process.env.PORT) || 3000;
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || "")
    .split(",").map((origin) => origin.trim()).filter(Boolean);
app.set("trust proxy", 1);
app.use(productionMiddleware_1.requestLogger);
app.use(productionMiddleware_1.requireProductionHttps);
app.use((0, cors_1.default)({
    origin(origin, callback) {
        if (!origin || process.env.NODE_ENV !== "production")
            return callback(null, true);
        return callback(null, allowedOrigins.includes(origin));
    },
    methods: ["GET", "POST", "PATCH"],
    allowedHeaders: ["Content-Type", "Authorization", "x-api-key", "x-request-id"],
}));
// Base64 expands a compressed receipt by roughly 33%. The application and
// database still enforce a strict 1.5 MB decoded-image ceiling.
app.use(express_1.default.json({ limit: "3mb" }));
// Verification routes (mounted at /api → /api/verify, /api/verify/:provider)
app.use("/api", operatorRoute_1.operatorRouter);
app.use("/api", productionMiddleware_1.verificationRateLimit, verifyRoute_1.verifyRouter);
// Liveness probe.
app.get("/health", (_req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
});
app.get("/ready", (_req, res) => {
    const ownedVerifier = (0, ownedVerifier_1.ownedVerifierConfiguration)();
    const verifierConfigured = verifyRoute_1.ACTIVE_VERIFIER_MODE === "fixtures" || ownedVerifier.configured;
    const configured = Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY && verifierConfigured);
    const operatorConfigured = Boolean(process.env.OPERATOR_EMAIL && (process.env.OPERATOR_PASSWORD_HASH || (process.env.NODE_ENV !== "production" && process.env.OPERATOR_PASSWORD)));
    res.status(configured ? 200 : 503).json({ status: configured ? "ready" : "not_ready", verifierMode: verifyRoute_1.ACTIVE_VERIFIER_MODE, verifier: ownedVerifier, operatorConfigured, timestamp: new Date().toISOString() });
});
// 404 → JSON (no HTML fallbacks).
app.use((req, res) => {
    res.status(404).json({ success: false, error: `Not found: ${req.method} ${req.path}`, code: "NOT_FOUND" });
});
// Global error handler.
app.use(((err, _req, res, _next) => {
    console.error("[server] unhandled error:", err);
    res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
}));
app.listen(PORT, "0.0.0.0", () => {
    const gate = process.env.VERIFY_API_KEY ? "ON" : "OFF (dev)";
    console.log(`CHEKMI API running on http://0.0.0.0:${PORT}`);
    console.log(`  verifier: owned (${(0, ownedVerifier_1.ownedVerifierConfiguration)().mode})`);
    console.log(`  api-key gate: ${gate}`);
});
exports.default = app;
//# sourceMappingURL=index.js.map