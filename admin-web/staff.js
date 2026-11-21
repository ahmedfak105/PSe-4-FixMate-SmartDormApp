/* FixMate maintenance staff web workspace.
 * Uses the same public connection/session as admin-web/app.js.
 * Authorization is enforced by Supabase RLS and role-checked RPCs.
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


const CONNECTION_KEY = 'fixmate_admin_public_connection_v1';
const SESSION_KEY = 'fixmate-admin-session';
const state = {
  client: null,
  userId: null,
  rows: [],
  history: new Map(),
  categories: new Map(),
  tab: 'available',
  busy: false,
};

const element = id => document.getElementById(id);
const htmlEscape = value => String(value ?? '').replace(/[&<>"']/g, character =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const formatTime = value => value ? new Date(value).toLocaleString('en-GB') : 'Not recorded';
const setMessage = (message, error = false) => {
  const node = element('message');
  node.textContent = message || '';
  node.classList.toggle('error', error);
  node.hidden = !message;
};

function eligibleForClaim(report) {
  return report.status === 'new' &&
    (report.assigned_to === null || report.assigned_to === state.userId);
}
function mine(report) {
  return report.assigned_to === state.userId;
}
function render() {
  const available = state.rows.filter(eligibleForClaim);
  const assigned = state.rows.filter(mine);
  const displayed = state.tab === 'available' ? available : assigned;
  element('availableTab').textContent = 'Available (' + available.length + ')';
  element('myJobsTab').textContent = 'My Jobs (' + assigned.length + ')';
  element('availableTab').setAttribute('aria-selected', String(state.tab === 'available'));
  element('myJobsTab').setAttribute('aria-selected', String(state.tab === 'mine'));
  element('availableTab').classList.toggle('selected', state.tab === 'available');
  element('myJobsTab').classList.toggle('selected', state.tab === 'mine');
  element('list').innerHTML = displayed.length ? displayed.map(report => {
    const action = eligibleForClaim(report) ?
      '<button type="button" data-action="claim" data-id="' + report.id + '">Claim report</button>' :
      report.status === 'in_progress' && mine(report) ?
        '<button type="button" data-action="resolve" data-id="' + report.id + '">Mark resolved</button>' :
        '<span class="muted">No status action available</span>';
    const updatedAt = state.history.get(report.id);
    return '<article class="report">' +
      '<div class="report-head"><h2>#' + report.id + ' · ' + htmlEscape(report.title) +
      '</h2><span class="chip">' + htmlEscape(report.status.replaceAll('_', ' ')) + '</span></div>' +
      '<dl><dt>Category</dt><dd>' + htmlEscape(state.categories.get(report.category_id) ?? ('#' + report.category_id)) + '</dd>' +
      '<dt>Location</dt><dd>' + htmlEscape(report.location || 'Not provided') + '</dd>' +
      '<dt>Submitted</dt><dd>' + htmlEscape(formatTime(report.created_at)) + '</dd>' +
      '<dt>Last status update</dt><dd>' + htmlEscape(formatTime(updatedAt)) + '</dd></dl>' +
      '<p>' + htmlEscape(report.description || 'No description') + '</p>' +
      '<div class="action-row">' + action + '</div></article>';
  }).join('') : '<p class="empty">No ' + (state.tab === 'available' ? 'available reports' : 'assigned jobs') + ' right now.</p>';
  element('list').querySelectorAll('button[data-action]').forEach(button => { button.disabled = state.busy; });
}

async function loadReports() {
  if (state.busy) return;
  state.busy = true;
  element('refresh').disabled = true;
  setMessage('');
  try {
    const [reports, categories, history] = await Promise.all([
      state.client.from('maintenance_reports')
        .select('id,category_id,title,description,location,status,assigned_to,created_at')
        .order('created_at', { ascending: false }).limit(500),
      state.client.from('maintenance_categories').select('id,name').limit(200),
      state.client.from('report_status_history')
        .select('report_id,changed_at').order('changed_at', { ascending: false }).limit(1000),
    ]);
    if (reports.error) throw reports.error;
    state.rows = reports.data || [];
    if (!categories.error) {
      state.categories = new Map((categories.data || []).map(row => [row.id, row.name]));
    }
    if (!history.error) {
      state.history = new Map();
      for (const row of history.data || []) {
        if (!state.history.has(row.report_id)) state.history.set(row.report_id, row.changed_at);
      }
    } else {
      state.history = new Map();
      setMessage('Report statuses loaded. Update timestamps are not available for this account.', true);
    }
    render();
  } catch (error) {
    setMessage('Could not load reports: ' + (error.message || String(error)), true);
  } finally {
    state.busy = false;
    element('refresh').disabled = false;
    render();
  }
}

async function performAction(action, reportId) {
  if (state.busy || !Number.isSafeInteger(reportId) || reportId <= 0) return;
  const report = state.rows.find(item => item.id === reportId);
  if (!report || (action === 'claim' && !eligibleForClaim(report)) ||
    (action === 'resolve' && !(mine(report) && report.status === 'in_progress'))) return;
  state.busy = true;
  render();
  setMessage('');
  const functionName = action === 'claim' ? 'claim_maintenance_report' : 'resolve_maintenance_report';
  let notice = '';
  let isError = false;
  try {
    const { data, error } = await state.client.rpc(functionName, { p_report_id: reportId });
    if (error) throw error;
    if (data !== true) {
      notice = 'Report #' + reportId + ' was already taken or changed. The list has been refreshed.';
      isError = true;
    } else {
      notice = action === 'claim' ?
        'Claimed report #' + reportId + '. You can now find it under My Jobs.' :
        'Resolved report #' + reportId + '.';
      if (action === 'claim') state.tab = 'mine';
    }
  } catch (error) {
    isError = true;
    notice = 'Could not update report #' + reportId + ': ' + (error.message || String(error));
  } finally {
    state.busy = false;
    await loadReports();
    setMessage(notice, isError);
  }
}

async function initialize() {
  try {
    const config = JSON.parse(localStorage.getItem(CONNECTION_KEY) || 'null');
    const parsed = new URL(config?.url || '');
    const hosted = parsed.protocol === 'https:' && parsed.hostname.endsWith('.supabase.co');
    const devApi = ['localhost', '127.0.0.1'].includes(window.location.hostname) &&
      parsed.protocol === 'http:' &&
      ['localhost', '127.0.0.1'].includes(parsed.hostname) &&
      parsed.port === '54321';
    if (!isSafePublicApiKey(config?.key) || !(hosted || devApi)) {
      throw new Error('Open the FixMate sign-in page and connect to an authorized Supabase project first.');
    }
    if (!window.supabase?.createClient) throw new Error('Supabase library did not load.');
    state.client = window.supabase.createClient(config.url, config.key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: SESSION_KEY },
    });
    const { data: userResult, error: userError } = await state.client.auth.getUser();
    if (userError || !userResult?.user) throw new Error('Please sign in from the main FixMate page.');
    const { data: profile, error: profileError } = await state.client.from('profiles')
      .select('id,full_name,role').eq('id', userResult.user.id).maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.role !== 'maintenance_staff')
      throw new Error('Access denied. This workspace is only for maintenance_staff accounts.');
    state.userId = userResult.user.id;
    element('staffName').textContent = profile.full_name || 'Maintenance staff';
    element('workspace').hidden = false;
    element('loading').hidden = true;
    await loadReports();
  } catch (error) {
    element('loading').textContent = error.message || String(error);
  }
}

element('availableTab').addEventListener('click', () => { state.tab = 'available'; render(); });
element('myJobsTab').addEventListener('click', () => { state.tab = 'mine'; render(); });
element('refresh').addEventListener('click', loadReports);
element('list').addEventListener('click', event => {
  const button = event.target.closest('button[data-action]');
  if (button) performAction(button.dataset.action, Number(button.dataset.id));
});
element('logout').addEventListener('click', async () => {
  if (state.client) await state.client.auth.signOut();
  window.location.assign('index.html');
});
initialize();
