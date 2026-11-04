import { type AiDeps, costHalalas, MODEL } from "./ai.ts";
import { type Aggregates, describeAggregates } from "./tips.ts";

/** Plain-text answers are short; a reply cut at the ceiling is still readable, so this one can be modest. */
export const MAX_TOKENS_CHAT = 1500;
export const MAX_CHAT_MESSAGES = 12;
export const MAX_CHAT_CHARS = 500;
const MAX_REPLY_CHARS = 2000;

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

function clean(s: string, maskLongDigits: boolean): string {
  const noControl = Array.from(s, (ch) => {
    const c = ch.charCodeAt(0);
    return c < 32 || c === 127 || c === 0x2028 || c === 0x2029 ? " " : ch;
  }).join("");
  let out = noControl.replace(/\S+@\S+/g, " ").replace(/https?:\/\/\S+/gi, " ");
  // Card, phone and IBAN-like runs never leave the phone; ordinary amounts ("1250", "1,250.50") still do.
  if (maskLongDigits) out = out.replace(/\d[\d\s-]{6,}\d/g, " ");
  return out.replace(/\s+/g, " ").trim();
}

/**
 * The conversation so far, rebuilt from scratch: at most 12 turns, each a short string, starting and ending with
 * the person's own message. Emails, URLs and long digit runs are removed from what the person typed.
 */
export function sanitizeMessages(input: unknown): ChatMessage[] | null {
  if (!Array.isArray(input) || input.length < 1 || input.length > MAX_CHAT_MESSAGES) return null;
  const out: ChatMessage[] = [];
  for (const m of input) {
    if (typeof m !== "object" || m === null) return null;
    const r = m as Record<string, unknown>;
    if ((r.role !== "user" && r.role !== "assistant") || typeof r.content !== "string") return null;
    const content = clean(r.content, r.role === "user").slice(
      0,
      r.role === "user" ? MAX_CHAT_CHARS : MAX_REPLY_CHARS,
    );
    if (!content) return null;
    out.push({ role: r.role, content });
  }
  if (out[0].role !== "user" || out[out.length - 1].role !== "user") return null;
  return out;
}

export function buildSystem(a: Aggregates, language: "en" | "ar"): string {
  return [
    "You are a careful personal-finance assistant inside a spending tracker. The person asks about their own month.",
    "Answer only from the numbers below; quote the SAR figures you use. If the numbers do not answer the question, say so.",
    "Never invent merchants, transactions or figures. You only know category totals, not individual purchases.",
    "Stay on budgeting and spending. Keep answers under 120 words, plain text, no markdown.",
    `Always answer in ${
      language === "ar" ? "Arabic" : "English"
    }, whatever language the question is written in.`,
    ...describeAggregates(a),
  ].join("\n");
}

export type ChatOutcome =
  | { ok: true; reply: string; costHalalas: number }
  | { ok: false; reason: "disabled" | "no_key" | "cap_reached" | "failed" };

/** One chat turn on aggregates only. Fails closed, like the tips call. */
export async function generateChat(
  deps: AiDeps,
  a: Aggregates,
  messages: ChatMessage[],
  language: "en" | "ar",
): Promise<ChatOutcome> {
  if (!deps.aiEnabled) return { ok: false, reason: "disabled" };
  if (!deps.apiKey) return { ok: false, reason: "no_key" };
  try {
    if ((await deps.spentHalalas()) >= deps.capHalalas) return { ok: false, reason: "cap_reached" };
    const res = await deps.fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": deps.apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: MAX_TOKENS_CHAT,
        system: buildSystem(a, language),
        messages,
      }),
    });
    if (!res.ok) return { ok: false, reason: "failed" };
    const data = await res.json();
    const text: string = (data?.content ?? []).map((b: { text?: string }) => b.text ?? "").join("");
    const inTok = Number(data?.usage?.input_tokens ?? 0);
    const outTok = Number(data?.usage?.output_tokens ?? 0);
    const cost = costHalalas(inTok, outTok);
    await deps.recordUsage({ inputTokens: inTok, outputTokens: outTok, costHalalas: cost });
    const reply = text.trim().slice(0, MAX_REPLY_CHARS);
    if (!reply) return { ok: false, reason: "failed" };
    return { ok: true, reply, costHalalas: cost };
  } catch {
    return { ok: false, reason: "failed" };
  }
}
