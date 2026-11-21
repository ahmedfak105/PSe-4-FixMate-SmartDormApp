/* FixMate Admin Dashboard — browser-only, RLS-enforced operations.
 * Uses ONLY the public publishable key. All authorization belongs in Supabase.
 */
'use strict';

// Reject legacy service_role JWTs as well as modern sb_secret API keys.
// A three-section JWT is not proof that a browser key is anonymous.
function isSafePublicApiKey(key) {
  if (typeof key !== 'string') return false;
  if (key.startsWith('sb_publishable_')) return key.length > 'sb_publishable_'.length;
  if (key.startsWith('sb_secret_') || key.startsWith('service_role')) return false;
  const parts = key.split('.');
  if (parts.length !== 3 || parts.some(x => !x)) return false;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.role === 'anon';
  } catch { return false; }
}


const PROJECT_URL = 'https://epsvagztisdovixlqehi.supabase.co';
const STORAGE_KEY = 'fixmate_admin_public_connection_v1';
const viewNames = { overview: 'OVERVIEW', reports: 'ALL REPORTS', assignments: 'ASSIGNMENTS', people: 'PEOPLE & ROLES' };

const state = {
  client: null,
  admin: null,
  profile: null,
  reports: [],
  profiles: [],
  categories: [],
  errors: {},
  loading: false,
  currentView: 'overview',
  assignReportId: null,
};

const el = id => document.getElementById(id);
const show = (node, on) => { node.hidden = !on; };
const asText = v => v === null || v === undefined || v === '' ? '—' : String(v);
const safe = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
const short = v => v && v.length > 10 ? `${v.slice(0, 7)}…` : asText(v);
const prettyRole = role => ({ system_admin:'System admin', maintenance_staff:'Maintenance staff', moderator:'Moderator', resident:'Resident' }[role] || asText(role));
const prettyStatus = status => ({ new:'New', in_progress:'In progress', resolved:'Resolved' }[status] || asText(status));
const niceDate = input => input ? new Date(input).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }) : '—';

function toast(message, type='info') {
  const node = el('toast');
  node.textContent = message;
  node.className = `toast${type === 'error' ? ' error' : ''}`;
  show(node, true);
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => show(node, false), 5200);
}
function errorBox(id, message) {
  const node = el(id);
  node.textContent = message || '';
  show(node, !!message);
}
function screen(name) {
  show(el('setupScreen'), name === 'setup');
  show(el('authScreen'), name === 'auth');
  show(el('dashboard'), name === 'dashboard');
}
function connection() {
  try { const raw = localStorage.getItem(STORAGE_KEY); return raw ? JSON.parse(raw) : null; }
  catch { return null; }
}
function checkConnection(url, key) {
  let parsed;
  try { parsed = new URL(url); }
  catch { throw new Error('Please enter a valid HTTPS Supabase project URL.'); }
  // Production connections remain HTTPS-only. A local Supabase CLI stack is
  // permitted ONLY while the dashboard itself is served from localhost.
  const hosted = parsed.protocol === 'https:' && parsed.hostname.endsWith('.supabase.co');
  const localPage = ['127.0.0.1', 'localhost'].includes(window.location.hostname);
  const localApi = parsed.protocol === 'http:' &&
    ['127.0.0.1', 'localhost'].includes(parsed.hostname) &&
    parsed.port === '54321';
  if (!hosted && !(localPage && localApi))
    throw new Error('Use an HTTPS *.supabase.co project or local Supabase CLI on localhost:54321.');
  if (!isSafePublicApiKey(key))
    throw new Error('Use only a public publishable API key or legacy anon JWT. Service-role and secret keys are forbidden.');
  return { url: parsed.origin, key };
}
function makeClient(cfg) {
  if (!window.supabase || !window.supabase.createClient)
    throw new Error('Supabase JavaScript library could not load. Check your internet connection and reload.');
  state.client = window.supabase.createClient(cfg.url, cfg.key, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'fixmate-admin-session' },
  });
  state.client.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') {
      state.admin = null;
      state.profile = null;
      screen('auth');
    }
  });
}

async function init() {
  const cfg = connection();
  el('projectUrl').value = cfg?.url || PROJECT_URL;
  if (!cfg) { screen('setup'); return; }
  try {
    makeClient(checkConnection(cfg.url, cfg.key));
    screen('auth');
    const { data: { session }, error } = await state.client.auth.getSession();
    if (error) throw error;
    if (session) await guardAndLoad();
  } catch(err) {
    screen('setup');
    errorBox('setupError', err.message || String(err));
  }
}

