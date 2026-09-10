const checks = [
  {
    name: "verification",
    url: "https://lpbdxtzyzlaioggefscc.supabase.co/functions/v1/chekmi-verify",
    validate: (body) =>
      body?.status === "ready" &&
      (body?.verifier?.engine === "veritas" || body?.verifier === "veritas"),
  },
  ...["privacy.html", "terms.html", "support.html", "delete-account.html"].map(
    (page) => ({
      name: page,
      url: `https://beki4kt.github.io/Verify-me/${page}`,
      validate: (body) => typeof body === "string" && body.includes("CHEKMI"),
      text: true,
    }),
  ),
];

let failed = false;
for (const check of checks) {
  const started = Date.now();
  try {
    const response = await fetch(check.url, {
      headers: { "user-agent": "chekmi-production-monitor/1.0" },
      signal: AbortSignal.timeout(15_000),
    });
    const body = check.text ? await response.text() : await response.json();
    const ok = response.ok && check.validate(body);
    failed ||= !ok;
    console.log(
      JSON.stringify({
        check: check.name,
        ok,
        status: response.status,
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
