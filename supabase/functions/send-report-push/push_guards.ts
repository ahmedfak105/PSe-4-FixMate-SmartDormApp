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


/**
 * Prefer current Supabase sb_secret keys. Older disposable Supabase CLI
 * stacks may still inject only the legacy service_role JWT.
 * Bad or incomplete current-key configuration fails closed.
 */
export function selectSupabaseServiceKey(
  secretKeysJson: string | null,
  legacyServiceRoleKey: string | null,
): string {
  if (secretKeysJson) {
    let keys: unknown;
    try {
      keys = JSON.parse(secretKeysJson);
    } catch (_) {
      throw Error('Invalid Supabase secret-key configuration');
    }
    const key = typeof keys === 'object' && keys !== null &&
      !Array.isArray(keys)
      ? (keys as Record<string, unknown>).default
      : undefined;
    if (typeof key !== 'string' || !key.startsWith('sb_secret_') ||
        key.length <= 'sb_secret_'.length) {
      throw Error('Supabase default secret key is missing or invalid');
    }
    return key;
  }
  if (legacyServiceRoleKey && isLegacyServiceRoleJwt(legacyServiceRoleKey)) {
    return legacyServiceRoleKey;
  }
  throw Error('Missing privileged Supabase server credential');
}

function isLegacyServiceRoleJwt(value: string): boolean {
  return /^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$/.test(value);
}

/**
 * New opaque API keys must be passed ONLY as apikey. Passing them as
 * Authorization: Bearer causes an Invalid JWT response.
 */
export function privilegedSupabaseRestHeaders(key: string): Record<string, string> {
  const common = { apikey: key, 'Content-Type': 'application/json' };
  if (key.startsWith('sb_secret_') && key.length > 'sb_secret_'.length) {
    return common;
  }
  if (isLegacyServiceRoleJwt(key)) {
    return { ...common, Authorization: `Bearer ${key}` };
  }
  throw Error('Invalid privileged Supabase server credential');
}
