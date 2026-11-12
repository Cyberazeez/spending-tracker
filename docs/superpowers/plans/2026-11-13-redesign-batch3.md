# Redesign batch 3: Bills

Owner's screenshots and comments: "add bill screen should look like this then get to more detail in the same design if start from scratch is tapped", "when tapping a bill (bill sheet)", "Mark as paid should ask for confirmation sheet like this and should match it". Owner rule: the redesign wins.

## Built
- **Add a bill** (the + on Bills): "Pick a starting point", four tiles (Bill, Fixed cost, Loan, Card statement) and "Start from scratch". A tile opens the bill form with its kind chosen (a bill's amount is estimated); Start from scratch opens it empty.
- **Bill sheet** (tap a bill; replaces the list of actions): tile, name, "Due 6 Nov · 5 days late", status pill, the amount (tap to change it), Amount Fixed / Estimated, Repeats, Due day (wheel), Remind me (on the day, 1 to 7 days before), Active (off stops the bill, asks first); Mark as paid (Re-open once paid); Skip this month, Edit details, Stop this bill. Settings save as they change (`save_my_obligation`, unchanged).
- **Mark as paid** asks first in the centred sheet: the bill's tile, "Mark Mobile bill as paid?", "A payment of SAR 230.00 on Mon 2 Nov looks like this bill." for a payment the server matched ("Not this payment" rejects it), else the amount and due date. The suggested-payment card's Confirm uses the same sheet.
- Confirm and notice sheets can now carry a centred icon tile (`icon:`), used next by Delete my account and Password changed.

## Changed or not built
- **Card statement tile:** the server only creates bills, fixed costs and loans (`save_my_obligation` refuses `card_statement`; statement bills are set up by migration today). The tile starts a bill named "Card statement" whose amount arrives later, which is the closest the app can do without a backend change. Owner decision: add real card-statement creation (backend) later?
