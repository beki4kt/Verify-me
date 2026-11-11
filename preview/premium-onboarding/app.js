/* Chekmi visual preview. All actions stay in this browser; no API client is loaded. */
const logo = '../../assets/branding/chekmi_mark.png';
const app = document.getElementById('app');
const splash = document.getElementById('splash');
const phone = document.getElementById('phone');
const presets = window.ChekmiPresets;
const stored = (() => { try { return JSON.parse(sessionStorage.getItem('chekmi-preview-draft') || '{}'); } catch { return {}; } })();
const legacyCategories = { shop:'shop_retail', food:'food_hospitality', restaurant:'food_hospitality', service:'services_professionals', general:'general_personal', events:'events_venues' };
const savedBusiness = legacyCategories[stored.business] || stored.business || '';
const data = {
  business: presets[savedBusiness] ? savedBusiness : '', subtype: stored.subtype || '', workflow: stored.workflow || '',
  mode: stored.mode || 'solo', review: stored.review || 'automatic', adjustOpen: false,
  reference: stored.reference || 'none', plan: stored.plan || 'basic', period: stored.period || 'monthly',
  name: stored.name || '', owner: stored.owner || '', country: stored.country || 'ET',
  phoneLocal: stored.phoneLocal || (stored.phone || '').replace(/^\+251/, ''),
  provider: stored.provider || 'telebirr', account: stored.account || '', code: '', staffPhone: '',
  ownerPhone: '', ownerCountry: 'ET', staffCountry: 'ET', ownerEmail: '', ownerPassword: '', staffPassword: '', registrationPassword: '',
  event: stored.event || 'Addis Autumn Fair', category: stored.category || 'Door Sales', station: stored.station || 'Main gate', eventReference: '',
  eventReturn: 'business', eventMessage: '', dashboardMessage: '', visiblePassword: false, error: '',
  sampleProvider: 'telebirr', sampleReference: '', sampleAmount: '', sampleResult: '', sampleBusy: false,
};
let route = location.hash.slice(1) || 'welcome';
let splashTimer;
let toastTimer;

