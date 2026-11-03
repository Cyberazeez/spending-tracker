import { createClient } from "@supabase/supabase-js";
import { handleWidgetSummary, type WidgetDeps } from "./handler.ts";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const deps: WidgetDeps = {
  async findWidgetToken(hash) {
    const { data, error } = await db
      .from("ingest_tokens")
      .select("id, user_id")
      .eq("token_hash", hash)
      .eq("kind", "widget")
      .is("revoked_at", null)
      .maybeSingle();
    if (error) throw new Error("token_lookup_failed");
    return data ? { id: data.id, userId: data.user_id } : null;
  },
  async bumpRateLimit(userId) {
    const { data, error } = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "widget_day",
      p_window: "day",
    });
    if (error) throw new Error("rate_limit_failed");
    return data as number;
  },
  async summary(userId) {
    const { data, error } = await db.rpc("widget_summary", { p_user: userId });
    if (error) throw new Error("summary_failed");
    const row = Array.isArray(data) ? data[0] : data;
    return {
      todayHalalas: Number(row?.today_halalas ?? 0),
      monthHalalas: Number(row?.month_halalas ?? 0),
      budgetHalalas: row?.budget_halalas == null ? null : Number(row.budget_halalas),
    };
  },
  async touchToken(tokenId) {
    const { error } = await db
      .from("ingest_tokens")
      .update({ last_used_at: new Date().toISOString() })
      .eq("id", tokenId);
    if (error) console.error("touch_token_failed", error.code);
  },
};

Deno.serve(async (req) => {
  try {
    return await handleWidgetSummary(req, deps);
  } catch (e) {
    console.error("widget_summary_failed", e instanceof Error ? e.message : "unknown");
    return new Response(JSON.stringify({ error: "server_error" }), {
      status: 500,
      headers: { "content-type": "application/json", "cache-control": "no-store" },
    });
  }
});
