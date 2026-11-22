import { fcmTokenIsUnregistered, matchesPushWebhookSecret } from "./push_guards.ts";

// FixMate F05.2: server-only FCM HTTP v1 sender.
// Deploy only AFTER Release Gate #47, as verify_jwt=false with a strong
// FIXMATE_PUSH_WEBHOOK_SECRET. No user JWT or browser access is accepted.
// Never commit FIREBASE_SERVICE_ACCOUNT_JSON or service_role key.

type PushJob = {
  id: number;
  notification_id: number;
  resident_id: string;
  report_id: number;
  new_status: string;
  token: string;
  attempts: number;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

const encoder = new TextEncoder();
const MAX_BATCH = 10;

function base64url(value: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < value.length; i += 4096) {
    binary += String.fromCharCode(...value.slice(i, i + 4096));
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function encodeJson(value: Record<string, unknown>): string {
  return base64url(encoder.encode(JSON.stringify(value)));
}

function requireConfig(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw Error(`Missing server configuration: ${name}`);
  return value;
}

async function googleAccessToken(account: ServiceAccount): Promise<string> {
  if (!account.private_key.includes("BEGIN PRIVATE KEY") ||
      !account.client_email.includes("@")) {
    throw Error("Invalid Firebase service account");
  }

  const now = Math.floor(Date.now() / 1000);
  const endpoint = "https://oauth2.googleapis.com/token";
  const header = encodeJson({ typ: "JWT", alg: "RS256" });
  const payload = encodeJson({
    iss: account.client_email,
    aud: endpoint,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    iat: now,
    exp: now + 3500,
  });
  const signingInput = `${header}.${payload}`;

  const pkcs8 = Uint8Array.from(
    atob(account.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/g, "")
      .replace(/-----END PRIVATE KEY-----/g, "")
      .replace(/\s/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8", pkcs8,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key,
      encoder.encode(signingInput)),
  );
  const assertion = `${signingInput}.${base64url(signature)}`;
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!response.ok) throw Error(`Google OAuth returned HTTP ${response.status}`);
  const result = await response.json();
  if (typeof result.access_token !== "string") {
    throw Error("Google OAuth returned no access token");
  }
  return result.access_token;
}

function restHeaders(serviceKey: string): HeadersInit {
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };
}

async function rest<T>(
  baseUrl: string, serviceKey: string, path: string,
  method = "GET", payload?: unknown,
): Promise<T> {
  const response = await fetch(`${baseUrl}/rest/v1/${path}`, {
    method,
    headers: {
      ...restHeaders(serviceKey),
      Prefer: "return=representation",
    },
    body: payload === undefined ? undefined : JSON.stringify(payload),
  });
  if (!response.ok) throw Error(`Supabase REST ${method} returned HTTP ${response.status}`);
  const result = await response.json();
  return result as T;
}

async function setJobState(
  baseUrl: string, serviceKey: string, id: number,
  state: "sent" | "pending" | "invalid" | "cancelled" | "failed",
  attempts: number,
): Promise<void> {
  const retryDelay = Math.min(3600, 30 * (2 ** attempts));
  const payload = {
    state,
    sent_at: state === "sent" ? new Date().toISOString() : null,
    next_attempt_at: state === "pending"
      ? new Date(Date.now() + retryDelay * 1000).toISOString()
      : new Date().toISOString(),
    // Never store Firebase tokens, Google OAuth payloads or user data as errors.
    last_error: state === "pending" || state === "failed"
      ? "FCM request failed; consult server metrics"
      : null,
  };
  await rest<unknown>(baseUrl, serviceKey,
    `push_delivery_outbox?id=eq.${id}&state=eq.processing`, "PATCH", payload);
}

