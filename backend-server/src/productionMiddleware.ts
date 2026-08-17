import type { NextFunction, Request, Response } from "express";

const buckets = new Map<string, { count: number; resetsAt: number }>();

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const started = Date.now();
  const requestId = req.header("x-request-id") || crypto.randomUUID();
  res.setHeader("x-request-id", requestId);
  res.on("finish", () => {
    console.log(JSON.stringify({
      level: "info", event: "http_request", requestId, method: req.method,
      path: req.path, status: res.statusCode, durationMs: Date.now() - started,
      timestamp: new Date().toISOString(),
    }));
  });
  next();
}

export function requireProductionHttps(req: Request, res: Response, next: NextFunction) {
  if (process.env.NODE_ENV !== "production") return next();
  const protocol = req.header("x-forwarded-proto")?.split(",")[0]?.trim();
  if (req.secure || protocol === "https") return next();
  res.status(426).json({ success: false, error: "HTTPS is required.", code: "HTTPS_REQUIRED" });
}

export function verificationRateLimit(req: Request, res: Response, next: NextFunction) {
  const maximum = Number(process.env.VERIFY_RATE_LIMIT_PER_MINUTE) || 20;
  const identity = req.header("authorization")?.slice(-24) || req.ip || "unknown";
  const now = Date.now();
  const current = buckets.get(identity);
  if (!current || current.resetsAt <= now) {
    buckets.set(identity, { count: 1, resetsAt: now + 60_000 });
    return next();
  }
  current.count += 1;
  if (current.count <= maximum) return next();
  res.setHeader("Retry-After", Math.ceil((current.resetsAt - now) / 1000));
  res.status(429).json({ success: false, error: "Too many verification requests. Try again shortly.", code: "RATE_LIMIT" });
}
