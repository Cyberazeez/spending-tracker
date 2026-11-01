// Developer tool: reads Alinma credit card statement PDFs, categorises with the owner's rules and prints a dry-run
// summary. It never touches the database; it writes the rows to a JSON file that is imported in a separate step.
//
//   deno run --allow-run --allow-read --allow-write supabase/functions/import_statement_cli.ts \
//     --rules rules.json [--before 2026-10-31] --out rows.json statement1.pdf statement2.pdf ...
//
// rules.json: { "categories": [{ "id", "name" }], "rules": [{ "id", "pattern", "match_type", "category_id", "status", "source" }] }
// Needs `pdftotext` (poppler-utils) on the PATH.
import { categorize, type CategoryIds, type Rule } from "./_shared/categorize.ts";
import { normalizeMerchant } from "./_shared/normalize.ts";
import { type ImportRow, parseStatementText, toImportRows } from "./_shared/statement.ts";

const args = [...Deno.args];
function flag(name: string): string | undefined {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
}
const rulesPath = flag("--rules");
const before = flag("--before");
const outPath = flag("--out");
if (!rulesPath || args.length === 0) {
  console.error("usage: --rules rules.json [--before YYYY-MM-DD] [--out rows.json] file.pdf ...");
  Deno.exit(2);
}

const cfg = JSON.parse(Deno.readTextFileSync(rulesPath)) as {
  categories: { id: string; name: string }[];
  rules: {
    id: string;
    pattern: string;
    match_type: string;
    category_id: string;
    status: string;
    source: string;
  }[];
};
const ids: CategoryIds = Object.fromEntries(cfg.categories.map((c) => [c.name, c.id]));
const nameOf = new Map(cfg.categories.map((c) => [c.id, c.name]));
const rules: Rule[] = cfg.rules.map((r) => ({
  id: r.id,
  pattern: r.pattern,
  matchType: r.match_type as Rule["matchType"],
  categoryId: r.category_id,
  status: r.status as Rule["status"],
  source: r.source as Rule["source"],
}));

const money = (h: number) =>
  (h / 100).toLocaleString("en", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const out: (ImportRow & { norm: string; category: string | null; bank: string })[] = [];
let problems = 0;

for (const file of args) {
  const p = await new Deno.Command("pdftotext", { args: ["-layout", file, "-"], stdout: "piped" })
    .output();
  if (!p.success) {
    console.error(`${file}: pdftotext failed`);
    problems++;
    continue;
  }
  const st = parseStatementText(new TextDecoder().decode(p.stdout));
  const { rows, skipped } = toImportRows(st);
  const counts = skipped.reduce<Record<string, number>>(
    (m, s) => (m[s.reason] = (m[s.reason] ?? 0) + 1, m),
    {},
  );
  const ok = st.checksum?.ok === true;
  if (!ok) problems++;
  console.log(
    `statement ${st.statementDate} card ${st.cardLast4}: ${st.rows.length} lines -> ${rows.length} to import, skipped ${
      JSON.stringify(counts)
    }, totals ${ok ? "MATCH the bank's" : "DO NOT MATCH"} (${JSON.stringify(st.checksum)})`,
  );
  for (const r of rows) {
    const norm = normalizeMerchant(r.merchant);
    const c = categorize(
      { type: r.type, merchantNorm: norm, isInternal: r.type === "wallet_topup" },
      rules,
      ids,
    );
    out.push({ ...r, norm, category: c ? nameOf.get(c.categoryId) ?? null : null, bank: "alinma" });
  }
}

let kept = out;
if (before) {
  kept = out.filter((r) => r.date < before);
  console.log(
    `\nkept ${kept.length} of ${out.length} rows dated before ${before} (later ones may overlap SMS capture)`,
  );
}
// the same transaction can be in two statements only if the user passes the same file twice
const seen = new Set<string>();
kept = kept.filter((r) => !seen.has(r.ref) && seen.add(r.ref));

const by = (t: string) => kept.filter((r) => r.type === t);
const spend = by("purchase").reduce((s, r) => s + r.amountHalalas, 0) +
  by("fee").reduce((s, r) => s + r.amountHalalas, 0) -
  by("refund").reduce((s, r) => s + r.amountHalalas, 0);
const dates = kept.map((r) => r.date).sort();
const uncat = kept.filter((r) => r.category === null && r.type !== "fee");
console.log(
  `\nrows to import: ${kept.length} (${by("purchase").length} purchases, ${
    by("refund").length
  } refunds, ${by("fee").length} fees, ${
    by("wallet_topup").length
  } wallet top-ups kept out of spending)`,
);
console.log(`date range: ${dates[0]} to ${dates.at(-1)}`);
console.log(`net spend in these rows: SAR ${money(spend)}`);
console.log(
  `categorised by your rules: ${kept.length - uncat.length}/${kept.length} (${
    Math.round(100 * (kept.length - uncat.length) / Math.max(kept.length, 1))
  }%)`,
);
const byCat: Record<string, number> = {};
for (const r of kept) {
  const k = r.category ?? "(uncategorised)";
  byCat[k] = (byCat[k] ?? 0) + (r.type === "refund" ? -r.amountHalalas : r.amountHalalas);
}
console.log("by category:");
for (const [k, v] of Object.entries(byCat).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(18)} SAR ${money(v)}`);
}
const unc: Record<string, number> = {};
for (const r of uncat) unc[r.merchant] = (unc[r.merchant] ?? 0) + r.amountHalalas;
console.log("biggest uncategorised merchants:");
for (const [k, v] of Object.entries(unc).sort((a, b) => b[1] - a[1]).slice(0, 15)) {
  console.log(`  ${k.slice(0, 32).padEnd(32)} SAR ${money(v)}`);
}
if (problems) console.log(`\n${problems} problem(s): do not import until the totals match.`);
if (outPath) {
  Deno.writeTextFileSync(
    outPath,
    JSON.stringify(kept.map((r) => ({
      ref: r.ref,
      date: r.date,
      type: r.type,
      direction: r.direction,
      amount: r.amountHalalas,
      merchant: r.merchant,
      norm: r.norm,
      category: r.category,
      card: r.card,
      bank: r.bank,
    }))),
  );
  console.log(`\nwrote ${kept.length} rows to ${outPath} (nothing was sent to the database)`);
}
Deno.exit(problems ? 1 : 0);
