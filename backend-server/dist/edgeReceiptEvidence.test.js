"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const node_zlib_1 = require("node:zlib");
const node_crypto_1 = require("node:crypto");
const edgeReceiptEvidence_1 = require("./edgeReceiptEvidence");
function chunk(type, data) {
    const size = Buffer.alloc(4);
    size.writeUInt32BE(data.length);
    const content = Buffer.concat([Buffer.from(type), data]);
    let crc = 0xffffffff;
    for (const byte of content) {
        crc ^= byte;
        for (let bit = 0; bit < 8; bit++)
            crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
    const checksum = Buffer.alloc(4);
    checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
    return Buffer.concat([size, content, checksum]);
}
function png() {
    const header = Buffer.alloc(13);
    header.writeUInt32BE(200, 0);
    header.writeUInt32BE(200, 4);
    header[8] = 8;
    header[9] = 6;
    const pixels = Buffer.alloc(200 * (1 + 200 * 4));
    return Buffer.concat([
        Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
        chunk("IHDR", header), chunk("IDAT", (0, node_zlib_1.deflateSync)(pixels)), chunk("IEND", Buffer.alloc(0)),
    ]);
}
const ticket = "11111111-1111-4111-8111-111111111111";
const otherTicket = "22222222-2222-4222-8222-222222222222";
const token = "t".repeat(64);
const image = png();
const sha = (0, node_crypto_1.createHash)("sha256").update(image).digest("hex");
function setup() {
    const state = { stored: false, image: null, uploadFails: false,
        finishFails: false, reserves: 0, completions: 0, accesses: 0, financialWrites: 0 };
    const objectKey = `business/${ticket}/receipt/original.png`;
    const transport = (async (input, init) => {
        const url = String(input);
        if (url.includes("/rest/v1/rpc/")) {
            const name = url.split("/").pop();
            const body = JSON.parse(String(init?.body));
            if (body.p_ticket_id !== ticket || body.p_token !== token)
                return Response.json({ code: "42501" }, { status: 403 });
            if (name === "reserve_receipt_original") {
                state.reserves++;
                strict_1.default.equal(body.p_sha256, sha);
                strict_1.default.equal(body.p_mime_type, "image/png");
                return Response.json({ status: state.stored ? "stored" : "pending_upload", receipt_id: "receipt", storage_object_key: objectKey });
            }
            if (name === "finish_receipt_original") {
                if (state.finishFails)
                    return Response.json({ code: "55000" }, { status: 503 });
                strict_1.default.ok(state.image);
                state.stored = true;
                state.completions++;
                return Response.json({ status: "stored", receipt_id: "receipt" });
            }
            if (name === "fail_receipt_original")
                return Response.json(null);
            if (name === "service_get_receipt_original_locator") {
                state.accesses++;
                return Response.json(state.stored ? { storage_object_key: objectKey, mime_type: "image/png" } : null);
            }
            throw Error(`Unexpected RPC ${name}`);
        }
        if (url.includes("/storage/v1/object/")) {
            if (init?.method === "POST") {
                strict_1.default.equal(new Headers(init.headers).get("x-upsert"), "false");
                if (state.uploadFails)
                    return Response.json({ error: "unavailable" }, { status: 503 });
                if (state.image)
                    return Response.json({ error: "duplicate" }, { status: 409 });
                state.image = Buffer.from(init.body);
                return Response.json({ Key: objectKey });
            }
            return state.image ? new Response(new Uint8Array(state.image)) : new Response(null, { status: 404 });
        }
        throw Error(`Unexpected URL ${url}`);
    });
    const handler = (0, edgeReceiptEvidence_1.createEdgeReceiptEvidenceHandler)({ SUPABASE_URL: "https://database.example", SUPABASE_SERVICE_ROLE_KEY: "secret" }, transport);
    const post = (bytes = image, id = ticket, auth = token) => handler(new Request("https://database.example/functions/v1/chekmi-receipt-evidence", {
        method: "POST", headers: { authorization: `Bearer ${auth}`, "x-chekmi-ticket-id": id, "x-chekmi-source": "camera", "content-type": "application/octet-stream" },
        body: new Uint8Array(bytes),
    }));
    const get = (id = ticket, auth = token) => handler(new Request(`https://database.example/functions/v1/chekmi-receipt-evidence?ticket=${id}`, {
        headers: { authorization: `Bearer ${auth}` },
    }));
    return { state, post, get };
}
(0, node_test_1.default)("genuine original is stored once, accessible only through authorized detail", async () => {
    strict_1.default.deepEqual((0, edgeReceiptEvidence_1.inspectOriginal)(image), { mime: "image/png", width: 200, height: 200 });
    const { state, post, get } = setup();
    strict_1.default.equal((await post()).status, 201);
    strict_1.default.equal(state.image?.toString("hex"), image.toString("hex"));
    strict_1.default.equal((await get()).status, 200);
    strict_1.default.deepEqual(Buffer.from(await (await get()).arrayBuffer()), image);
    strict_1.default.equal((await post()).status, 200);
    strict_1.default.equal(state.completions, 1);
    strict_1.default.equal(state.financialWrites, 0);
});
(0, node_test_1.default)("storage failure preserves bank result and retry stores same original", async () => {
    const { state, post } = setup();
    state.uploadFails = true;
    strict_1.default.equal((await post()).status, 503);
    strict_1.default.equal(state.stored, false);
    state.uploadFails = false;
    strict_1.default.equal((await post()).status, 201);
    strict_1.default.equal(state.completions, 1);
    strict_1.default.equal(state.financialWrites, 0);
});
(0, node_test_1.default)("finalization timeout recovers an existing object without overwriting it", async () => {
    const { state, post } = setup();
    state.finishFails = true;
    strict_1.default.equal((await post()).status, 503);
    strict_1.default.ok(state.image);
    state.finishFails = false;
    strict_1.default.equal((await post()).status, 201);
    strict_1.default.equal(state.completions, 1);
    strict_1.default.deepEqual(state.image, image);
});
(0, node_test_1.default)("cross-workspace, bad sessions, corrupt images and missing originals are denied", async () => {
    const { state, post, get } = setup();
    strict_1.default.equal((await post(image, otherTicket)).status, 403);
    strict_1.default.equal((await get(otherTicket)).status, 403);
    strict_1.default.equal((await post(image, ticket, "bad")).status, 401);
    strict_1.default.equal((await get()).status, 404);
    const corrupt = Buffer.from(image);
    corrupt[45] ^= 1;
    strict_1.default.equal((0, edgeReceiptEvidence_1.inspectOriginal)(corrupt), null);
    strict_1.default.equal((await post(corrupt)).status, 415);
    strict_1.default.equal(state.reserves, 0);
});
//# sourceMappingURL=edgeReceiptEvidence.test.js.map