async function guardAndLoad() {
  if (!state.client) return;
  const { data, error: userError } = await state.client.auth.getUser();
  if (userError || !data?.user) {
    screen('auth');
    if (userError) errorBox('authError', userError.message);
    return;
  }
  const { data: profile, error } = await state.client.from('profiles')
    .select('id, full_name, role, building, room_number')
    .eq('id', data.user.id)
    .maybeSingle();
  if (error || !profile) {
    screen('auth');
    errorBox('authError', `Cannot read your profile: ${error?.message || 'Profile record not found'}. Check the profiles SELECT permission and RLS policy.`);
    return;
  }
  if (profile.role === 'maintenance_staff') {
    // The staff view has its own role guard and uses the same authenticated session.
    window.location.replace('staff.html');
    return;
  }
  if (profile.role === 'moderator') {
    // Moderator page has its own backend and session role checks.
    window.location.replace('moderator.html');
    return;
  }
  if (profile.role !== 'system_admin') {
    await state.client.auth.signOut();
    screen('auth');
    errorBox('authError', `Access denied: this account has role "${profile.role}". Only system_admin can open this workspace.`);
    return;
  }
  state.admin = data.user;
  state.profile = profile;
  const displayName = profile.full_name?.trim() || 'Admin';
  el('welcomeName').textContent = displayName.split(' ')[0];
  el('sideName').textContent = displayName;
  el('sideEmail').textContent = data.user.email || '';
  el('sideEmail').title = data.user.email || '';
  screen('dashboard');
  await loadAll();
}

