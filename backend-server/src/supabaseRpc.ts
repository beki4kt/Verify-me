export class SupabaseRpcError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code?: string,
  ) {
    super(message);
  }
}

export async function callServiceRpc<T>(
  functionName: string,
  params: Record<string, unknown>,
): Promise<T> {
  const url = process.env.SUPABASE_URL?.replace(/\/$/, "");
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    throw new SupabaseRpcError(
      "Server database credentials are not configured.",
      503,
      "DATABASE_NOT_CONFIGURED",
    );
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
    signal: AbortSignal.timeout(15_000),
  });

  const text = await response.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!response.ok) {
    const body = payload as { message?: string; code?: string } | null;
    throw new SupabaseRpcError(
      body?.message || `Database operation failed (${response.status}).`,
      response.status,
      body?.code,
    );
  }
  return payload as T;
}
