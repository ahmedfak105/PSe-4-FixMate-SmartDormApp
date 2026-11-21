/* FixMate Moderator Review — TASK #39 / F03.2.
 * Requires the PROPOSED_MODERATOR_REVIEW_MIGRATION.sql backend migration
 * to be reviewed, tested, and explicitly applied to the target Supabase DB.
 * Never write moderation decisions directly from the browser.
 */
'use strict';

const CONFIG_KEY = 'fixmate_admin_public_connection_v1';
const SESSION_KEY = 'fixmate-admin-session';
const state = {
  client: null,
  rows: [],
  categories: new Map(),
  decisions: new Map(),
  attachments: new Map(),
  reportId: null,
  busy: false,
  activePhotoUrl: null,
};
const get = id => document.getElementById(id);
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
const displayDate = value => value ? new Date(value).toLocaleString('en-GB') : '—';

function message(text, isError = false) {
  const node = get('message');
  node.textContent = text || '';
  node.classList.toggle('error', isError);
  node.hidden = !text;
}
function showReviewError(text) {
  const node = get('reviewError');
  node.textContent = text;
  node.hidden = !text;
}
function reviewable(report) {
  return report.status === 'new' &&
    report.assigned_to == null && !state.decisions.has(report.id);
}
function decisionLabel(value) {
  return ({ valid: 'Valid', duplicate: 'Duplicate', inappropriate: 'Inappropriate' })[value] || value;
}
function render() {
  const filter = get('filter').value;
  const rows = state.rows.filter(report => {
    if (filter === 'pending') return reviewable(report);
    if (filter === 'reviewed') return state.decisions.has(report.id);
    return true;
  });
  get('counter').textContent = rows.length + ' reports';
  get('reportList').innerHTML = rows.length ? rows.map(report => {
    const decision = state.decisions.get(report.id);
    const photoList = state.attachments.get(report.id) || [];
    const status = decision
      ? '<span class="chip ' + (decision.outcome === 'valid' ? '' : 'rejected') + '">' +
          escapeHtml(decisionLabel(decision.outcome)) + '</span>'
      : '<span class="chip">Awaiting review</span>';
    const reviewText = decision
      ? '<p class="muted">Reviewed ' + escapeHtml(displayDate(decision.reviewed_at)) +
          (decision.reason ? ' · ' + escapeHtml(decision.reason) : '') + '</p>'
      : (report.assigned_to ? '<p class="muted">Already assigned; cannot be reviewed now.</p>' : '');
    const photos = photoList.map(item =>
      '<button class="secondary" type="button" data-photo="' + escapeHtml(item.id) + '">View photo</button>'
    ).join(' ');
    const buttons = reviewable(report) ?
      '<button type="button" data-review="' + report.id + '">Review report</button>' :
      '<span class="muted">Decision not available</span>';
    return '<article class="report">' +
      '<div class="report-head"><h2>#' + report.id + ' · ' + escapeHtml(report.title) + '</h2>' + status + '</div>' +
      '<dl><dt>Category</dt><dd>' + escapeHtml(state.categories.get(report.category_id) || ('Category #' + report.category_id)) +
      '</dd><dt>Location</dt><dd>' + escapeHtml(report.location || 'Not provided') +
      '</dd><dt>Submitted</dt><dd>' + escapeHtml(displayDate(report.created_at)) +
      '</dd><dt>Maintenance status</dt><dd>' + escapeHtml(report.status.replaceAll('_', ' ')) +
      '</dd></dl><p>' + escapeHtml(report.description || 'No description') + '</p>' + reviewText +
      '<div class="actions">' + buttons + ' ' + photos + '</div></article>';
  }).join('') : '<p class="empty">There are no reports in this review category.</p>';
  get('reportList').querySelectorAll('button').forEach(button => { button.disabled = state.busy; });
}
async function refresh() {
  if (!state.client || state.busy) return;
  state.busy = true;
  get('refresh').disabled = true;
  message('');
  try {
    const { data: reports, error: reportError } = await state.client
      .from('maintenance_reports')
      .select('id,title,description,location,status,assigned_to,category_id,created_at')
      .eq('status', 'new').order('created_at', { ascending: false }).limit(500);
    if (reportError) throw reportError;
    const ids = (reports || []).map(report => report.id);
    const categoriesPromise = state.client.from('maintenance_categories')
      .select('id,name').limit(200);
    const reviewsPromise = state.client.from('report_reviews')
      .select('report_id,outcome,reason,reviewed_at,reviewer_id')
      .in('report_id', ids.length ? ids : [-1]);
    const photosPromise = state.client.from('report_attachments')
      .select('id,report_id,storage_path').in('report_id', ids.length ? ids : [-1]);
    const [categories, reviews, photos] = await Promise.all([
      categoriesPromise, reviewsPromise, photosPromise,
    ]);
    if (reviews.error) {
      throw new Error('Cannot read report reviews. The moderator database migration may not be installed or its grants/RLS are missing: ' + reviews.error.message);
    }
    if (categories.error) throw categories.error;
    if (photos.error) throw photos.error;
    state.rows = reports || [];
    state.categories = new Map((categories.data || []).map(row => [row.id, row.name]));
    state.decisions = new Map((reviews.data || []).map(row => [row.report_id, row]));
    state.attachments = new Map();
    for (const photo of photos.data || []) {
      const list = state.attachments.get(photo.report_id) || [];
      list.push(photo);
      state.attachments.set(photo.report_id, list);
    }
    render();
  } catch (error) {
    message('Could not refresh moderation reports: ' + (error.message || String(error)), true);
  } finally {
    state.busy = false;
    get('refresh').disabled = false;
  }
}
function openReview(id) {
  const report = state.rows.find(row => row.id === id);
  if (!report || !reviewable(report) || state.busy) return;
  state.reportId = id;
  get('reviewTitle').textContent = 'Review report #' + id;
  get('outcome').value = 'valid';
  get('reason').value = '';
  showReviewError('');
  get('reviewDialog').showModal();
}
async function saveReview(event) {
  event.preventDefault();
  if (state.busy || state.reportId == null) return;
  const outcome = get('outcome').value;
  const reason = get('reason').value.trim();
  if (!['valid', 'duplicate', 'inappropriate'].includes(outcome)) {
    showReviewError('Select a valid review decision.');
    return;
  }
  if (reason.length > 500 || (outcome !== 'valid' && !reason)) {
    showReviewError('A reason of 1–500 characters is required for duplicate or inappropriate reports.');
    return;
  }
  state.busy = true;
  get('submitReview').disabled = true;
  showReviewError('');
  try {
    const id = state.reportId;
    const { data, error } = await state.client.rpc('review_maintenance_report', {
      p_report_id: id, p_outcome: outcome, p_reason: reason,
    });
    if (error) throw error;
    if (data !== true) throw new Error('This report was already reviewed, assigned or updated. Refresh the list.');
    get('reviewDialog').close();
    state.reportId = null;
    state.busy = false;
    await refresh();
    message('Review saved for report #' + id + ': ' + decisionLabel(outcome) + '.');
  } catch (error) {
    showReviewError(error.message || String(error));
  } finally {
    state.busy = false;
    get('submitReview').disabled = false;
    if (!get('reviewDialog').open) render();
  }
}
function closePreview() {
  get('previewDialog').close();
  get('previewImage').hidden = true;
  get('previewImage').removeAttribute('src');
  if (state.activePhotoUrl) URL.revokeObjectURL(state.activePhotoUrl);
  state.activePhotoUrl = null;
}
async function previewPhoto(photoId) {
  const photo = [...state.attachments.values()].flat().find(row => row.id === photoId);
  if (!photo) return;
  get('previewImage').hidden = true;
  get('photoMessage').textContent = 'Loading authorized private photo…';
  get('previewDialog').showModal();
  try {
    const { data, error } = await state.client.storage.from('report-photos').download(photo.storage_path);
    if (error) throw error;
    if (!data || (data.type && !['image/png', 'image/jpeg', 'image/webp'].includes(data.type))) {
      throw new Error('The storage object is not a supported image.');
    }
    if (state.activePhotoUrl) URL.revokeObjectURL(state.activePhotoUrl);
    state.activePhotoUrl = URL.createObjectURL(data);
    get('previewImage').src = state.activePhotoUrl;
    get('previewImage').hidden = false;
    get('photoMessage').textContent = '';
  } catch (error) {
    get('photoMessage').textContent = 'Could not load photo: ' + (error.message || String(error));
  }
}
async function initialize() {
  try {
    const config = JSON.parse(localStorage.getItem(CONFIG_KEY) || 'null');
    const parsed = new URL(config?.url || '');
    const hosted = parsed.protocol === 'https:' && parsed.hostname.endsWith('.supabase.co');
    const devApi = ['localhost', '127.0.0.1'].includes(window.location.hostname) &&
      parsed.protocol === 'http:' &&
      ['localhost', '127.0.0.1'].includes(parsed.hostname) &&
      parsed.port === '54321';
    if (!config || !(hosted || devApi) ||
      !(config.key?.startsWith('sb_publishable_') || config.key?.split('.').length === 3)) {
      throw new Error('Open index.html first and connect with a public Supabase key.');
    }
    if (!window.supabase?.createClient) throw new Error('Supabase JavaScript SDK failed to load.');
    state.client = window.supabase.createClient(config.url, config.key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: SESSION_KEY },
    });
    const { data: userData, error: userError } = await state.client.auth.getUser();
    if (userError || !userData?.user) throw new Error('Please sign in from the main FixMate page first.');
    const { data: profile, error: profileError } = await state.client.from('profiles')
      .select('id,role').eq('id', userData.user.id).maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !['moderator', 'system_admin'].includes(profile.role)) {
      throw new Error('Access denied: only moderator or system_admin accounts can review reports.');
    }
    get('loading').hidden = true;
    get('workspace').hidden = false;
    await refresh();
  } catch (error) {
    get('loading').textContent = error.message || String(error);
  }
}

get('refresh').addEventListener('click', refresh);
get('filter').addEventListener('change', render);
get('reportList').addEventListener('click', event => {
  const review = event.target.closest('[data-review]');
  const photo = event.target.closest('[data-photo]');
  if (review) openReview(Number(review.dataset.review));
  else if (photo) previewPhoto(photo.dataset.photo);
});
get('reviewForm').addEventListener('submit', saveReview);
get('cancelReview').addEventListener('click', () => get('reviewDialog').close());
get('closePreview').addEventListener('click', closePreview);
get('previewDialog').addEventListener('close', () => {
  get('previewImage').removeAttribute('src');
  get('previewImage').hidden = true;
  if (state.activePhotoUrl) URL.revokeObjectURL(state.activePhotoUrl);
  state.activePhotoUrl = null;
});
get('logout').addEventListener('click', async () => {
  if (state.client) await state.client.auth.signOut();
  window.location.assign('index.html');
});
initialize();
