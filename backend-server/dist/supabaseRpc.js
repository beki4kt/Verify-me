"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupabaseRpcError = void 0;
exports.callServiceRpc = callServiceRpc;
class SupabaseRpcError extends Error {
    constructor(message, status, code) {
        super(message);
        this.status = status;
        this.code = code;
    }
}
exports.SupabaseRpcError = SupabaseRpcError;
async function callServiceRpc(functionName, params) {
    const url = process.env.SUPABASE_URL?.replace(/\/$/, "");
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !serviceKey) {
        throw new SupabaseRpcError("Server database credentials are not configured.", 503, "DATABASE_NOT_CONFIGURED");
    }
    const response = await fetch(`${url}/rest/v1/rpc/${functionName}`, {
        method: "POST",
        headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
            Accept: "application/json",
        },
        body: JSON.stringify(params),
        signal: AbortSignal.timeout(15000),
    });
    const text = await response.text();
    let payload = null;
    if (text) {
        try {
            payload = JSON.parse(text);
        }
        catch {
            payload = text;
        }
    }
    if (!response.ok) {
        const body = payload;
        throw new SupabaseRpcError(body?.message || `Database operation failed (${response.status}).`, response.status, body?.code);
    }
    return payload;
}
//# sourceMappingURL=supabaseRpc.js.map