// FixMate TASKS #38/#39/#40/#41 — browser role workflows on local Supabase.
// Intended for GitHub Actions only. Uses public anon key and fresh synthetic
// users from local_supabase_api_smoke.sh. Never opens a hosted production URL.
'use strict';
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const API = 'http://127.0.0.1:54321';
const APP = 'http://127.0.0.1:5500';
const KEY = process.env.SUPABASE_ANON_KEY;
const PASSWORD = 'LocalSmoke-Only-Password-2026!';
if (!KEY) throw Error('Missing local Supabase anonymous key.');

async function apiLogin(email) {
  const response = await fetch(API + '/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { 'apikey': KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: PASSWORD }),
  });
  const raw = await response.text();
  assert.equal(response.status, 200, raw);
  return JSON.parse(raw).access_token;
}
async function apiReq(path, token, options = {}) {
  const response = await fetch(API + path, {
    ...options,
    headers: {
      apikey: KEY,
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(options.headers || {}),
    },
  });
  const data = await response.text();
  assert.ok(response.ok, path + ' HTTP ' + response.status + ': ' + data);
  return data ? JSON.parse(data) : null;
}
async function fixture() {
  const token = await apiLogin('resident.a.fixmate@example.com');
  const categories = await apiReq('/rest/v1/maintenance_categories?select=id&name=eq.Plumbing', token);
  const profiles = await apiReq('/rest/v1/profiles?select=id,role', token);
  assert.equal(profiles[0].role, 'resident');
  const owner = profiles[0].id;
  async function addReport(title) {
    const rows = await apiReq('/rest/v1/maintenance_reports?select=id,title,status', token, {
      method: 'POST',
      body: JSON.stringify({
        resident_id: owner, category_id: categories[0].id,
        title, description: 'Browser test report', location: 'Room 105', status: 'new'
      }),
    });
    assert.equal(rows.length,1);
    return rows[0].id;
  }
  const staffReport = await addReport('BROWSER_STAFF_CLAIM_TEST');
  const moderatorReport = await addReport('BROWSER_MOD_REVIEW_TEST');
  await addReport('BROWSER_ADMIN_REPORT_TEST');

  // Original local image; never access existing private Supabase assets.
  const photo = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2l9mYAAAAASUVORK5CYII=', 'base64');
  const storagePath = owner + '/' + moderatorReport + '/browser-image.png';
  const upload = await fetch(API + '/storage/v1/object/report-photos/' + storagePath, {
    method: 'POST',
    headers: {apikey: KEY, Authorization:'Bearer ' + token, 'Content-Type':'image/png'},
    body: photo,
  });
  assert.ok(upload.status===200 || upload.status===201,
    'Could not upload photo: HTTP '+upload.status+' '+await upload.text());
  await apiReq('/rest/v1/report_attachments',token,{
    method:'POST',body:JSON.stringify({report_id:moderatorReport,uploaded_by:owner,storage_path:storagePath}),
  });
  return { staffReport, moderatorReport, owner, token };
}

async function login(browser, email) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(APP + '/index.html',{waitUntil:'domcontentloaded'});
  await page.evaluate(({url,key}) => {
    localStorage.setItem('fixmate_admin_public_connection_v1', JSON.stringify({url,key}));
  },{url:API,key:KEY});
  await page.reload({waitUntil:'domcontentloaded'});
  await page.locator('#authScreen').waitFor({state:'visible',timeout:30000});
  await page.locator('#email').fill(email);
  await page.locator('#password').fill(PASSWORD);
  await page.locator('#loginSubmit').click();
  return { context,page,errors };
}

