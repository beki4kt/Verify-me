import { Router, type NextFunction, type Request, type Response } from "express";

import {
  authenticateOperator,
  OperatorAuthenticationError,
  OperatorConfigurationError,
  operatorIsConfigured,
  verifyOperatorToken,
  type OperatorClaims,
} from "../operatorAuth";
import { callServiceRpc, SupabaseRpcError } from "../supabaseRpc";
import { ownedVerifierConfiguration } from "../ownedVerifier";

try {
  process.loadEnvFile?.();
} catch (error) {
  if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
}

export const operatorRouter = Router();

const loginBuckets = new Map<string, { attempts: number; resetsAt: number }>();

function clientIdentity(req: Request): string {
  return req.ip || req.socket.remoteAddress || "unknown";
}

function operatorLoginRateLimit(req: Request, res: Response, next: NextFunction): void {
  const identity = clientIdentity(req);
  const now = Date.now();
  const current = loginBuckets.get(identity);
  if (!current || current.resetsAt <= now) {
    loginBuckets.set(identity, { attempts: 1, resetsAt: now + 15 * 60_000 });
    next();
    return;
  }
  current.attempts += 1;
  if (current.attempts <= 5) {
    next();
    return;
  }
  res.setHeader("Retry-After", Math.ceil((current.resetsAt - now) / 1000));
  res.status(429).json({
    success: false,
    error: "Too many owner login attempts. Try again later.",
    code: "OPERATOR_RATE_LIMIT",
  });
}

function requireOperator(req: Request, res: Response, next: NextFunction): void {
  const authorization = req.header("authorization") || "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  try {
    res.locals.operator = verifyOperatorToken(token);
    next();
  } catch (error) {
    const code = error instanceof OperatorConfigurationError
      ? error.code
      : "OPERATOR_SESSION_INVALID";
    res.status(error instanceof OperatorConfigurationError ? 503 : 401).json({
      success: false,
      error: error instanceof Error ? error.message : "Owner session is invalid.",
      code,
    });
  }
}

function owner(res: Response): OperatorClaims {
  return res.locals.operator as OperatorClaims;
}

function text(value: unknown, maximum = 160): string {
  return typeof value === "string" ? value.trim().slice(0, maximum) : "";
}

