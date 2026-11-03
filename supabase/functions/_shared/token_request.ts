// Validates the body of a `rotate-token` request. Pure, so it can be tested without a server.

export type TokenKind = "shortcut" | "app" | "widget";
export type TokenAction = "rotate" | "revoke";

export interface TokenRequest {
  kind: TokenKind;
  action: TokenAction;
  label: string;
}

const KINDS: TokenKind[] = ["shortcut", "app", "widget"];
const ACTIONS: TokenAction[] = ["rotate", "revoke"];

/** Defaults keep the old request (`{}` or `{label}`) meaning "rotate the shortcut token". */
export function parseTokenRequest(body: unknown): TokenRequest | null {
  const b = (typeof body === "object" && body !== null ? body : {}) as Record<string, unknown>;
  const kind = b.kind === undefined ? "shortcut" : b.kind;
  const action = b.action === undefined ? "rotate" : b.action;
  if (typeof kind !== "string" || !KINDS.includes(kind as TokenKind)) return null;
  if (typeof action !== "string" || !ACTIONS.includes(action as TokenAction)) return null;
  const defaultLabel = kind === "app" ? "App" : kind === "widget" ? "Widget" : "iPhone";
  const label = typeof b.label === "string" && b.label.trim() !== ""
    ? b.label.trim().slice(0, 40)
    : defaultLabel;
  return { kind: kind as TokenKind, action: action as TokenAction, label };
}
