import { createClient } from "@supabase/supabase-js";
import { ingestDeps } from "../ingest/deps.ts";
import { DUPLICATE_WINDOW_MS, handlePaste, type PasteDeps } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const db = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const plain = ingestDeps(db);
const withAi = ingestDeps(db, "ai_enabled");

const deps: PasteDeps = {
  async authUser(req) {
    const asUser = createClient(url, anonKey, {
      global: { headers: { Authorization: req.headers.get("authorization") ?? "" } },
      auth: { persistSession: false },
    });
    const { data, error } = await asUser.auth.getUser();
    return error || !data.user ? null : data.user.id;
  },
  async bumpRateLimit(userId) {
    const { data, error } = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "paste_day",
      p_window: "day",
    });
    if (error) throw new Error("rate_limit_failed");
    return data as number;
  },
  loadOwnAccounts: (userId) => plain.loadOwnAccounts(userId),
  loadCategorization: (userId) => plain.loadCategorization(userId),
  async loadBills(userId) {
    return (await plain.obligations.loadObligations(userId)).obs;
  },
  async findDuplicates(userId, q) {
    const t = new Date(q.occurredAt).getTime();
    let query = db.from("transactions")
      .select(
        "id, merchant_raw, amount_halalas, occurred_at, category_id, card_last4, account_last4",
      )
      .eq("user_id", userId)
      .is("deleted_at", null)
      .eq("amount_halalas", q.amountHalalas)
      .gte("occurred_at", new Date(t - DUPLICATE_WINDOW_MS).toISOString())
      .lte("occurred_at", new Date(t + DUPLICATE_WINDOW_MS).toISOString())
      .limit(5);
    if (q.last4s.length) {
      // Only digits reach the filter (last 4 from the parser), so the or() string cannot be bent.
      const d = q.last4s.filter((x) => /^\d{4}$/.test(x));
      if (d.length) {
        query = query.or(
          d.flatMap((x) => [`card_last4.eq.${x}`, `account_last4.eq.${x}`]).join(","),
        );
      }
    }
    const { data, error } = await query;
    if (error) throw new Error("duplicate_lookup_failed");
    return (data ?? []).map((r) => ({
      id: r.id,
      merchant: r.merchant_raw,
      amountHalalas: Number(r.amount_halalas),
      occurredAt: r.occurred_at,
      categoryId: r.category_id,
    }));
  },
  async aiAvailable(userId) {
    const { data, error } = await db.from("settings").select("ai_allowed, ai_enabled").eq(
      "user_id",
      userId,
    ).maybeSingle();
    return !error && data?.ai_allowed === true && data?.ai_enabled === true;
  },
  ingest: (ai) => (ai ? withAi : { ...plain, aiParse: undefined }),
};

Deno.serve(async (req) => {
  try {
    return await handlePaste(req, deps);
  } catch (e) {
    // Only the error code is logged, never message content.
    console.error("paste_error", (e as Error).message);
    return new Response(JSON.stringify({ error: "server_error" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