function positiveInteger(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function optionalIsoDate(value: unknown): string | null {
  if (value == null || value === "") return null;
  const parsed = new Date(String(value));
  if (Number.isNaN(parsed.valueOf())) throw new Error("Invalid date value.");
  return parsed.toISOString();
}

function emptySnapshot() {
  return {
    businesses: [],
    support_cases: [],
    deletion_requests: [],
    invoices: [],
    operator_audit: [],
    metrics: {
      businesses: 0,
      active_businesses: 0,
      attention_businesses: 0,
      active_sessions: 0,
      open_support_cases: 0,
      open_invoices: 0,
    },
  };
}

function sendOperatorError(res: Response, error: unknown): void {
  if (error instanceof SupabaseRpcError) {
    const unavailable = error.code === "DATABASE_NOT_CONFIGURED";
    res.status(unavailable ? 503 : Math.min(Math.max(error.status, 400), 599)).json({
      success: false,
      error: error.message,
      code: error.code || "OPERATOR_DATABASE_ERROR",
    });
    return;
  }
  const message = error instanceof Error ? error.message : "Operator action failed.";
  res.status(400).json({ success: false, error: message, code: "OPERATOR_ACTION_FAILED" });
}

async function audit(action: string, claims: OperatorClaims, metadata: Record<string, unknown> = {}) {
  try {
    await callServiceRpc("service_operator_record_audit", {
      p_operator_email: claims.sub,
      p_action: action,
      p_subject_type: text(metadata.subjectType, 64) || "operator",
      p_subject_id: text(metadata.subjectId, 160) || claims.sub,
      p_metadata: metadata,
    });
  } catch (error) {
    console.error("[operator-audit]", action, error);
  }
}

operatorRouter.post("/operator/login", operatorLoginRateLimit, async (req, res) => {
  try {
    const email = text(req.body?.email, 200);
    const password = typeof req.body?.password === "string" ? req.body.password : "";
    const code = text(req.body?.code, 12);
    if (!email || !password || !code) {
      res.status(400).json({
        success: false,
        error: "Email, password, and authenticator code are required.",
        code: "OPERATOR_CREDENTIALS_REQUIRED",
      });
      return;
    }
    const authenticated = authenticateOperator({ email, password, code });
    loginBuckets.delete(clientIdentity(req));
    await audit("operator_login_succeeded", authenticated.claims, {
      subjectType: "operator_session",
      subjectId: authenticated.claims.jti,
    });
    res.json({
      success: true,
      token: authenticated.token,
      operator: {
        email: authenticated.claims.sub,
        role: authenticated.claims.role,
        expiresAt: new Date(authenticated.claims.exp * 1000).toISOString(),
      },
    });
  } catch (error) {
    if (error instanceof OperatorConfigurationError) {
      res.status(503).json({ success: false, error: error.message, code: error.code });
      return;
    }
    const authError = error instanceof OperatorAuthenticationError;
    res.status(authError ? 401 : 500).json({
      success: false,
      error: authError ? "Invalid owner credentials or authenticator code." : "Owner login failed.",
      code: authError ? error.code : "OPERATOR_LOGIN_FAILED",
    });
  }
});

operatorRouter.get("/operator/overview", requireOperator, async (_req, res) => {
  const claims = owner(res);
  const system = {
    environment: process.env.CHEKMI_ENV || process.env.NODE_ENV || "development",
    operatorConfigured: operatorIsConfigured(),
    databaseConfigured: Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY),
    verifierConfigured:
      process.env.CHEKMI_VERIFIER_MODE === "fixtures" ||
      ownedVerifierConfiguration().configured,
    verifierMode: process.env.CHEKMI_VERIFIER_MODE || "live",
    verifier: ownedVerifierConfiguration(),
    generatedAt: new Date().toISOString(),
  };
  if (!system.databaseConfigured) {
    res.json({ success: true, snapshot: emptySnapshot(), system });
    return;
  }
  try {
    const snapshot = await callServiceRpc("service_operator_snapshot", {});
    res.json({ success: true, snapshot, system });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.post("/operator/businesses", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    const body = req.body || {};
    const name = text(body.name, 120);
    const code = text(body.businessCode, 32).toUpperCase();
    const adminName = text(body.adminName, 120);
    const adminPhone = text(body.adminPhone, 24);
    const adminPassword = typeof body.adminPassword === "string" ? body.adminPassword : "";
    const adminPin = text(body.adminPin, 20);
    if (!name || !/^[A-Z0-9-]{3,32}$/.test(code) || !adminName || !adminPhone || !adminPin) {
      throw new Error("Restaurant, code, and complete root-admin details are required.");
    }
    if (adminPassword.length < 10) throw new Error("Root-admin password must be at least 10 characters.");
    const result = await callServiceRpc("service_operator_create_business", {
      p_operator_email: claims.sub,
      p_name: name,
      p_business_code: code,
      p_address: text(body.address, 240),
      p_tier: text(body.tier, 32) || "basic",
      p_status: text(body.status, 32) || "trial",
      p_max_staff: positiveInteger(body.maxStaff, 5),
      p_has_cashier: body.hasCashier === true,
      p_admin_name: adminName,
      p_admin_phone: adminPhone,
      p_admin_password: adminPassword,
      p_admin_pin: adminPin,
    });
    res.status(201).json({ success: true, business: result });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.patch("/operator/businesses/:id/status", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    if (typeof req.body?.active !== "boolean") throw new Error("An active status is required.");
    await callServiceRpc("service_operator_set_business_active", {
      p_operator_email: claims.sub,
      p_business_id: req.params.id,
      p_active: req.body.active,
      p_reason: text(req.body.reason, 500),
    });
    res.json({ success: true });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.patch("/operator/businesses/:id/subscription", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    const status = text(req.body?.status, 32);
    const allowed = ["trial", "active", "overdue", "grace_period", "cancelled", "suspended"];
    if (!allowed.includes(status)) throw new Error("Choose a valid subscription status.");
    await callServiceRpc("service_operator_update_subscription", {
      p_operator_email: claims.sub,
      p_business_id: req.params.id,
      p_tier: text(req.body?.tier, 32) || "basic",
      p_status: status,
      p_ends_at: optionalIsoDate(req.body?.endsAt),
      p_grace_ends_at: optionalIsoDate(req.body?.graceEndsAt),
      p_max_staff: positiveInteger(req.body?.maxStaff, 5),
      p_has_cashier: req.body?.hasCashier === true,
    });
    res.json({ success: true });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.post("/operator/businesses/:id/revoke-sessions", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    const revoked = await callServiceRpc<number>("service_operator_revoke_business_sessions", {
      p_operator_email: claims.sub,
      p_business_id: req.params.id,
      p_reason: text(req.body?.reason, 500),
    });
    res.json({ success: true, revoked });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.patch("/operator/support/:id", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    const status = text(req.body?.status, 32);
    if (!["open", "in_progress", "resolved", "closed"].includes(status)) {
      throw new Error("Choose a valid support status.");
    }
    await callServiceRpc("service_operator_update_support_case", {
      p_operator_email: claims.sub,
      p_case_id: req.params.id,
      p_status: status,
    });
    res.json({ success: true });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.patch("/operator/deletions/:id", requireOperator, async (req, res) => {
  const claims = owner(res);
  try {
    const status = text(req.body?.status, 32);
    const allowed = ["pending_review", "retention_hold", "approved", "rejected"];
    if (!allowed.includes(status)) throw new Error("Choose a valid deletion-review status.");
    await callServiceRpc("service_operator_review_deletion", {
      p_operator_email: claims.sub,
      p_request_id: req.params.id,
      p_status: status,
      p_notes: text(req.body?.notes, 1000),
    });
    res.json({ success: true });
  } catch (error) {
    sendOperatorError(res, error);
  }
});

operatorRouter.post("/operator/system/refresh-subscriptions", requireOperator, async (_req, res) => {
  const claims = owner(res);
  try {
    const changed = await callServiceRpc<number>("service_refresh_subscription_statuses", {});
    await audit("subscription_status_refresh", claims, { changed });
    res.json({ success: true, changed });
  } catch (error) {
    sendOperatorError(res, error);
  }
});
