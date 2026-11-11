# Receipt evidence browser preview

From the repository root run `python -m http.server 8088 --bind 127.0.0.1`, then open `http://127.0.0.1:8088/preview/receipt-evidence/`.

This is an isolated, illustrative product preview. The example payment is **not bank-verified**. You can select a real JPEG/PNG image to exercise original-byte storage in this browser's IndexedDB, view it full-screen, and simulate a failed save/retry. No image leaves this browser. The production implementation uses the private Supabase bucket and authenticated Edge function instead.
