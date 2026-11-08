import { createClient } from "@supabase/supabase-js";
import { INGEST_TOKEN_KINDS } from "../_shared/token.ts";
import { riyadhMonthStartIso } from "../_shared/ai_budget.ts";
import { createBudget } from "../_shared/ai_reserve.ts";
import { parseWithAi } from "../_shared/ai_parse.ts";
import { AI_TRUST_AFTER, handleIngest, type IngestDeps } from "./handler.ts";

const AI_PARSE_LIMIT_PER_DAY = 100;

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
      .in("kind", [...INGEST_TOKEN_KINDS]) // never the widget token
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
  async findRetryableRaw(userId, dedupeHash) {
    const { data, error } = await db.from("raw_messages").select("id").eq("user_id", userId).eq(
      "dedupe_hash",
      dedupeHash,
    ).eq("parse_status", "needs_review").is("transaction_id", null).maybeSingle();
    if (error) throw new Error("retry_lookup_failed");
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
  async findTransferCounterparts(userId, t) {
    const at = new Date(t.occurredAt).getTime();
    const { data, error } = await db.from("transactions").select(
      "id, is_internal, type, bank, account_last4, counterparty_last4, occurred_at",
    ).eq("user_id", userId).eq("type", t.type).eq("amount_halalas", t.amountHalalas).is(
      "deleted_at",
      null,
    ).gte("occurred_at", new Date(at - 5 * 60000).toISOString()).lte(
      "occurred_at",
      new Date(at + 5 * 60000).toISOString(),
    ).limit(20);
    if (error) throw new Error("counterpart_lookup_failed");
    const gap = (r: { occurred_at: unknown }) =>
      Math.abs(new Date(r.occurred_at as string).getTime() - at);
    return (data ?? []).sort((a, b) => gap(a) - gap(b)).slice(0, 5).map((r) => ({
      id: r.id as string,
      isInternal: !!r.is_internal,
      type: r.type as string,
      bank: r.bank as string,
      accountLast4: (r.account_last4 as string | null) ?? null,
      counterpartyLast4: (r.counterparty_last4 as string | null) ?? null,
    }));
  },
  async saveOwnAccounts(userId, accounts) {
    const { data, error } = await db.from("own_accounts").select("last4").eq("user_id", userId);
    if (error) throw new Error("own_accounts_failed");
    const have = new Set((data ?? []).map((a) => a.last4 as string));
    const fresh: { bank: string; last4: string }[] = [];
    for (const a of accounts) {
      if (have.size >= 50) break; // the same cap as the app's own quota
      if (have.has(a.last4)) continue; // already saved (under any bank): skip
      have.add(a.last4);
      fresh.push(a);
    }
    if (!fresh.length) return;
    const { error: e } = await db.from("own_accounts").upsert(
      fresh.map((a) => ({ user_id: userId, bank: a.bank, last4: a.last4, kind: "account" })),
      { onConflict: "user_id,bank,last4", ignoreDuplicates: true },
    );
    if (e) throw new Error("own_accounts_save_failed");
  },
  async markInternal(userId, ids, transfersCategoryId) {
    const { error } = await db.from("transactions").update({
      is_internal: true,
      excluded_from_spend: true,
    }).eq("user_id", userId).in("id", ids);
    if (error) throw new Error("mark_internal_failed");
    if (transfersCategoryId) {
      await db.from("transactions").update({
        category_id: transfersCategoryId,
        category_source: "rule",
      }).eq("user_id", userId).in("id", ids).is("category_id", null);
    }
  },
  async saveParsed(
    { userId, rawId, parser, status, confidence, ignoreReason, redactBody, replaceBody, rows },
  ) {
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
      confidence: confidence ?? 1,
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
  async aiParse(userId, sender, body, receivedAt) {
    // Needs the paid plan (server flag) AND the person's own consent to have message text read by AI.
    const { data: s, error } = await db.from("settings").select(
      "ai_allowed, ai_parse_enabled, ai_monthly_cap_halalas",
    ).eq("user_id", userId).maybeSingle();
    if (error || !s || s.ai_allowed !== true || s.ai_parse_enabled !== true) return null;
    const { data: n, error: rlErr } = await db.rpc("bump_rate_limit", {
      p_user: userId,
      p_bucket: "ai_parse",
      p_window: "day",
    });
    if (rlErr || Number(n) > AI_PARSE_LIMIT_PER_DAY) return null;
    const budget = createBudget(db, {
      userId,
      purpose: "parse",
      userCapHalalas: Number(s.ai_monthly_cap_halalas),
      monthStartIso: riyadhMonthStartIso(),
      globalCapEnv: Deno.env.get("AI_GLOBAL_CAP_HALALAS"),
    });
    return await parseWithAi(
      {
        apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
        fetch,
        aiAllowed: true,
        ...budget,
      },
      sender,
      body,
      receivedAt,
    );
  },
  async aiTrusted(userId, sender) {
    const { count, error } = await db.from("raw_messages").select("id", {
      count: "exact",
      head: true,
    })
      .eq("user_id", userId).eq("sender", sender).eq("parser", "ai/v1").eq(
        "parse_status",
        "parsed",
      );
    if (error) return false;
    return (count ?? 0) >= AI_TRUST_AFTER;
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
