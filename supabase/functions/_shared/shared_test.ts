import assert from "node:assert/strict";
import { dedupeKey, normalizeBody } from "./dedupe.ts";
import { isOtpLike } from "./otp.ts";
import { parseIngestPayload } from "./request.ts";
import { generateToken, isWellFormedToken, sha256Hex } from "./token.ts";

Deno.test("token: generated tokens are well formed, unique and hash to 64 hex chars", async () => {
  const a = generateToken();
  const b = generateToken();
  assert.ok(isWellFormedToken(a));
  assert.notEqual(a, b);
  assert.match(await sha256Hex(a), /^[0-9a-f]{64}$/);
});

Deno.test("token: malformed values are rejected", () => {
  for (
    const t of [
      null,
      undefined,
      "",
      "stk_short",
      "abc",
      `stk_${"a".repeat(44)}`,
      `xxx_${"a".repeat(43)}`,
    ]
  ) {
    assert.equal(isWellFormedToken(t), false);
  }
});

Deno.test("token: sha256 matches a known vector", async () => {
  assert.equal(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("dedupe: same text in the same 2-minute bucket collides, different text or bucket does not", async () => {
  const t = new Date("2026-10-26T14:19:10Z");
  const same = new Date("2026-10-26T14:19:50Z");
  const later = new Date("2026-10-26T14:23:00Z");
  const k = await dedupeKey("barq app", "Amount 3.99 SAR", t);
  assert.equal(k, await dedupeKey("barq app", "Amount 3.99 SAR", same));
  assert.equal(k, await dedupeKey("  BARQ APP ", "Amount   3.99  SAR\n", t));
  assert.notEqual(k, await dedupeKey("barq app", "Amount 3.99 SAR", later));
  assert.notEqual(k, await dedupeKey("barq app", "Amount 4.99 SAR", t));
  assert.notEqual(k, await dedupeKey("D360 Bank", "Amount 3.99 SAR", t));
});

Deno.test("dedupe: normalizeBody collapses whitespace", () => {
  assert.equal(normalizeBody("  a \n\n b\t c "), "a b c");
});

Deno.test("otp: detects the code messages seen in the catalog", () => {
  const otps = [
    "OTP: 887448\nFor: Adding card to digital wallet",
    "رمز التفعيل: 6067\nالمبلغ: SAR 1,800\nلـ تحويل محلي",
    "رمز التحقق لإتمام عمليتك هو: 0159\n\nلا تشارك الرمز مع الآخرين.",
    "رمز التحقق لـأبل باى هو 721532. لتنشيط بطاقتك أدخل هذا الرمز في تطبيق المحفظة.",
    "Your verification code is 1234",
    "Your security code is 4821",
    "One-time password 552201 for your transfer",
    "Your passcode: 8890",
    "رمز التأكيد 4455 لإتمام العملية",
    "رمز الأمان الخاص بك 9911",
    "كلمة المرور المؤقتة هي 7788",
    "كلمة المرور لمرة واحدة: 3344",
  ];
  for (const m of otps) assert.equal(isOtpLike(m), true, m);
});

Deno.test("otp: purchases and transfers are not OTP", () => {
  const normal = [
    "POS Purchase\nVisa card: **9105 (Apple Pay)\nAmount: 19.00 SAR\nAt: OTTEN\n2026-10-22 20:47",
    "حوالة صادرة محلية\nمبلغ SAR 1,800\nرسوم: SAR 0.58",
    "Local Online Purchase\nAmount: SAR 90.70\nAt: HUNGERSTATION LLC",
    "تم إيداع الراتب\nمبلغ SAR 13822.93\nلـ حساب **6000",
    "Credit Transfer Internal\nAmount: 106.00 SAR\nSender A/C: **6784",
  ];
  for (const m of normal) assert.equal(isOtpLike(m), false, m);
});

Deno.test("request: valid payload parses and trims the sender", () => {
  const r = parseIngestPayload(
    { sender: " alinma ", body: "x", received_at: "2026-10-26T14:19:00Z" },
    new Date("2026-10-26T14:20:00Z"),
  );
  assert.ok(r.ok);
  if (r.ok) {
    assert.equal(r.value.sender, "alinma");
    assert.equal(r.value.receivedAt.toISOString(), "2026-10-26T14:19:00.000Z");
  }
});

Deno.test("request: missing received_at falls back to now, far-future timestamps are clamped to now", () => {
  const now = new Date("2026-10-26T14:20:00Z");
  const a = parseIngestPayload({ sender: "s", body: "b" }, now);
  const b = parseIngestPayload(
    { sender: "s", body: "b", received_at: "2030-01-01T00:00:00Z" },
    now,
  );
  assert.ok(a.ok && b.ok);
  if (a.ok && b.ok) {
    assert.equal(a.value.receivedAt.getTime(), now.getTime());
    assert.equal(b.value.receivedAt.getTime(), now.getTime());
  }
});

Deno.test("request: invalid payloads are rejected", () => {
  const bad: unknown[] = [
    null,
    "x",
    5,
    {},
    { sender: "", body: "b" },
    { sender: "s", body: "" },
    { sender: "s", body: "b".repeat(4001) },
    { sender: "s".repeat(65), body: "b" },
    { sender: "s", body: "b", received_at: "not a date" },
    { sender: 1, body: "b" },
  ];
  for (const p of bad) assert.equal(parseIngestPayload(p).ok, false, JSON.stringify(p));
});
