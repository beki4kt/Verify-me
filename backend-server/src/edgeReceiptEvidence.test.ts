import assert from "node:assert/strict";
import test from "node:test";
import { deflateSync } from "node:zlib";
import { createHash } from "node:crypto";
import { createEdgeReceiptEvidenceHandler, inspectOriginal } from "./edgeReceiptEvidence";

function chunk(type: string, data: Buffer): Buffer {
  const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
  const content = Buffer.concat([Buffer.from(type), data]);
  let crc = 0xffffffff;
  for (const byte of content) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  const checksum = Buffer.alloc(4); checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
  return Buffer.concat([size, content, checksum]);
}
function png(firstPixel = 0): Buffer {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(200, 0); header.writeUInt32BE(200, 4);
  header[8] = 8; header[9] = 6;
  const pixels = Buffer.alloc(200 * (1 + 200 * 4));
  pixels[1] = firstPixel;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header), chunk("IDAT", deflateSync(pixels)), chunk("IEND", Buffer.alloc(0)),
  ]);
}
const ticket = "11111111-1111-4111-8111-111111111111";
const otherTicket = "22222222-2222-4222-8222-222222222222";
const token = "t".repeat(64);
const image = png();
const sha = createHash("sha256").update(image).digest("hex");

function setup() {
  const state = { stored: false, image: null as Buffer | null, uploadFails: false,
    storedSha: null as string | null, pendingSha: null as string | null,
    finishFails: false, dropUploadResponse: false,
    uploadWrites: 0, failures: 0,
    reserves: 0, completions: 0, accesses: 0, financialWrites: 0 };
  const objectKey = `business/${ticket}/receipt/original.png`;
  const transport = (async (input: Parameters<typeof fetch>[0], init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/rest/v1/rpc/")) {
      const name = url.split("/").pop();
      const body = JSON.parse(String(init?.body));
      if (body.p_ticket_id !== ticket || body.p_token !== token) return Response.json({ code: "42501" }, { status: 403 });
      if (name === "reserve_receipt_original") {
        state.reserves++;
        assert.match(body.p_sha256, /^[a-f0-9]{64}$/);
        assert.equal(body.p_mime_type, "image/png");
        if (!state.stored) state.pendingSha = body.p_sha256;
        return Response.json({ status: state.stored
          ? body.p_sha256 === state.storedSha ? "stored" : "replacement_denied"
          : "pending_upload", receipt_id: "receipt", storage_object_key: objectKey });
      }
      if (name === "finish_receipt_original") {
        if (state.finishFails) return Response.json({ code: "55000" }, { status: 503 });
        assert.ok(state.image);
        assert.equal(body.p_sha256, state.pendingSha);
        assert.equal(createHash("sha256").update(state.image).digest("hex"), body.p_sha256);
        state.stored = true; state.storedSha = body.p_sha256; state.completions++;
        return Response.json({ status: "stored", receipt_id: "receipt" });
      }
      if (name === "fail_receipt_original") { state.failures++; return Response.json(null); }
      if (name === "service_get_receipt_original_locator") {
        state.accesses++;
        return Response.json(state.stored ? { storage_object_key: objectKey, mime_type: "image/png" } : null);
      }
      throw Error(`Unexpected RPC ${name}`);
    }
    if (url.includes("/storage/v1/object/")) {
      if (init?.method === "POST") {
        assert.equal(new Headers(init.headers).get("x-upsert"), "false");
        if (state.uploadFails) return Response.json({ error: "unavailable" }, { status: 503 });
        if (state.image) return Response.json({ error: "duplicate" }, { status: 409 });
        state.image = Buffer.from(init.body as Uint8Array);
        state.uploadWrites++;
        if (state.dropUploadResponse) {
          state.dropUploadResponse = false;
          throw new Error("Connection closed after storage accepted the original");
        }
        return Response.json({ Key: objectKey });
      }
      return state.image ? new Response(new Uint8Array(state.image)) : new Response(null, { status: 404 });
    }
    throw Error(`Unexpected URL ${url}`);
  }) as typeof fetch;
  const handler = createEdgeReceiptEvidenceHandler({ SUPABASE_URL: "https://database.example", SUPABASE_SERVICE_ROLE_KEY: "secret" }, transport);
  const post = (bytes: Buffer = image, id = ticket, auth = token) => handler(new Request("https://database.example/functions/v1/chekmi-receipt-evidence", {
    method: "POST", headers: { authorization: `Bearer ${auth}`, "x-chekmi-ticket-id": id, "x-chekmi-source": "camera", "content-type": "application/octet-stream" },
    body: new Uint8Array(bytes),
  }));
  const get = (id = ticket, auth = token) => handler(new Request(`https://database.example/functions/v1/chekmi-receipt-evidence?ticket=${id}`, {
    headers: { authorization: `Bearer ${auth}` },
  }));
  return { state, post, get };
}

test("genuine original is stored once, accessible only through authorized detail", async () => {
  assert.deepEqual(inspectOriginal(image), { mime: "image/png", width: 200, height: 200 });
  const { state, post, get } = setup();
  assert.equal((await post()).status, 201);
  assert.equal(state.image?.toString("hex"), image.toString("hex"));
  assert.equal((await get()).status, 200);
  assert.deepEqual(Buffer.from(await (await get()).arrayBuffer()), image);
  assert.equal((await post()).status, 200);
  assert.equal(state.completions, 1);
  assert.equal(state.financialWrites, 0);
});

test("storage failure preserves bank result and retry stores same original", async () => {
  const { state, post } = setup();
  state.uploadFails = true;
  assert.equal((await post()).status, 503);
  assert.equal(state.stored, false);
  state.uploadFails = false;
  assert.equal((await post()).status, 201);
  assert.equal(state.completions, 1);
  assert.equal(state.financialWrites, 0);
});

