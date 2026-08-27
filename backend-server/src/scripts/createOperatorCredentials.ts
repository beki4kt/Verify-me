import { randomBytes } from "node:crypto";

import { hashOperatorPassword } from "../operatorAuth";

function base32(bytes: Buffer): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const byte of bytes) bits += byte.toString(2).padStart(8, "0");
  let encoded = "";
  for (let index = 0; index < bits.length; index += 5) {
    encoded += alphabet[Number.parseInt(bits.slice(index, index + 5).padEnd(5, "0"), 2)];
  }
  return encoded;
}

const email = (process.argv[2] || "owner@chekmi.local").trim().toLowerCase();
if (!email.includes("@")) {
  console.error("Usage: npm run operator:setup -- you@example.com");
  process.exitCode = 1;
} else {
  const password = `${randomBytes(9).toString("base64url")}!${randomBytes(9).toString("base64url")}`;
  const totpSecret = base32(randomBytes(20));
  const sessionSecret = randomBytes(48).toString("base64url");
  const passwordHash = hashOperatorPassword(password);
  const otpAuth = `otpauth://totp/CHEKMI:${encodeURIComponent(email)}?secret=${totpSecret}&issuer=CHEKMI&algorithm=SHA1&digits=6&period=30`;

  console.log("\nCHEKMI owner credentials — save the password in a password manager now.\n");
  console.log(`Owner email: ${email}`);
  console.log(`Owner password: ${password}`);
  console.log(`Authenticator setup key: ${totpSecret}`);
  console.log(`Authenticator URI: ${otpAuth}`);
  console.log("\nPaste these server-only values into backend-server/.env:\n");
  console.log(`OPERATOR_EMAIL=${email}`);
  console.log(`OPERATOR_PASSWORD_HASH=${passwordHash}`);
  console.log(`OPERATOR_TOTP_SECRET=${totpSecret}`);
  console.log(`OPERATOR_SESSION_SECRET=${sessionSecret}`);
  console.log("\nNever add the generated values to Git or the Flutter build.\n");
}
