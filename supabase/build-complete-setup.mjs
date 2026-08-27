import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const directory = dirname(fileURLToPath(import.meta.url));
const migrationDirectory = join(directory, "migrations");
const includeDemo = process.argv.includes("--with-demo");
const migrationNames = readdirSync(migrationDirectory)
  .filter((name) => /^\d{12}_.+\.sql$/.test(name))
  .sort();

if (migrationNames.length === 0) {
  throw new Error("No CHEKMI migrations were found.");
}

const sections = [
  includeDemo
    ? "-- CHEKMI complete Supabase APP TEST setup"
    : "-- CHEKMI complete Supabase setup",
  "-- Generated from base_schema.sql plus every dated migration.",
  "-- Schema version: 2026-08-26.3",
  includeDemo
    ? "-- TEST ONLY: includes the known MESOB-DEMO role credentials used by Trial Mode."
    : "-- Safe to rerun; it does not insert demo businesses or known credentials.",
  "-- Replace the legal-document YOUR_DOMAIN URLs before production launch.",
  "",
  "begin;",
  "",
  "-- Base schema",
  readFileSync(join(directory, "base_schema.sql"), "utf8").trim(),
];

for (const migrationName of migrationNames) {
  sections.push(
    "",
    `-- Migration: ${migrationName}`,
    readFileSync(join(migrationDirectory, migrationName), "utf8").trim(),
  );
}

if (includeDemo) {
  sections.push(
    "",
    "-- Test-only workspace and role accounts required by Trial Mode",
    readFileSync(join(directory, "seed.sql"), "utf8").trim(),
    "",
    "-- Test-only database assertions",
    readFileSync(join(directory, "staging_verification.sql"), "utf8").trim(),
  );
}

sections.push(
  "",
  "commit;",
  "",
  "select schema_version,applied_at",
  "from public.chekmi_schema_meta",
  "where singleton=true;",
  "",
  "select count(*) as legacy_staff_requiring_phone_update",
  "from public.staff",
  "where phone_number like 'legacy-unset-%';",
  "",
);

const output = sections.join("\n").replaceAll("\r\n", "\n");

for (const migrationName of migrationNames) {
  const marker = `-- Migration: ${migrationName}`;
  if (output.split(marker).length !== 2) {
    throw new Error(`Migration was not included exactly once: ${migrationName}`);
  }
}
if ((output.match(/\$\$/g) ?? []).length % 2 !== 0) {
  throw new Error("Generated SQL contains an unbalanced $$ delimiter.");
}
if (!includeDemo && /MESOB-DEMO|AdminTest!2026|CashierTest!2026|WaiterTest!2026/.test(output)) {
  throw new Error("Generated SQL unexpectedly contains demo credentials.");
}
if (includeDemo && !/MESOB-DEMO[\s\S]*WaiterTest!2026/.test(output)) {
  throw new Error("Test bundle is missing the Trial Mode workspace or waiter.");
}

const outputName = includeDemo
  ? "CHEKMI_APP_TEST_SETUP.sql"
  : "CHEKMI_COMPLETE_SETUP.sql";
writeFileSync(join(directory, outputName), output, "utf8");
console.log(
  `Generated ${outputName} from ${migrationNames.length} migrations.`,
);
