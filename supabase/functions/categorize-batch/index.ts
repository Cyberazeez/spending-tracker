import { createClient } from "@supabase/supabase-js";
import { MODEL } from "../_shared/ai.ts";
import { runBatch } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, apikey",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json", "cache-control": "no-store" },
  });

/** Riyadh month window as UTC instants. */
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
    const [settings, cats] = await Promise.all([
      db.from("settings").select("ai_enabled, ai_monthly_cap_halalas").eq("user_id", userId)
        .maybeSingle(),
      db.from("categories").select("id, name").eq("user_id", userId),
    ]);
    if (settings.error || cats.error || !settings.data) return json(500, { error: "server_error" });

    const result = await runBatch({
      categoryIds: Object.fromEntries((cats.data ?? []).map((c) => [c.name, c.id])),
      ai: {
        apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
        fetch,
        aiEnabled: settings.data.ai_enabled,
        capHalalas: Number(settings.data.ai_monthly_cap_halalas),
        async spentHalalas() {
          const { data, error } = await db.from("ai_usage").select("cost_halalas").eq(
            "user_id",
            userId,
          )
            .gte("created_at", monthStartUtc());
          if (error) throw new Error("usage_read_failed");
          return (data ?? []).reduce((s, r) => s + Number(r.cost_halalas), 0);
        },
        async recordUsage(x) {
          const { error } = await db.from("ai_usage").insert({
            user_id: userId,
            day: new Date().toISOString().slice(0, 10),
            purpose: "categorize",
            input_tokens: x.inputTokens,
            output_tokens: x.outputTokens,
            cost_halalas: x.costHalalas,
          });
          // An unrecorded spend would let the cap under-count, so fail loudly.
          if (error) throw new Error("usage_write_failed");
        },
      },
      async uncategorizedMerchants() {
        const { data, error } = await db.from("transactions").select("merchant_norm").eq(
          "user_id",
          userId,
        )
          .is("category_id", null).is("deleted_at", null).eq("is_internal", false)
          .not("merchant_norm", "is", null).order("occurred_at", { ascending: false }).limit(1000);
        if (error) throw new Error("read_failed");
        // Merchants that already have a rule (user or AI) are never second-guessed by the model.
        const { data: ruled, error: ruleErr } = await db.from("merchant_rules").select("pattern")
          .eq("user_id", userId).eq("match_type", "exact");
        if (ruleErr) throw new Error("read_failed");
        const has = new Set((ruled ?? []).map((r) => r.pattern as string));
        return [...new Set((data ?? []).map((r) => r.merchant_norm as string))].filter((m) =>
          !has.has(m)
        );
      },
      async saveGuesses(guesses) {
        let updated = 0;
        for (const g of guesses) {
          const { data: rule, error } = await db.from("merchant_rules").upsert(
            {
              user_id: userId,
              pattern: g.merchantNorm,
              match_type: "exact",
              category_id: g.categoryId,
              status: "auto_unconfirmed",
              source: "ai",
            },
            { onConflict: "user_id,pattern,match_type", ignoreDuplicates: true },
          ).select("id");
          // No row back = a rule for this merchant already exists; keep it and leave its transactions alone.
          if (error || !rule?.length) continue;
          const { data: rows } = await db.from("transactions")
            .update({
              category_id: g.categoryId,
              category_source: "ai",
              rule_id: rule[0].id,
            })
            .eq("user_id", userId).eq("merchant_norm", g.merchantNorm).is("category_id", null)
            .select("id");
          updated += rows?.length ?? 0;
        }
        return updated;
      },
    });
    return result.ok
      ? json(200, { ...result, model: MODEL })
      : json(200, { ok: false, reason: result.reason });
  } catch (e) {
    console.error("categorize_batch_error", (e as Error).message);
    return json(500, { error: "server_error" });
  }
});
