# Chekmi premium onboarding design preview

This is an isolated browser prototype for design approval. It reuses the repository's original `assets/branding/chekmi_mark.png` and is not loaded by the Flutter app.

From the repository root, run:

```powershell
python -m http.server 8089 --bind 127.0.0.1 --directory .
```

Open <http://127.0.0.1:8089/preview/premium-onboarding/>.

The desktop toolbar changes the simulated phone width and replays the splash. Five business presets, workflow choices, and non-secret form fields persist in this browser tab. The Events example remembers its event, category, and station. Authentication, workspace lookup, bank verification, registration, and activation are intentionally disabled; the prototype makes no API calls.

The production app currently uses Supabase email/password for business owners and a workspace-scoped phone/password RPC for staff. The preview's owner phone form is a proposed experience, not a working login. Existing owners can inspect a separate email compatibility screen. A real phone-first release requires an enabled and tested Supabase phone provider, verified OTP ownership, resend and recovery controls, duplicate-phone handling, and a safe migration linking verified phone identities to existing owner records. The existing anonymous `lookup_business` RPC returns workspace name and active status; its disclosure and rate limits need review before using a code-first public connection screen in production.

Events is a presentation preset and illustrative receipt-verification workspace only. The current database profile and payment-context constraints do not yet accept an `events` use case or event/category/station references. An additive migration, scoped permissions, event-specific ledger queries, and aggregation tests would be needed after design approval. There is no ticketing, admission, or inventory flow.

For browser regression checks and screenshots, run `python preview/premium-onboarding/check_preview.py`. Screenshots are written to `artifacts/premium-preview/` and are ignored by Git.
