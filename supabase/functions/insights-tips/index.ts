import { createClient } from "@supabase/supabase-js";
import { aiActive, MODEL } from "../_shared/ai.ts";
import { createBudget } from "../_shared/ai_reserve.ts";
import { generateTips, sanitizeAggregates } from "../_shared/tips.ts";

// Optional AI tips on aggregated numbers. Off unless settings.ai_enabled and ANTHROPIC_API_KEY are both set.
// The caller (the app) sends only totals; the function rebuilds them with sanitizeAggregates, so no merchant,
// account number, name or SMS text can reach the model.
const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const TIPS_LIMIT_PER_DAY = 30;

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, apikey, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json", "cache-control": "no-store" },
  });

function monthStartUtc(now = new Date()): string {
  const r = new Date(now.getTime() + 3 * 3600 * 1000);
  return new Date(Date.UTC(r.getUTCFullYear(), r.getUTCMonth(), 1, -3)).toISOString();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: req.headers.get("authorization") ?? "" } },
    auth: { persistSession: false },
  });
  const { data: u, error: ue } = await asUser.auth.getUser();
  if (ue || !u.user) return json(401, { error: "unauthorized" });
  const userId = u.user.id;
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

  try {
    let body: { aggregates?: unknown; language?: unknown };
    try {
      body = await req.json();
    } catch {
      return json(400, { error: "invalid_json" });
    }
    const used = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "ai_tips",
      p_window: "day",
    });
    if (used.error) throw new Error("rate_limit_failed");
    if (Number(used.data) > TIPS_LIMIT_PER_DAY) {
      return json(200, { ok: false, reason: "cap_reached" });
    }
    const [settings, cats] = await Promise.all([
      db.from("settings").select("ai_enabled, ai_allowed, ai_monthly_cap_halalas, locale").eq(
        "user_id",
        userId,
      )
        .maybeSingle(),
      db.from("categories").select("name").eq("user_id", userId),
    ]);
    if (settings.error || cats.error || !settings.data) return json(500, { error: "server_error" });

    const agg = sanitizeAggregates(body.aggregates, (cats.data ?? []).map((c) => c.name as string));
    if (!agg) return json(400, { error: "invalid_aggregates" });

    const budget = createBudget(db, {
      userId,
      purpose: "insights",
      userCapHalalas: Number(settings.data.ai_monthly_cap_halalas),
      monthStartIso: monthStartUtc(),
      globalCapEnv: Deno.env.get("AI_GLOBAL_CAP_HALALAS"),
    });
    const result = await generateTips(
      {
        apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
        fetch,
        aiEnabled: aiActive(settings.data),
        ...budget,
      },
      agg,
      body.language === "ar" || settings.data.locale === "ar" ? "ar" : "en",
    );
    if (!result.ok) return json(200, { ok: false, reason: result.reason });

    const start = `${agg.month}-01`;
    const [y, m] = agg.month.split("-").map(Number);
    const end = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
    const { error } = await db.from("insights").insert({
      user_id: userId,
      period_start: start,
      period_end: end,
      kind: "on_demand",
      metrics: agg,
      tips: result.tips,
      model: MODEL,
    });
    if (error) throw new Error("insights_write_failed");
    return json(200, { ok: true, tips: result.tips, model: MODEL });
  } catch (e) {
    console.error("insights_tips_error", (e as Error).message);
    return json(500, { error: "server_error" });
  }
});
