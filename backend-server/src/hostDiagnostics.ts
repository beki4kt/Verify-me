import { spawn } from "node:child_process";
import { resolve } from "node:path";

export const hostDiagnostics = {
  status: "not_run",
  startedAt: null as string | null,
  finishedAt: null as string | null,
  output: "",
  note: "Connectivity only: no receipt lookup or payment commit. SKIP does not mean PASS.",
};

export function startHostDiagnostics(): void {
  if (process.env.CHEKMI_VERIFICATION_ENGINE === "veritas") {
    hostDiagnostics.status = "not_applicable";
    hostDiagnostics.note = "Veritas transaction-ID verification is selected. Direct bank egress diagnostics do not apply.";
    return;
  }
  if (process.env.CHEKMI_RUN_PREFLIGHT !== "true" || hostDiagnostics.status !== "not_run") return;
  hostDiagnostics.status = "running";
  hostDiagnostics.startedAt = new Date().toISOString();
  const args = [resolve(__dirname, "../scripts/host-preflight.mjs")];
  if (process.env.SUPABASE_URL) {
    try { args.push(`--supabase-host=${new URL(process.env.SUPABASE_URL).hostname}`); }
    catch { /* Readiness/configuration troubleshooting remains separate. */ }
  }
  const child = spawn(process.execPath, args, { stdio: ["ignore", "pipe", "pipe"] });
  let deadline: NodeJS.Timeout;
  const append = (chunk: Buffer | string) => {
    const output = chunk.toString();
    hostDiagnostics.output = (hostDiagnostics.output + output).slice(-32000);
    process.stdout.write(output);
  };
  const finish = (status: string) => {
    if (hostDiagnostics.status !== "running") return;
    clearTimeout(deadline);
    hostDiagnostics.status = status;
    hostDiagnostics.finishedAt = new Date().toISOString();
  };
  child.stdout.on("data", append);
  child.stderr.on("data", append);
  child.once("error", (error) => {
    append(`Preflight could not start: ${error.message}\n`);
    finish("failed");
  });
  child.once("close", (code) => finish(code === 0 ? "passed" : "failed"));
  deadline = setTimeout(() => {
    append("Preflight exceeded the 150-second deadline.\n");
    finish("timed_out");
    child.kill();
  }, 150000);
  deadline.unref();
}