async function stillAuthorized(
  baseUrl: string, serviceKey: string, job: PushJob,
): Promise<boolean> {
  const [devices, owners] = await Promise.all([
    rest<Array<{ token: string }>>(baseUrl, serviceKey,
      `push_device_tokens?select=token&user_id=eq.${encodeURIComponent(job.resident_id)}&token=eq.${encodeURIComponent(job.token)}`),
    rest<Array<{ id: string }>>(baseUrl, serviceKey,
      `profiles?select=id&id=eq.${encodeURIComponent(job.resident_id)}&role=eq.resident`),
  ]);
  return devices.length === 1 && owners.length === 1;
}

async function send(
  account: ServiceAccount, oauthToken: string, job: PushJob,
): Promise<"sent" | "invalid" | "retry"> {
  const status = {
    new: "new",
    in_progress: "in progress",
    resolved: "resolved",
  }[job.new_status] ?? "updated";
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${oauthToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: job.token,
          notification: {
            title: "FixMate · Report update",
            body: `Report #${job.report_id} is now ${status}`,
          },
          data: {
            report_id: String(job.report_id),
            status: job.new_status,
          },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (response.ok) return "sent";
  if (response.status === 404) {
    // FCM 404 UNREGISTERED is terminal for an individual device token.
    const error: unknown = await response.json().catch(() => ({}));
    if (fcmTokenIsUnregistered(response.status, error)) return "invalid";
  }
  return "retry";
}

async function deliver(): Promise<Record<string, number>> {
  const baseUrl = requireConfig("SUPABASE_URL");
  const serviceKey = requireConfig("SUPABASE_SERVICE_ROLE_KEY");
  const account = JSON.parse(requireConfig("FIREBASE_SERVICE_ACCOUNT_JSON"))
    as ServiceAccount;
  const expectedProject = requireConfig("FIREBASE_PROJECT_ID");
  if (account.project_id !== expectedProject ||
      !/^[a-z0-9-]{6,63}$/.test(expectedProject)) {
    throw Error("Firebase project ID mismatch");
  }

  // Validate sender credentials BEFORE claiming retryable jobs.
  const oauthToken = await googleAccessToken(account);
  const jobs = await rest<PushJob[]>(
    baseUrl, serviceKey, "rpc/claim_fixmate_push_jobs", "POST",
    { p_batch_size: MAX_BATCH },
  );

  const counts = { claimed: jobs.length, sent: 0, invalid: 0, retries: 0 };
  for (const job of jobs) {
    let state: "sent" | "pending" | "invalid" | "cancelled" | "failed" = "pending";
    try {
      if (!await stillAuthorized(baseUrl, serviceKey, job)) {
        state = "cancelled";
      } else {
        const outcome = await send(account, oauthToken, job);
        if (outcome === "sent") {
          state = "sent";
          counts.sent++;
        } else if (outcome === "invalid") {
          state = "invalid";
          counts.invalid++;
          // Removing the owner token cancels other pending jobs in the DB.
          await rest<unknown>(baseUrl, serviceKey,
            `push_device_tokens?token=eq.${encodeURIComponent(job.token)}&user_id=eq.${encodeURIComponent(job.resident_id)}`,
            "DELETE");
        } else {
          state = job.attempts >= 5 ? "failed" : "pending";
          counts.retries++;
        }
      }
    } catch (_) {
      state = job.attempts >= 5 ? "failed" : "pending";
      counts.retries++;
    }

    // A DB state failure aborts this invocation; an expired lease will make
    // the job retryable. Delivery is at-least-once after a network crash.
    await setJobState(baseUrl, serviceKey, job.id, state, job.attempts);
  }
  return counts;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const expectedSecret = Deno.env.get("FIXMATE_PUSH_WEBHOOK_SECRET") ?? "";
  if (!matchesPushWebhookSecret(request.headers.get("x-fixmate-push-secret"),
    expectedSecret)) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    // Never return device tokens, account IDs, report descriptions or
    // Google access tokens in an HTTP response or log.
    const counts = await deliver();
    return Response.json(counts);
  } catch (_) {
    return Response.json({ error: "Push dispatcher unavailable" },
      { status: 503 });
  }
});
