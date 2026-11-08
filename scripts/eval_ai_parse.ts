// Manual accuracy check of the AI SMS parser against the real redacted fixtures. Costs a few cents and sends the
// (already redacted) fixture texts to Anthropic, so run it only on purpose:
//   ANTHROPIC_API_KEY=... deno run --allow-env --allow-read --allow-net scripts/eval_ai_parse.ts
// Pass criteria (docs/superpowers/specs/2026-11-05-ai-sms-parsing-design.md): 98% exact on amount and kind,
// and ZERO accepted results with a wrong amount (a rejected result is fine: it goes to Needs review).
import { eligibleForAi, parseWithAi } from "../supabase/functions/_shared/ai_parse.ts";

const key = Deno.env.get("ANTHROPIC_API_KEY");
if (!key) {
  console.error("Set ANTHROPIC_API_KEY first.");
  Deno.exit(1);
}

const ROOT = new URL("../supabase/tests/fixtures/", import.meta.url);
const KINDS = new Set(["purchase", "refund", "atm_withdrawal", "salary", "card_payment", "loan_installment", "bill_payment", "fee"]);
let spent = 0;
const deps = {
  apiKey: key,
  fetch,
  aiAllowed: true,
  capHalalas: Number.MAX_SAFE_INTEGER,
  spentHalalas: () => Promise.resolve(0),
  recordUsage: (u: { costHalalas: number }) => {
    spent += u.costHalalas;
    return Promise.resolve();
  },
};

let total = 0, exact = 0, rejected = 0, wrong = 0;
for (const dir of Deno.readDirSync(ROOT)) {
  if (!dir.isDirectory || dir.name === "statement") continue;
  for (const f of Deno.readDirSync(new URL(`${dir.name}/`, ROOT))) {
    if (!f.name.endsWith(".json")) continue;
    const fx = JSON.parse(Deno.readTextFileSync(new URL(`${dir.name}/${f.name}`, ROOT)));
    const e = fx.expected;
    if (e.kind !== "transaction" || !KINDS.has(e.type) || e.origCurrency || !eligibleForAi(fx.body).ok) continue;
    total++;
    const out = await parseWithAi(deps, fx.sender, fx.body, new Date(fx.receivedAt));
    const name = `${dir.name}/${f.name}`;
    if (!out.ok || out.result.kind === "rejected") {
      rejected++;
      console.log("REJECTED ", name, out.ok ? out.result.kind === "rejected" ? out.result.reason : "" : out.reason);
    } else if (out.result.kind === "transaction" && out.result.txn.amountHalalas === e.amountHalalas && out.result.txn.type === e.type) {
      exact++;
    } else {
      wrong++;
      console.log("WRONG    ", name, JSON.stringify(out.result));
    }
  }
}
console.log(`\n${total} messages: ${exact} exact, ${rejected} rejected (Needs review), ${wrong} WRONG`);
console.log(`exact rate ${((exact / total) * 100).toFixed(1)}%  |  spent about ${(spent / 100).toFixed(2)} SAR`);
console.log(wrong === 0 && exact / total >= 0.98 ? "PASS" : "NOT YET: do not enable AI parsing");
