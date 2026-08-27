import {
  createHash,
  createHmac,
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";

export interface OperatorCredentials {
  email: string;
  password: string;
  code: string;
}

export interface OperatorClaims {
  sub: string;
  role: "super_admin";
  iat: number;
  exp: number;
  jti: string;
}

export class OperatorConfigurationError extends Error {
  readonly code = "OPERATOR_NOT_CONFIGURED";
}

export class OperatorAuthenticationError extends Error {
  readonly code = "INVALID_OPERATOR_CREDENTIALS";
}

const SESSION_SECONDS = 2 * 60 * 60;

function safeEqual(left: string | Buffer, right: string | Buffer): boolean {
  const leftBuffer = Buffer.isBuffer(left) ? left : Buffer.from(left);
  const rightBuffer = Buffer.isBuffer(right) ? right : Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) return false;
  return timingSafeEqual(leftBuffer, rightBuffer);
}

export function hashOperatorPassword(password: string, salt = randomBytes(16)): string {
  if (password.length < 12) throw new Error("Operator password must be at least 12 characters.");
  const digest = scryptSync(password, salt, 64);
  return `scrypt$${salt.toString("base64url")}$${digest.toString("base64url")}`;
}

export function verifyOperatorPassword(password: string, encoded: string): boolean {
  const [scheme, saltValue, expectedValue] = encoded.split("$");
  if (scheme !== "scrypt" || !saltValue || !expectedValue) return false;
  try {
    const salt = Buffer.from(saltValue, "base64url");
    const expected = Buffer.from(expectedValue, "base64url");
    const actual = scryptSync(password, salt, expected.length);
    return safeEqual(actual, expected);
  } catch {
    return false;
  }
}

function decodeBase32(value: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const normalized = value.toUpperCase().replace(/=+$/g, "").replace(/\s+/g, "");
  let bits = "";
  for (const character of normalized) {
    const index = alphabet.indexOf(character);
    if (index < 0) throw new Error("Invalid base32 secret.");
    bits += index.toString(2).padStart(5, "0");
  }
  const bytes: number[] = [];
  for (let index = 0; index + 8 <= bits.length; index += 8) {
    bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  }
  return Buffer.from(bytes);
}

export function totpCode(secret: string, nowMs = Date.now(), stepOffset = 0): string {
  const counter = Math.floor(nowMs / 30_000) + stepOffset;
  const counterBytes = Buffer.alloc(8);
  counterBytes.writeBigUInt64BE(BigInt(counter));
  const digest = createHmac("sha1", decodeBase32(secret)).update(counterBytes).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const value =
    (((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff)) %
    1_000_000;
  return value.toString().padStart(6, "0");
}

export function verifyTotp(code: string, secret: string, nowMs = Date.now()): boolean {
  if (!/^\d{6}$/.test(code)) return false;
  return [-1, 0, 1].some((offset) => safeEqual(code, totpCode(secret, nowMs, offset)));
}

function sessionSecret(env: NodeJS.ProcessEnv): string {
  const configured = env.OPERATOR_SESSION_SECRET;
  if (configured && configured.length >= 32) return configured;
  if (env.NODE_ENV === "production") {
    throw new OperatorConfigurationError("OPERATOR_SESSION_SECRET must contain at least 32 characters.");
  }
  const developmentMaterial = `${env.OPERATOR_PASSWORD_HASH || env.OPERATOR_PASSWORD || ""}:${env.OPERATOR_TOTP_SECRET || env.OPERATOR_MFA_CODE || ""}`;
  if (developmentMaterial === ":") {
    throw new OperatorConfigurationError("Operator credentials are not configured.");
  }
  return createHash("sha256").update(developmentMaterial).digest("hex");
}

function assertConfigured(env: NodeJS.ProcessEnv): void {
  if (!env.OPERATOR_EMAIL) {
    throw new OperatorConfigurationError("OPERATOR_EMAIL is not configured.");
  }
  const hasHashedPassword = Boolean(env.OPERATOR_PASSWORD_HASH);
  const hasTotp = Boolean(env.OPERATOR_TOTP_SECRET);
  if (env.NODE_ENV === "production" && (!hasHashedPassword || !hasTotp)) {
    throw new OperatorConfigurationError(
      "Production requires OPERATOR_PASSWORD_HASH and OPERATOR_TOTP_SECRET.",
    );
  }
  if (!hasHashedPassword && !(env.NODE_ENV !== "production" && env.OPERATOR_PASSWORD)) {
    throw new OperatorConfigurationError("Operator password credentials are not configured.");
  }
  if (!hasTotp && !(env.NODE_ENV !== "production" && env.OPERATOR_MFA_CODE)) {
    throw new OperatorConfigurationError("Operator MFA credentials are not configured.");
  }
  sessionSecret(env);
}

export function operatorIsConfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  try {
    assertConfigured(env);
    return true;
  } catch {
    return false;
  }
}

