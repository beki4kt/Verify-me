export function verifierIsReady(body, response) {
  return response.ok && body?.status === 'ready' &&
    ['owned', 'veritas'].includes(body?.verifier?.engine) &&
    body?.verifier?.configured === true;
}

export function healthState(status, ok) {
  if (ok) return 'ready';
  if (status === 404) return 'endpoint_missing';
  if (status === 401 || status === 403) return 'unauthorized';
  if (status >= 500) return 'dependency_failure';
  return 'unexpected_response';
}
