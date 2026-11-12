# Redesign batch 1: Home, tab bar, failed-to-load, Insights bars

**Owner rule (2026-11-12):** where the current app and the redesign mockups differ, the redesign wins. This reverses two stage 1 decisions: Home's budget ring becomes the mockup's bar, and only the selected tab shows its name.

Owner's batch plan (his screenshots and comments, 2026-11-12): 1 Home and tab bar (this PR), 2 Activity (chips, floating add button, transaction screen, filter sheet, category picker, Quick add), 3 Bills (Add a bill tiles, bill sheet, mark-as-paid sheet), 4 More (account card, groups, SMS capture status, icon sheets, delete), 5 Needs review, AI chat, monthly budget sheet.

## Built
- **Tab bar:** the selected tab is a wide emerald pill with its icon and name; the others show their icon only. Bills uses the receipt icon, Insights the bar-chart icon. Pill and widths slide to the tapped tab.
- **Home hero:** "Spent this month", the amount, a white panel with Left to spend and Today (without a budget: vs last month and Today), the gold budget bar (red when over) and "69% of your SAR 6,000 budget". The ring is gone.
- **Chips under the hero:** "3 to review" (gold), "Dining at 82%" / "Budget at 85%" (coral), "... over budget" (red). They replace the alert card. Budget chips open Insights.
- **New account:** the logo card "Waiting for your first SMS" with Set up SMS capture and Add one by hand, and the compact Getting started card (gold target tile, progress, Hide; tapping the title shows the steps).
- **Could not load** on every tab and on Bank accounts: outlined card, coral warning tile, title, "Check your connection. Your saved numbers are still on Home.", Try again.
- **Insights bars** (`OutlinedBar`) grow in like the Bills bar.
- Home's title is "Home" (was "Overview").

## Not built yet
- The bell button at the top of Home: the mockup does not say what it opens. Waiting for the owner.
