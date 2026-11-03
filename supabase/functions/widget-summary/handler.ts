import { isWellFormedToken, sha256Hex } from "../_shared/token.ts";

/** The widget refreshes every 15 to 30 minutes; this leaves room for retries and several widgets. */
export const WIDGET_LIMIT_PER_DAY = 300;

export interface WidgetSummary {
  todayHalalas: number;
  monthHalalas: number;
  /** null when no monthly budget is set */
  budgetHalalas: number | null;
}

export interface WidgetDeps {
  /** Owner of the active (not revoked) token of kind `widget`, or null. Any other kind must not match. */
  findWidgetToken(hash: string): Promise<{ id: string; userId: string } | null>;
  bumpRateLimit(userId: string): Promise<number>;
  summary(userId: string): Promise<WidgetSummary>;
  touchToken(tokenId: string): Promise<void>;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

/** GET or POST with header `x-widget-token`. Returns only three numbers; no merchants, no messages. */
export async function handleWidgetSummary(req: Request, deps: WidgetDeps): Promise<Response> {
  if (req.method !== "GET" && req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }
  const token = req.headers.get("x-widget-token");
  if (!isWellFormedToken(token)) return json(401, { error: "unauthorized" });
  const found = await deps.findWidgetToken(await sha256Hex(token));
  if (!found) return json(401, { error: "unauthorized" });

  if (await deps.bumpRateLimit(found.userId) > WIDGET_LIMIT_PER_DAY) {
    return json(429, { error: "rate_limited" });
  }
  const s = await deps.summary(found.userId);
  await deps.touchToken(found.id);
  return json(200, {
    today: s.todayHalalas,
    month: s.monthHalalas,
    budget: s.budgetHalalas,
  });
}
