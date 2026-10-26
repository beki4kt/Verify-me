import dns from "node:dns/promises";
import https from "node:https";
import tls from "node:tls";
import providerTls from "./provider-tls.cjs";
import { planPreflight } from "./preflight-targets.mjs";

const DEFAULT_TIMEOUT_MS = 12_000;
const timeoutMs = Number(process.env.PREFLIGHT_TIMEOUT_MS || DEFAULT_TIMEOUT_MS);
const allowNonEthiopianEgress = process.argv.includes("--allow-non-et");

function argument(name) {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
}

if (process.argv.includes("--help")) {
  console.log(`CHEKMI verifier host preflight

Usage:
  npm run preflight:host -- --supabase-host=YOUR_PROJECT.supabase.co

Options:
  --supabase-host=HOST  Include the production Supabase hostname.
  --allow-non-et        Report rather than fail on non-Ethiopian egress.

Environment:
  PREFLIGHT_TIMEOUT_MS  Per-check timeout (default ${DEFAULT_TIMEOUT_MS}).`);
  process.exit(0);
}

if (!Number.isFinite(timeoutMs) || timeoutMs < 1_000 || timeoutMs > 60_000) {
  throw new Error("PREFLIGHT_TIMEOUT_MS must be between 1000 and 60000.");
}

const supabaseHost = argument("supabase-host");
const plan = planPreflight(process.env, supabaseHost);

function getEgressTrace() {
  return new Promise((resolve, reject) => {
    const request = https.get({
      hostname: "www.cloudflare.com",
      path: "/cdn-cgi/trace",
      headers: { "user-agent": "chekmi-host-preflight/1.0" },
      timeout: timeoutMs,
    }, (response) => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => { body += chunk; });
      response.on("end", () => {
        if (response.statusCode !== 200) {
          reject(new Error(`HTTP ${response.statusCode}`));
          return;
        }
        const trace = Object.fromEntries(
          body.trim().split("\n").map((line) => line.trim().split("=", 2)),
        );
        resolve({ ip: trace.ip, country: trace.loc });
      });
    });
    request.on("timeout", () => request.destroy(new Error("timed out")));
    request.on("error", reject);
  });
}

async function resolveTarget(host) {
  const attempts = await Promise.allSettled([dns.resolve4(host), dns.resolve6(host)]);
  const addresses = attempts
    .filter((attempt) => attempt.status === "fulfilled")
    .flatMap((attempt) => attempt.value);
  if (addresses.length === 0) throw new Error("DNS returned no IPv4 or IPv6 address");
  return addresses;
}

function checkTls(host, port) {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({
      host,
      port,
      servername: host,
      ...providerTls.providerTlsOptions(host),
    });
    const fail = (error) => {
      socket.destroy();
      reject(error);
    };
    socket.setTimeout(timeoutMs, () => fail(new Error("timed out")));
    socket.once("error", fail);
    socket.once("secureConnect", () => {
      const protocol = socket.getProtocol() || "TLS";
      socket.end();
      resolve(protocol);
    });
  });
}

let failures = 0;
console.log(`CHEKMI verifier host preflight (${plan.mode} egress)\n`);
for (const error of plan.errors) { console.log(`FAIL configuration: ${error}`); failures++; }

try {
  const egress = await getEgressTrace();
  const isEthiopian = egress.country === "ET";
  const acceptable = isEthiopian || !plan.requiresEthiopianEgress || allowNonEthiopianEgress;
  const outcome = isEthiopian || !plan.requiresEthiopianEgress ? "PASS" : allowNonEthiopianEgress ? "WARN" : "FAIL";
  console.log(`${outcome} egress: ${egress.ip || "unknown"} (${egress.country || "unknown"})${plan.requiresEthiopianEgress ? "" : " via configured Ethiopian relays for blocked banks"}`);
  if (!acceptable) failures += 1;
} catch (error) {
  failures += 1;
  console.log(`FAIL egress: ${error.message}`);
}

for (const [label, host, port] of plan.targets) {
  if (host === "apps.cbe.com.et" && process.env.CBE_LEGACY_ENABLED?.trim().toLowerCase() === "false") {
    console.log(`SKIP ${label.padEnd(11)} ${host}:${port} (legacy CBE disabled; not a connectivity pass)`);
    continue;
  }
  try {
    const addresses = await resolveTarget(host);
    const protocol = await checkTls(host, port);
    console.log(`PASS ${label.padEnd(11)} ${host}:${port} ${protocol} (${addresses[0]})`);
  } catch (error) {
    failures += 1;
    console.log(`FAIL ${label.padEnd(11)} ${host}:${port} ${error.message}`);
  }
}

if (failures > 0) {
  console.error(`\nPreflight failed: ${failures} check(s) need attention.`);
  process.exitCode = 1;
} else {
  console.log("\nPreflight passed for enabled targets. Skipped targets remain unverified. Save this output with the hosting decision.");
}
