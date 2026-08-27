"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OperatorAuthenticationError = exports.OperatorConfigurationError = void 0;
exports.hashOperatorPassword = hashOperatorPassword;
exports.verifyOperatorPassword = verifyOperatorPassword;
exports.totpCode = totpCode;
exports.verifyTotp = verifyTotp;
exports.operatorIsConfigured = operatorIsConfigured;
exports.authenticateOperator = authenticateOperator;
exports.verifyOperatorToken = verifyOperatorToken;
const node_crypto_1 = require("node:crypto");
class OperatorConfigurationError extends Error {
    constructor() {
        super(...arguments);
        this.code = "OPERATOR_NOT_CONFIGURED";
    }
}
exports.OperatorConfigurationError = OperatorConfigurationError;
class OperatorAuthenticationError extends Error {
    constructor() {
        super(...arguments);
        this.code = "INVALID_OPERATOR_CREDENTIALS";
    }
}
exports.OperatorAuthenticationError = OperatorAuthenticationError;
const SESSION_SECONDS = 2 * 60 * 60;
function safeEqual(left, right) {
    const leftBuffer = Buffer.isBuffer(left) ? left : Buffer.from(left);
    const rightBuffer = Buffer.isBuffer(right) ? right : Buffer.from(right);
    if (leftBuffer.length !== rightBuffer.length)
        return false;
    return (0, node_crypto_1.timingSafeEqual)(leftBuffer, rightBuffer);
}
function hashOperatorPassword(password, salt = (0, node_crypto_1.randomBytes)(16)) {
    if (password.length < 12)
        throw new Error("Operator password must be at least 12 characters.");
    const digest = (0, node_crypto_1.scryptSync)(password, salt, 64);
    return `scrypt$${salt.toString("base64url")}$${digest.toString("base64url")}`;
}
function verifyOperatorPassword(password, encoded) {
    const [scheme, saltValue, expectedValue] = encoded.split("$");
    if (scheme !== "scrypt" || !saltValue || !expectedValue)
        return false;
    try {
        const salt = Buffer.from(saltValue, "base64url");
        const expected = Buffer.from(expectedValue, "base64url");
        const actual = (0, node_crypto_1.scryptSync)(password, salt, expected.length);
        return safeEqual(actual, expected);
    }
    catch {
        return false;
    }
}
function decodeBase32(value) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    const normalized = value.toUpperCase().replace(/=+$/g, "").replace(/\s+/g, "");
    let bits = "";
    for (const character of normalized) {
        const index = alphabet.indexOf(character);
        if (index < 0)
            throw new Error("Invalid base32 secret.");
        bits += index.toString(2).padStart(5, "0");
    }
    const bytes = [];
    for (let index = 0; index + 8 <= bits.length; index += 8) {
        bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
    }
    return Buffer.from(bytes);
}
function totpCode(secret, nowMs = Date.now(), stepOffset = 0) {
    const counter = Math.floor(nowMs / 30000) + stepOffset;
    const counterBytes = Buffer.alloc(8);
    counterBytes.writeBigUInt64BE(BigInt(counter));
    const digest = (0, node_crypto_1.createHmac)("sha1", decodeBase32(secret)).update(counterBytes).digest();
    const offset = digest[digest.length - 1] & 0x0f;
    const value = (((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff)) %
        1000000;
    return value.toString().padStart(6, "0");
}
function verifyTotp(code, secret, nowMs = Date.now()) {
    if (!/^\d{6}$/.test(code))
        return false;
    return [-1, 0, 1].some((offset) => safeEqual(code, totpCode(secret, nowMs, offset)));
}
function sessionSecret(env) {
    const configured = env.OPERATOR_SESSION_SECRET;
    if (configured && configured.length >= 32)
        return configured;
    if (env.NODE_ENV === "production") {
        throw new OperatorConfigurationError("OPERATOR_SESSION_SECRET must contain at least 32 characters.");
    }
    const developmentMaterial = `${env.OPERATOR_PASSWORD_HASH || env.OPERATOR_PASSWORD || ""}:${env.OPERATOR_TOTP_SECRET || env.OPERATOR_MFA_CODE || ""}`;
    if (developmentMaterial === ":") {
        throw new OperatorConfigurationError("Operator credentials are not configured.");
    }
    return (0, node_crypto_1.createHash)("sha256").update(developmentMaterial).digest("hex");
}
function assertConfigured(env) {
    if (!env.OPERATOR_EMAIL) {
        throw new OperatorConfigurationError("OPERATOR_EMAIL is not configured.");
    }
    const hasHashedPassword = Boolean(env.OPERATOR_PASSWORD_HASH);
    const hasTotp = Boolean(env.OPERATOR_TOTP_SECRET);
    if (env.NODE_ENV === "production" && (!hasHashedPassword || !hasTotp)) {
        throw new OperatorConfigurationError("Production requires OPERATOR_PASSWORD_HASH and OPERATOR_TOTP_SECRET.");
    }
    if (!hasHashedPassword && !(env.NODE_ENV !== "production" && env.OPERATOR_PASSWORD)) {
        throw new OperatorConfigurationError("Operator password credentials are not configured.");
    }
    if (!hasTotp && !(env.NODE_ENV !== "production" && env.OPERATOR_MFA_CODE)) {
        throw new OperatorConfigurationError("Operator MFA credentials are not configured.");
    }
    sessionSecret(env);
}
function operatorIsConfigured(env = process.env) {
    try {
        assertConfigured(env);
        return true;
    }
    catch {
        return false;
    }
}
function encodeToken(claims, secret) {
    const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
    const payload = Buffer.from(JSON.stringify(claims)).toString("base64url");
    const signature = (0, node_crypto_1.createHmac)("sha256", secret).update(`${header}.${payload}`).digest("base64url");
    return `${header}.${payload}.${signature}`;
}
function authenticateOperator(credentials, env = process.env, nowMs = Date.now()) {
    assertConfigured(env);
    const expectedEmail = env.OPERATOR_EMAIL.trim().toLowerCase();
    const suppliedEmail = credentials.email.trim().toLowerCase();
    const emailMatches = safeEqual(suppliedEmail, expectedEmail);
    const passwordMatches = env.OPERATOR_PASSWORD_HASH
        ? verifyOperatorPassword(credentials.password, env.OPERATOR_PASSWORD_HASH)
        : safeEqual(credentials.password, env.OPERATOR_PASSWORD);
    const codeMatches = env.OPERATOR_TOTP_SECRET
        ? verifyTotp(credentials.code, env.OPERATOR_TOTP_SECRET, nowMs)
        : safeEqual(credentials.code, env.OPERATOR_MFA_CODE);
    if (!emailMatches || !passwordMatches || !codeMatches) {
        throw new OperatorAuthenticationError("Invalid owner credentials or authenticator code.");
    }
    const issuedAt = Math.floor(nowMs / 1000);
    const claims = {
        sub: expectedEmail,
        role: "super_admin",
        iat: issuedAt,
        exp: issuedAt + SESSION_SECONDS,
        jti: (0, node_crypto_1.randomUUID)(),
    };
    return { token: encodeToken(claims, sessionSecret(env)), claims };
}
function verifyOperatorToken(token, env = process.env, nowMs = Date.now()) {
    assertConfigured(env);
    const parts = token.split(".");
    if (parts.length !== 3)
        throw new OperatorAuthenticationError("Invalid operator session.");
    const expectedSignature = (0, node_crypto_1.createHmac)("sha256", sessionSecret(env))
        .update(`${parts[0]}.${parts[1]}`)
        .digest("base64url");
    if (!safeEqual(parts[2], expectedSignature)) {
        throw new OperatorAuthenticationError("Invalid operator session.");
    }
    try {
        const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
        if (claims.role !== "super_admin" ||
            claims.sub !== env.OPERATOR_EMAIL.trim().toLowerCase() ||
            !Number.isFinite(claims.exp) ||
            claims.exp <= Math.floor(nowMs / 1000)) {
            throw new Error("expired");
        }
        return claims;
    }
    catch {
        throw new OperatorAuthenticationError("Operator session expired or is invalid.");
    }
}
//# sourceMappingURL=operatorAuth.js.map