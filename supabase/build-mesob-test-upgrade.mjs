import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const directory = dirname(fileURLToPath(import.meta.url));
const migrations = [
  "202610180001_owner_registration.sql",
  "202610200001_receipt_evidence_archive.sql",
];
const sections = [
  "-- CHEKMI MESOB CATCH-UP — 2026-10-20",
  "-- Run ONCE after 202610160001_inclusive_workspaces.sql on an existing Mesob workspace.",
  "-- Does not seed demo accounts or change Mesob passwords, receiving accounts, or subscriptions.",
  "-- Do not run this combined query if either migration below is already applied.",
  "-- SQL alone is insufficient: deploy chekmi-verify and chekmi-receipt-evidence Edge Functions too.",
  "",
  "begin;",
  "do $$ begin",
  "  if to_regclass('public.workspace_profiles') is null then",
  "    raise exception 'Apply inclusive workspaces migration first';",
  "  end if;",
  "  if to_regclass('public.workspace_owner_identities') is not null then",
  "    raise exception 'Owner registration is already applied; use only the pending dated migrations';",
  "  end if;",
  "  if to_regprocedure('public.reserve_receipt_original(text,uuid,text,integer,text,text)') is not null then",
  "    raise exception 'Receipt archive is already applied; do not rerun this one-time bundle';",
  "  end if;",
  "end $$;",
];

for (const name of migrations) {
  sections.push("", `-- Migration: ${name}`, readFileSync(join(directory, "migrations", name), "utf8").trim());
}
sections.push(
  "",
  "-- Assert the existing Mesob workspace and new schema before committing",
  readFileSync(join(directory, "mesob_readiness.sql"), "utf8").trim(),
  "",
  "commit;",
  "",
);

const output = sections.join("\n").replaceAll("\r\n", "\n");
for (const name of migrations) {
  if (output.split(`-- Migration: ${name}`).length !== 2) {
    throw new Error(`Missing or repeated migration: ${name}`);
  }
}
if ((output.match(/\$\$/g) ?? []).length % 2 !== 0) {
  throw new Error("Generated SQL has unbalanced $$ delimiters.");
}
const outputName = "CHEKMI_MESOB_TEST_UPGRADE_20261020.sql";
writeFileSync(join(directory, outputName), output, "utf8");
console.log(`Generated ${outputName}.`);
