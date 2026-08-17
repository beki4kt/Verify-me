# CHEKMI Operations Runbook

## Production controls

- Host the API behind HTTPS and set `NODE_ENV=production`.
- Store service-role and provider keys in a managed secret store.
- Monitor `/health`, `/ready`, HTTP errors, provider failures, and latency.
- Never send receipt images, credentials, or payment payloads to crash logs.

## Backup and restore

1. Enable point-in-time recovery or daily managed database backups.
2. Copy encrypted backups to an access-controlled secondary location.
3. Monthly, restore the latest backup into an isolated test project.
4. Verify row counts and exercise login, receipts, settlements, and payouts.
5. Record restore duration, recovery point, operator, and outcome.

## Incident response

1. Disable the affected provider or suspend the tenant using service tooling.
2. Preserve request IDs, evidence, financial events, and audit logs.
3. Rotate exposed keys and revoke active sessions.
4. Notify affected customers under the privacy/support policy.
5. Document root cause, remediation, and follow-up owners.
