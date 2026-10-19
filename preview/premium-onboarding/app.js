/* Chekmi visual preview. All actions stay in this browser; no API client is loaded. */
const logo = '../../assets/branding/chekmi_mark.png';
const app = document.getElementById('app');
const splash = document.getElementById('splash');
const phone = document.getElementById('phone');
const stored = (() => { try { return JSON.parse(sessionStorage.getItem('chekmi-preview-draft') || '{}'); } catch { return {}; } })();
const data = {
  business: stored.business || '', mode: stored.mode || 'solo', review: stored.review || 'automatic',
  reference: stored.reference || 'none', plan: stored.plan || 'basic', period: stored.period || 'monthly',
  name: stored.name || '', owner: stored.owner || '', phone: stored.phone || '', email: stored.email || '',
  provider: stored.provider || 'telebirr', account: stored.account || '', code: '', member: '',
  ownerEmail: '', ownerPassword: '', staffPassword: '', registrationPassword: '',
  loginMode: 'team', visiblePassword: false, error: '', note: '',
};
let route = location.hash.slice(1) || 'welcome';
let splashTimer;
let toastTimer;

const icons = {
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m14 5-7 7 7 7"/></svg>',
  shop: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 11h20l-2-6H6l-2 6Zm2 0v12h16V11M11 23v-8h6v8M4 11c0 2 2 3 4 2 1.5 1 3 .4 4-1 1.5 2 3 2 5 0 1 2 2.5 2 4.5 1 2 1 3.5 0 3.5-2"/></svg>',
  restaurant: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 4v8m3-8v8M4 4v6c0 2 2 3 4 3s4-1 4-3V4M8 13v11M21 4c-4 3-5 8-5 13h5V4Zm0 13v7"/></svg>',
  service: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="9" width="20" height="15" rx="2"/><path d="M10 9V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v3M4 15c5 3 15 3 20 0"/></svg>',
  general: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="4" width="18" height="20" rx="2"/><path d="M9 10h10M9 15h10M9 20h6"/></svg>',
};
function esc(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
function persist() {
  const keys = ['business','mode','review','reference','plan','period','name','owner','phone','email','provider','account'];
  sessionStorage.setItem('chekmi-preview-draft', JSON.stringify(Object.fromEntries(keys.map(key => [key, data[key]]))));
}
function button(label, action, variant = 'primary', extra = '') { return `<button type="button" class="button button-${variant}" data-action="${action}" ${extra}>${label}</button>`; }
function header(back, count = '') { return `<div class="screen-top"><button type="button" class="icon-button" data-action="${back}" aria-label="Go back">${icons.back}</button><span class="screen-count">${count}</span></div>`; }
function progress(step) { return `<div class="progress" aria-label="Step ${step} of 4">${[1,2,3,4].map(n => `<span class="${n <= step ? 'active' : ''}"></span>`).join('')}</div>`; }
function error() { return data.error ? `<p class="form-error" role="alert">${esc(data.error)}</p>` : ''; }
function field(key, label, placeholder = '', type = 'text', attrs = '') {
  return `<label class="field"><span class="field-label">${label}</span><input class="field-input" data-field="${key}" type="${type}" value="${esc(data[key])}" placeholder="${placeholder}" autocomplete="off" ${attrs}></label>`;
}
function passwordField(key, label = 'Password') {
  return `<div class="field"><label class="field-label" for="field-${key}">${label}</label><div class="field-wrap"><input id="field-${key}" class="field-input" data-field="${key}" type="${data.visiblePassword ? 'text' : 'password'}" value="${esc(data[key])}" autocomplete="off" placeholder="Enter password"><button class="field-reveal" type="button" data-action="toggle-password" aria-label="${data.visiblePassword ? 'Hide' : 'Show'} password">${data.visiblePassword ? 'Hide' : 'Show'}</button></div></div>`;
}
function segment(options, current, action) { return `<div class="segmented" role="group">${options.map(([value,label]) => `<button type="button" class="${value === current ? 'selected' : ''}" aria-pressed="${value === current}" data-action="${action}" data-value="${value}">${label}</button>`).join('')}</div>`; }
function choice(value, label, icon) { return `<button class="choice ${data.business === value ? 'selected' : ''}" type="button" data-action="business" data-value="${value}" aria-pressed="${data.business === value}"><span class="choice-icon">${icons[icon]}</span><span class="choice-check" aria-hidden="true">✓</span><span class="choice-label">${label}</span></button>`; }
function nav(path, replace = false) {
  data.error = ''; data.note = '';
  route = path;
  if (replace) history.replaceState({route}, '', `#${path}`); else history.pushState({route}, '', `#${path}`);
  render();
}
function showToast(message) {
  clearTimeout(toastTimer);
  document.querySelector('.toast')?.remove();
  const element = document.createElement('div'); element.className = 'toast'; element.role = 'status'; element.textContent = message;
  document.querySelector('.phone-screen').appendChild(element);
  toastTimer = setTimeout(() => element.remove(), 3500);
}
function replaySplash() {
  clearTimeout(splashTimer);
  splash.classList.remove('exit','running'); void splash.offsetWidth;
  splash.classList.add('running'); splash.setAttribute('aria-hidden','false');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  splashTimer = setTimeout(() => {
    splash.classList.add('exit');
    setTimeout(() => { splash.classList.remove('running','exit'); splash.setAttribute('aria-hidden','true'); }, reduced ? 30 : 360);
  }, reduced ? 160 : 1130);
}
function renderWelcome() {
  return `<section class="screen welcome" aria-label="Welcome">
    <div class="welcome-top"><img class="logo-mark" src="${logo}" alt="Chekmi receipt and checkmark logo"><div class="brand-name">Chekmi</div></div>
    <div class="welcome-center"><h1 class="welcome-title">Payments,<br><span>verified.</span></h1><div class="welcome-rule"></div></div>
    <div class="welcome-actions">${button('Get Started','start')}${button('Connect Workspace','connect','secondary')}<div class="centered-link"><button class="text-button" type="button" data-action="preview">Preview</button></div></div>
  </section>`;
}
function renderConnect() {
  const team = data.loginMode === 'team';
  return `<section class="screen" aria-label="Connect workspace">${header('welcome')}
    <div class="screen-body compact"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Welcome back</h1><p class="subtle">Sign in to your workspace.</p>
      <div class="auth-tabs">${segment([['team','Team member'],['owner','Business owner']],data.loginMode,'login-mode')}</div>
      ${team ? field('code','Workspace code','e.g. CK-123456','text','autocapitalize="characters"') : `${field('ownerEmail','Email address','you@business.com','email','inputmode="email"')}${passwordField('ownerPassword')}<div class="recovery-row"><button class="text-button" type="button" data-action="recovery">Forgot password?</button></div>`}
      ${error()}<p class="inline-note">Design preview only. No credentials or workspace codes are sent.</p>
    </div><div class="screen-footer">${button(team ? 'Continue' : 'Sign In',team ? 'team-continue' : 'owner-login')}
      <div class="centered-link"><button class="text-button" type="button" data-action="start">Create business</button></div></div>
  </section>`;
}
function renderStaffLogin() {
  return `<section class="screen" aria-label="Team sign in">${header('connect')}
    <div class="screen-body"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Team sign in</h1><p class="subtle">Workspace ${esc(data.code.toUpperCase())}</p>
      ${field('member','Member ID','Your staff ID')}${passwordField('staffPassword')}${error()}
      <p class="inline-note">A real sign-in requires a valid workspace and staff account. This preview makes no request.</p>
    </div><div class="screen-footer">${button('Sign In','staff-login')}</div>
  </section>`;
}
function renderBusiness() {
  return `<section class="screen" aria-label="Choose business">${header('welcome','01 / 04')}
    <div class="screen-body">${progress(1)}<h1 class="headline">Choose your<br>business</h1>
      <div class="choice-grid">${choice('shop','Shop','shop')}${choice('restaurant','Restaurant','restaurant')}${choice('service','Services','service')}${choice('general','General','general')}</div>
      <p class="small-help" style="margin-top:17px">You can change your setup later.</p>${error()}
    </div><div class="screen-footer">${button('Continue','business-next','primary',data.business ? '' : 'disabled')}</div>
  </section>`;
}
function referenceChoices() {
  return ({shop:[['order','Order'],['customer','Customer'],['none','None']],restaurant:[['table','Table'],['order','Order'],['none','None']],service:[['invoice','Invoice'],['booking','Booking'],['none','None']],general:[['none','None'],['customer','Customer'],['note','Note']]})[data.business] || [['none','None']];
}
function renderWorkflow() {
  return `<section class="screen" aria-label="Set workflow">${header('business','02 / 04')}
    <div class="screen-body">${progress(2)}<h1 class="headline">Set your<br>workflow</h1>
      <p class="group-title">Who uses Chekmi?</p>${segment([['solo','Just Me'],['team','My Team']],data.mode,'mode')}
      <p class="group-title">When is a payment complete?</p>${segment([['automatic','Auto'],['review_required','Review']],data.review,'review')}
      <p class="small-help">${data.review === 'automatic' ? 'Verified payments can complete automatically.' : 'An authorized member completes payments after review.'}</p>
      <p class="group-title">Track payments by</p>${segment(referenceChoices(),data.reference,'reference')}
      ${error()}
    </div><div class="screen-footer">${button('Continue','workflow-next')}</div>
  </section>`;
}
function planCard(value,name,price,meta,disabled = false) {
  return `<button type="button" class="plan-card ${data.plan === value ? 'selected' : ''}" data-action="plan" data-value="${value}" aria-pressed="${data.plan === value}" ${disabled ? 'disabled' : ''}>
    <span class="plan-card-top"><span class="plan-name">${name}</span><span class="plan-price">${price}</span></span><span class="plan-meta">${meta}</span></button>`;
}
function renderPlans() {
  const basicPrice = data.period === 'monthly' ? 'ETB 1,200 / mo' : 'ETB 3,000 / 3 mo';
  const team = data.mode === 'team';
  return `<section class="screen" aria-label="Select plan">${header('workflow','03 / 04')}
    <div class="screen-body">${progress(3)}<h1 class="headline">Choose a plan</h1>
      <p class="group-title">Billing period</p>${segment([['monthly','Monthly'],['quarterly','Quarterly']],data.period,'period')}
      <div style="margin-top:25px">${planCard('basic','Basic',basicPrice,'1 member · 2,500 verifications',team)}${planCard('pro','Pro','Request quote','Team access · Unlimited verifications')}</div>
      ${team ? '<p class="small-help">Team workspaces use Pro. Add members after activation.</p>' : '<p class="small-help">Plans are activated after review. No in-app charge.</p>'}
      ${error()}
    </div><div class="screen-footer">${button('Continue','plan-next')}</div>
  </section>`;
}
function renderRegistration() {
  return `<section class="screen" aria-label="Business registration">${header('plans','04 / 04')}
    <div class="screen-body">${progress(4)}<h1 class="headline">Create your<br>business</h1><p class="subtle">A few essentials. Then request activation.</p>
      ${field('name','Business name','Your business')}${field('owner','Your name','Business owner')}${field('phone','Phone','+251…','tel','inputmode="tel"')}${field('email','Email','you@business.com','email','inputmode="email"')}${passwordField('registrationPassword','Create password')}
      <hr class="section-divider"><p class="group-title">Receiving account</p><label class="field"><span class="field-label">Provider</span><select class="field-select" data-field="provider"><option value="telebirr" ${data.provider==='telebirr'?'selected':''}>Telebirr</option><option value="cbe" ${data.provider==='cbe'?'selected':''}>CBE</option><option value="cbebirr" ${data.provider==='cbebirr'?'selected':''}>CBE Birr</option><option value="dashen" ${data.provider==='dashen'?'selected':''}>Dashen</option><option value="abyssinia" ${data.provider==='abyssinia'?'selected':''}>Abyssinia</option><option value="mpesa" ${data.provider==='mpesa'?'selected':''}>M-Pesa</option></select></label>
      ${field('account','Receiving account','Account or merchant number')}${error()}
      <p class="inline-note">Preview only. Real registration requires email verification and activation.</p>
    </div><div class="screen-footer">${button('Review request','registration-next')}</div>
  </section>`;
}
function renderSummary() {
  const preset = {shop:'Shop',restaurant:'Restaurant',service:'Services',general:'General'}[data.business] || 'General';
  return `<section class="screen" aria-label="Registration request preview">${header('registration')}
    <div class="screen-body"><div class="complete-mark" aria-hidden="true">✓</div><span class="preview-pill"><span class="small-dot"></span> Preview only</span><h1 class="headline">Ready to<br>request access</h1>
      <div class="preview-panel"><div class="receipt-title">${esc(data.name || 'Your business')}</div><div class="receipt-sub">${preset} · ${data.mode === 'team' ? 'My Team' : 'Just Me'}</div><div class="receipt-detail"><span>Plan</span><strong>${data.plan === 'pro' ? 'Pro · quote' : 'Basic'}</strong></div></div>
      <p class="inline-note">No business was created and no subscription was activated. In the app, this request would await real email confirmation and operator approval.</p>
    </div><div class="screen-footer">${button('Edit details','registration','secondary')}${button('Back to welcome','welcome','secondary')}</div>
  </section>`;
}
function renderPreview() {
  return `<section class="screen" aria-label="Illustrative payment preview">${header('welcome')}
    <div class="screen-body"><span class="preview-pill"><span class="small-dot"></span> Illustrative preview</span><h1 class="headline" style="margin-top:22px">Payment clarity,<br>at a glance.</h1>
      <div class="preview-panel"><div class="receipt-row"><span class="receipt-check" aria-hidden="true">✓</span><div><div class="receipt-title">Example verification</div><div class="receipt-sub">Sample screen · no bank lookup</div></div></div><div class="receipt-detail"><span>Amount</span><strong>1,250.00 ETB</strong></div></div>
      <p class="inline-note">This screen demonstrates presentation only. No receipt was verified or recorded.</p>
    </div><div class="screen-footer">${button('Get Started','start')}${button('Connect Workspace','connect','secondary')}</div>
  </section>`;
}
function render() {
  const views = {welcome:renderWelcome,connect:renderConnect,staff:renderStaffLogin,business:renderBusiness,workflow:renderWorkflow,plans:renderPlans,registration:renderRegistration,summary:renderSummary,preview:renderPreview};
  app.innerHTML = (views[route] || renderWelcome)(); app.scrollTop = 0; document.title = `Chekmi · ${route === 'welcome' ? 'Design preview' : route[0].toUpperCase()+route.slice(1)}`;
}
function processAction(action, value) {
  if (action === 'welcome' || action === 'connect' || action === 'business' && !value || ['workflow','plans','registration'].includes(action)) return nav(action);
  if (action === 'start') return nav('business');
  if (action === 'preview') return nav('preview');
  if (action === 'business') {
    data.business = value;
    data.reference = ({shop:'order',restaurant:'table',service:'invoice',general:'none'})[value];
    persist(); return render();
  }
  if (action === 'business-next') return data.business ? nav('workflow') : (data.error='Choose a business type.',render());
  if (action === 'mode') { data.mode=value; if (value==='team') data.plan='pro'; persist(); return render(); }
  if (action === 'review' || action === 'reference' || action === 'period' || action === 'plan') { data[action]=value; persist(); return render(); }
  if (action === 'workflow-next') return nav('plans');
  if (action === 'plan-next') return nav('registration');
  if (action === 'login-mode') { data.loginMode=value; data.error=''; return render(); }
  if (action === 'toggle-password') {
    data.visiblePassword=!data.visiblePassword;
    const input = app.querySelector('.field-wrap input'); if (input) input.type=data.visiblePassword?'text':'password';
    const reveal=app.querySelector('.field-reveal'); if(reveal){reveal.textContent=data.visiblePassword?'Hide':'Show';reveal.setAttribute('aria-label',`${data.visiblePassword?'Hide':'Show'} password`)}
    return;
  }
  if (action === 'team-continue') {
    if (!/^[A-Za-z0-9-]{3,32}$/.test(data.code.trim())) {data.error='Enter the workspace code from your business.';return render()}
    return nav('staff');
  }
  if (action === 'owner-login') {
    if (!data.ownerEmail.includes('@') || !data.ownerPassword) {data.error='Enter your email and password.';return render()}
    data.error='Sign-in is disabled in this design preview. Use the app for real access.'; return render();
  }
  if (action === 'staff-login') {
    if (!data.member.trim() || !data.staffPassword) {data.error='Enter your member ID and password.';return render()}
    data.error='Sign-in is disabled in this design preview. Use the app for real access.'; return render();
  }
  if (action === 'recovery') return showToast('Password recovery is available in the app, not this preview.');
  if (action === 'registration-next') {
    if (data.name.trim().length<2 || data.owner.trim().length<2 || !/^\+251[79]\d{8}$/.test(data.phone.trim()) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim()) || data.registrationPassword.length<10 || data.account.trim().length<6) {
      data.error='Complete every field. Use a +251 phone and a password of at least 10 characters.'; return render();
    }
    return nav('summary');
  }
}
app.addEventListener('click', event => { const target=event.target.closest('[data-action]'); if(target) processAction(target.dataset.action,target.dataset.value); });
app.addEventListener('input', event => { const key=event.target.dataset.field; if(!key)return; data[key]=event.target.value; if(data.error){data.error='';app.querySelector('.form-error')?.remove();} if(['name','owner','phone','email','account'].includes(key))persist(); });
app.addEventListener('change', event => { const key=event.target.dataset.field; if(key){data[key]=event.target.value;persist();} });
app.addEventListener('keydown', event => { if(event.key==='Enter' && event.target.matches('input')){event.preventDefault();const next=[...app.querySelectorAll('input')].indexOf(event.target)+1;const fields=app.querySelectorAll('input');if(fields[next])fields[next].focus();else app.querySelector('.screen-footer .button-primary')?.click();} });
window.addEventListener('popstate', () => {route=location.hash.slice(1)||'welcome';data.error='';render();});
document.getElementById('viewport').addEventListener('change', event => {phone.style.setProperty('--phone-width',`${event.target.value}px`);});
document.getElementById('replay').addEventListener('click',replaySplash);
render(); replaySplash();
