# CHEKMI production operations

## Service checks and incidents

`production-health.yml` checks the live verification Edge Function plus every
public legal/support page every ten minutes. A failed check opens or
updates a GitHub issue with the `incident` label. Recovery closes the issue.

Treat an inability to verify payments or sign in as severity 1. Treat degraded
demo, support, or legal-page access as severity 2. For severity 1, confirm the
Supabase project status, inspect Edge Function logs, pause receipt acceptance if
verification cannot establish settlement truth, and post updates in the incident
issue. Never paste receipts, credentials, API keys, or customer data into issues.

## Client errors

Authenticated unhandled Flutter errors are recorded through
`report_client_error`. Events include only business/staff references, a runtime
error type, app area, platform, and time. They exclude exception messages, stack
traces, receipt contents, credentials, and payment references. Review new event
groups after releases and during incidents. Retain these events for 90 days.

## Backup and restore

`database-backup.yml` runs daily. It dumps roles, schema, and data separately,
restores schema and data into an ephemeral PostgreSQL database, then encrypts the
backup before uploading it as a private 30-day Actions artifact. This provides a
24-hour recovery point objective. The operational recovery target is four hours.

Required repository secrets:

- `SUPABASE_DB_URL`
- `BACKUP_PASSPHRASE`

Every quarter, download the newest encrypted artifact, verify its SHA-256 file,
decrypt it in an access-controlled environment, and restore it to a disposable
Supabase project. Record migration count, table count, business count, ticket
count, and completion time without recording customer rows. Delete the disposable
project and decrypted files when the drill is complete.

## Release credentials

Production GitHub environments should require review for Supabase and store
deployments. Android upload keys, Apple certificates, database URLs, passwords,
and App Store Connect keys belong in repository secrets or the owner password
manager. Rotate a credential immediately if it appears in source, logs, issues,
or chat.
