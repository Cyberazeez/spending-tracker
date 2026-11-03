# Add obligations by hand, and the AI switch (2026-11-03)

Owner decisions: form is the **Full** version; the Anthropic key is already stored as the Supabase secret `ANTHROPIC_API_KEY`.
Each part is its own PR and TestFlight build.

## Part 1. Add / edit obligations by hand
**Entry points:** a "+" in the Bills navigation bar opens the form. Tapping a row's action sheet gets **Edit details** (next to Edit amount) and **Stop tracking**.

**Form fields** (Cupertino form sheet, same card style as More):
| Field | Rule |
|---|---|
| Name | required, max 60 |
| Type | Bill / Fixed payment / Loan (card statement is SMS-only, not creatable) |
| Amount | Fixed or Estimated switch + SAR amount, > 0 and <= the budget cap; a Bill may leave it empty (then instances only come from the bill SMS) |
| Repeats | Monthly / Every 3 months / Yearly |
| Due day | 1 to 31 (short months clamp to the last day) |
| First due month | only for quarterly and yearly (which month it starts) |
| Grace days | 0 to 14, default 3 |
| Remind days before | 0 to 14, default 2 |
| Category | optional, from the user's categories |
| Match words | optional, comma separated words found in the merchant name |
| Amount tolerance % | default 10, only used with match words |
| Mark paid automatically | off by default: with it off a match is only suggested (Confirm / Not this) |

**Stop tracking** sets `active=false` (history stays). Nothing is hard-deleted. Editing changes the obligation and the expected amount of its still-pending instances only; paid history is untouched.

**Server:** rows go through the existing RLS (own rows). One migration changes `refresh_obligation_instances` to honour `frequency`: quarterly/yearly create an instance only in months matching `due_rule.start_month` (every 3 / 12 months), monthly is unchanged. Local DB test covers monthly, quarterly, yearly, clamping to month end, inactive. The app validates every field; the migration also adds CHECKs for `due_rule.day` 1..31 and `grace` 0..14, so a hand-made request cannot store nonsense.

**Not in scope:** custom frequency, editing the seeded card statement, SMS-format learning for new bills.

## Part 2. AI switch, suggest categories, AI tips
Server functions `categorize-batch` and `insights-tips` already exist (cap, usage log, redaction). Needed: confirm both are deployed, then the app side.
- **More > AI** group: switch bound to `settings.ai_enabled` (client-writable), with a note "Sends only merchant names and totals, never SMS text, numbers or names" and the month's usage vs the cap (read from `ai_usage`, own rows).
- **Suggest categories** button on Transactions (shown when uncategorised rows exist and AI is on): calls `categorize-batch`, shows "N categorised", the new rules appear as unconfirmed so they can be corrected.
- **AI tips card** on Insights (when AI is on): "Get tips" calls `insights-tips` with the month's totals; shows the tips and keeps the last result (the `insights` row).
- Errors map to plain messages: switch off, no key, cap reached, failed.
- Cap stays 5 USD/month (`ai_monthly_cap_halalas`, not client-writable).
