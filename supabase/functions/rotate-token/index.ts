import { createClient } from "@supabase/supabase-js";
import { generateToken, sha256Hex } from "../_shared/token.ts";

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

/** Creates a new ingest token for the signed-in user and revokes the old ones. The plaintext is returned once. */
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

  let label = "iPhone";
  try {
    const b = await req.json();
    if (typeof b?.label === "string" && b.label.trim() !== "") label = b.label.trim().slice(0, 40);
  } catch { /* body is optional */ }

  const db = createClient(url, serviceKey, { auth: { persistSession: false } });
  const revoke = await db
    .from("ingest_tokens")
    .update({ revoked_at: new Date().toISOString() })
    .eq("user_id", userId)
    .is("revoked_at", null);
  if (revoke.error) return json(500, { error: "server_error" });

  const token = generateToken();
  const insert = await db
    .from("ingest_tokens")
    .insert({ user_id: userId, label, token_hash: await sha256Hex(token) });
  if (insert.error) return json(500, { error: "server_error" });

  return json(200, { token });
});