test("finalization timeout recovers an existing object without overwriting it", async () => {
  const { state, post } = setup();
  state.finishFails = true;
  assert.equal((await post()).status, 503);
  assert.ok(state.image);
  state.finishFails = false;
  assert.equal((await post()).status, 201);
  assert.equal(state.completions, 1);
  assert.deepEqual(state.image, image);
});

test("lost upload response recovers the saved original without a second object write", async () => {
  const { state, post, get } = setup();
  state.dropUploadResponse = true;
  const interrupted = await post();
  assert.equal(interrupted.status, 503);
  const interruptedBody = await interrupted.json() as { code: string };
  assert.equal(interruptedBody.code, "EVIDENCE_UNAVAILABLE");
  assert.deepEqual(state.image, image);
  assert.equal(state.stored, false);
  assert.equal((await post()).status, 201);
  assert.equal(state.uploadWrites, 1);
  assert.equal(state.completions, 1);
  assert.equal(state.financialWrites, 0);
  assert.deepEqual(Buffer.from(await (await get()).arrayBuffer()), image);
});

test("a conflicting object with different bytes cannot finalize as this original", async () => {
  const { state, post } = setup();
  state.image = Buffer.from(image);
  state.image[state.image.length - 1] ^= 1;
  const response = await post();
  assert.equal(response.status, 503);
  const body = await response.json() as { code: string };
  assert.equal(body.code, "UPLOAD_FAILED");
  assert.equal(state.stored, false);
  assert.equal(state.completions, 0);
  assert.equal(state.failures, 1);
  assert.equal(state.financialWrites, 0);
});

test("an archived original cannot be replaced by a different valid image", async () => {
  const { state, post, get } = setup();
  const replacement = png(1);
  assert.deepEqual(inspectOriginal(replacement), { mime: "image/png", width: 200, height: 200 });
  assert.notEqual(createHash("sha256").update(replacement).digest("hex"), sha);
  assert.equal((await post()).status, 201);
  const response = await post(replacement);
  assert.equal(response.status, 409);
  const body = await response.json() as { code: string };
  assert.equal(body.code, "ORIGINAL_IMMUTABLE");
  assert.equal(state.uploadWrites, 1);
  assert.equal(state.completions, 1);
  assert.deepEqual(Buffer.from(await (await get()).arrayBuffer()), image);
});

test("cross-workspace, bad sessions, corrupt images and missing originals are denied", async () => {
  const { state, post, get } = setup();
  assert.equal((await post(image, otherTicket)).status, 403);
  assert.equal((await get(otherTicket)).status, 403);
  assert.equal((await post(image, ticket, "bad")).status, 401);
  assert.equal((await get()).status, 404);
  const corrupt = Buffer.from(image); corrupt[45] ^= 1;
  assert.equal(inspectOriginal(corrupt), null);
  assert.equal((await post(corrupt)).status, 415);
  assert.equal(state.reserves, 0);
});

test("two synthetic workspace sessions cannot read each other's stored original", async () => {
  const workspaceA = { token, ticket, key: `workspace-a/${ticket}/original.png` };
  const workspaceB = { token: 'b'.repeat(64), ticket: otherTicket,
    key: `workspace-b/${otherTicket}/original.png` };
  const transport = (async (input: Parameters<typeof fetch>[0], init?: RequestInit) => {
    const url = String(input);
    if (url.includes('/rpc/service_get_receipt_original_locator') ||
        url.includes('/rpc/reserve_receipt_original')) {
      const params = JSON.parse(String(init?.body));
      const member = [workspaceA, workspaceB].find((workspace) =>
        workspace.token === params.p_token && workspace.ticket === params.p_ticket_id);
      return member ? Response.json({ storage_object_key: member.key, mime_type: 'image/png' })
        : Response.json({ code: '42501' }, { status: 403 });
    }
    if (url.includes('/storage/v1/object/')) return new Response(new Uint8Array(image));
    throw Error(`Unexpected URL ${url}`);
  }) as typeof fetch;
  const handler = createEdgeReceiptEvidenceHandler({
    SUPABASE_URL: 'https://database.example', SUPABASE_SERVICE_ROLE_KEY: 'service-test-only',
  }, transport);
  const read = (session: string, payment: string) => handler(new Request(
    `https://database.example/functions/v1/chekmi-receipt-evidence?ticket=${payment}`,
    { headers: { authorization: `Bearer ${session}` } },
  ));
  assert.equal((await read(workspaceA.token, workspaceA.ticket)).status, 200);
  assert.equal((await read(workspaceB.token, workspaceB.ticket)).status, 200);
  assert.equal((await read(workspaceA.token, workspaceB.ticket)).status, 403);
  assert.equal((await read(workspaceB.token, workspaceA.ticket)).status, 403);
  const crossUpload = handler(new Request(
    'https://database.example/functions/v1/chekmi-receipt-evidence', {
      method: 'POST',
      headers: { authorization: `Bearer ${workspaceA.token}`,
        'x-chekmi-ticket-id': workspaceB.ticket, 'x-chekmi-source': 'camera' },
      body: new Uint8Array(image),
    },
  ));
  assert.equal((await crossUpload).status, 403);
  for (const method of ['PUT', 'DELETE']) {
    const response = await handler(new Request(
      'https://database.example/functions/v1/chekmi-receipt-evidence', {
        method, headers: { authorization: `Bearer ${workspaceA.token}`,
          'x-chekmi-ticket-id': workspaceB.ticket },
      },
    ));
    assert.equal(response.status, 405);
  }
});
