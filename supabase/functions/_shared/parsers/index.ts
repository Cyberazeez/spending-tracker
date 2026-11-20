import { parseAlinma } from "./alinma.ts";
import { parseAlRajhi } from "./alrajhi.ts";
import { parseBarq } from "./barq.ts";
import { parseD360 } from "./d360.ts";
import { parseSnb } from "./snb.ts";
import { parseStc } from "./stc.ts";
import { parseStc900 } from "./stc900.ts";
import { parseSe } from "./se.ts";
import type { ParseResult } from "./types.ts";

export type { Bank, Biller, ParsedTxn, ParseResult, TxType } from "./types.ts";

/** Sender IDs exactly as iOS shows them (compared case-insensitively). */
const PARSERS: Record<string, (body: string, receivedAt: Date) => ParseResult> = {
  "alinma": parseAlinma,
  "barq app": parseBarq,
  "d360 bank": parseD360,
  "stc bank": parseStc,
  "snb-alahli": parseSnb,
  "alrajhibank": parseAlRajhi,
  "900": parseStc900,
  // Not a real sender ID yet: the sender a pasted Saudi Electricity notice is stored under (see SENDER_OF).
  "se": parseSe,
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

/**
 * Every reader by its code, for a pasted message that has no sender. The Saudi Electricity reader is here only until
 * its sender ID is confirmed on the phone; then it joins PARSERS too.
 */
export const READERS: Record<string, (body: string, receivedAt: Date) => ParseResult> = {
  alinma: parseAlinma,
  barq: parseBarq,
  d360: parseD360,
  stc: parseStc,
  snb: parseSnb,
  alrajhi: parseAlRajhi,
  stc900: parseStc900,
  se: parseSe,
};

/** The sender ID the Shortcut uses for each reader code (the paste path stores a pasted message under it). */
export const SENDER_OF: Record<string, string> = {
  alinma: "alinma",
  barq: "barq app",
  d360: "d360 bank",
  stc: "stc bank",
  snb: "snb-alahli",
  alrajhi: "alrajhibank",
  stc900: "900",
  se: "se",
};

/** Reads [body] with one reader by its code. Never throws. */
export function parseWith(code: string, body: string, receivedAt: Date): ParseResult {
  const reader = READERS[code];
  if (!reader) return { kind: "unparsed" };
  try {
    return reader(body, receivedAt);
  } catch {
    return { kind: "unparsed" };
  }
}

/** Every reader that understands [body] as a transaction or a notice. Never guessed from words in the text. */
export function matchingReaders(body: string, receivedAt: Date): string[] {
  return Object.keys(READERS).filter((c) => {
    const r = parseWith(c, body, receivedAt);
    return r.kind === "transaction" || r.kind === "notice";
  });
}

/**
 * Which reader understands a pasted message: the code when exactly one reader does, else null (none, or several:
 * the person picks the bank).
 */
export function detectReader(body: string, receivedAt: Date): string | null {
  const hits = matchingReaders(body, receivedAt);
  return hits.length === 1 ? hits[0] : null;
}
