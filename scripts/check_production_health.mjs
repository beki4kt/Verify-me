import { existsSync, readFileSync } from "node:fs";
import { healthState, verifierIsReady } from './health_contract.mjs';

const environment = (process.env.CHEKMI_ENV || "production").toLowerCase();
if (!['staging', 'production'].includes(environment)) {
  throw new Error('CHEKMI_ENV must be staging or production for remote health checks');
}
const productionUrl = 'https://lpbdxtzyzlaioggefscc.supabase.co';
const supabaseUrl = (process.env.CHEKMI_SUPABASE_URL ||
  (environment === 'production' ? productionUrl : '')).replace(/\/$/, '');
if (!supabaseUrl || (environment === 'staging' && supabaseUrl === productionUrl) ||
    (environment === 'production' && supabaseUrl !== productionUrl)) {
  throw new Error('Health-check target does not match CHEKMI_ENV');
}
const localConfigPath = new URL("../config/production.json", import.meta.url);
const localConfig = environment === 'production' && existsSync(localConfigPath)
  ? JSON.parse(readFileSync(localConfigPath, "utf8"))
  : {};
const publishableKey =
  process.env.CHEKMI_SUPABASE_PUBLISHABLE_KEY ||
  localConfig.CHEKMI_SUPABASE_PUBLISHABLE_KEY;

if (!publishableKey) {
  throw new Error("CHEKMI_SUPABASE_PUBLISHABLE_KEY is required for remote health checks");
}

const supabaseHeaders = {
  apikey: publishableKey,
  authorization: `Bearer ${publishableKey}`,
};

const checks = [
  {
    name: "verification",
    url: `${supabaseUrl}/functions/v1/chekmi-verify`,
    validate: verifierIsReady,
  },
  {
    name: "receipt evidence",
    url: `${supabaseUrl}/functions/v1/chekmi-receipt-evidence`,
    validate: (body, response) =>
      response.status === 401 && body?.code === 'SESSION_REQUIRED',
  },
  {
    name: "demo verification",
    url: `${supabaseUrl}/functions/v1/chekmi-demo`,
    validate: (body, response) =>
      response.ok &&
      body?.status === "ready" &&
      body?.demo === true &&
      body?.service === "chekmi-demo",
  },
  {
    name: "current legal versions",
    url: `${supabaseUrl}/rest/v1/legal_documents?select=document_type,version,is_current&is_current=eq.true`,
    headers: supabaseHeaders,
    validate: (body, response) =>
      response.ok &&
      Array.isArray(body) &&
      body.length === 2 &&
      ["privacy", "terms"].every(
        (type) =>
          body.filter(
            (document) =>
              document.document_type === type &&
              document.version === "2026-09-10" &&
              document.is_current === true,
          ).length === 1,
      ),
  },
  ...[
    ["delete_current_staff_account", { p_token: "__chekmi_health_invalid_session__", p_reason: null }],
    ["report_client_error", {
      p_token: "__chekmi_health_invalid_session__",
      p_area: "health",
      p_error_code: "invalid_session_probe",
      p_platform: "ci",
    }],
  ].map(([name, body]) => ({
    name: `${name} availability`,
    url: `${supabaseUrl}/rest/v1/rpc/${name}`,
    method: "POST",
    headers: { ...supabaseHeaders, "content-type": "application/json" },
    body: JSON.stringify(body),
    validate: (result, response) =>
      response.status === 403 && result?.code === "28000",
  })),
  ...(environment === 'production' ? ["privacy.html", "terms.html", "support.html", "delete-account.html"] : []).map(
    (page) => ({
      name: page,
      url: `https://beki4kt.github.io/Verify-me/${page}`,
      validate: (body, response) =>
        response.ok && typeof body === "string" && body.includes("CHEKMI"),
      text: true,
    }),
  ),
];

let failed = false;
for (const check of checks) {
  const started = Date.now();
  try {
    const response = await fetch(check.url, {
      method: check.method ?? "GET",
      headers: {
        "user-agent": "chekmi-production-monitor/1.0",
        ...check.headers,
      },
      body: check.body,
      signal: AbortSignal.timeout(15_000),
    });
    const raw = await response.text();
    let body = raw;
    if (!check.text) {
      try { body = JSON.parse(raw); } catch { body = null; }
    }
    const ok = check.validate(body, response);
    const state = healthState(response.status, ok);
    failed ||= !ok;
    console.log(
      JSON.stringify({
        check: check.name,
        ok,
        state,
        status: response.status,
        engine: check.name === 'verification' ? body?.verifier?.engine ?? null : undefined,
        code: check.method === "POST" ? body?.code ?? null : undefined,
        duration_ms: Date.now() - started,
      }),
    );
  } catch (error) {
    failed = true;
    console.error(
      JSON.stringify({
        check: check.name,
        ok: false,
        state: 'service_unavailable',
        error: error?.name ?? "RequestError",
        duration_ms: Date.now() - started,
      }),
    );
  }
}

if (failed) process.exitCode = 1;
