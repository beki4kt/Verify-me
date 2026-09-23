# M-Pesa missing intermediate certificate

On 2026-09-06, m-pesabusiness.safaricom.et served only its leaf certificate,
causing Node to report UNABLE_TO_VERIFY_LEAF_SIGNATURE. This bundle supplies
the missing DigiCert Global G2 TLS RSA SHA256 2020 CA1 intermediate only for
that hostname. Hostname checks, expiry checks, and certificate validation stay
enabled. No partial-chain trust or global TLS override is used.

Source: https://cacerts.digicert.com/DigiCertGlobalG2TLSRSASHA2562020CA1-1.crt.pem

Published metadata:
https://knowledge.digicert.com/general-information/digicert-trusted-root-authority-certificates

SHA256 fingerprint:
C8:02:5F:9F:C6:5F:DF:C9:5B:3C:A8:CC:78:67:B9:A5:87:B5:27:79:73:95:79:17:46:3F:C8:13:D0:B6:25:A9

Issuer: DigiCert Global Root G2. Intermediate expires 2031-03-29.
The helper verifies the fingerprint and signature against Node's existing
trusted roots before using the intermediate. Provider certificate renewal can
require revisiting this workaround. The observed leaf expires 2026-09-17;
Safaricom must renew it, and CHEKMI must continue rejecting expired certificates.
