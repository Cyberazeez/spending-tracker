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
  async saveParsed({ userId, rawId, parser, status, ignoreReason, rows }) {
    let firstId: string | null = null;
    if (rows.length) {
      const { data, error } = await db
        .from("transactions")
        .insert(rows.map((r) => ({ ...r, user_id: userId, raw_message_id: rawId })))
        .select("id");
      if (error) throw new Error("transactions_insert_failed");
      firstId = data?.[0]?.id ?? null;
    }
    const { error } = await db
      .from("raw_messages")
      .update({
        parse_status: status,
        parser,
        ignore_reason: ignoreReason ?? null,
        transaction_id: firstId,
        confidence: 1,
      })
      .eq("id", rawId);
    if (error) throw new Error("raw_update_failed");
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
