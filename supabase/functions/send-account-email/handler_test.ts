import assert from "node:assert/strict";
import { renderAccountEmail, sendAccountEmail } from "../_shared/account_email.ts";
import { EMAIL_LIMIT_PER_DAY, type EmailDeps, handleSendAccountEmail } from "./handler.ts";

function setup(over: Partial<EmailDeps> = {}) {
  const sent: [string, string][] = [];
  const deps: EmailDeps = {
    getUser: (a) =>
      Promise.resolve(a === "Bearer good" ? { id: "u1", email: "me@example.test" } : null),
    bumpRateLimit: () => Promise.resolve(1),
    send: (to, kind) => {
      sent.push([to, kind]);
      return Promise.resolve(true);
    },
    ...over,
  };
  const call = (
    body: unknown,
    headers: Record<string, string> = { authorization: "Bearer good" },
  ) =>
    handleSendAccountEmail(
      new Request("https://x.test/send-account-email", {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      }),
      deps,
    );
  return { call, sent };
}

Deno.test("sends the reactivated mail to the caller's own address only", async () => {
  const { call, sent } = setup();
  const res = await call({ kind: "reactivated", to: "victim@example.test" });
  assert.equal(res.status, 200);
  assert.deepEqual(sent, [["me@example.test", "reactivated"]]);
});

Deno.test("no token, bad token or other kinds send nothing", async () => {
  const { call, sent } = setup();
  assert.equal((await call({ kind: "reactivated" }, {})).status, 401);
  assert.equal((await call({ kind: "reactivated" }, { authorization: "Bearer bad" })).status, 401);
  assert.equal((await call({ kind: "deletion_requested" })).status, 400);
  assert.equal((await call({})).status, 400);
  assert.deepEqual(sent, []);
});

Deno.test("is rate limited per day", async () => {
  const { call, sent } = setup({ bumpRateLimit: () => Promise.resolve(EMAIL_LIMIT_PER_DAY + 1) });
  assert.equal((await call({ kind: "reactivated" })).status, 429);
  assert.deepEqual(sent, []);
});

Deno.test("a provider failure is reported as ok:false, not an error", async () => {
  const { call } = setup({ send: () => Promise.resolve(false) });
  const res = await call({ kind: "reactivated" });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: false });
});

Deno.test("the mail is bilingual and the provider call carries the key but never logs it", async () => {
  const mail = renderAccountEmail("reactivated");
  assert.match(mail.text, /active again/);
  assert.match(mail.text, /نشط/);
  assert.match(mail.html, /dir="rtl"/);

  let seen: { url: string; init: RequestInit } | undefined;
  const logs: unknown[][] = [];
  const orig = console.error;
  console.error = (...a: unknown[]) => logs.push(a);
  try {
    const fakeFetch = ((url: string, init: RequestInit) => {
      seen = { url, init };
      return Promise.resolve(new Response("{}", { status: 500 }));
    }) as unknown as typeof fetch;
    const ok = await sendAccountEmail(
      { fetch: fakeFetch, apiKey: "re_secret", from: "A <a@x.test>" },
      "me@example.test",
      "deletion_requested",
    );
    assert.equal(ok, false);
  } finally {
    console.error = orig;
  }
  assert.equal(seen?.url, "https://api.resend.com/emails");
  assert.equal(
    (seen?.init.headers as Record<string, string>).authorization,
    "Bearer re_secret",
  );
  assert.deepEqual(JSON.parse(seen!.init.body as string).to, ["me@example.test"]);
  assert.ok(!JSON.stringify(logs).includes("re_secret"));
  assert.ok(!JSON.stringify(logs).includes("me@example.test"));
});

Deno.test("no API key means no send", async () => {
  const ok = await sendAccountEmail(
    {
      fetch: (() => Promise.reject(new Error("must not be called"))) as unknown as typeof fetch,
      apiKey: undefined,
      from: "x",
    },
    "me@example.test",
    "reactivated",
  );
  assert.equal(ok, false);
});

Deno.test("the deletion mail uses the Halala layout: both languages, support address, privacy link", () => {
  const mail = renderAccountEmail("deletion_requested");
  assert.match(mail.subject, /30 days/);
  assert.match(mail.subject, /30 يومًا/);
  assert.match(mail.html, /halala-support@rawafiddata\.com/);
  assert.match(mail.html, /halala\.rawafiddata\.com\/privacy\//);
  assert.match(mail.html, /dir="ltr"/);
  assert.match(mail.html, /dir="rtl"/);
  assert.match(mail.text, /sign in again/);
});
