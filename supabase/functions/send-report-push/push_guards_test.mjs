import test from 'node:test';
import assert from 'node:assert/strict';
import { fcmTokenIsUnregistered, matchesPushWebhookSecret } from './push_guards.ts';

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