function encodeToken(claims: OperatorClaims, secret: string): string {
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
  const payload = Buffer.from(JSON.stringify(claims)).toString("base64url");
  const signature = createHmac("sha256", secret).update(`${header}.${payload}`).digest("base64url");
  return `${header}.${payload}.${signature}`;
}

export function authenticateOperator(
  credentials: OperatorCredentials,
  env: NodeJS.ProcessEnv = process.env,
  nowMs = Date.now(),
): { token: string; claims: OperatorClaims } {
  assertConfigured(env);
  const expectedEmail = env.OPERATOR_EMAIL!.trim().toLowerCase();
  const suppliedEmail = credentials.email.trim().toLowerCase();
  const emailMatches = safeEqual(suppliedEmail, expectedEmail);
  const passwordMatches = env.OPERATOR_PASSWORD_HASH
    ? verifyOperatorPassword(credentials.password, env.OPERATOR_PASSWORD_HASH)
    : safeEqual(credentials.password, env.OPERATOR_PASSWORD!);
  const codeMatches = env.OPERATOR_TOTP_SECRET
    ? verifyTotp(credentials.code, env.OPERATOR_TOTP_SECRET, nowMs)
    : safeEqual(credentials.code, env.OPERATOR_MFA_CODE!);
  if (!emailMatches || !passwordMatches || !codeMatches) {
    throw new OperatorAuthenticationError("Invalid owner credentials or authenticator code.");
  }
  const issuedAt = Math.floor(nowMs / 1000);
  const claims: OperatorClaims = {
    sub: expectedEmail,
    role: "super_admin",
    iat: issuedAt,
    exp: issuedAt + SESSION_SECONDS,
    jti: randomUUID(),
  };
  return { token: encodeToken(claims, sessionSecret(env)), claims };
}

export function verifyOperatorToken(
  token: string,
  env: NodeJS.ProcessEnv = process.env,
  nowMs = Date.now(),
): OperatorClaims {
  assertConfigured(env);
  const parts = token.split(".");
  if (parts.length !== 3) throw new OperatorAuthenticationError("Invalid operator session.");
  const expectedSignature = createHmac("sha256", sessionSecret(env))
    .update(`${parts[0]}.${parts[1]}`)
    .digest("base64url");
  if (!safeEqual(parts[2], expectedSignature)) {
    throw new OperatorAuthenticationError("Invalid operator session.");
  }
  try {
    const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as OperatorClaims;
    if (
      claims.role !== "super_admin" ||
      claims.sub !== env.OPERATOR_EMAIL!.trim().toLowerCase() ||
      !Number.isFinite(claims.exp) ||
      claims.exp <= Math.floor(nowMs / 1000)
    ) {
      throw new Error("expired");
    }
    return claims;
  } catch {
    throw new OperatorAuthenticationError("Operator session expired or is invalid.");
  }
}
