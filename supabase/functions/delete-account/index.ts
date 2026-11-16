import { createClient } from "@supabase/supabase-js";
import { FROM_DEFAULT, sendAccountEmail } from "../_shared/account_email.ts";
import { appleConfigFromEnv, revokeAppleAccess } from "../_shared/apple_auth.ts";
import { verifyAppleIdToken } from "../_shared/apple_id_token.ts";
import { verifyGoogleIdToken } from "../_shared/google_id_token.ts";
import { type DeleteDeps, handleDeleteAccount } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(url, serviceKey, noSession);
const tokenDeps = { fetch, now: () => Date.now() / 1000 };
const BUNDLE_ID = "com.cyberazeez.spendingtracker";

/** True when [userId] signs in with [provider] as the provider's account [sub]. */
async function hasIdentity(userId: string, provider: string, sub: string): Promise<boolean> {
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data.user) return false;
  return (data.user.identities ?? []).some((i) =>
    i.provider === provider && (i.id === sub || i.identity_data?.sub === sub)
  );
}

const deps: DeleteDeps = {
  async getUser(authorization) {
    const asUser = createClient(url, anonKey, {
      ...noSession,
      global: { headers: { Authorization: authorization } },
    });
    const { data, error } = await asUser.auth.getUser();
    if (error || !data.user) return null;
    // An Apple account can hide its email, so it may be empty; the password path still needs one.
    const providers = (data.user.app_metadata?.providers as string[] | undefined) ?? ["email"];
    return { id: data.user.id, email: data.user.email ?? "", providers };
  },
  async verifyPassword(email, password) {
    // A throwaway client: the session this creates is never stored or used.
    const probe = createClient(url, anonKey, noSession);
    const { error } = await probe.auth.signInWithPassword({ email, password });
    return !error;
  },
  // Apple and Google proofs are read, never used to sign in: signing in would create an account for an unknown
  // Apple ID or Google account, or start a session for someone else's (which also cancels their pending deletion).
  // The token's account must then be this user's own Apple or Google sign-in.
  async verifyApple(idToken, nonce, userId) {
    // Native Sign in with Apple issues the token to the app's bundle ID, and the app has no web Apple sign-in.
    const sub = await verifyAppleIdToken(tokenDeps, idToken, nonce, [BUNDLE_ID]);
    return sub !== null && await hasIdentity(userId, "apple", sub);
  },
  async verifyGoogle(idToken, userId) {
    const sub = await verifyGoogleIdToken(tokenDeps, idToken);
    return sub !== null && await hasIdentity(userId, "google", sub);
  },
  async revokeApple(authorizationCode) {
    const cfg = appleConfigFromEnv((k) => Deno.env.get(k));
    if (!cfg) return false;
    return await revokeAppleAccess({ fetch }, cfg, authorizationCode);
  },
  async requestDeletion(userId) {
    const { error } = await admin.rpc("request_account_deletion", { p_user: userId });
    if (error) throw new Error("delete_failed");
  },
  async notifyDeletion(email) {
    await sendAccountEmail(
      {
        fetch,
        apiKey: Deno.env.get("RESEND_API_KEY"),
        from: Deno.env.get("EMAIL_FROM") ?? FROM_DEFAULT,
      },
      email,
      "deletion_requested",
    );
  },
  async bumpRateLimit(userId) {
    const { data, error } = await admin.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "delete_account",
      p_window: "day",
    });
    if (error) throw new Error("rate_limit_failed");
    return data as number;
  },
};

Deno.serve(async (req) => {
  try {
    return await handleDeleteAccount(req, deps);
  } catch (e) {
    console.error("delete_account_failed", e instanceof Error ? e.message : "unknown");
    return new Response(JSON.stringify({ error: "server_error" }), {
      status: 500,
      headers: { "content-type": "application/json", "cache-control": "no-store" },
    });
  }
});
