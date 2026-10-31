import { createClient } from "@supabase/supabase-js";
import { handleIngest, type IngestDeps } from "./handler.ts";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const deps: IngestDeps = {
  async findToken(hash) {
    const { data, error } = await db
      .from("ingest_tokens")
      .select("id, user_id")
      .eq("token_hash", hash)
      .is("revoked_at", null)
      .maybeSingle();
    if (error) throw new Error("token_lookup_failed");
    return data ? { id: data.id, userId: data.user_id } : null;
  },
  async bumpRateLimit(userId, window) {
    const { data, error } = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: window === "minute" ? "ingest_min" : "ingest_day",
      p_window: window,
    });
    if (error) throw new Error("rate_limit_failed");
    return data as number;
  },
  async insertRaw(row) {
    const { data, error } = await db.from("raw_messages").insert(row).select("id").maybeSingle();
    if (error) {
      if (error.code === "23505") return null; // duplicate dedupe_hash
      throw new Error("insert_failed");
    }
    return data?.id ?? null;
  },
  async loadOwnAccounts(userId) {
    const { data, error } = await db.from("own_accounts").select("bank, last4").eq(
      "user_id",
      userId,
    ).eq("is_active", true);
    if (error) throw new Error("own_accounts_failed");
    return data ?? [];
  },
  async loadCategorization(userId) {
    const [cats, rules] = await Promise.all([
      db.from("categories").select("id, name").eq("user_id", userId),
      db.from("merchant_rules").select("id, pattern, match_type, category_id, status, source").eq(
        "user_id",
        userId,
      ),
    ]);
    if (cats.error || rules.error) throw new Error("categorization_load_failed");
    return {
      ids: Object.fromEntries((cats.data ?? []).map((c) => [c.name, c.id])),
      rules: (rules.data ?? []).map((r) => ({
        id: r.id,
        pattern: r.pattern,
        matchType: r.match_type,
        categoryId: r.category_id,
        status: r.status,
        source: r.source,
      })),
    };
  },
  async saveParsed({ userId, rawId, parser, status, ignoreReason, redactBody, replaceBody, rows }) {
    const ids: Record<string, string> = {};
    if (rows.length) {
      // (raw_message_id, type) is unique, so a retry after a half-finished save cannot duplicate rows.
      const { error } = await db.from("transactions").upsert(
        rows.map((r) => ({ ...r, user_id: userId, raw_message_id: rawId })),
        { onConflict: "raw_message_id,type", ignoreDuplicates: true },
      );
      if (error) throw new Error("transactions_insert_failed");
      const { data, error: readError } = await db.from("transactions").select("id, type").eq(
        "raw_message_id",
        rawId,
      );
      if (readError) throw new Error("transactions_read_failed");
      for (const t of data ?? []) ids[t.type as string] = t.id as string;
    }
    const patch: Record<string, unknown> = {
      parse_status: status,
      parser,
      ignore_reason: ignoreReason ?? null,
      transaction_id: rows.length ? ids[rows[0].type] ?? null : null,
      confidence: 1,
    };
    if (redactBody) patch.body = "[redacted]";
    else if (replaceBody) patch.body = replaceBody;
    const { error } = await db.from("raw_messages").update(patch).eq("id", rawId);
    if (error) throw new Error("raw_update_failed");
    return { ids };
  },
  obligations: {
    async refresh(userId) {
      const { error } = await db.rpc("refresh_obligation_instances", { p_user: userId });
      if (error) throw new Error("refresh_failed");
    },
    async loadObligations(userId) {
      const [obs, inst] = await Promise.all([
        db.from("obligations").select("id, name, kind, expected_amount_halalas, due_rule, match")
          .eq("user_id", userId).eq("active", true),
        db.from("obligation_instances").select(
          "id, obligation_id, period_start, due_date, expected_amount_halalas, actual_amount_halalas, status, transaction_id, match_state, created_at",
        ).eq("user_id", userId).in("status", ["pending", "overdue"]),
      ]);
      if (obs.error || inst.error) throw new Error("obligations_load_failed");
      return {
        obs: (obs.data ?? []).map((o) => ({
          id: o.id,
          name: o.name,
          kind: o.kind,
          expectedHalalas: o.expected_amount_halalas === null
            ? null
            : Number(o.expected_amount_halalas),
          dueRule: o.due_rule ?? {},
          match: o.match ?? {},
        })),
        open: (inst.data ?? []).map((i) => ({
          id: i.id,
          obligationId: i.obligation_id,
          periodStart: i.period_start,
          dueDate: i.due_date,
          expectedHalalas: i.expected_amount_halalas === null
            ? null
            : Number(i.expected_amount_halalas),
          actualHalalas: i.actual_amount_halalas === null ? null : Number(i.actual_amount_halalas),
          status: i.status,
          transactionId: i.transaction_id,
          matchState: i.match_state,
          createdAt: i.created_at,
        })),
      };
    },
    async upsertNoticeInstance({ userId, obligationId, rawId, inst }) {
      const { data: existing, error } = await db.from("obligation_instances").select("id, status")
        .eq("user_id", userId).eq("obligation_id", obligationId).eq(
          "period_start",
          inst.periodStart,
        )
        .maybeSingle();
      if (error) throw new Error("instance_read_failed");
      if (!existing) {
        const { error: e } = await db.from("obligation_instances").insert({
          user_id: userId,
          obligation_id: obligationId,
          period_start: inst.periodStart,
          due_date: inst.dueDate,
          expected_amount_halalas: inst.expectedHalalas,
          source_raw_message_id: rawId,
        });
        if (e) throw new Error("instance_insert_failed");
      } else if (existing.status === "pending" || existing.status === "overdue") {
        const { error: e } = await db.from("obligation_instances").update({
          due_date: inst.dueDate,
          expected_amount_halalas: inst.expectedHalalas,
          source_raw_message_id: rawId,
          status: "pending",
          // A re-issued bill starts over: a payment matched to the old amount no longer applies.
          transaction_id: null,
          actual_amount_halalas: null,
          match_state: "none",
          paid_at: null,
        }).eq("id", existing.id).eq("user_id", userId);
        if (e) throw new Error("instance_update_failed");
      }
    },
    async applyMatch({ userId, match, paidAt }) {
      const { error } = await db.from("obligation_instances").update({
        status: match.status,
        actual_amount_halalas: match.actualHalalas,
        transaction_id: match.transactionId,
        match_state: match.state,
        paid_at: match.status === "paid" ? paidAt : null,
      }).eq("id", match.instanceId).eq("user_id", userId).in("status", ["pending", "overdue"]);
      if (error) throw new Error("instance_match_failed");
    },
    async setDueDate(userId, instanceId, dueDate) {
      const { error } = await db.from("obligation_instances").update({ due_date: dueDate }).eq(
        "id",
        instanceId,
      ).eq("user_id", userId).in("status", ["pending", "overdue"]);
      if (error) throw new Error("instance_due_failed");
    },
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
    return await handleIngest(req, deps);
  } catch (e) {
    // Only the error code is logged, never message content.
    console.error("ingest_error", (e as Error).message);
    return new Response(JSON.stringify({ error: "server_error" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
