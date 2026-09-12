import { existsSync, readFileSync } from "node:fs";

const supabaseUrl = "https://lpbdxtzyzlaioggefscc.supabase.co";
const localConfigPath = new URL("../config/production.json", import.meta.url);
const localConfig = existsSync(localConfigPath)
  ? JSON.parse(readFileSync(localConfigPath, "utf8"))
  : {};
const publishableKey =
  process.env.CHEKMI_SUPABASE_PUBLISHABLE_KEY ||
  localConfig.CHEKMI_SUPABASE_PUBLISHABLE_KEY;

if (!publishableKey) {
  throw new Error("CHEKMI_SUPABASE_PUBLISHABLE_KEY is required for production health checks");
}

const supabaseHeaders = {
  apikey: publishableKey,
  authorization: `Bearer ${publishableKey}`,
};

const checks = [
  {
    name: "verification",
    url: `${supabaseUrl}/functions/v1/chekmi-verify`,
    validate: (body, response) =>
      response.ok &&
      body?.status === "ready" &&
      (body?.verifier?.engine === "veritas" || body?.verifier === "veritas"),
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
  ...["privacy.html", "terms.html", "support.html", "delete-account.html"].map(
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
    const body = check.text ? await response.text() : await response.json();
    const ok = check.validate(body, response);
    failed ||= !ok;
    console.log(
      JSON.stringify({
        check: check.name,
        ok,
        status: response.status,
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
        error: error?.name ?? "RequestError",
        duration_ms: Date.now() - started,
      }),
    );
  }
}

if (failed) process.exitCode = 1;
