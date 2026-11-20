import { createClient } from "@supabase/supabase-js";
import { handleIngest } from "./handler.ts";
import { ingestDeps } from "./deps.ts";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const deps = ingestDeps(db);

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
