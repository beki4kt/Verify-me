# Mesob iPhone self-hosted verifier pilot

## What this build tests

The unsigned AltStore IPA from `build/iphone-altstore-relay-20261028` uses the
existing master Supabase project and sends payment verification directly to
`https://api.chekmiverifier.com.et/api/verify-and-create`. It does not compile
the `chekmi-verify` Supabase Edge URL. The build uses `CHEKMI_TEST2=true` for
the Mesob pilot interface. The Supabase publishable key is supplied by the
GitHub Actions secret; the service-role and relay keys are never in the app.

This proves the **configured client route**. To prove an actual payment used
the self-hosted verifier, compare one authorized iPhone test's timestamp and
provider with the Node API's `POST /api/verify-and-create` access log and
request outcome. Do not share full references, receipt contents, session
tokens, or raw PHP access URLs containing `key=`.

At preparation time Node `/ready` reported `owned/direct`; its
`/connectivity` reported `not_run`. The app can call the self-hosted Node
verifier in this configuration, but this does not establish use of the separate
PHP relay at `chekmiverifier.com.et`. For that path, the Node host must be
configured with `CHEKMI_PROVIDER_EGRESS=proxy` and the provider relay URLs and
keys, then restarted and checked again. Direct Ethiopian provider egress may
be intended on this host; record the selected route before interpreting results.

## Master database migration ledger, read 28 October 2026

The linked CLI reports migrations through `202610260001` applied. A dry run
lists exactly three pending files, in order:

1. `supabase/migrations/202610260002_explicit_future_tips.sql` — changes future
   overpayment policy to unresolved while preserving historical tip records.
   Review the effect on Mesob before applying.
2. `supabase/migrations/202610270001_phone_owner_registration.sql` — replaces
   owner registration/session RPCs for confirmed phone or existing confirmed
   email identities. Apply only after Supabase Phone Auth, SMS, abuse controls,
   recovery, and authorization tests are ready.
3. `supabase/migrations/202610270002_owner_archive_access.sql` — owner archive
   RPCs that depend on the preceding identity behavior. Apply only with Phase 3
   acceptance.

**No new SQL migration is required to route this iPhone build to Node.** Do not
run a blanket `supabase db push` just to test the relay, because it would push
all three pending migrations. The existing `supabase/mesob_readiness.sql` is a
read-only post-change check. SQL Editor execution does not automatically record
the CLI migration history; reconcile it before a later CLI push.

## Pilot test

1. Confirm `https://api.chekmiverifier.com.et/health` returns `ok` and
   `/ready` returns `ready`, `live`, `owned`. Record the reported egress mode.
2. Download the `Chekmi-iPhone-AltStore` artifact from the successful GitHub
   Actions run and install its unsigned IPA through AltStore.
3. Sign in to `MESOB-DEMO` with an existing authorized member.
4. Verify one authorized, genuine receipt belonging to Mesob's configured
   receiving account. Inspect the Node access log for the corresponding POST.
5. Check the resulting payment once in Activity, its amount and status, and
   whether original receipt evidence is stored. Repeat the same reference and
   confirm it does not add another payment.
6. If the Node host is in `proxy` mode, confirm the relevant PHP relay was
   called using redacted server-side diagnostics. Do not infer PHP relay usage
   from a successful iPhone screen alone.

This pilot uses the shared prelaunch project. A genuine verified receipt can
create a durable financial record. Use a receipt you are authorized to test and
do not repeatedly submit different real transactions as connectivity probes.