function detailError(name, err) {
  return `${name}: ${err?.message || String(err)}${err?.code ? ` (code ${err.code})` : ''}`;
}
async function loadAll() {
  if (state.loading || !state.client || !state.admin) return;
  state.loading = true;
  const button = el('refreshButton');
  button.disabled = true;
  button.textContent = '↻ Loading…';
  try {
    const [r,c,p] = await Promise.all([
      state.client.from('maintenance_reports')
        .select('id,title,description,location,status,resident_id,assigned_to,category_id,created_at')
        .order('created_at', { ascending:false }).limit(500),
      state.client.from('maintenance_categories')
        .select('id,name,is_active').order('name', { ascending:true }).limit(200),
      state.client.from('profiles')
        .select('id,full_name,role,building,room_number,created_at').order('created_at', { ascending:false }).limit(500),
    ]);
    state.errors = {};
    if (r.error) state.errors.reports = detailError('Reports', r.error);
    else state.reports = r.data || [];
    if (c.error) state.errors.categories = detailError('Categories', c.error);
    else state.categories = c.data || [];
    if (p.error) state.errors.profiles = detailError('Profiles', p.error);
    else state.profiles = p.data || [];
    const warnings = Object.values(state.errors);
    // A user can have access to their own profile but not the staff directory.
    if (!warnings.length && !state.profiles.some(x => x.role === 'maintenance_staff'))
      warnings.push('No maintenance staff profiles are visible. If staff exist, check the admin SELECT policy on profiles before assigning reports.');
    const notice = el('globalNotice');
    notice.textContent = warnings.join(' • ');
    show(notice, !!warnings.length);
    el('lastRefreshed').textContent = new Date().toLocaleString('en-GB', { hour:'2-digit',minute:'2-digit',day:'numeric',month:'short' });
    renderAll();
  } catch(err) {
    toast(`Could not refresh: ${err.message || err}`, 'error');
  } finally {
    state.loading = false;
    button.disabled = false;
    button.innerHTML = '↻ <span>Refresh</span>';
  }
}
function nameForUser(id) {
  if (!id) return 'Unassigned';
  const p = state.profiles.find(x=>x.id===id);
  return p ? (p.full_name?.trim() || prettyRole(p.role)) : short(id);
}
function categoryFor(id) {
  const c = state.categories.find(x=>String(x.id)===String(id));
  return c?.name || `Category ${asText(id)}`;
}
function statusPill(v) {
  const cls = ['new','in_progress','resolved'].includes(v) ? v : '';
  return `<span class="status-pill ${cls}">${safe(prettyStatus(v))}</span>`;
}
function reportTable(data, { assign=false, recent=false }={}) {
  if (!data.length) return '<div class="empty-state">No reports found for this view.</div>';
  const rows = data.map(r => {
    const assigned = r.assigned_to ? nameForUser(r.assigned_to) : 'Unassigned';
    const assignment = r.status==='new' && r.assigned_to ? 'Assigned · awaiting claim' : assigned;
    const action = assign && !r.assigned_to && r.status==='new'
      ? `<button type="button" class="table-action" data-assign="${Number(r.id)}">Assign →</button>` : '';
    return `<tr><td><span class="report-title">#${safe(r.id)} · ${safe(r.title)}</span><div class="subcell">${safe(categoryFor(r.category_id))}</div></td><td>${safe(r.location || 'Not specified')}</td><td>${statusPill(r.status)}</td><td><div>${safe(assignment)}</div>${r.assigned_to ? `<div class="subcell">${safe(short(r.assigned_to))}</div>` : ''}</td><td>${safe(niceDate(r.created_at))}</td>${assign ? `<td>${action}</td>` : ''}</tr>`;
  }).join('');
  return `<table class="data-table"><thead><tr><th>REPORT</th><th>LOCATION</th><th>STATUS</th><th>ASSIGNED TO</th><th>CREATED</th>${assign ? '<th>ACTION</th>' : ''}</tr></thead><tbody>${rows}</tbody></table>`;
}
function renderAll() {
  const reports = state.reports;
  const counts = { new: 0, in_progress: 0, resolved: 0 };
  for (const r of reports) if (counts[r.status] !== undefined) counts[r.status] += 1;
  el('totalReports').textContent = state.errors.reports ? '—' : reports.length;
  el('newReports').textContent = state.errors.reports ? '—' : counts.new;
  el('activeReports').textContent = state.errors.reports ? '—' : counts.in_progress;
  el('resolvedReports').textContent = state.errors.reports ? '—' : counts.resolved;
  el('navReportsCount').textContent = reports.length;
  el('statusBars').innerHTML = Object.entries(counts).map(([s,count]) => {
    const pct = reports.length ? Math.round(count/reports.length*100) : 0;
    return `<div class="status-item"><div class="bar-header"><span>${safe(prettyStatus(s))}</span><strong>${count} · ${pct}%</strong></div><div class="bar-track"><div class="bar-fill ${s}" style="width:${pct}%"></div></div></div>`;
  }).join('');
  el('recentReports').innerHTML = state.errors.reports ? '<div class="empty-state">Reports cannot be loaded; check database permissions.</div>' : reportTable(reports.slice(0,6));
  const assignable = reports.filter(r=>r.status==='new' && !r.assigned_to);
  el('assignableCount').textContent = `${assignable.length} available`;
  el('assignableReports').innerHTML = state.errors.reports ? '<div class="empty-state">Reports unavailable.</div>' : reportTable(assignable,{assign:true});
  renderReports();
  renderPeople();
}
function renderReports() {
  const term = el('searchReports').value.trim().toLowerCase();
  const status = el('statusFilter').value;
  const data = state.reports.filter(r => {
    if (status!=='all' && r.status !== status) return false;
    return `${r.id} ${r.title} ${r.location || ''} ${categoryFor(r.category_id)}`.toLowerCase().includes(term);
  });
  el('reportsMatchCount').textContent = `${data.length} report${data.length===1?'':'s'}`;
  el('allReports').innerHTML = state.errors.reports ? '<div class="empty-state">Cannot load report data. Check RLS and table grants.</div>' : reportTable(data,{assign:true});
}
function renderPeople() {
  const profiles = state.profiles;
  if (state.errors.profiles) {
    el('peopleTable').innerHTML = '<div class="empty-state">Cannot read profiles directory. Check RLS and SELECT grants for system_admin.</div>';
    return;
  }
  if (!profiles.length) { el('peopleTable').innerHTML='<div class="empty-state">No profiles visible.</div>';return; }
  const rows = profiles.map(p => `<tr><td><div class="report-title">${safe(p.full_name || 'Unnamed profile')}</div><div class="subcell">${safe(short(p.id))}</div></td><td><span class="status-pill assigned">${safe(prettyRole(p.role))}</span></td><td>${safe(p.building || '—')}</td><td>${safe(p.room_number || '—')}</td><td>${safe(niceDate(p.created_at))}</td></tr>`).join('');
  el('peopleTable').innerHTML=`<table class="data-table"><thead><tr><th>USER</th><th>ROLE</th><th>BUILDING</th><th>ROOM</th><th>CREATED</th></tr></thead><tbody>${rows}</tbody></table>`;
}
function changeView(view) {
  if (!viewNames[view]) return;
  state.currentView = view;
  for (const name of Object.keys(viewNames)) show(el(`${name}View`), name===view);
  document.querySelectorAll('[data-view]').forEach(button => button.classList.toggle('active', button.dataset.view===view));
  el('pageCrumb').textContent = viewNames[view];
  window.scrollTo({top:0,behavior:'smooth'});
}
function openAssign(id) {
  const r=state.reports.find(x=>x.id===Number(id));
  if (!r || r.status!=='new' || r.assigned_to) { toast('This report is no longer available for assignment.', 'error'); return; }
  const staff=state.profiles.filter(p=>p.role==='maintenance_staff');
  if (!staff.length) { toast('No staff profiles visible to the admin. Check profiles SELECT RLS.', 'error'); return; }
  state.assignReportId=r.id;
  el('assignDialogTitle').textContent=`Assign report #${r.id}`;
  el('assignDialogDescription').textContent=r.title;
  const select=el('staffSelect');
  select.replaceChildren();
  staff.forEach(p => {
    const option=document.createElement('option');
    option.value=p.id;
    option.textContent=`${p.full_name?.trim()||'Maintenance staff'} (${p.id.slice(0,8)}…)`;
    select.append(option);
  });
  errorBox('assignError','');
  el('assignDialog').showModal();
}
async function doAssign(event) {
  event.preventDefault();
  if (!state.assignReportId || !state.admin) return;
  const btn=el('confirmAssign');
  btn.disabled=true;
  errorBox('assignError','');
  try {
    const { data, error }=await state.client.rpc('assign_maintenance_report', {
      p_report_id:state.assignReportId,
      p_staff_id:el('staffSelect').value,
    });
    if (error) throw error;
    if (data!==true) throw new Error('The report was not assigned. It may have been claimed or assigned already.');
    el('assignDialog').close();
    toast(`Report #${state.assignReportId} assigned. Staff can now claim it.`);
    await loadAll();
  } catch(err) {
    errorBox('assignError',`${err.message||err}${err.code?` (${err.code})`:''}`);
  } finally { btn.disabled=false; }
}

