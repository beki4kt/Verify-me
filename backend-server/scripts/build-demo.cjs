const fs=require('node:fs');const path=require('node:path');const esbuild=require('esbuild');
const root=path.resolve(__dirname,'..');const target=path.resolve(root,'../supabase/functions/chekmi-demo/index.js');
fs.mkdirSync(path.dirname(target),{recursive:true});
esbuild.buildSync({stdin:{contents:'import {createDemoVerificationHandler} from "./src/demoVerification"; Deno.serve(createDemoVerificationHandler(Deno.env.toObject()));',resolveDir:root,loader:'ts'},bundle:true,platform:'browser',format:'esm',target:'es2022',outfile:target});
const code=fs.readFileSync(target,'utf8');if(/sk_live_[a-z0-9]{20,}|aletcloud\.com|commit_verified_payment|WaiterTest!/i.test(code))throw Error('Unexpected secret or business payment path in demo bundle');
console.log('Built standalone demo function:',fs.statSync(target).size,'bytes');
