import { createClient } from "@supabase/supabase-js";
import { aiActive, MODEL } from "../_shared/ai.ts";
import { createBudget } from "../_shared/ai_reserve.ts";
import { runBatch } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const CATEGORIZE_LIMIT_PER_DAY = 20;

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
    // Same per-user daily limit idea as the chat: the money cap alone lets a script call this in a tight loop.
    const used = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "ai_categorize",
      p_window: "day",
    });
    if (used.error) throw new Error("rate_limit_failed");
    if (Number(used.data) > CATEGORIZE_LIMIT_PER_DAY) {
      return json(200, { ok: false, reason: "cap_reached" });
    }
    const [settings, cats] = await Promise.all([
      db.from("settings").select("ai_enabled, ai_allowed, ai_monthly_cap_halalas").eq(
        "user_id",
        userId,
      )
        .maybeSingle(),
      db.from("categories").select("id, name").eq("user_id", userId).limit(200),
    ]);
    if (settings.error || cats.error || !settings.data) return json(500, { error: "server_error" });

    const budget = createBudget(db, {
      userId,
      purpose: "categorize",
      userCapHalalas: Number(settings.data.ai_monthly_cap_halalas),
      monthStartIso: monthStartUtc(),
      globalCapEnv: Deno.env.get("AI_GLOBAL_CAP_HALALAS"),
    });
    const result = await runBatch({
      categoryIds: Object.fromEntries((cats.data ?? []).map((c) => [c.name, c.id])),
      ai: {
        apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
        fetch,
        aiEnabled: aiActive(settings.data),
        ...budget,
      },
      async uncategorizedMerchants() {
        const { data, error } = await db.from("transactions").select("merchant_norm").eq(
          "user_id",
          userId,
        )
          .is("category_id", null).is("deleted_at", null).eq("is_internal", false).in("type", [
            "purchase",
            "refund",
          ])
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
          const { data: rows, error: updErr } = await db.from("transactions")
            .update({
              category_id: g.categoryId,
              category_source: "ai",
              rule_id: rule[0].id,
            })
            .eq("user_id", userId).eq("merchant_norm", g.merchantNorm).is("category_id", null)
            .select("id");
          if (updErr) {
            // Without this the merchant would keep its rule, never be asked again, and stay uncategorised.
            console.error("save_guess_update_failed", updErr.code);
            await db.from("merchant_rules").delete().eq("id", rule[0].id).eq("user_id", userId);
            continue;
          }
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
