import { createClient } from "@supabase/supabase-js";
import { generateToken, sha256Hex } from "../_shared/token.ts";
import { parseTokenRequest } from "../_shared/token_request.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, apikey",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json", "cache-control": "no-store" },
  });
}

/**
 * Creates a new ingest token of the requested kind (default `shortcut`) for the signed-in user and revokes that kind's
 * old one, or with `action: "revoke"` only revokes it. The plaintext is returned once.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authHeader = req.headers.get("authorization") ?? "";
  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return json(401, { error: "unauthorized" });
  const userId = userData.user.id;

  let body: unknown = {};
  try {
    body = await req.json();
  } catch { /* body is optional */ }
  const request = parseTokenRequest(body);
  if (!request) return json(400, { error: "invalid_request" });

  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

  if (request.action === "revoke") {
    const revoked = await db.rpc("revoke_ingest_token", { p_user: userId, p_kind: request.kind });
    if (revoked.error) return json(500, { error: "server_error" });
    return json(200, { ok: true });
  }

  const token = generateToken();
  // One transaction: revoke this kind's old token and store the new hash. Never leaves zero or two active tokens of a kind.
  const rotated = await db.rpc("rotate_ingest_token", {
    p_user: userId,
    p_hash: await sha256Hex(token),
    p_label: request.label,
    p_kind: request.kind,
  });
  if (rotated.error) return json(500, { error: "server_error" });

  return json(200, { token });
});
