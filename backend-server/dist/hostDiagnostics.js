"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hostDiagnostics = void 0;
exports.startHostDiagnostics = startHostDiagnostics;
const node_child_process_1 = require("node:child_process");
const node_path_1 = require("node:path");
exports.hostDiagnostics = {
    status: "not_run",
    startedAt: null,
    finishedAt: null,
    output: "",
    note: "Connectivity only: no receipt lookup or payment commit. SKIP does not mean PASS.",
};
function startHostDiagnostics() {
    if (process.env.CHEKMI_VERIFICATION_ENGINE === "veritas") {
        exports.hostDiagnostics.status = "not_applicable";
        exports.hostDiagnostics.note = "Veritas transaction-ID verification is selected. Direct bank egress diagnostics do not apply.";
        return;
    }
    if (process.env.CHEKMI_RUN_PREFLIGHT !== "true" || exports.hostDiagnostics.status !== "not_run")
        return;
    exports.hostDiagnostics.status = "running";
    exports.hostDiagnostics.startedAt = new Date().toISOString();
    const args = [(0, node_path_1.resolve)(__dirname, "../scripts/host-preflight.mjs")];
    if (process.env.SUPABASE_URL) {
        try {
            args.push(`--supabase-host=${new URL(process.env.SUPABASE_URL).hostname}`);
        }
        catch { /* Readiness/configuration troubleshooting remains separate. */ }
    }
    const child = (0, node_child_process_1.spawn)(process.execPath, args, { stdio: ["ignore", "pipe", "pipe"] });
    let deadline;
    const append = (chunk) => {
        const output = chunk.toString();
        exports.hostDiagnostics.output = (exports.hostDiagnostics.output + output).slice(-32000);
        process.stdout.write(output);
    };
    const finish = (status) => {
        if (exports.hostDiagnostics.status !== "running")
            return;
        clearTimeout(deadline);
        exports.hostDiagnostics.status = status;
        exports.hostDiagnostics.finishedAt = new Date().toISOString();
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
//# sourceMappingURL=hostDiagnostics.js.map