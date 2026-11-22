import test from 'node:test';
import assert from 'node:assert/strict';
import {
  fcmTokenIsUnregistered,
  matchesPushWebhookSecret,
  privilegedSupabaseRestHeaders,
  selectSupabaseServiceKey,
} from './push_guards.ts';

const strongSecret = 'fixmate-strong-webhook-secret-0123456789';
const unregistered = {
  error: {
    code: 404,
    status: 'NOT_FOUND',
    details: [
      { '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' },
    ],
  },
};

test('webhook rejects missing, short and different secrets', () => {
  assert.equal(matchesPushWebhookSecret(null, strongSecret), false);
  assert.equal(matchesPushWebhookSecret(strongSecret, 'short'), false);
  assert.equal(matchesPushWebhookSecret('short', 'short'), false);
  assert.equal(matchesPushWebhookSecret(`${strongSecret}x`, strongSecret), false);
  assert.equal(matchesPushWebhookSecret(strongSecret.slice(0, -1), strongSecret), false);
  assert.equal(matchesPushWebhookSecret(`X${strongSecret.slice(1)}`, strongSecret), false);
});

test('webhook permits an exact long UTF-8 secret', () => {
  assert.equal(matchesPushWebhookSecret(strongSecret, strongSecret), true);
  const utf8Secret = '🔐'.repeat(32);
  assert.equal(matchesPushWebhookSecret(utf8Secret, utf8Secret), true);
  assert.equal(matchesPushWebhookSecret('🔒'.repeat(32), utf8Secret), false);
});

test('FCM UNREGISTERED is terminal only with matching HTTP 404 and typed error', () => {
  assert.equal(fcmTokenIsUnregistered(404, unregistered), true);
  assert.equal(fcmTokenIsUnregistered(400, unregistered), false);
  assert.equal(fcmTokenIsUnregistered(503, unregistered), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { message: 'UNREGISTERED' } }), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { details: [{ errorCode: 'UNREGISTERED' }] } }), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { details: [{ '@type': 'bad', errorCode: 'UNREGISTERED' }] } }), false);
});

test('transient, malformed and project-level FCM errors retain device tokens', () => {
  assert.equal(fcmTokenIsUnregistered(404, null), false);
  assert.equal(fcmTokenIsUnregistered(404, {}), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { details: null } }), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { details: ['UNREGISTERED'] } }), false);
  assert.equal(fcmTokenIsUnregistered(404, { error: { details: [{ '@type': 'type.googleapis.com/google.rpc.ErrorInfo', reason: 'NOT_FOUND' }] } }), false);
});


test('new Supabase secret takes precedence and never appears in Bearer auth', () => {
  const opaque = 'sb_secret_nonproduction_local_fixture';
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature';
  const selected = selectSupabaseServiceKey(JSON.stringify({ default: opaque }), jwt);
  assert.equal(selected, opaque);
  const headers = privilegedSupabaseRestHeaders(selected);
  assert.equal(headers.apikey, opaque);
  assert.equal(Object.hasOwn(headers, 'Authorization'), false);
  assert.equal(headers['Content-Type'], 'application/json');
});

test('legacy local Supabase CLI compatibility uses service-role JWT only', () => {
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature';
  assert.equal(selectSupabaseServiceKey(null, jwt), jwt);
  assert.deepEqual(privilegedSupabaseRestHeaders(jwt), {
    apikey: jwt,
    'Content-Type': 'application/json',
    Authorization: `Bearer ${jwt}`,
  });
});

test('malformed and missing server credentials fail closed', () => {
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature';
  assert.throws(() => selectSupabaseServiceKey(null, null));
  assert.throws(() => selectSupabaseServiceKey('{', jwt));
  assert.throws(() => selectSupabaseServiceKey('{}', jwt));
  assert.throws(() => selectSupabaseServiceKey('{"default":"sb_publishable_public"}', jwt));
  assert.throws(() => selectSupabaseServiceKey('[]', jwt));
  assert.throws(() => selectSupabaseServiceKey('{"default":123}', jwt));
  assert.throws(() => selectSupabaseServiceKey(null, 'plain-bad-key'));
  assert.throws(() => privilegedSupabaseRestHeaders('sb_publishable_public'));
});
