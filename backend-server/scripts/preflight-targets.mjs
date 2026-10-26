const directBanks = [
  ["Telebirr", "transactioninfo.ethiotelecom.et", 443],
  ["CBE app", "apps.cbe.com.et", 100],
  ["CBE mobile", "mb.cbe.com.et", 443],
  ["Dashen", "receipt.dashensuperapp.com", 443],
  ["Abyssinia", "cs.bankofabyssinia.com", 443],
  ["CBE Birr", "cbepay1.cbe.com.et", 443],
  ["M-Pesa", "m-pesabusiness.safaricom.et", 443],
];
const globallyReachableBanks = directBanks.slice(3, 6);

function configuredKey(value) {
  const key = value?.trim();
  return Boolean(key && !/^(?:replace|set|your|example|placeholder)[-_\s]/i.test(key));
}

export function planPreflight(env, supabaseHost) {
  const mode = (env.CHEKMI_PROVIDER_EGRESS || "direct").trim().toLowerCase();
  if (!["direct", "auto", "proxy"].includes(mode)) throw new Error("Invalid provider egress mode.");
  const targets = mode === "proxy" ? [...globallyReachableBanks] : [...directBanks];
  const errors = [];
  if (mode === "proxy") {
    for (const [label, urlName, keyName] of [
      ["Telebirr relay", "TELEBIRR_PROXY_URLS", "TELEBIRR_PROXY_KEY"],
      ["CBE relay", "CBE_PROXY_URL", "CBE_PROXY_KEY"],
      ["M-Pesa relay", "MPESA_PROXY_URL", "MPESA_PROXY_KEY"],
    ]) {
      if (!configuredKey(env[keyName])) errors.push(`${keyName} is missing or still a placeholder.`);
      const values = (env[urlName] || "").split(",").map(value => value.trim()).filter(Boolean);
      if (!values.length) errors.push(`${urlName} is missing.`);
      for (const value of values) {
        try {
          const url = new URL(value);
          if (url.protocol !== "https:" || url.username || url.password || url.hash || url.search) throw Error();
          targets.push([label, url.hostname, url.port ? Number(url.port) : 443]);
        } catch { errors.push(`${urlName} must contain bare HTTPS endpoint URLs.`); }
      }
    }
  }
  if (supabaseHost) {
    if (!/^[a-z0-9.-]+$/i.test(supabaseHost)) throw new Error("--supabase-host must be a hostname, not a URL or secret.");
    targets.push(["Supabase", supabaseHost, 443]);
  }
  return { mode, targets, errors, requiresEthiopianEgress: mode !== "proxy" };
}
