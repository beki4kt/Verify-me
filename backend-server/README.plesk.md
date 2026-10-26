# Chekmi Node backend on Ethio Telecom Plesk

Use a **separate subdomain** (for example, `api.chekmiverifier.com.et`). Do not
enable Node.js on the existing `chekmiverifier.com.et` site: its `/httpdocs`
contains the working PHP bank relay. A Node app on the same subscription needs
its own application root and public document root.

## Prepare the subdomain

In Plesk, add the subdomain under Websites & Domains, giving it a document root
that is separate from the parent's `/httpdocs`. Confirm that the new subdomain
has its own Node.js page, DNS and valid HTTPS certificate before uploading.
On that subdomain, the backend archive should be extracted into an application
root such as `chekmi-node`; its public document root should be the `public`
subdirectory **inside** that root. The startup file is `app.js` in the root.
The compiled server is `dist/index.js`. Node.js 22.9+ is required; the
observed Plesk version 22.23.4 meets it.

## Package and run

From the repository, build locally and make the Plesk archive:

    cd backend-server
    npm ci
    npm test
    npm run build
    cd ..
    .\backend-server\scripts\package-alet.ps1 -Plesk -Destination .\build\Chekmi-Backend-Plesk.zip

Upload and extract the archive only into the new subdomain's application root.
In its Node.js panel, set application root to that directory, document root to
its `public` child, startup file to `app.js`, mode to production and package
manager to npm. Run NPM Install, then enable Node.js. Plesk Passenger supplies
`PORT` dynamically: **do not set a fixed PORT** in custom variables.

Use `.env.plesk.example` as a names-only checklist for Plesk custom environment
variables. Enter the private service-role key, internal lookup key and three
PHP relay keys only in the hosting secret configuration. Never extract a real
`.env` into the document root. Use a unique internal lookup key also configured
on Supabase Edge. Do not paste keys into chat, source, logs or mobile builds.

## Readiness before connecting Chekmi

With HTTPS working, GET `/health` should return `status: ok`; GET `/ready`
should return `status: ready`, `verifierMode: live` and engine `owned`.
`/connectivity` should eventually report `passed`. These checks do not submit
a receipt or prove that relay keys work. The unsigned private provider route
must reject access. From a local machine, run:

    node backend-server/scripts/check-deployment.mjs https://api.chekmiverifier.com.et

If Plesk's resource or process limits prevent Node from starting, stop and use
a Node-capable hosting plan; do not replace the working PHP relay. After these
checks, a controlled Supabase Edge rollout and authorized genuine Mesob receipt
test are still required. See `README.relay.md` for the full request path and
financial acceptance steps.
