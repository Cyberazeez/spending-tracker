import { createClient } from "@supabase/supabase-js";
import { MODEL } from "../_shared/ai.ts";
import { effectiveSpent, globalCapFromEnv } from "../_shared/ai_budget.ts";
import { generateTips, sanitizeAggregates } from "../_shared/tips.ts";

// Optional AI tips on aggregated numbers. Off unless settings.ai_enabled and ANTHROPIC_API_KEY are both set.
// The caller (the app) sends only totals; the function rebuilds them with sanitizeAggregates, so no merchant,
// account number, name or SMS text can reach the model.
const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

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
    const [settings, cats] = await Promise.all([
      db.from("settings").select("ai_enabled, ai_monthly_cap_halalas, locale").eq("user_id", userId)
        .maybeSingle(),
      db.from("categories").select("name").eq("user_id", userId),
    ]);
    if (settings.error || cats.error || !settings.data) return json(500, { error: "server_error" });

    const agg = sanitizeAggregates(body.aggregates, (cats.data ?? []).map((c) => c.name as string));
    if (!agg) return json(400, { error: "invalid_aggregates" });

    const result = await generateTips(
      {
        apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
        fetch,
        aiEnabled: settings.data.ai_enabled,
        capHalalas: Number(settings.data.ai_monthly_cap_halalas),
        async spentHalalas() {
          // This user's spend against their own cap, plus one ceiling over all users (see _shared/ai_budget.ts).
          const { data, error } = await db.from("ai_usage").select("user_id, cost_halalas")
            .gte("created_at", monthStartUtc());
          if (error) throw new Error("usage_read_failed");
          const rows = data ?? [];
          const all = rows.reduce((s, r) => s + Number(r.cost_halalas), 0);
          const mine = rows.filter((r) => r.user_id === userId).reduce(
            (s, r) => s + Number(r.cost_halalas),
            0,
          );
          return effectiveSpent(mine, all, globalCapFromEnv(Deno.env.get("AI_GLOBAL_CAP_HALALAS")));
        },
        async recordUsage(x) {
          const { error } = await db.from("ai_usage").insert({
            user_id: userId,
            day: new Date().toISOString().slice(0, 10),
            purpose: "insights",
            input_tokens: x.inputTokens,
            output_tokens: x.outputTokens,
            cost_halalas: x.costHalalas,
          });
          if (error) throw new Error("usage_write_failed");
        },
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
