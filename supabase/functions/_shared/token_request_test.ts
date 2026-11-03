import assert from "node:assert/strict";
import { parseTokenRequest } from "./token_request.ts";

Deno.test("an empty or label-only request still means: rotate the shortcut token", () => {
  assert.deepEqual(parseTokenRequest({}), { kind: "shortcut", action: "rotate", label: "iPhone" });
  assert.deepEqual(parseTokenRequest(undefined), {
    kind: "shortcut",
    action: "rotate",
    label: "iPhone",
  });
  assert.deepEqual(parseTokenRequest({ label: "  My phone  " }), {
    kind: "shortcut",
    action: "rotate",
    label: "My phone",
  });
});

Deno.test("the app token and revoke are explicit", () => {
  assert.deepEqual(parseTokenRequest({ kind: "app" }), {
    kind: "app",
    action: "rotate",
    label: "App",
  });
  assert.deepEqual(parseTokenRequest({ kind: "app", action: "revoke" }), {
    kind: "app",
    action: "revoke",
    label: "App",
  });
});

Deno.test("unknown kinds and actions are refused", () => {
  assert.deepEqual(parseTokenRequest({ kind: "admin" }), null);
  assert.deepEqual(parseTokenRequest({ kind: 1 }), null);
  assert.deepEqual(parseTokenRequest({ action: "delete" }), null);
  assert.deepEqual(parseTokenRequest({ action: ["rotate"] }), null);
});

Deno.test("the label is trimmed and capped at 40 characters", () => {
  const r = parseTokenRequest({ label: "x".repeat(80) });
  assert.deepEqual(r?.label.length, 40);
  assert.deepEqual(parseTokenRequest({ label: "   " })?.label, "iPhone");
});

Deno.test("the widget token is its own kind", () => {
  assert.deepEqual(parseTokenRequest({ kind: "widget" }), {
    kind: "widget",
    action: "rotate",
    label: "Widget",
  });
  assert.deepEqual(parseTokenRequest({ kind: "widget", action: "revoke" })?.kind, "widget");
});
