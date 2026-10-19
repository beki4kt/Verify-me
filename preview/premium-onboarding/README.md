# Chekmi premium onboarding design preview

This is an isolated browser prototype for design approval. It reuses the repository's original `assets/branding/chekmi_mark.png` and is not loaded by the Flutter app.

From the repository root, run:

```powershell
python -m http.server 8089 --bind 127.0.0.1 --directory .
```

Open <http://127.0.0.1:8089/preview/premium-onboarding/>.

The desktop toolbar changes the simulated phone width and replays the splash. Business choices and non-secret form fields persist in this browser tab. Authentication, workspace lookup, bank verification, registration, and activation are intentionally disabled; the prototype makes no API calls.

For browser regression checks and screenshots, run `python preview/premium-onboarding/check_preview.py`. Screenshots are written to `artifacts/premium-preview/` and are ignored by Git.
