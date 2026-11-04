# 08-setup-guide: set up and run

For the owner. Short on purpose; the reasons are in the other docs.

## 1. The Shortcuts (one per bank)
iOS cannot send every bank's SMS through one automation reliably, so make **one automation per sender**. Seven in total:

| Sender (exactly as iOS shows it) | Bank |
|---|---|
| `alinma` | Alinma (account, debit card, credit card) |
| `barq app` | barq |
| `D360 Bank` | D360 |
| `STC Bank` | STC Bank |
| `SNB-AlAhli` | SNB |
| `AlRajhiBank` | Al Rajhi |
| `900` | STC bills (internet 7356, mobile 0569) |

For each one: Shortcuts app, Automation, `+`, **Message**.
1. **Sender:** pick the sender above. If iOS will not let you pick an alphanumeric sender, use *Message Contains* with a word every SMS from that bank has.
2. **Run Immediately.** Turn **Notify When Run** off (otherwise iOS asks every time).
3. Add the action **Get Contents of URL**:
   - URL: `https://evepfssanoffnwtqjmyq.supabase.co/functions/v1/ingest`
   - Method: `POST`
   - Header: `X-Ingest-Token` = your token (`scripts/get-ingest-token.ps1` on Windows; the app no longer shows it. Prefer the app's own "Add bank message" action, see More > SMS capture)
   - Request body: **JSON** with three fields: `sender` = Shortcut Input, Sender; `body` = Shortcut Input, Content; `received_at` = Current Date (ISO 8601).
4. Only the `X-Ingest-Token` header is needed. No Authorization header.

**If it stops working:** the app's Home screen warns "No SMS for N days" after three silent days. Check, in this order: is the automation still on, is *Notify When Run* off, was the token replaced (replacing the token breaks every Shortcut until the new one is pasted in), did iOS ask to allow the automation after an update.

A token only leaves the phone when you copy it; the app removes it from the clipboard after a minute.

## 2. What happens to an SMS
`ingest` stores it (one-time codes become `[redacted]`, balance lines are dropped), the parser for that bank reads it, rules pick a category, and any matching obligation is marked paid. Anything it cannot read stays in **Needs review**; nothing is guessed. Parsers and every known format: `07-sms-catalog.md`.

## 3. Importing a card statement (history)
Alinma credit card statement PDFs can be imported as history. Developer tool, run from the repo (needs `pdftotext`, from poppler-utils):
```bash
deno run --allow-run --allow-read --allow-write supabase/functions/import_statement_cli.ts \
  --rules rules.json --before <date of your first SMS> --out rows.json statement1.pdf statement2.pdf
```
`rules.json` is your categories and merchant rules exported from the database. The tool prints a dry-run summary and refuses to continue if a statement's totals do not match the bank's own. It never touches the database; the rows are imported separately with `import_statement_rows` (service role). Importing the same statement twice changes nothing. A phone import screen comes later.

## 4. AI categories and tips (optional, off by default)
1. Create an API key in the Claude Console with a small prepaid balance and **auto-reload off**.
2. Supabase, Edge Functions, Secrets: add `ANTHROPIC_API_KEY`. Never put it in the app, in git or in a chat.
3. Turn on the AI switch in settings. The monthly cap (about SAR 19) and a usage log keep it bounded; only merchant names with numbers stripped, or totals and your own category names, are ever sent.

## 5. Deploying
Deploys happen after a pull request is merged to `main`, never from a branch. The database changes are the files in `supabase/migrations/`; the functions are `ingest`, `rotate-token`, `categorize-batch` and `insights-tips`. See `CLAUDE.md` for the working rules.

## 6. Backups
Supabase takes daily backups on paid plans; on the free plan export the tables you care about now and then (Table editor, export as CSV): `transactions`, `merchant_rules`, `obligations`, `budgets`.
