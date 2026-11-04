import { createClient } from "@supabase/supabase-js";
import { type DeleteDeps, handleDeleteAccount } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(url, serviceKey, noSession);

const deps: DeleteDeps = {
  async getUser(authorization) {
    const asUser = createClient(url, anonKey, {
      ...noSession,
      global: { headers: { Authorization: authorization } },
    });
    const { data, error } = await asUser.auth.getUser();
    if (error || !data.user || !data.user.email) return null;
    return { id: data.user.id, email: data.user.email };
  },
  async verifyPassword(email, password) {
    // A throwaway client: the session this creates is never stored or used.
    const probe = createClient(url, anonKey, noSession);
    const { error } = await probe.auth.signInWithPassword({ email, password });
    return !error;
  },
  async requestDeletion(userId) {
    const { error } = await admin.rpc("request_account_deletion", { p_user: userId });
    if (error) throw new Error("delete_failed");
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
