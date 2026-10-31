import assert from "node:assert/strict";
import { parseSms } from "./index.ts";

const FIXTURES = new URL("../../../tests/fixtures/", import.meta.url);

interface Fixture {
  sender: string;
  receivedAt: string;
  body: string;
  expected: Record<string, unknown>;
}

const SENDERS = ["alinma", "alrajhi", "barq", "d360", "snb", "stc"];
let total = 0;

for (const dir of SENDERS) {
  for (const entry of Deno.readDirSync(new URL(`${dir}/`, FIXTURES))) {
    if (!entry.name.endsWith(".json")) continue;
    total++;
    Deno.test(`fixture ${dir}/${entry.name.replace(".json", "")}`, () => {
      const f: Fixture = JSON.parse(
        Deno.readTextFileSync(new URL(`${dir}/${entry.name}`, FIXTURES)),
      );
      const r = parseSms(f.sender, f.body, new Date(f.receivedAt)) as unknown as Record<
        string,
        unknown
      >;
      const flat: Record<string, unknown> = r.kind === "transaction"
        ? { kind: "transaction", ...(r.txn as object) }
        : r;
      for (const [key, want] of Object.entries(f.expected)) {
        assert.deepEqual(
          flat[key],
          want,
          `${key}: got ${JSON.stringify(flat[key])} want ${JSON.stringify(want)}\n${
            JSON.stringify(flat)
          }`,
        );
      }
    });
  }
}

Deno.test("every supported bank has fixtures", () => {
  assert.ok(total >= 60, `only ${total} fixtures`);
});

Deno.test("a parsed transaction never carries a balance", () => {
  for (const dir of SENDERS) {
    for (const entry of Deno.readDirSync(new URL(`${dir}/`, FIXTURES))) {
      const f: Fixture = JSON.parse(
        Deno.readTextFileSync(new URL(`${dir}/${entry.name}`, FIXTURES)),
      );
      const r = parseSms(f.sender, f.body, new Date(f.receivedAt));
      assert.ok(
        !/balance|رصيد/i.test(JSON.stringify(r)),
        `${dir}/${entry.name} leaked a balance field`,
      );
    }
  }
});

Deno.test("unknown senders and parser crashes end up unparsed, never thrown", () => {
  assert.deepEqual(parseSms("SomeShop", "SAR 100", new Date()), { kind: "unparsed" });
  assert.deepEqual(parseSms("alinma", "", new Date()), { kind: "unparsed" });
  assert.deepEqual(
    parseSms("barq app", "Online Purchase\nAmount 9999999999999999999999 SAR", new Date()).kind,
    "unparsed",
  );
});

Deno.test("sender matching ignores case and spaces", () => {
  const body = "Online Purchase\nVISA card **1224\nAmount 3.99 SAR\nAt X\n2026-10-26 17:19";
  assert.equal(parseSms("  BARQ App ", body, new Date("2026-10-26T14:20:00Z")).kind, "transaction");
});

Deno.test("Arabic-Indic digits are read like ASCII digits", () => {
  const r = parseSms(
    "alinma",
    "شراء POS-ApplePay\nبـ SAR ١٩.٠٠\nبطاقة ائتمانية *٨١١٩\nلدى *SA /TEST\nفي ٠٦:٤٤ ٢٩-١٠-٢٦",
    new Date("2026-10-29T03:45:00Z"),
  );
  assert.equal(r.kind, "transaction");
  if (r.kind === "transaction") assert.equal(r.txn.amountHalalas, 1900);
});

Deno.test("a message that arrives late still resolves the right year from the arrival time", () => {
  const r = parseSms(
    "AlRajhiBank",
    "حوالة داخلية واردة بـSR 1000\nلـ6331\nمن5247;X\n26/10/2 05:13",
    new Date("2026-10-02T02:14:00Z"),
  );
  assert.equal(r.kind, "transaction");
  if (r.kind === "transaction") assert.equal(r.txn.occurredAt, "2026-10-02T02:13:00.000Z");
});

Deno.test("amounts use integer maths (no float drift)", () => {
  const mk = (amt: string) =>
    parseSms(
      "barq app",
      `Online Purchase\nVISA card **1224\nAmount ${amt} SAR\nAt X\n2026-10-26 17:19`,
      new Date("2026-10-26T14:20:00Z"),
    );
  for (
    const [s, h] of [["0.10", 10], ["0.29", 29], ["1,234.56", 123456], ["19.99", 1999], [
      "4.35",
      435,
    ]] as const
  ) {
    const r = mk(s);
    assert.ok(
      r.kind === "transaction" && r.txn.amountHalalas === h,
      `${s} -> ${JSON.stringify(r)}`,
    );
  }
});
