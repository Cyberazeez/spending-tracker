import {
  dueDateAfterSalary,
  type Inst,
  instanceFromBill,
  instanceFromStatement,
  type MatchResult,
  matchTransaction,
  monthStartOf,
  type NewInstance,
  type Ob,
  obligationForBill,
  obligationForStatement,
} from "../_shared/obligations.ts";
import type { ParseResult } from "../_shared/parsers/index.ts";
import type { TxRow } from "../_shared/enrich.ts";

export interface ObligationDeps {
  /** Active obligations and their open (pending/overdue) instances. */
  loadObligations(userId: string): Promise<{ obs: Ob[]; open: Inst[] }>;
  /** Creates the period's instance, or refreshes an unpaid one (a re-issued bill). Never touches a paid one. */
  upsertNoticeInstance(
    a: { userId: string; obligationId: string; rawId: string; inst: NewInstance },
  ): Promise<void>;
  applyMatch(a: { userId: string; match: MatchResult; paidAt: string }): Promise<void>;
  setDueDate(userId: string, instanceId: string, dueDate: string): Promise<void>;
}

type Notice = Extract<ParseResult, { kind: "notice" }>;

/** A bill or statement SMS creates (or updates) that month's instance. Unknown lines are simply not tracked. */
export async function applyNotice(
  deps: ObligationDeps,
  userId: string,
  rawId: string,
  receivedAt: Date,
  n: Notice,
): Promise<void> {
  const { obs } = await deps.loadObligations(userId);
  if (n.notice === "bill_issued") {
    const ob = obligationForBill(obs, n.lineLast4);
    if (!ob) return;
    await deps.upsertNoticeInstance({
      userId,
      obligationId: ob.id,
      rawId,
      inst: instanceFromBill(ob, n.totalHalalas, receivedAt),
    });
  } else {
    const ob = obligationForStatement(obs, n.cardLast4);
    if (!ob) return;
    await deps.upsertNoticeInstance({
      userId,
      obligationId: ob.id,
      rawId,
      inst: instanceFromStatement(n.totalDueHalalas, n.dueDate, receivedAt),
    });
  }
}

/**
 * Saved transactions can pay an open instance (a salary only moves "after salary" due dates). Each row is matched
 * against what is still open, and an instance already used by an earlier row of the same SMS is not reused.
 */
export async function applyTransactions(
  deps: ObligationDeps,
  userId: string,
  rows: TxRow[],
  ids: Record<string, string>,
): Promise<void> {
  const { obs, open } = await deps.loadObligations(userId);
  let instances = open;
  for (const row of rows) {
    const id = ids[row.type];
    if (!id) continue;
    if (row.type === "salary") {
      const month = monthStartOf(row.occurred_at);
      for (const inst of instances) {
        const ob = obs.find((o) => o.id === inst.obligationId);
        if (!ob || inst.periodStart !== month || inst.transactionId) continue;
        const due = dueDateAfterSalary(ob.dueRule, row.occurred_at, inst.dueDate);
        if (due !== inst.dueDate) await deps.setDueDate(userId, inst.id, due);
      }
      continue;
    }
    if (row.type === "fee") continue;
    const m = matchTransaction(
      {
        id,
        type: row.type,
        direction: row.direction,
        amountHalalas: row.amount_halalas,
        counterpartyLast4: row.counterparty_last4,
        cardLast4: row.card_last4,
        merchantNorm: row.merchant_norm,
        occurredAt: row.occurred_at,
      },
      instances,
      obs,
    );
    if (!m) continue;
    await deps.applyMatch({ userId, match: m, paidAt: row.occurred_at });
    instances = instances.map((i) =>
      i.id === m.instanceId
        ? { ...i, status: m.status, actualHalalas: m.actualHalalas, transactionId: m.transactionId }
        : i
    );
  }
}
