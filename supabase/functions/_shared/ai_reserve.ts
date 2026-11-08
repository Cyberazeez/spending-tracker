import { globalCapFromEnv } from "./ai_budget.ts";

/** The slice of the Supabase client the budget needs (so tests can fake it). */
export interface BudgetDb {
  rpc(
    fn: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
}

export interface Budget {
  /** Reserve the worst-case cost before the model call. False when the user's cap or the global ceiling would be passed. */
  reserve(estimateHalalas: number): Promise<boolean>;
  /** Replace the reservation with the real tokens and cost. */
  recordUsage(u: { inputTokens: number; outputTokens: number; costHalalas: number }): Promise<void>;
  /** Give the reservation back (the call failed before it was billed). Never throws. */
  release(): Promise<void>;
}

/**
 * Atomic reserve-before-call budget for one AI call. The database function takes a lock, adds up this month's spend
 * (reservations included) and only then inserts the reservation, so parallel calls cannot overshoot the cap.
 */
export function createBudget(
  db: BudgetDb,
  o: {
    userId: string;
    purpose: "parse" | "categorize" | "insights" | "chat";
    userCapHalalas: number;
    monthStartIso: string;
    globalCapEnv?: string;
  },
): Budget {
  let id: string | null = null;
  return {
    async reserve(estimateHalalas) {
      const { data, error } = await db.rpc("ai_reserve", {
        p_user: o.userId,
        p_purpose: o.purpose,
        p_estimate: Math.max(1, Math.ceil(estimateHalalas)),
        p_user_cap: Math.max(0, Math.floor(o.userCapHalalas)),
        p_global_cap: globalCapFromEnv(o.globalCapEnv),
        p_since: o.monthStartIso,
      });
      if (error) throw new Error("usage_reserve_failed");
      id = typeof data === "string" ? data : null;
      return id !== null;
    },
    async recordUsage(u) {
      if (!id) throw new Error("usage_write_failed");
      const { error } = await db.rpc("ai_settle", {
        p_id: id,
        p_user: o.userId,
        p_input: u.inputTokens,
        p_output: u.outputTokens,
        p_cost: u.costHalalas,
      });
      id = null;
      if (error) throw new Error("usage_write_failed");
    },
    async release() {
      if (!id) return;
      const held = id;
      id = null;
      try {
        await db.rpc("ai_release", { p_id: held, p_user: o.userId });
      } catch { /* the worst-case estimate stays; that errs on the safe side */ }
    },
  };
}
