import { parseAlinma } from "./alinma.ts";
import { parseAlRajhi } from "./alrajhi.ts";
import { parseBarq } from "./barq.ts";
import { parseD360 } from "./d360.ts";
import { parseSnb } from "./snb.ts";
import { parseStc } from "./stc.ts";
import { parseStc900 } from "./stc900.ts";
import type { ParseResult } from "./types.ts";

export type { Bank, ParsedTxn, ParseResult, TxType } from "./types.ts";

/** Sender IDs exactly as iOS shows them (compared case-insensitively). */
const PARSERS: Record<string, (body: string, receivedAt: Date) => ParseResult> = {
  "alinma": parseAlinma,
  "barq app": parseBarq,
  "d360 bank": parseD360,
  "stc bank": parseStc,
  "snb-alahli": parseSnb,
  "alrajhibank": parseAlRajhi,
  "900": parseStc900,
};

/** Never throws: any parser error becomes `unparsed`, which lands in Needs review. */
export function parseSms(sender: string, body: string, receivedAt: Date): ParseResult {
  const parser = PARSERS[sender.trim().toLowerCase()];
  if (!parser) return { kind: "unparsed" };
  try {
    return parser(body, receivedAt);
  } catch {
    return { kind: "unparsed" };
  }
}
