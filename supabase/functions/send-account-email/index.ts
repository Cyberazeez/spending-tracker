import { createClient } from "@supabase/supabase-js";
import { FROM_DEFAULT, sendAccountEmail } from "../_shared/account_email.ts";
import { type EmailDeps, handleSendAccountEmail } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(url, serviceKey, noSession);

const deps: EmailDeps = {
  async getUser(authorization) {
    const asUser = createClient(url, anonKey, {
      ...noSession,
      global: { headers: { Authorization: authorization } },
    });
    const { data, error } = await asUser.auth.getUser();
    if (error || !data.user || !data.user.email) return null;
    return { id: data.user.id, email: data.user.email };
  },
  async bumpRateLimit(userId) {
    const { data, error } = await admin.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "account_email",
      p_window: "day",
    });
    if (error) throw new Error("rate_limit_failed");
    return data as number;
  },
  send: (to, kind) =>
    sendAccountEmail(
      {
        fetch,
        apiKey: Deno.env.get("RESEND_API_KEY"),
        from: Deno.env.get("EMAIL_FROM") ?? FROM_DEFAULT,
      },
      to,
      kind,
    ),
};

Deno.serve(async (req) => {
  try {
    return await handleSendAccountEmail(req, deps);
  } catch (e) {
    console.error("send_account_email_failed", e instanceof Error ? e.message : "unknown");
    return new Response(JSON.stringify({ error: "server_error" }), {
      status: 500,
      headers: { "content-type": "application/json", "cache-control": "no-store" },
    });
  }
});