const icons = {
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m14 5-7 7 7 7"/></svg>',
  building: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 21v-4h6v4M8 7h2m4 0h2M8 11h2m4 0h2"/></svg>',
  link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 13a5 5 0 0 0 7.1 0l2-2a5 5 0 0 0-7.1-7.1l-1.1 1.1M14 11a5 5 0 0 0-7.1 0l-2 2A5 5 0 0 0 12 20.1l1.1-1.1"/></svg>',
  eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/></svg>',
  shop: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 11h20l-2-6H6l-2 6Zm2 0v12h16V11M11 23v-8h6v8M4 11c0 2 2 3 4 2 1.5 1 3 .4 4-1 1.5 2 3 2 5 0 1 2 2.5 2 4.5 1 2 1 3.5 0 3.5-2"/></svg>',
  service: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="9" width="20" height="15" rx="2"/><path d="M10 9V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v3M4 15c5 3 15 3 20 0"/></svg>',
  general: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="4" width="18" height="20" rx="2"/><path d="M9 10h10M9 15h10M9 20h6"/></svg>',
  food: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 4v8m3-8v8M4 4v6c0 2 2 3 4 3s4-1 4-3V4M8 13v11M21 4c-4 3-5 8-5 13h5V4Zm0 13v7"/></svg>',
  events: '<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="6" width="20" height="18" rx="2"/><path d="M9 3v6m10-6v6M4 12h20M9 17h3m4 0h3M9 21h3"/></svg>',
};
function esc(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
function persist() {
  const keys = ['business','subtype','workflow','mode','review','reference','plan','period','name','owner','country','phoneLocal','provider','account','event','category','station'];
  sessionStorage.setItem('chekmi-preview-draft', JSON.stringify(Object.fromEntries(keys.map(key => [key, data[key]]))));
}
function button(label, action, variant = 'primary', extra = '', icon = '') { return `<button type="button" class="button button-${variant} ${icon ? 'has-icon' : ''}" data-action="${action}" ${extra}>${icon ? `<span class="button-leading">${icons[icon]}</span>` : ''}<span>${label}</span></button>`; }
function header(back, count = '') { return `<div class="screen-top"><button type="button" class="icon-button" data-action="${back}" aria-label="Go back">${icons.back}</button><span class="screen-count">${count}</span></div>`; }
function progress(step) { return `<div class="progress" aria-label="Step ${step} of 5">${[1,2,3,4,5].map(n => `<span class="${n <= step ? 'active' : ''}"></span>`).join('')}</div>`; }
function error() { return data.error ? `<p class="form-error" role="alert">${esc(data.error)}</p>` : ''; }
function field(key, label, placeholder = '', type = 'text', attrs = '') {
  return `<label class="field"><span class="field-label">${label}</span><input class="field-input" data-field="${key}" type="${type}" value="${esc(data[key])}" placeholder="${placeholder}" autocomplete="off" ${attrs}></label>`;
}
function passwordField(key, label = 'Password') {
  return `<div class="field"><label class="field-label" for="field-${key}">${label}</label><div class="field-wrap"><input id="field-${key}" class="field-input" data-field="${key}" type="${data.visiblePassword ? 'text' : 'password'}" value="${esc(data[key])}" autocomplete="off" placeholder="Enter password"><button class="field-reveal" type="button" data-action="toggle-password" aria-label="${data.visiblePassword ? 'Hide' : 'Show'} password">${data.visiblePassword ? 'Hide' : 'Show'}</button></div></div>`;
}
function segment(options, current, action) { return `<div class="segmented" role="group">${options.map(([value,label]) => `<button type="button" class="${value === current ? 'selected' : ''}" aria-pressed="${value === current}" data-action="${action}" data-value="${value}">${label}</button>`).join('')}</div>`; }
function choice(value) { const preset=presets[value]; return `<button class="choice ${value === 'events_venues' ? 'choice-wide' : ''} ${data.business === value ? 'selected' : ''}" type="button" data-action="business" data-value="${value}" aria-pressed="${data.business === value}"><span class="choice-icon">${icons[preset.icon]}</span><span class="choice-check" aria-hidden="true">✓</span><span class="choice-label">${preset.title}</span></button>`; }
function selectedSubtype() { return presets[data.business]?.subtypes[data.subtype] || null; }
function selectedWorkflow() { return selectedSubtype()?.choices.find(item => item.id === data.workflow) || null; }
function referenceLabel() {
  const workflow=selectedWorkflow();
  if (workflow?.reference===data.reference && workflow.referenceLabel) return workflow.referenceLabel;
  return presets[data.business]?.references.find(([id]) => id === data.reference)?.[1] || 'Payment ref';
}
if (!selectedSubtype()) { data.subtype=''; data.workflow=''; }
else if (!selectedWorkflow()) {
  const recommended=selectedSubtype().choices[0];
  data.workflow=recommended.id; data.reference=recommended.reference;
  data.mode=recommended.mode; data.review=recommended.review;
}
if (data.mode==='team') data.plan='pro';
const countries = {ET:['Ethiopia','+251'],KE:['Kenya','+254'],US:['United States','+1'],GB:['United Kingdom','+44']};
function phoneInput(key, label='Phone number', countryKey='country') {
  return `<div class="field"><label class="field-label" for="field-${key}">${label}</label><div class="phone-input"><select class="country-select" data-field="${countryKey}" aria-label="Country code">${Object.entries(countries).map(([id,[name,dial]])=>`<option value="${id}" ${data[countryKey]===id?'selected':''}>${dial} ${id}</option>`).join('')}</select><input id="field-${key}" class="field-input" type="tel" inputmode="tel" autocomplete="tel-national" data-field="${key}" value="${esc(data[key])}" placeholder="${data[countryKey]==='ET'?'911 234 567':'Phone number'}"></div></div>`;
}
function normalizePhone(country, raw) {
  if (!countries[country]) return null;
  const digits=String(raw||'').replace(/[^0-9]/g,'').replace(/^0(?=[79][0-9]{8}$)/,'');
  if (country==='ET') return /^[79][0-9]{8}$/.test(digits) ? `+251${digits}` : null;
  return /^[0-9]{7,12}$/.test(digits) ? `${countries[country][1]}${digits}` : null;
}
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
    <div class="welcome-actions">${button('Get Started','start','primary','','building')}${button('Connect Workspace','connect','secondary','','link')}<div class="centered-link"><button class="preview-action" type="button" data-action="preview">${icons.eye}<span>Explore Preview</span></button></div></div>
  </section>`;
}
function renderConnect() {
  return `<section class="screen" aria-label="Connect workspace">${header('welcome')}
    <div class="screen-body"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Connect Workspace</h1><p class="subtle">Enter your workspace code.</p>
      <label class="field code-field"><span class="field-label">Workspace code</span><span class="code-wrap"><span class="code-icon">${icons.building}</span><input class="field-input" data-field="code" type="text" value="${esc(data.code)}" placeholder="Workspace code" autocapitalize="characters" autocomplete="off" spellcheck="false"></span></label>${error()}
    </div><div class="screen-footer">${button('Continue','code-continue')}</div>
  </section>`;
}
function renderStaffLogin() {
  return `<section class="screen" aria-label="Workspace sign in">${header('connect')}
    <div class="screen-body"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Welcome back</h1><p class="subtle">Workspace ${esc(data.code)}</p>
      ${phoneInput('staffPhone','Phone number','staffCountry')}${passwordField('staffPassword')}${error()}
      <p class="inline-note">Preview only. No workspace or membership lookup.</p>
      <div class="centered-link"><button class="text-button" type="button" data-action="owner-phone">Business owner? Sign in</button></div>
    </div><div class="screen-footer">${button('Sign In','staff-login')}<div class="centered-link"><button class="text-button" type="button" data-action="dashboard-preview">Explore workspace preview</button></div></div>
  </section>`;
}
function renderOwnerPhone() {
  return `<section class="screen" aria-label="Owner phone sign in">${header('staff')}
    <div class="screen-body"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Welcome back</h1><p class="subtle">Business owner</p>
      ${phoneInput('ownerPhone','Phone number','ownerCountry')}${passwordField('ownerPassword')}
      <div class="recovery-row"><button class="text-button" type="button" data-action="recovery">Forgot password?</button></div>${error()}
      <p class="inline-note">Phone sign-in needs verified SMS setup.</p>
    </div><div class="screen-footer">${button('Sign In','owner-login')}<div class="centered-link"><button class="text-button" type="button" data-action="owner-email">Use email to sign in</button></div><div class="centered-link"><button class="text-button" type="button" data-action="dashboard-preview">Explore dashboard preview</button></div></div>
  </section>`;
}
function renderOwnerEmail() {
  return `<section class="screen" aria-label="Existing owner email sign in">${header('owner-phone')}
    <div class="screen-body"><img class="mini-mark" src="${logo}" alt=""><h1 class="headline">Existing owner?</h1><p class="subtle">Use your current email account.</p>
      ${field('ownerEmail','Email address','you@business.com','email','inputmode="email"')}${passwordField('ownerPassword')}${error()}
      <p class="inline-note">Existing owners still use email in the iOS app.</p>
    </div><div class="screen-footer">${button('Sign In','owner-email-login')}</div>
  </section>`;
}
function renderBusiness() {
  return `<section class="screen" aria-label="Choose business">${header('welcome','01 / 05')}
    <div class="screen-body">${progress(1)}<h1 class="headline">Choose your<br>business</h1>
      <div class="choice-grid">${Object.keys(presets).map(choice).join('')}</div>
    </div><div class="screen-footer">${button('Continue','business-next','primary',data.business ? '' : 'disabled')}</div>
  </section>`;
}
function subtypeChoice(id, subtype) {
  const selected = data.subtype === id;
  return `<button type="button" class="subtype-choice ${selected?'selected':''}" data-action="subtype" data-value="${id}" aria-pressed="${selected}"><span>${esc(subtype.title)}</span><span class="subtype-check" aria-hidden="true">✓</span></button>`;
}
function renderSubtype() {
  const category=presets[data.business];
  if (!category) return renderBusiness();
  const prompts={shop_retail:'What kind of shop?',food_hospitality:'What do you operate?',services_professionals:'What service do you offer?',general_personal:'How will you use Chekmi?',events_venues:'What type of event?'};
  return `<section class="screen" aria-label="Choose business type">${header('business','02 / 05')}
    <div class="screen-body">${progress(2)}<p class="setup-context">${esc(category.title)}</p><h1 class="headline">${prompts[data.business]}</h1>
      <div class="subtype-list" role="group" aria-label="${esc(category.title)} types">${Object.entries(category.subtypes).map(([id,item])=>subtypeChoice(id,item)).join('')}</div>
    </div><div class="screen-footer">${button('Continue','subtype-next','primary',data.subtype ? '' : 'disabled')}</div>
  </section>`;
}
function referenceChoices() {
  const choices=presets[data.business]?.references || presets.general_personal.references;
  const workflow=selectedWorkflow();
  return choices.map(([id,label])=>[id,workflow?.reference===id && workflow.referenceLabel ? workflow.referenceLabel : label]);
}
function workflowChoice(item) {
  const selected=data.workflow===item.id;
  return `<button class="workflow-choice ${selected?'selected':''}" type="button" data-action="workflow" data-value="${item.id}" aria-pressed="${selected}"><span>${esc(item.label)}</span><span class="subtype-check" aria-hidden="true">✓</span></button>`;
}
function featureNote() {
  const features=selectedWorkflow()?.features || [];
  if (data.business==='events_venues') return 'Event labels and stations are preview-only.';
  if (features.includes('counter_labels')) return 'Counter labels and staff attribution can be added later.';
  if (features.includes('tables')) return 'Table labels can be added later.';
  return '';
}
function renderWorkflow() {
  const category=presets[data.business], subtype=selectedSubtype();
  if (!category || !subtype) return renderSubtype();
  return `<section class="screen" aria-label="Set workflow">${header('subtype','03 / 05')}
    <div class="screen-body">${progress(3)}<p class="setup-context">${esc(subtype.title)}</p><h1 class="headline">${esc(subtype.question)}</h1>
      <div class="workflow-list" role="group" aria-label="${esc(subtype.question)}">${subtype.choices.map(workflowChoice).join('')}</div>
      <div class="setup-summary"><div><span>Track by</span><strong id="setup-reference">${esc(referenceLabel())}</strong></div><div><span>Workspace</span><strong id="setup-mode">${data.mode==='team'?'My Team':'Just Me'}</strong></div><div><span>Completion</span><strong id="setup-review">${data.review==='automatic'?'Auto':'Review'}</strong></div></div>
      <p class="small-help feature-note" id="feature-note" ${featureNote()?'':'hidden'}>${esc(featureNote())}</p>
      <button class="adjust-toggle" type="button" data-action="toggle-adjust" aria-expanded="${data.adjustOpen}" aria-controls="setup-adjust">Adjust setup <span aria-hidden="true">⌄</span></button>
      <div class="setup-adjust" id="setup-adjust" ${data.adjustOpen?'':'hidden'}>
        <p class="group-title">Who uses Chekmi?</p>${segment([['solo','Just Me'],['team','My Team']],data.mode,'mode')}
        <p class="group-title">When is payment complete?</p>${segment([['automatic','Auto'],['review_required','Review']],data.review,'review')}
        <p class="small-help" id="review-help">${data.review === 'automatic' ? 'Verified payments can complete automatically.' : 'An authorized member completes payments after review.'}</p>
        <p class="group-title">Track payments by</p><select class="field-select reference-select" data-field="reference" aria-label="Track payments by">${referenceChoices().map(([id,label])=>`<option value="${id}" ${id===data.reference?'selected':''}>${esc(label)}</option>`).join('')}</select>
      </div>
    </div><div class="screen-footer">${data.business==='events_venues'?'<div class="centered-link"><button class="text-button" type="button" data-action="events-preview">See event workspace</button></div>':''}${button('Continue','workflow-next','primary',data.workflow ? '' : 'disabled')}</div>
  </section>`;
}
function planCard(value,name,price,meta,disabled = false) {
  return `<button type="button" class="plan-card ${data.plan === value ? 'selected' : ''}" data-action="plan" data-value="${value}" aria-pressed="${data.plan === value}" ${disabled ? 'disabled' : ''}>
    <span class="plan-card-top"><span class="plan-name">${name}</span><span class="plan-price">${price}</span></span><span class="plan-meta">${meta}</span></button>`;
}
function renderPlans() {
  const basicPrice = data.period === 'monthly' ? 'ETB 1,200 / mo' : 'ETB 3,000 / 3 mo';
  const team = data.mode === 'team';
  return `<section class="screen" aria-label="Select plan">${header('workflow','04 / 05')}
    <div class="screen-body">${progress(4)}<h1 class="headline">Choose a plan</h1>
      <p class="setup-context">${esc(selectedSubtype()?.title || '')} · ${esc(selectedWorkflow()?.label || '')}</p>
      <p class="group-title">Billing period</p>${segment([['monthly','Monthly'],['quarterly','Quarterly']],data.period,'period')}
      <div style="margin-top:25px">${planCard('basic','Basic',basicPrice,'1 member · 2,500 verifications',team)}${planCard('pro','Pro','Request quote','Unlimited members · Unlimited verifications')}</div>
      ${team ? '<p class="small-help">Team workspaces use Pro. Add members after activation.</p>' : '<p class="small-help">Plans are activated after review. No in-app charge.</p>'}
      ${error()}
    </div><div class="screen-footer">${button('Continue','plan-next')}</div>
  </section>`;
}
function renderRegistration() {
  return `<section class="screen" aria-label="Business registration">${header('plans','05 / 05')}
    <div class="screen-body">${progress(5)}<h1 class="headline">Create your<br>business</h1>
      <p class="setup-context">${esc(selectedSubtype()?.title || '')} · ${esc(selectedWorkflow()?.label || '')}</p>
      ${field('name','Business name','Your business')}${field('owner','Owner name','Your name')}${phoneInput('phoneLocal','Phone number','country')}${passwordField('registrationPassword','Create password')}
      <hr class="section-divider"><p class="group-title">Receiving account</p><label class="field"><span class="field-label">Provider</span><select class="field-select" data-field="provider"><option value="telebirr" ${data.provider==='telebirr'?'selected':''}>Telebirr</option><option value="cbe" ${data.provider==='cbe'?'selected':''}>CBE</option><option value="cbebirr" ${data.provider==='cbebirr'?'selected':''}>CBE Birr</option><option value="dashen" ${data.provider==='dashen'?'selected':''}>Dashen</option><option value="abyssinia" ${data.provider==='abyssinia'?'selected':''}>Abyssinia</option><option value="mpesa" ${data.provider==='mpesa'?'selected':''}>M-Pesa</option></select></label>
      ${field('account','Receiving account','Account or merchant number')}${error()}
      <p class="inline-note">Preview only. Phone verification and activation are not available in this browser.</p>
    </div><div class="screen-footer">${button('Review request','registration-next')}</div>
  </section>`;
}
function renderSummary() {
  const preset = presets[data.business]?.title || presets.general_personal.title;
  return `<section class="screen" aria-label="Registration request preview">${header('registration')}
    <div class="screen-body"><div class="complete-mark" aria-hidden="true">✓</div><span class="preview-pill"><span class="small-dot"></span> Preview only</span><h1 class="headline">Ready to<br>request access</h1>
      <div class="preview-panel"><div class="receipt-title">${esc(data.name || 'Your business')}</div><div class="receipt-sub">${preset} · ${esc(selectedSubtype()?.title || '')}</div><div class="receipt-detail"><span>Workflow</span><strong>${esc(selectedWorkflow()?.label || '')}</strong></div><div class="receipt-detail"><span>Plan</span><strong>${data.plan === 'pro' ? 'Pro · quote' : 'Basic'}</strong></div></div>
      <p class="inline-note">No business was created. Real phone verification, workspace setup, and plan activation remain separate backend steps.</p>
    </div><div class="screen-footer">${data.business==='events_venues'?button('See Events preview','events-preview','secondary'):''}${button('Edit details','registration','secondary')}${button('Back to welcome','welcome','secondary')}</div>
  </section>`;
}
function renderPreview() {
  return `<section class="screen" aria-label="Illustrative payment preview">${header('welcome')}
    <div class="screen-body preview-body"><span class="preview-pill"><span class="small-dot"></span> Interactive sample</span><h1 class="headline preview-headline">Try a receipt</h1>
      <p class="subtle">See how a payment result appears.</p>
      <div class="sample-quick" role="group" aria-label="Sample receipts">
        <button type="button" class="sample-chip" data-action="sample-fill" data-value="CK-DEMO-PAID">Verified</button>
        <button type="button" class="sample-chip" data-action="sample-fill" data-value="CK-DEMO-DUP">Duplicate</button>
        <button type="button" class="sample-chip" data-action="sample-fill" data-value="CK-DEMO-PENDING">Pending</button>
      </div>
      <label class="field"><span class="field-label">Payment provider</span><select class="field-select" data-field="sampleProvider"><option value="telebirr" ${data.sampleProvider==='telebirr'?'selected':''}>Telebirr</option><option value="cbe" ${data.sampleProvider==='cbe'?'selected':''}>CBE</option></select></label>
      ${field('sampleReference','Receipt reference','Choose a sample or type a reference')}
      ${field('sampleAmount','Expected amount (ETB)','e.g. 1,250','text','inputmode="decimal"')}
      <div class="sample-account"><span>Receiving account</span><strong>Demo account ·•• 4242</strong></div>
      <div id="sample-result" class="sample-result" role="status" aria-live="polite"></div>
    </div><div class="screen-footer preview-footer">${button('Check sample receipt','sample-check')}<p class="sample-disclaimer">Illustrative only · No bank lookup or ledger write</p></div>
  </section>`;
}
function updateSelection(action, value) {
  app.querySelectorAll(`[data-action="${action}"][data-value]`).forEach(element => {
    const selected = element.dataset.value === value;
    element.classList.toggle('selected', selected);
    element.setAttribute('aria-pressed', String(selected));
  });
}
function refreshSetupSummary() {
  const reference=app.querySelector('#setup-reference');
  if (!reference) return;
  reference.textContent=referenceLabel();
  app.querySelector('#setup-mode').textContent=data.mode==='team'?'My Team':'Just Me';
  app.querySelector('#setup-review').textContent=data.review==='automatic'?'Auto':'Review';
  const note=app.querySelector('#feature-note'); note.textContent=featureNote(); note.hidden=!featureNote();
  const referenceInput=app.querySelector('[data-field="reference"]');
  if(referenceInput) {
    const labels=new Map(referenceChoices());
    [...referenceInput.options].forEach(option=>{option.textContent=labels.get(option.value) || option.textContent;});
    referenceInput.value=data.reference;
  }
}
function updateSampleResult() {
  const panel = app.querySelector('#sample-result');
  if (!panel) return;
  const labels = {
    verified: ['Sample: payment verified', 'The sample receipt matches the expected amount.', 'verified'],
    duplicate: ['Sample: duplicate payment', 'This sample reference was already used.', 'duplicate'],
    pending: ['Sample: verification pending', 'The sample result is uncertain. Check again later.', 'pending'],
    unverified: ['Sample: payment not verified', 'No matching sample receipt was found.', 'unverified'],
    invalid: ['Enter a receipt reference and a valid amount.', 'Use a positive amount in ETB.', 'invalid'],
    loading: ['Checking sample…', 'No bank is contacted.', 'loading'],
  };
  if (!data.sampleResult) { panel.innerHTML = ''; panel.classList.remove('visible'); return; }
  const [title, detail, style] = labels[data.sampleResult];
  panel.className = `sample-result visible sample-${style}`;
  panel.innerHTML = `<span class="sample-result-mark" aria-hidden="true">${style==='verified'?'✓':style==='loading'?'···':'!'}</span><div><strong>${title}</strong><span>${detail}</span></div>`;
}
function selectField(key,label,options) {
  return `<label class="field"><span class="field-label">${label}</span><select class="field-select" data-field="${key}">${options.map(value=>`<option value="${esc(value)}" ${data[key]===value?'selected':''}>${esc(value)}</option>`).join('')}</select></label>`;
}
function renderEventsPreview() {
  const categories=presets.events_venues.categories;
  return `<section class="screen" aria-label="Events payment preview">${header(data.eventReturn)}
    <div class="screen-body"><span class="preview-pill"><span class="small-dot"></span> Illustrative workspace</span><h1 class="headline" style="margin-top:18px">Event payments</h1>
      <div class="event-grid">${selectField('event','Event',['Addis Autumn Fair','Bole Night Market'])}${selectField('category','Category',categories)}</div>
      ${selectField('station','Station',['Main gate','North counter','Hall kiosk'])}
      ${field('eventReference','Receipt reference','Scan or enter reference')}
      <div class="event-actions">${button('Scan receipt','event-scan','secondary')}${button('Check receipt','event-check')}</div>
      ${data.eventMessage?`<p class="inline-note" role="status">${esc(data.eventMessage)}</p>`:''}
      <div class="ledger-mini"><div class="ledger-header"><strong>Event ledger</strong><span>Sample only</span></div><div class="ledger-row"><span>Door Sales</span><strong>1,250 ETB</strong></div><div class="ledger-row"><span>Food & Drinks</span><strong>420 ETB</strong></div></div>
      <p class="small-help">Event, category, and station stay selected for the next receipt. No ticketing or admission tools.</p>
    </div>
  </section>`;
}
function renderDashboardPreview() {
  return `<section class="screen" aria-label="Illustrative workspace dashboard">${header('staff')}
    <div class="screen-body"><span class="preview-pill"><span class="small-dot"></span> Illustrative workspace</span><h1 class="headline" style="margin-top:18px">Your workspace</h1>
      <div class="preview-panel"><div class="receipt-title">Verify payment</div><div class="receipt-sub">Scan a receipt or enter its reference</div><div class="receipt-detail"><span>Receiving account</span><strong>Configured in app</strong></div></div>
      <p class="inline-note">A real sign-in would load your server-authorized membership and permitted actions. This preview has no account access.</p>
    </div><div class="screen-footer">${button('Explore Preview','preview','secondary')}</div>
  </section>`;
}
function render() {
  const nextRoute = ['subtype','workflow','plans','registration','summary'].includes(route) && !presets[data.business] ? 'business'
    : ['workflow','plans','registration','summary'].includes(route) && !selectedSubtype() ? 'subtype'
    : ['plans','registration','summary'].includes(route) && !selectedWorkflow() ? 'workflow' : route;
  if (nextRoute !== route) { route=nextRoute; history.replaceState({route},'',`#${route}`); }
  const views = {welcome:renderWelcome,connect:renderConnect,staff:renderStaffLogin,'owner-phone':renderOwnerPhone,'owner-email':renderOwnerEmail,business:renderBusiness,subtype:renderSubtype,workflow:renderWorkflow,plans:renderPlans,registration:renderRegistration,summary:renderSummary,preview:renderPreview,'events-preview':renderEventsPreview,'dashboard-preview':renderDashboardPreview};
  app.innerHTML = (views[route] || renderWelcome)(); app.scrollTop = 0; document.title = `Chekmi · ${route === 'welcome' ? 'Design preview' : route[0].toUpperCase()+route.slice(1)}`;
}
function processAction(action, value) {
  if (['welcome','connect','staff','owner-phone','owner-email','plans','registration','dashboard-preview'].includes(action) || ['business','subtype','workflow'].includes(action) && !value) return nav(action);
  if (action === 'start') return nav('business');
  if (action === 'preview') return nav('preview');
  if (action === 'events-preview') { data.eventReturn=route; return nav('events-preview'); }
  if (action === 'business') {
    if (!presets[value]) return;
    if (data.business !== value) { data.subtype=''; data.workflow=''; data.reference='none'; data.mode='solo'; data.review='automatic'; data.plan='basic'; data.adjustOpen=false; }
    data.business = value;
    persist(); updateSelection('business',value);
    app.querySelector('[data-action="business-next"]').disabled = false;
    app.querySelector('.form-error')?.remove(); data.error=''; return;
  }
  if (action === 'business-next') return data.business ? nav('subtype') : undefined;
  if (action === 'subtype') {
    const selected=presets[data.business]?.subtypes[value]; if (!selected) return;
    const previous=data.subtype;
    data.subtype=value;
    const recommended=previous===value ? selected.choices.find(item=>item.id===data.workflow) || selected.choices[0] : selected.choices[0];
    data.workflow=recommended.id; data.reference=recommended.reference;
    if (previous!==value) { data.mode=recommended.mode; data.review=recommended.review; data.adjustOpen=false; }
    data.plan=data.mode==='team'?'pro':'basic';
    persist(); updateSelection('subtype',value);
    app.querySelector('[data-action="subtype-next"]').disabled=false; return;
  }
  if (action === 'subtype-next') return selectedSubtype() ? nav('workflow') : undefined;
  if (action === 'workflow') {
    const selected=selectedSubtype()?.choices.find(item=>item.id===value); if (!selected) return;
    data.workflow=value; data.reference=selected.reference; data.mode=selected.mode; data.review=selected.review;
    data.plan=data.mode==='team'?'pro':'basic'; persist(); updateSelection('workflow',value);
    updateSelection('mode',data.mode); updateSelection('review',data.review);
    const help=app.querySelector('#review-help'); if(help) help.textContent=data.review==='automatic'?'Verified payments can complete automatically.':'An authorized member completes payments after review.';
    refreshSetupSummary(); app.querySelector('[data-action="workflow-next"]').disabled=false; return;
  }
  if (action === 'toggle-adjust') {
    data.adjustOpen=!data.adjustOpen;
    const toggle=app.querySelector('[data-action="toggle-adjust"]'); toggle.setAttribute('aria-expanded',String(data.adjustOpen));
    app.querySelector('#setup-adjust').hidden=!data.adjustOpen; return;
  }
  if (action === 'mode') { data.mode=value; data.plan=value==='team'?'pro':'basic'; persist(); updateSelection(action,value); refreshSetupSummary(); return; }
  if (action === 'review' || action === 'reference' || action === 'period' || action === 'plan') {
    data[action]=value; persist(); updateSelection(action,value);
    if (action==='review') app.querySelector('#review-help').textContent = value==='automatic' ? 'Verified payments can complete automatically.' : 'An authorized member completes payments after review.';
    if (action==='period') app.querySelector('[data-action="plan"][data-value="basic"] .plan-price').textContent = value==='monthly' ? 'ETB 1,200 / mo' : 'ETB 3,000 / 3 mo';
    if (action==='review') refreshSetupSummary();
    return;
  }
  if (action === 'sample-fill') {
    data.sampleReference=value; data.sampleAmount='1250'; data.sampleResult='';
    app.querySelector('[data-field="sampleReference"]').value=value;
    app.querySelector('[data-field="sampleAmount"]').value=data.sampleAmount;
    app.querySelectorAll('.sample-chip').forEach(chip => chip.classList.toggle('selected',chip.dataset.value===value));
    updateSampleResult(); return;
  }
  if (action === 'sample-check') {
    if (data.sampleBusy) return;
    const amount=Number(data.sampleAmount.replace(/,/g,''));
    if (!data.sampleReference.trim() || !Number.isFinite(amount) || amount<=0) {data.sampleResult='invalid';updateSampleResult();return;}
    const reference=data.sampleReference.trim().toUpperCase();
    const provider=data.sampleProvider;
    data.sampleBusy=true; data.sampleResult='loading'; updateSampleResult();
    const check=app.querySelector('[data-action="sample-check"]'); check.disabled=true;
    setTimeout(() => {
      data.sampleBusy=false;
      if (route !== 'preview') return;
      data.sampleResult=provider==='telebirr' && amount===1250 ? ({ 'CK-DEMO-PAID':'verified','CK-DEMO-DUP':'duplicate','CK-DEMO-PENDING':'pending' })[reference] || 'unverified' : 'unverified';
      updateSampleResult(); check.disabled=false;
    },450);
    return;
  }
  if (action === 'workflow-next') return selectedWorkflow() ? nav('plans') : undefined;
  if (action === 'plan-next') return nav('registration');
  if (action === 'toggle-password') {
    data.visiblePassword=!data.visiblePassword;
    const input = app.querySelector('.field-wrap input'); if (input) input.type=data.visiblePassword?'text':'password';
    const reveal=app.querySelector('.field-reveal'); if(reveal){reveal.textContent=data.visiblePassword?'Hide':'Show';reveal.setAttribute('aria-label',`${data.visiblePassword?'Hide':'Show'} password`)}
    return;
  }
  if (action === 'code-continue') {
    data.code=data.code.trim().toUpperCase();
    if (!/^[A-Z0-9-]{3,32}$/.test(data.code)) {data.error='Enter a valid workspace code.';return render()}
    return nav('staff');
  }
  if (action === 'owner-login') {
    if (!normalizePhone(data.ownerCountry,data.ownerPhone) || !data.ownerPassword) {data.error='Enter a valid phone number and password.';return render()}
    data.error='Owner phone sign-in is not configured. No authentication was attempted.'; return render();
  }
  if (action === 'owner-email-login') {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.ownerEmail.trim()) || !data.ownerPassword) {data.error='Enter your email and password.';return render()}
    data.error='Use the iOS app to sign in with your existing owner account.'; return render();
  }
  if (action === 'staff-login') {
    if (!normalizePhone(data.staffCountry,data.staffPhone) || !data.staffPassword) {data.error='Enter your phone number and password.';return render()}
    data.error='Sign-in is disabled in this browser preview. No membership was checked.'; return render();
  }
  if (action === 'recovery') return showToast('Owner phone recovery needs verified SMS support. Existing email recovery remains in the app.');
  if (action === 'event-scan') return showToast('Camera scanning is available in the app, not this preview.');
  if (action === 'event-check') {
    clearTimeout(toastTimer); document.querySelector('.toast')?.remove();
    data.eventMessage=data.eventReference.trim().length<5 ? 'Enter a receipt reference to preview this step.' : 'No bank lookup or ledger write happens in this preview.';
    return render();
  }
  if (action === 'registration-next') {
    if (data.name.trim().length<2 || data.owner.trim().length<2 || !normalizePhone(data.country,data.phoneLocal) || data.registrationPassword.length<10 || data.account.trim().length<6) {
      data.error='Enter business and owner details, a valid phone, a 10-character password, and a receiving account.'; return render();
    }
    return nav('summary');
  }
}
app.addEventListener('click', event => { const target=event.target.closest('[data-action]'); if(target) processAction(target.dataset.action,target.dataset.value); });
app.addEventListener('input', event => { const key=event.target.dataset.field; if(!key)return; data[key]=event.target.value; if(data.error){data.error='';app.querySelector('.form-error')?.remove();} if(['sampleReference','sampleAmount'].includes(key)){data.sampleResult='';updateSampleResult();app.querySelectorAll('.sample-chip').forEach(chip => chip.classList.toggle('selected',chip.dataset.value===data.sampleReference));} if(['name','owner','phoneLocal','account','eventReference'].includes(key))persist(); });
app.addEventListener('change', event => { const key=event.target.dataset.field; if(key){data[key]=event.target.value;if(key==='sampleProvider'){data.sampleResult='';updateSampleResult();}else {persist();if(key==='reference')refreshSetupSummary();}} });
app.addEventListener('keydown', event => { if(event.key==='Enter' && event.target.matches('input')){event.preventDefault();const next=[...app.querySelectorAll('input')].indexOf(event.target)+1;const fields=app.querySelectorAll('input');if(fields[next])fields[next].focus();else app.querySelector('.screen-footer .button-primary')?.click();} });
window.addEventListener('popstate', () => {route=location.hash.slice(1)||'welcome';data.error='';render();});
document.getElementById('viewport').addEventListener('change', event => {phone.style.setProperty('--phone-width',`${event.target.value}px`);});
document.getElementById('replay').addEventListener('click',replaySplash);
render(); replaySplash();
