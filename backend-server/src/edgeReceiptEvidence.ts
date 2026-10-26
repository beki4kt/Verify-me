// Private original-receipt transport. Chekmi staff sessions are checked by
// tenant-scoped SQL RPCs; the service key never reaches the mobile client.
type Env = Record<string, string | undefined>;
type Json = Record<string, unknown>;
const MAX_BYTES = 6 * 1024 * 1024;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function asObject(value: unknown): Json | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Json : null;
}

export function inspectOriginal(bytes: Uint8Array): { mime: "image/jpeg" | "image/png"; width: number; height: number } | null {
  if (bytes.length < 24 || bytes.length > MAX_BYTES) return null;
  if (bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71 &&
      bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10) {
    const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    let offset = 8, width = 0, height = 0, hasImageData = false;
    while (offset + 12 <= bytes.length) {
      const length = v.getUint32(offset);
      if (length > bytes.length - offset - 12) return null;
      const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
      let crc = 0xffffffff;
      for (let i = offset + 4; i < offset + 8 + length; i++) {
        crc ^= bytes[i];
        for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
      }
      if ((crc ^ 0xffffffff) >>> 0 !== v.getUint32(offset + 8 + length)) return null;
      if (offset === 8) {
        if (type !== "IHDR" || length !== 13) return null;
        width = v.getUint32(offset + 8); height = v.getUint32(offset + 12);
        if (width < 200 || height < 200 || width > 10000 || height > 10000) return null;
      }
      if (type === "IDAT") hasImageData = true;
      offset += 12 + length;
      if (type === "IEND") return length === 0 && offset === bytes.length && hasImageData
        ? { mime: "image/png", width, height } : null;
    }
    return null;
  }
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff ||
      bytes[bytes.length - 2] !== 0xff || bytes[bytes.length - 1] !== 0xd9) return null;
  // Walk actual JPEG markers; EXIF orientation and original bytes are retained.
  let offset = 2;
  while (offset + 4 < bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xd9 || marker === 0xda) break;
    if (marker === 0x01 || marker >= 0xd0 && marker <= 0xd7) continue;
    if (offset + 2 > bytes.length) return null;
    const length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
      if (length < 7) return null;
      const height = bytes[offset + 3] * 256 + bytes[offset + 4];
      const width = bytes[offset + 5] * 256 + bytes[offset + 6];
      return width >= 200 && height >= 200 && width <= 10000 && height <= 10000
        ? { mime: "image/jpeg", width, height } : null;
    }
    offset += length;
  }
  return null;
}

async function readBounded(req: Request): Promise<Uint8Array> {
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = []; let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > MAX_BYTES) { await reader.cancel(); throw new Error("IMAGE_TOO_LARGE"); }
    chunks.push(value);
  }
  const result = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.byteLength; }
  return result;
}

async function digest(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", bytes.slice().buffer as ArrayBuffer);
  return Array.from(new Uint8Array(hash), n => n.toString(16).padStart(2, "0")).join("");
}

