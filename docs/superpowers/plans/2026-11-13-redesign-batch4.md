# Redesign batch 4: More, SMS capture, account sheets

Owner's screenshots and comments: "more design and order should match this", "SMS capture screen should match this", "password change sheet is needed and should match this", "delete account screen should look like this". Owner rule: when the app and the mockup differ, the mockup wins.

## Done
- **More** in the mockup's order: account card on top (mint tile, "Your account", email); Monthly budget, Categories and rules, Bank accounts (count), SMS capture ("Last sent 11:20" or "N waiting"); AI assistant, (AI reading of unknown banks, paid plans only), Language, Bill reminders; Sign out. Row subtitles are gone except where a row needs one (paid-only note, AI reading consent). Bank accounts moved here from Account.
- **Categories and rules** (new, owner chose the simple page 2026-11-13): each category with the places that always go to it; a rule can be deleted after an icon sheet asks. Purchases it already filed keep their category. Internal account rules (`acct:` / `card:`) are not listed. Categories without rules are shown as chips. Adding or renaming categories is not built yet.
- **SMS capture**: one status card (Working mint / Not sending pink / Waiting for the first message or Not set up gold) with "N waiting" and "Send waiting messages now" when messages wait; a card listing each bank: every sender a message came from (`bankCodeForSender` maps sender IDs to banks; `900` is "Bill messages") and every bank of the owner's accounts that has sent nothing ("No messages yet"); "Show me how, step by step"; "Open Shortcuts"; the privacy line. The five numbered steps moved into the step-by-step guide only.
- **Password changed**: the centred icon sheet with a mint check and "This phone reconnects SMS capture and the widget by itself."
- **Delete my account**: "Are you sure?" is the centred icon sheet (pink warning tile), "Yes, delete it" (red) and "Keep my account" (emerald).

## Deviation from the mockup
- "Send a test message" is not built: nothing in the app or server can send a test through the Shortcut today (it needs native and server work). The second button is "Open Shortcuts" instead.
