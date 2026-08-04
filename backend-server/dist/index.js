"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const verifyRoute_1 = require("./routes/verifyRoute");
const app = (0, express_1.default)();
const PORT = Number(process.env.PORT) || 3000;
app.use((0, cors_1.default)());
app.use(express_1.default.json({ limit: "1mb" }));
// Verification routes (mounted at /api → /api/verify, /api/verify/:provider)
app.use("/api", verifyRoute_1.verifyRouter);
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
}));
app.listen(PORT, "0.0.0.0", () => {
    const gate = process.env.VERIFY_API_KEY ? "ON" : "OFF (dev)";
    console.log(`Verify-me API running on http://0.0.0.0:${PORT}`);
    console.log(`  upstream: ${process.env.VERIFIER_BASE_URL || "https://verifyapi.leulzenebe.pro"}`);
    console.log(`  api-key gate: ${gate}`);
});
exports.default = app;
//# sourceMappingURL=index.js.map