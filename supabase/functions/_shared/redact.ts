/** Balance lines are never stored. "رصيد غير كافي" (insufficient balance) is a message, not a balance. */
const BALANCE_LINE =
  /^[ \t]*(?:الرصيد|رصيدك|رصيد(?![ \t]*غير)|(?:available |wallet )?balance\b).*$\n?/gimu;

export function stripBalances(body: string): string {
  return body.replace(BALANCE_LINE, "").replace(/\n+$/, "");
}