el('setupForm').addEventListener('submit', async e => {
  e.preventDefault();
  errorBox('setupError','');
  try {
    const cfg=checkConnection(el('projectUrl').value.trim(),el('publishableKey').value.trim());
    // Changing the connection discards the previous session and configuration.
    const old = state.client;
    if (old) { try { await old.auth.signOut(); } catch { /* may be offline */ } }
    localStorage.setItem(STORAGE_KEY,JSON.stringify(cfg));
    makeClient(cfg);
    el('password').value='';
    screen('auth');
  } catch(err) { errorBox('setupError',err.message || String(err)); }
});
el('editConnection').addEventListener('click', async () => {
  if (state.client) { try { await state.client.auth.signOut(); } catch {} }
  localStorage.removeItem(STORAGE_KEY);
  state.client=null;state.admin=null;state.profile=null;
  el('publishableKey').value='';
  screen('setup');
});
el('loginForm').addEventListener('submit', async e => {
  e.preventDefault();
  errorBox('authError','');
  const btn=el('loginSubmit');btn.disabled=true;
  try {
    const {error}=await state.client.auth.signInWithPassword({ email:el('email').value.trim(),password:el('password').value });
    if (error) throw error;
    el('password').value='';
    await guardAndLoad();
  } catch(err) { errorBox('authError',err.message||String(err)); }
  finally {btn.disabled=false;}
});
el('logoutButton').addEventListener('click',async () => {
  try { await state.client.auth.signOut(); screen('auth'); toast('Signed out successfully.'); }
  catch(err) { toast(`Sign-out failed: ${err.message||err}`,'error'); }
});
el('refreshButton').addEventListener('click',loadAll);
el('searchReports').addEventListener('input',renderReports);
el('statusFilter').addEventListener('change',renderReports);
document.addEventListener('click',e=>{
  const nav=e.target.closest('[data-view]');
  if (nav) changeView(nav.dataset.view);
  const go=e.target.closest('[data-go]');
  if (go) changeView(go.dataset.go);
  const assign=e.target.closest('[data-assign]');
  if (assign) openAssign(assign.dataset.assign);
});
el('assignForm').addEventListener('submit',doAssign);
el('cancelAssign').addEventListener('click',()=>el('assignDialog').close());

init();
