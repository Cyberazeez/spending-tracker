// Ingest token helpers. The token is 256 bits of randomness, so a plain SHA-256 is enough to store.

const PREFIX = "stk_";

function toBase64Url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return PREFIX + toBase64Url(bytes);
}

export function isWellFormedToken(token: string | null | undefined): token is string {
  return typeof token === "string" && /^stk_[A-Za-z0-9_-]{43}$/.test(token);
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
