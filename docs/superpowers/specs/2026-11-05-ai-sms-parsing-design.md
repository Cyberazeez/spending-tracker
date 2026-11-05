# AI parsing of SMS from banks we have no fixture for (design, 2026-11-05)

Status: **design only, nothing built.** Paying customers only (owner decision 2026-11-05). Builds on the existing fallback chain in `docs/01-prd.md` F2 (rule parser, then Claude extraction, then Needs review); `raw_messages.parse_status = 'ai_parsed'` already exists in the schema.

## Goal
A new user whose bank has no parser (no fixture) still gets purchases, refunds, bills, salary and transfers recognised from their SMS. Today those land in **Needs review** and are entered by hand.

## How it works
1. The sender has no regex parser, or its parser returned "unknown format": the message is stored as now, then (paying accounts only) sent to a Claude model for structured extraction. The model is small and cheap (Haiku class); the model id is a config value.
2. **Redact before sending.** Balance lines are already stripped (`stripBalances`). Add `redactForAi()`: mask long digit runs (card, account, IBAN, phone), emails and URLs; keep the amount, currency, date and the merchant text. Person names in transfer messages cannot be removed reliably (see open decisions).
3. **Structured output only.** One tool-style JSON schema, no free text: `kind` (purchase, refund, atm, transfer_out, transfer_in, salary, bill_notice, bill_payment, card_payment, fee, ignore), `amount`, `currency`, `merchant`, `occurred_at`, `card_last4`, `confidence`, `ignore_reason` (otp, marketing, declined). The SMS body is untrusted **data**: the prompt says so, the model has no tools, and a message containing instructions cannot do anything but change its own row.
4. **Validate, never trust.** Reject the result (row goes to Needs review) unless: the amount and the merchant text literally occur in the SMS, the currency is a known code, the date parses and is not in the future, `kind` is in the enum, and the amount is within sane bounds. Same `ParsedRow` shape as the regex parsers, `parser = 'ai/v1'`, `parse_status = 'ai_parsed'`.
5. **Confirm first.** The first few AI-parsed rows per sender and user show a "Check this" chip in Needs review (one tap to confirm or fix). After N confirmations in a row (default 5) that sender is trusted for that user and rows land directly. A correction is stored as a feedback row for the eval set.
6. **Never spend on junk.** OTP-like and obvious marketing messages are dropped by the existing `isOtpLike` and ignore rules before any AI call.

## Gate and cost
- Server flag `ai_allowed` (the same one as the other AI features, not client-writable) plus a per-subscriber monthly quota; reserve budget **before** the call (ship-review finding 2). Free accounts keep Needs review with manual entry.
- Cost is one small call per unparsed message; phase 2 removes most of it.

## Phase 2: learn the format once
After a sender's AI parses are confirmed by enough distinct users, the model proposes a **regex template** with named captures. It is validated against the real confirmed messages (must reproduce amount, merchant and date on all of them), length-limited and checked for catastrophic backtracking, then **reviewed by the owner** and saved with a redacted fixture in `supabase/tests/fixtures/<sender>/`. That keeps the rule "no parser without a real fixture" and makes the new bank free for everyone, forever.

## Tackle plan
1. **Prerequisite:** paid AI plans (`ai_allowed`, quota, reserve-before-call). Until then AI parsing stays off.
2. **Eval set first:** run the AI extractor over the existing fixtures (7 senders) and compare with the regex results. Ship only if purchases and bills reach the agreed accuracy (proposal: 98% exact on amount and kind, 0 invented amounts).
3. `redactForAi()` with tests (digits, IBAN, phone, email, URL; amount and merchant survive).
4. Extractor function and validator (`_shared/ai_parse.ts`), fake-model unit tests including prompt-injection bodies and hallucinated amounts.
5. Wire into ingest as a background step for paying accounts; `ai_parsed` rows, "Check this" chip and trust counter (small migration + app change).
6. Run behind the flag for the owner's own account with a bank that has no fixture; review the results; then enable for paying users.
7. Phase 2 (template learning) only after enough real confirmed traffic.

## Decisions (owner, 2026-11-05)
- **Transfers stay out of AI parsing.** Transfer and person-to-person messages (names in the text) are never sent to the model; they stay in Needs review or the existing regex parsers. Only purchase, refund, bill, salary, fee and ATM-like messages go through `redactForAi()`.
- Still open: the accuracy bar and trust threshold (proposed above), and whether a failed AI parse refunds quota (proposed: yes).