export function createEdgeReceiptEvidenceHandler(env: Env, transport: typeof fetch = fetch) {
  const base = env.SUPABASE_URL?.replace(/\/$/, "") ?? "";
  const key = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const rate = new Map<string, { count: number; until: number }>();
  return async (req: Request): Promise<Response> => {
    const origin = req.headers.get("origin");
    const allowed = (env.CORS_ALLOWED_ORIGINS ?? "").split(",").map(x => x.trim());
    const headers: Record<string, string> = { "Cache-Control": "no-store", "Content-Type": "application/json", "X-Content-Type-Options": "nosniff" };
    if (origin && !allowed.includes(origin)) return new Response(JSON.stringify({ error: "Origin not allowed" }), { status: 403, headers });
    if (origin) {
      headers["Access-Control-Allow-Origin"] = origin;
      headers.Vary = "Origin";
      headers["Access-Control-Allow-Headers"] = "authorization, apikey, content-type, x-chekmi-ticket-id, x-chekmi-source";
      headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
    }
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
    const reply = (status: number, code: string, message: string) => new Response(JSON.stringify({ success: false, code, error: message }), { status, headers });
    if (!base.startsWith("https://") || !key) return reply(503, "NOT_CONFIGURED", "Receipt evidence service is not configured.");
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim() ?? "";
    if (token.length < 32) return reply(401, "SESSION_REQUIRED", "Sign in to access receipt evidence.");
    const rateKey = `${token}:${req.method}`;
    const now = Date.now();
    const bucket = rate.get(rateKey);
    const next = !bucket || bucket.until < now
      ? { count: 1, until: now + 60_000 }
      : { count: bucket.count + 1, until: bucket.until };
    rate.set(rateKey, next);
    if (rate.size > 2000) for (const [id, value] of rate) if (value.until < now) rate.delete(id);
    if (next.count > (req.method === "POST" ? 20 : 90)) return reply(429, "RATE_LIMIT", "Too many receipt requests. Try again shortly.");
    const ticketId = req.method === "GET"
      ? new URL(req.url).searchParams.get("ticket") ?? ""
      : req.headers.get("x-chekmi-ticket-id") ?? "";
    if (!uuid.test(ticketId)) return reply(400, "INVALID_TICKET", "A valid payment ID is required.");
    const serviceHeaders = { apikey: key, Authorization: `Bearer ${key}` };
    const rpc = async (name: string, params: Json): Promise<{ ok: boolean; status: number; data: Json | null }> => {
      const response = await transport(`${base}/rest/v1/rpc/${name}`, {
        method: "POST", headers: { ...serviceHeaders, "Content-Type": "application/json" },
        body: JSON.stringify(params), signal: AbortSignal.timeout(15000), redirect: "error",
      });
      const raw = await response.text();
      return { ok: response.ok, status: response.status, data: asObject(raw ? JSON.parse(raw) : null) };
    };
    const objectUrl = (path: string) => `${base}/storage/v1/object/receipt-evidence/${path.split("/").map(encodeURIComponent).join("/")}`;
    try {
      if (req.method === "GET") {
        const located = await rpc("service_get_receipt_original_locator", { p_token: token, p_ticket_id: ticketId });
        if (!located.ok) return reply(located.status === 401 ? 401 : 403, "ACCESS_DENIED", "Receipt access denied.");
        if (!located.data) return reply(404, "ORIGINAL_MISSING", "No original image has been archived for this payment.");
        const legacy = located.data.legacy_image_base64;
        if (typeof legacy === "string") {
          const binary = atob(legacy);
          const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
          return new Response(bytes, { status: 200, headers: { ...headers, "Content-Type": String(located.data.mime_type ?? "image/jpeg") } });
        }
        const path = located.data.storage_object_key;
        if (typeof path !== "string" || !path) return reply(404, "ORIGINAL_MISSING", "Original image is unavailable.");
        const object = await transport(objectUrl(path), { headers: serviceHeaders, signal: AbortSignal.timeout(15000), redirect: "error" });
        if (!object.ok) return reply(503, "STORAGE_UNAVAILABLE", "Original image could not be loaded. Try again.");
        return new Response(object.body, { status: 200, headers: { ...headers, "Content-Type": String(located.data.mime_type ?? "image/jpeg") } });
      }
      if (req.method !== "POST") return reply(405, "METHOD_NOT_ALLOWED", "Use GET or POST.");
      const source = req.headers.get("x-chekmi-source");
      if (source !== "camera" && source !== "photo_library") return reply(400, "INVALID_SOURCE", "Choose a camera or photo-library original.");
      if (Number(req.headers.get("content-length") ?? "0") > MAX_BYTES) return reply(413, "IMAGE_TOO_LARGE", "Image must be under 6 MB.");
      const bytes = await readBounded(req);
      const image = inspectOriginal(bytes);
      if (!image) return reply(415, "INVALID_IMAGE", "Use an unaltered JPEG or PNG image between 200 and 10,000 pixels per side, under 6 MB.");
      const sha = await digest(bytes);
      const reserved = await rpc("reserve_receipt_original", {
        p_token: token, p_ticket_id: ticketId, p_mime_type: image.mime,
        p_byte_size: bytes.length, p_sha256: sha, p_source_type: source,
      });
      if (!reserved.ok) return reply(reserved.status === 401 ? 401 : reserved.status === 409 ? 409 : 403,
        "RESERVATION_DENIED", "This original cannot be attached to that payment.");
      if (reserved.data?.status === "replacement_denied") return reply(409, "ORIGINAL_IMMUTABLE", "An original image is already archived for this payment.");
      if (reserved.data?.status === "retry_image_mismatch") return reply(409, "RETRY_ORIGINAL_MISMATCH", "Retry using the same original image.");
      if (reserved.data?.status === "stored") return new Response(JSON.stringify({ success: true, status: "stored", receiptId: reserved.data.receipt_id }), { status: 200, headers });
      const path = reserved.data?.storage_object_key;
      if (typeof path !== "string" || !path) return reply(503, "RESERVATION_FAILED", "Receipt upload could not be prepared.");
      const upload = await transport(objectUrl(path), {
        method: "POST", headers: { ...serviceHeaders, "Content-Type": image.mime, "Cache-Control": "no-store", "x-upsert": "false" },
        body: bytes, signal: AbortSignal.timeout(30000), redirect: "error",
      });
      if (!upload.ok) {
        // A previous upload may have succeeded before finalization timed out.
        // Confirm exact bytes before treating the existing object as a retry.
        const existing = await transport(objectUrl(path), { headers: serviceHeaders, signal: AbortSignal.timeout(15000), redirect: "error" });
        const same = existing.ok && await digest(new Uint8Array(await existing.arrayBuffer())) === sha;
        if (!same) {
          await rpc("fail_receipt_original", { p_token: token, p_ticket_id: ticketId, p_sha256: sha }).catch(() => null);
          return reply(503, "UPLOAD_FAILED", "Payment is verified, but its original image was not saved. Retry the image upload.");
        }
      }
      const finished = await rpc("finish_receipt_original", { p_token: token, p_ticket_id: ticketId, p_sha256: sha });
      if (!finished.ok || finished.data?.status !== "stored") return reply(503, "FINALIZATION_PENDING", "Image upload needs confirmation. Retry using the same image.");
      return new Response(JSON.stringify({ success: true, status: "stored", receiptId: finished.data.receipt_id }), { status: 201, headers });
    } catch (error) {
      if (error instanceof Error && error.message === "IMAGE_TOO_LARGE") return reply(413, "IMAGE_TOO_LARGE", "Image must be under 6 MB.");
      return reply(503, "EVIDENCE_UNAVAILABLE", "Receipt evidence is temporarily unavailable. The payment result is unchanged.");
    }
  };
}
