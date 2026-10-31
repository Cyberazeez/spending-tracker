import { normalizeMerchant } from "./normalize.ts";

export const MODEL = "claude-haiku-5-5";
/** USD per million tokens for prompts under 100k tokens (check Anthropic's pricing page before changing). */
const INPUT_USD_PER_MTOK = 0.10;
const OUTPUT_USD_PER_MTOK = 0.50;
const HALALAS_PER_USD = 375; // 3.75 SAR per USD, 100 halalas per SAR
export const MAX_MERCHANTS_PER_CALL = 40;

/** Cost of one call in halalas, rounded up and never below 1, so the monthly cap errs on the safe side. */
export function costHalalas(inputTokens: number, outputTokens: number): number {
  const usd = (inputTokens * INPUT_USD_PER_MTOK + outputTokens * OUTPUT_USD_PER_MTOK) / 1_000_000;
  return Math.max(1, Math.ceil(usd * HALALAS_PER_USD));
}

/**
 * Only a short merchant name ever leaves the system: digits runs of 4+ (card/account/phone numbers),
 * emails, URLs and IBAN-looking text are removed, and the text is length-capped.
 */
export function maskMerchant(s: string): string {
  return normalizeMerchant(
    s
      .replace(/\b[A-Za-z]{2}\d{2}[A-Za-z0-9]{10,}\b/g, " ")
      .replace(/\S+@\S+/g, " ")
      .replace(/https?:\/\/\S+/gi, " ")
      .replace(/\d{4,}/g, " "),
  ).slice(0, 60).trim();
}

export interface AiDeps {
  apiKey: string | undefined;
  fetch: typeof fetch;
  aiEnabled: boolean;
  capHalalas: number;
  /** Halalas already spent this Riyadh month. */
  spentHalalas(): Promise<number>;
  recordUsage(u: { inputTokens: number; outputTokens: number; costHalalas: number }): Promise<void>;
}

export type AiOutcome =
  | { ok: true; categories: Record<string, string>; costHalalas: number }
  | { ok: false; reason: "disabled" | "no_key" | "cap_reached" | "failed" };

/**
 * Asks Claude to pick a category for each merchant. Fails closed: any problem returns { ok:false } and the
 * caller leaves everything uncategorised. Nothing but masked merchant names and category names is sent.
 */
export async function categorizeMerchants(
  deps: AiDeps,
  merchants: string[],
  categoryNames: string[],
): Promise<AiOutcome> {
  if (!deps.aiEnabled) return { ok: false, reason: "disabled" };
  if (!deps.apiKey) return { ok: false, reason: "no_key" };
  const masked = [...new Set(merchants.map(maskMerchant).filter(Boolean))].slice(
    0,
    MAX_MERCHANTS_PER_CALL,
  );
  if (!masked.length) return { ok: true, categories: {}, costHalalas: 0 };
  try {
    if ((await deps.spentHalalas()) >= deps.capHalalas) return { ok: false, reason: "cap_reached" };
    const prompt = [
      "Assign each merchant name (from Saudi bank SMS, Arabic or English, often abbreviated) to exactly one category.",
      `Categories: ${categoryNames.join(", ")}.`,
      'Reply with only a JSON object mapping each merchant string to a category, or to "Other" if unsure.',
      `Merchants: ${JSON.stringify(masked)}`,
    ].join("\n");
    const res = await deps.fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": deps.apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1500,
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (!res.ok) return { ok: false, reason: "failed" };
    const data = await res.json();
    const text: string = (data?.content ?? []).map((b: { text?: string }) => b.text ?? "").join("");
    const inTok = Number(data?.usage?.input_tokens ?? 0);
    const outTok = Number(data?.usage?.output_tokens ?? 0);
    const cost = costHalalas(inTok, outTok);
    await deps.recordUsage({ inputTokens: inTok, outputTokens: outTok, costHalalas: cost });
    const json = text.match(/\{[\s\S]*\}/)?.[0];
    if (!json) return { ok: false, reason: "failed" };
    const raw = JSON.parse(json) as Record<string, unknown>;
    const allowed = new Set(categoryNames);
    const categories: Record<string, string> = {};
    for (const m of masked) {
      const c = raw[m];
      if (typeof c === "string" && allowed.has(c)) categories[m] = c;
    }
    return { ok: true, categories, costHalalas: cost };
  } catch {
    return { ok: false, reason: "failed" };
  }
}
