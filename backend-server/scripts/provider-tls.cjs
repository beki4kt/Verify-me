const { X509Certificate } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { Agent } = require('node:https');
const { join } = require('node:path');
const { rootCertificates } = require('node:tls');

const MPESA_HOST = 'm-pesabusiness.safaricom.et';
const INTERMEDIATE_SHA256 = 'C8:02:5F:9F:C6:5F:DF:C9:5B:3C:A8:CC:78:67:B9:A5:87:B5:27:79:73:95:79:17:46:3F:C8:13:D0:B6:25:A9';
let mpesaCa;
let mpesaAgent;

function mpesaCertificateAuthorities() {
  if (mpesaCa) return mpesaCa;
  const pem = readFileSync(join(__dirname, '../certs/digicert-global-g2-tls-rsa-sha256-2020-ca1.pem'), 'utf8');
  const certificate = new X509Certificate(pem);
  // The provider omits this intermediate. It must still chain to a root
  // already trusted by Node; never trust a downloaded leaf or private root.
  const signedByTrustedRoot = rootCertificates.some((rootPem) => {
    const root = new X509Certificate(rootPem);
    return certificate.checkIssued(root) && certificate.verify(root.publicKey);
  });
  if (!certificate.ca || certificate.fingerprint256 !== INTERMEDIATE_SHA256 || !signedByTrustedRoot) {
    throw new Error('M-Pesa intermediate certificate failed integrity/issuer validation.');
  }
  mpesaCa = [...rootCertificates, pem];
  return mpesaCa;
}

function providerTlsOptions(hostname) {
  return {
    rejectUnauthorized: true,
    minVersion: 'TLSv1.2',
    allowPartialTrustChain: false,
    ...(hostname.toLowerCase() === MPESA_HOST ? { ca: mpesaCertificateAuthorities() } : {}),
  };
}

function providerHttpsAgent(url) {
  if (url.protocol !== 'https:' || url.hostname.toLowerCase() !== MPESA_HOST) return undefined;
  mpesaAgent ??= new Agent({ ...providerTlsOptions(url.hostname), keepAlive: true });
  return mpesaAgent;
}

module.exports = { providerTlsOptions, providerHttpsAgent };
