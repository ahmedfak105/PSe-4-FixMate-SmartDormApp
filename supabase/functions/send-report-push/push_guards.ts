// Security-critical pure helpers for the FixMate FCM dispatcher.
// No runtime secrets or network access; safe to unit-test independently.

const encoder = new TextEncoder();

/** Compare two small webhook secrets without early exit on the first mismatch. */
export function matchesPushWebhookSecret(
  supplied: string | null,
  expected: string,
): boolean {
  if (!supplied || expected.length < 32) return false;
  const a = encoder.encode(supplied);
  const b = encoder.encode(expected);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return difference === 0;
}

/** Delete an FCM registration only after a structured UNREGISTERED response. */
export function fcmTokenIsUnregistered(status: number, payload: unknown): boolean {
  if (status !== 404 || typeof payload !== 'object' || payload === null) {
    return false;
  }
  const error = (payload as { error?: unknown }).error;
  if (typeof error !== 'object' || error === null) return false;
  const details = (error as { details?: unknown }).details;
  if (!Array.isArray(details)) return false;
  return details.some((detail: unknown) => {
    if (typeof detail !== 'object' || detail === null) return false;
    const typed = detail as { '@type'?: unknown; errorCode?: unknown };
    return typed['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError' &&
      typed.errorCode === 'UNREGISTERED';
  });
}