async function assertStaff(browser,id){
  const {context,page,errors}=await login(browser,'staff.fixmate@example.com');
  try{
    await page.waitForURL('**/staff.html',{timeout:25000});
    await page.locator('#workspace').waitFor({state:'visible',timeout:20000});
    const card=page.locator('article.report').filter({hasText:'BROWSER_STAFF_CLAIM_TEST'});
    await card.locator('button[data-action="claim"]').click();
    await page.locator('#message').getByText('Claimed report #'+id,{exact:false}).waitFor({timeout:15000});
    await page.locator('#myJobsTab').click();
    const own=page.locator('article.report').filter({hasText:'BROWSER_STAFF_CLAIM_TEST'});
    await own.locator('button[data-action="resolve"]').click();
    await page.locator('#message').getByText('Resolved report #'+id,{exact:false}).waitFor({timeout:15000});
    await page.goto(APP+'/moderator.html');
    await page.locator('#loading').getByText('Access denied',{exact:false}).waitFor({timeout:15000});
    assert.equal(errors.length,0,JSON.stringify(errors));
    console.log('PASS staff: role redirect, claim, resolve and moderator denial');
  }finally{await context.close();}
}
async function assertModerator(browser,id){
  const {context,page,errors}=await login(browser,'moderator.fixmate@example.com');
  try{
    await page.waitForURL('**/moderator.html',{timeout:25000});
    await page.locator('#workspace').waitFor({state:'visible',timeout:20000});
    const card=page.locator('article.report').filter({hasText:'BROWSER_MOD_REVIEW_TEST'});
    await card.locator('button[data-photo]').click();
    await page.locator('#previewImage').waitFor({state:'visible',timeout:15000});
    await page.locator('#closePreview').click();
    await card.locator('button[data-review]').click();
    await page.locator('#outcome').selectOption('duplicate');
    await page.locator('#reason').fill('Duplicate submitted as a browser E2E test');
    await page.locator('#submitReview').click();
    await page.locator('#message').getByText('Review saved for report #'+id,{exact:false}).waitFor({timeout:15000});
    await page.locator('#filter').selectOption('reviewed');
    await page.locator('article.report').filter({hasText:'BROWSER_MOD_REVIEW_TEST'}).waitFor({timeout:15000});
    assert.equal(errors.length,0,JSON.stringify(errors));
    console.log('PASS moderator: sign-in redirect, private photo, persisted review');
  }finally{await context.close();}
}
async function assertAdmin(browser){
  const {context,page,errors}=await login(browser,'admin.fixmate@example.com');
  try{
    await page.locator('#dashboard').waitFor({state:'visible',timeout:30000});
    await page.locator('#totalReports').waitFor({state:'visible'});
    await page.locator('[data-view="reports"]').first().click();
    await page.locator('#allReports').getByText('BROWSER_ADMIN_REPORT_TEST',{exact:false}).waitFor({timeout:15000});
    assert.equal(errors.length,0,JSON.stringify(errors));
    console.log('PASS admin: sign-in, dashboard, all reports list');
  }finally{await context.close();}
}
async function assertRejectServerSideApiKey(browser) {
  const context = await browser.newContext();
  const page = await context.newPage();
  try {
    await page.goto(APP+'/index.html',{waitUntil:'domcontentloaded'});
    const payload = Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url');
    const legacyServiceRoleJwt = 'eyJhbGciOiJIUzI1NiJ9.' + payload + '.dummy_signature';
    await page.evaluate(({url,key}) => {
      localStorage.setItem('fixmate_admin_public_connection_v1', JSON.stringify({url,key}));
    },{url:API,key:legacyServiceRoleJwt});
    await page.reload({waitUntil:'domcontentloaded'});
    await page.locator('#setupScreen').waitFor({state:'visible',timeout:15000});
    await page.locator('#setupError').getByText('Service-role',{exact:false})
      .waitFor({timeout:15000});

    // Modern secret keys must also fail locally, before any network request.
    await page.evaluate((url) => {
      localStorage.setItem('fixmate_admin_public_connection_v1',
        JSON.stringify({url,key:'sb_secret_ci_only_do_not_use'}));
    },API);
    await page.reload({waitUntil:'domcontentloaded'});
    await page.locator('#setupError').getByText('Service-role',{exact:false})
      .waitFor({timeout:15000});
    console.log('PASS security: legacy service_role JWT and sb_secret keys rejected');
  }finally{await context.close();}
}

async function assertResidentDenied(browser){
  const {context,page,errors}=await login(browser,'resident.b.fixmate@example.com');
  try{
    await page.locator('#authError').getByText('Access denied',{exact:false}).waitFor({timeout:15000});
    assert.equal(await page.locator('#dashboard').isVisible(),false);
    assert.equal(errors.length,0,JSON.stringify(errors));
    console.log('PASS resident: cannot enter privileged web workspace');
  }finally{await context.close();}
}
(async ()=>{
  const {staffReport,moderatorReport,token}=await fixture();
  const browser=await chromium.launch({headless:true});
  try{
    await assertStaff(browser,staffReport);
    await assertModerator(browser,moderatorReport);
    await assertAdmin(browser);
    await assertResidentDenied(browser);
    await assertRejectServerSideApiKey(browser);
    const rows=await apiReq('/rest/v1/maintenance_reports?select=status&id=eq.'+staffReport,token);
    assert.equal(rows[0].status,'resolved');
    console.log('PASS all browser-role acceptance checks against isolated Supabase');
  }finally{await browser.close();}
})().catch(err=>{console.error(err);process.exitCode=1;});
