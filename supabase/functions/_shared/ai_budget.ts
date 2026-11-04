/**
 * The AI budget check used by both AI functions. Each user has their own monthly cap (`settings.ai_monthly_cap_halalas`)
 * and there is one ceiling over everybody, so a family member cannot spend the owner's budget and many accounts
 * cannot add up to more than the owner agreed to pay.
 *
 * Returns the number the caller compares with the user's cap: the user's own spend normally, or "infinite" once the
 * global ceiling is reached (so every user gets `cap_reached`).
 */
export const DEFAULT_GLOBAL_CAP_HALALAS = 5700; // about 15 USD a month over all users

export function effectiveSpent(
  userSpentHalalas: number,
  allSpentHalalas: number,
  globalCapHalalas = DEFAULT_GLOBAL_CAP_HALALAS,
): number {
  return allSpentHalalas >= globalCapHalalas ? Number.MAX_SAFE_INTEGER : userSpentHalalas;
}

export function globalCapFromEnv(raw: string | undefined): number {
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : DEFAULT_GLOBAL_CAP_HALALAS;
}
