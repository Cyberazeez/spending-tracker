// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Spending';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTransactions => 'Transactions';

  @override
  String get tabObligations => 'Obligations';

  @override
  String get tabInsights => 'Insights';

  @override
  String get tabMore => 'More';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get signOut => 'Sign out';

  @override
  String get fieldRequired => 'Required';

  @override
  String get invalidCredentials => 'Wrong email or password.';

  @override
  String get networkError =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get lockTitle => 'Locked';

  @override
  String get lockBody => 'Unlock to see your spending.';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock Spending';

  @override
  String get unlockFailed => 'Could not unlock. Try again.';

  @override
  String get emptyHomeTitle => 'Waiting for your first SMS';

  @override
  String get emptyHomeBody =>
      'Set up the iOS Shortcut in More, then every bank SMS shows up here.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get captureStatus => 'SMS capture';

  @override
  String captureWaiting(int count) {
    return '$count waiting';
  }

  @override
  String get captureNone => 'Nothing waiting';

  @override
  String get copy => 'Copy';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get done => 'Done';

  @override
  String get tryAgain => 'Try again';

  @override
  String get genericError => 'Something went wrong. Try again.';

  @override
  String get txTitle => 'Transactions';

  @override
  String get txEmptyTitle => 'No transactions yet';

  @override
  String get txEmptyBody =>
      'Bank SMS appear here once your Shortcut is running. You can also add one by hand.';

  @override
  String get txInternal => 'Internal';

  @override
  String get txFee => 'Fee';

  @override
  String txOpenReview(int count) {
    return 'Needs review ($count)';
  }

  @override
  String get typePurchase => 'Purchase';

  @override
  String get typeRefund => 'Refund';

  @override
  String get typeAtm => 'ATM withdrawal';

  @override
  String get typeTransferOut => 'Transfer out';

  @override
  String get typeTransferIn => 'Transfer in';

  @override
  String get typeSalary => 'Salary';

  @override
  String get typeBill => 'Bill payment';

  @override
  String get typeCardPayment => 'Card payment';

  @override
  String get typeWalletTopup => 'Wallet top-up';

  @override
  String get typeLoan => 'Loan instalment';

  @override
  String get typeFee => 'Fee';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get qaAmount => 'Amount (SAR)';

  @override
  String get qaMerchant => 'Merchant or note';

  @override
  String get qaSpent => 'Spent';

  @override
  String get qaReceived => 'Received';

  @override
  String get qaWhen => 'When';

  @override
  String get qaSave => 'Save';

  @override
  String get qaAmountInvalid => 'Enter an amount like 25 or 25.50';

  @override
  String get qaSaveFailed => 'Could not save. Try again.';

  @override
  String get reviewTitle => 'Needs review';

  @override
  String get reviewEmpty => 'Nothing to review';

  @override
  String get reviewEmptyBody => 'Every message was read correctly.';

  @override
  String reviewFrom(String sender) {
    return 'From $sender';
  }

  @override
  String get reviewConvert => 'Add as transaction';

  @override
  String get reviewDismiss => 'Not a transaction';

  @override
  String get reviewLoadFailed => 'Could not load messages.';

  @override
  String get sar => 'SAR';

  @override
  String get loadFailed => 'Could not load. Pull to retry.';

  @override
  String get searchHint => 'Search merchants';

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterAll => 'All categories';

  @override
  String get filterUncategorized => 'Uncategorized only';

  @override
  String get filterHideInternal => 'Hide internal moves';

  @override
  String get filterShowInternal => 'Show internal moves';

  @override
  String get filterClear => 'Clear filters';

  @override
  String get categoryNone => 'No category';

  @override
  String get categoryPickTitle => 'Category';

  @override
  String get categoryRemove => 'Remove category';

  @override
  String applyPastTitle(int count) {
    return 'Apply to $count other transactions?';
  }

  @override
  String applyPastBody(String merchant, String category) {
    return 'Always file \"$merchant\" under $category, and change the past ones too?';
  }

  @override
  String get applyPastYes => 'Change all';

  @override
  String get applyPastNo => 'Only future ones';

  @override
  String get categorySaveFailed => 'Could not change the category. Try again.';

  @override
  String get noMatches => 'No transactions match';

  @override
  String get obSegUpcoming => 'Upcoming';

  @override
  String get obSegOverdue => 'Overdue';

  @override
  String get obSegHistory => 'History';

  @override
  String get obCommitted => 'Still to pay in the next 30 days';

  @override
  String obDue(String date) {
    return 'Due $date';
  }

  @override
  String obExpected(String amount) {
    return 'Expected $amount';
  }

  @override
  String obPaidAmount(String amount) {
    return 'Paid $amount';
  }

  @override
  String get obStatusPending => 'Pending';

  @override
  String get obStatusOverdue => 'Overdue';

  @override
  String get obStatusPaid => 'Paid';

  @override
  String get obStatusSkipped => 'Skipped';

  @override
  String get obMarkPaid => 'Mark as paid';

  @override
  String get obSkip => 'Skip this one';

  @override
  String get obReopen => 'Re-open';

  @override
  String obSuggestTitle(String name) {
    return 'Mark \"$name\" as paid with this payment?';
  }

  @override
  String get obConfirm => 'Confirm';

  @override
  String get obNotThis => 'Not this';

  @override
  String get obEmptyUpcoming => 'Nothing due in the next 30 days';

  @override
  String get obEmptyOverdue => 'Nothing overdue';

  @override
  String get obEmptyHistory => 'No history yet';

  @override
  String get obMonthTitle => 'This month';

  @override
  String get obMonthCommitted => 'Obligations this month';

  @override
  String obGroupThis(String month) {
    return 'This month · $month';
  }

  @override
  String obGroupNext(String month) {
    return 'Next month · $month';
  }

  @override
  String obGroupLater(String month, String year) {
    return '$month $year';
  }

  @override
  String get obMonthCommittedNote => 'Paid and still to pay';

  @override
  String obUsually(String min, String max) {
    return 'Usually $min to $max';
  }

  @override
  String get obEditAmount => 'Edit amount';

  @override
  String get obEditAmountPrompt => 'Amount in SAR';

  @override
  String get obAmountInvalid => 'Enter an amount like 700 or 1,250.50';

  @override
  String get obMonthOther => 'Everything else';

  @override
  String get obSaveFailed => 'Could not save. Try again.';

  @override
  String get insMonthlyBudget => 'Monthly budget';

  @override
  String get insMonthlyBudgetNotSet => 'Not set';

  @override
  String insMonthlyBudgetUsed(String percent) {
    return '$percent% used';
  }

  @override
  String get insMonthlyBudgetPrompt => 'Monthly budget in SAR';

  @override
  String get homeToday => 'Spent today';

  @override
  String get homeBudgetUsed => 'Monthly budget used';

  @override
  String homeMonthlyWarn(String percent) {
    return 'Monthly budget at $percent%';
  }

  @override
  String get homeMonthlyOver => 'Over the monthly budget';

  @override
  String get remindersTitle => 'Bill reminders';

  @override
  String get remindersOn => 'On';

  @override
  String get remindersOff => 'Off';

  @override
  String get remindersHelp =>
      'A notification at 9:00 about two days before a bill or payment is due.';

  @override
  String get remindersDenied =>
      'Notifications are turned off for this app. Turn them on in iPhone Settings, then try again.';

  @override
  String reminderBody(String date) {
    return 'Due $date';
  }

  @override
  String reminderBodyAmount(String date, String amount) {
    return 'Due $date · about $amount';
  }

  @override
  String get insThisMonth => 'This month';

  @override
  String get insSpent => 'Spent so far';

  @override
  String get insVsLast => 'Same day last month';

  @override
  String insUp(String amount) {
    return 'Up $amount';
  }

  @override
  String insDown(String amount) {
    return 'Down $amount';
  }

  @override
  String get insSame => 'About the same';

  @override
  String get insNoCompare =>
      'Nothing to compare yet: no spending recorded for the same days last month';

  @override
  String get insSavings => 'Savings rate';

  @override
  String insSavingsValue(String pct) {
    return '$pct%';
  }

  @override
  String insSalaryAbove(String amount) {
    return 'Salary is above your base of $amount';
  }

  @override
  String get insByCategory => 'By category';

  @override
  String get insTopMerchants => 'Top merchants';

  @override
  String get insSpikes => 'Spending spikes';

  @override
  String insSpikeLine(String amount, String avg) {
    return '$amount this month, usually $avg';
  }

  @override
  String get insSubs => 'Subscriptions';

  @override
  String insSubsTotal(String amount) {
    return '$amount a month';
  }

  @override
  String get insBudgets => 'Budgets';

  @override
  String get insBudgetSet => 'Set a budget';

  @override
  String get insBudgetRemove => 'Remove budget';

  @override
  String get insBudgetPrompt => 'Monthly limit in SAR';

  @override
  String get insBudgetInvalid => 'Enter an amount like 1500 or 1,500.50';

  @override
  String insBudgetWarn(String name, String pct) {
    return '$name is at $pct% of its budget';
  }

  @override
  String insBudgetOver(String name) {
    return '$name is over budget';
  }

  @override
  String insOfLimit(String limit) {
    return 'of $limit';
  }

  @override
  String get insEmpty => 'Not enough data yet';

  @override
  String get insEmptyBody =>
      'Spending shows up here once your first transactions arrive.';

  @override
  String get insSave => 'Save';

  @override
  String obPlanNote(String name, String n, String total, String amount) {
    return 'Includes $name instalment $n of $total ($amount)';
  }

  @override
  String get homeNext => 'Next up';

  @override
  String get homeNothingDue => 'Nothing due soon';

  @override
  String homeStale(String days) {
    return 'No SMS for $days days. Check that your Shortcuts are still on.';
  }

  @override
  String homeTop(String name, String amount) {
    return 'Top category: $name ($amount)';
  }

  @override
  String get homeAlerts => 'Budgets';

  @override
  String get homeAddTx => 'Add a transaction';

  @override
  String get captureSetupTitle => 'Set up SMS capture';

  @override
  String get captureIntro => 'Do this once:';

  @override
  String get captureStep1 => 'Shortcuts > Automation > + > Message';

  @override
  String get captureStep2 => 'Message contains “SAR”, Run Immediately';

  @override
  String get captureStep3 => 'Add action “Add bank message” (this app\'s icon)';

  @override
  String get captureStep4 => 'Set Message and Sender to the matching variables';

  @override
  String get captureStep5 => 'Done. Bank SMS are added by themselves.';

  @override
  String get captureOpenShortcuts => 'Open Shortcuts';

  @override
  String get captureStatusHeader => 'Status';

  @override
  String get captureSendNow => 'Send waiting messages now';

  @override
  String get homeOverview => 'Overview';

  @override
  String get homeSpentThisMonth => 'Spent this month';

  @override
  String get homeLast7 => 'Last 7 days';

  @override
  String get homeWhereItWent => 'Where it went';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeNextBills => 'Next bills';

  @override
  String get homeAllBills => 'All bills';

  @override
  String get homeLeftToSpend => 'Left to spend';

  @override
  String get homeVsLastMonth => 'vs last month';

  @override
  String get homeSetBudget => 'Set a monthly budget';

  @override
  String get homeTodayShort => 'Today';

  @override
  String get homeSameShort => 'Same';

  @override
  String homeOfBudget(String amount) {
    return 'of $amount budget';
  }

  @override
  String homeLower(String percent) {
    return '$percent% lower';
  }

  @override
  String homeHigher(String percent) {
    return '$percent% higher';
  }

  @override
  String homeToReview(int count) {
    return '$count to review';
  }

  @override
  String homeWeekTotal(String amount) {
    return '$amount total';
  }

  @override
  String homeBarLabel(String amount, String weekday) {
    return 'Spent $amount on $weekday';
  }

  @override
  String homeDueIn(int days) {
    return 'Due in $days days';
  }

  @override
  String get homeDueTomorrow => 'Due tomorrow';

  @override
  String get homeDueToday => 'Due today';

  @override
  String get groupFood => 'Food';

  @override
  String get groupTransport => 'Transport';

  @override
  String get groupHomeBills => 'Home and bills';

  @override
  String get groupHorse => 'Horse';

  @override
  String get groupLifestyle => 'Lifestyle';

  @override
  String get groupSubscriptions => 'Subscriptions';

  @override
  String get groupHealth => 'Health';

  @override
  String get groupMoney => 'Money';

  @override
  String get groupOther => 'Other';

  @override
  String get txToday => 'Today';

  @override
  String get txYesterday => 'Yesterday';

  @override
  String get txChooseCategory => 'Choose category';

  @override
  String get txChipAll => 'All';

  @override
  String get txChipNoCategory => 'No category';

  @override
  String get txChipHideInternal => 'Hide internal';

  @override
  String get insTrendTitle => 'This month vs last month';

  @override
  String get insLegendThis => 'This month';

  @override
  String get insLegendLast => 'Last month';

  @override
  String get insMonthsTitle => 'Last 4 months';

  @override
  String insBudgetLine(String amount) {
    return 'Budget $amount';
  }

  @override
  String get insWhereTitle => 'Where it goes';

  @override
  String insTrendLabel(String now, String before) {
    return '$now so far this month, $before by the same day last month';
  }

  @override
  String insMonthBarLabel(String month, String amount) {
    return '$month: $amount';
  }

  @override
  String insVisits(int count) {
    return '$count visits';
  }

  @override
  String get insVisit => '1 visit';

  @override
  String get insSavingsRateLabel => 'Savings rate';

  @override
  String get insSpikeBadge => 'Spending spike';

  @override
  String insSubsServices(int count) {
    return '$count services a month';
  }

  @override
  String get obNew => 'New obligation';

  @override
  String get obEditTitle => 'Edit obligation';

  @override
  String get obfName => 'Name';

  @override
  String get obfType => 'Type';

  @override
  String get obfKindBill => 'Bill';

  @override
  String get obfKindFixed => 'Fixed';

  @override
  String get obfKindLoan => 'Loan';

  @override
  String get obfAmountFixed => 'Fixed amount';

  @override
  String get obfAmountEstimated => 'Estimated';

  @override
  String get obfAmount => 'Amount in SAR';

  @override
  String get obfAmountBillNote =>
      'Optional for a bill: leave it empty and the bill message sets each month\'s amount.';

  @override
  String get obfRepeats => 'Repeats';

  @override
  String get obfMonthly => 'Monthly';

  @override
  String get obfQuarterly => 'Every 3 months';

  @override
  String get obfAnnual => 'Yearly';

  @override
  String get obfDueDay => 'Due day';

  @override
  String get obfDueDayNote => 'Short months use their last day.';

  @override
  String get obfStartMonth => 'First due month';

  @override
  String get obfGrace => 'Grace days';

  @override
  String get obfLead => 'Remind days before';

  @override
  String get obfCategory => 'Category';

  @override
  String get obfNoCategory => 'None';

  @override
  String get obfMatchWords => 'Match words';

  @override
  String get obfMatchHint =>
      'e.g. gym club, stc (up to 5, separated by commas)';

  @override
  String get obfTolerance => 'Amount tolerance %';

  @override
  String get obfAuto => 'Mark paid automatically';

  @override
  String get obfAutoNote =>
      'Off: a matching payment is only suggested for you to confirm.';

  @override
  String get obfSave => 'Save';

  @override
  String get obfNameRequired => 'Enter a name (up to 60 letters).';

  @override
  String get obfWordsInvalid => 'Up to 5 words, each up to 30 letters.';

  @override
  String get obEditDetails => 'Edit details';

  @override
  String get obStop => 'Stop tracking';

  @override
  String obStopConfirm(String name) {
    return '$name will stop appearing. Paid history stays.';
  }

  @override
  String get obAddHint => 'Add an obligation';

  @override
  String get obfNameTaken => 'You already have an obligation with this name.';

  @override
  String get aiTitle => 'AI assistant';

  @override
  String get aiSubtitle =>
      'Sends only totals and merchant names. Never message text, names or account numbers.';

  @override
  String get aiTipsTitle => 'AI tips';

  @override
  String get aiTipsGet => 'Get tips';

  @override
  String get aiTipsRefresh => 'Refresh tips';

  @override
  String get aiTipsEmpty => 'Get savings tips based on this month\'s totals.';

  @override
  String get aiTipsNote =>
      'Based on totals only. Check the numbers before acting.';

  @override
  String get aiTipsNone => 'No tips this time.';

  @override
  String aiSuggestTitle(String n) {
    return '$n transactions have no category';
  }

  @override
  String get aiSuggestAction => 'Suggest with AI';

  @override
  String aiSuggestDone(String n) {
    return 'Categorised $n transactions. Tap “AI suggested” to review them.';
  }

  @override
  String get aiSuggestNone => 'Nothing to categorise yet.';

  @override
  String get aiReasonDisabled => 'AI is off. Turn it on in More.';

  @override
  String get aiReasonNoKey => 'AI is not set up on the server yet.';

  @override
  String get aiReasonCap =>
      'This month\'s AI budget is used up. It resets next month.';

  @override
  String get aiReasonOffline => 'No connection. Try again.';

  @override
  String get aiReasonFailed => 'Could not get an answer. Try again later.';

  @override
  String get txAiTag => 'AI';

  @override
  String get txChipAi => 'AI suggested';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountSecurity => 'Security';

  @override
  String get accountSecurityHint => 'Change password';

  @override
  String get accountPrivacy => 'Privacy';

  @override
  String get accountName => 'Name';

  @override
  String get accountNameHint => 'Your name';

  @override
  String get accountSave => 'Save';

  @override
  String get accountNameTooLong => 'Use up to 60 letters.';

  @override
  String get accountEmailInvalid => 'Enter a valid email address.';

  @override
  String get accountEmailSent =>
      'Check your new address for a confirmation link. The old one stays until you use it.';

  @override
  String get accountSaveFailed => 'Could not save. Try again.';

  @override
  String get secChangePassword => 'Change password';

  @override
  String get secCurrent => 'Current password';

  @override
  String get secNew => 'New password';

  @override
  String get secConfirm => 'Repeat new password';

  @override
  String get secRulesHint => 'At least 8 characters.';

  @override
  String get secWrongCurrent => 'The current password is wrong.';

  @override
  String get secTooShort => 'Use at least 8 characters.';

  @override
  String get secMismatch => 'The two passwords do not match.';

  @override
  String get secSame => 'Choose a different password.';

  @override
  String get secDone => 'Password changed.';

  @override
  String get secNote =>
      'This also resets SMS capture and the widget on this phone. They reconnect by themselves.';

  @override
  String get privacyBody =>
      'Your data is stored in your own account and only you can read it. More options will appear here soon.';

  @override
  String get moreAccount => 'Account';

  @override
  String get signUpTitle => 'Create account';

  @override
  String get signUpLink => 'Create account';

  @override
  String get signUpNameRequired => 'Enter your name (up to 60 letters).';

  @override
  String get signUpEmailTaken =>
      'This email already has an account. Sign in instead.';

  @override
  String get signUpDisabled => 'Sign-up is closed right now. Ask the owner.';

  @override
  String get signUpCheckEmail =>
      'Check your email and tap the confirmation link, then come back and sign in.';

  @override
  String get signUpWeak =>
      'That password is too weak. Use at least 8 characters and mix letters and numbers.';

  @override
  String get signUpTryLater =>
      'Could not create the account right now. Try again in a few minutes.';

  @override
  String get signUpBackToSignIn => 'Back to sign in';

  @override
  String get accountBanks => 'Bank accounts';

  @override
  String get accountBanksShort => 'Your own accounts and cards';

  @override
  String get accountBanksHint =>
      'List your own accounts, cards and wallets so moving money between them is not counted as spending.';

  @override
  String get banksEmpty => 'No accounts yet.';

  @override
  String get bankAdd => 'Add account';

  @override
  String get bankPick => 'Bank';

  @override
  String get bankKind => 'Type';

  @override
  String get bankLast4 => 'Last 4 digits';

  @override
  String get bankLabelOptional => 'Name (optional)';

  @override
  String get bankSave => 'Add';

  @override
  String get bankLast4Invalid => 'Enter exactly 4 digits.';

  @override
  String get bankDuplicate => 'This account is already in the list.';

  @override
  String get bankRemove => 'Remove';

  @override
  String bankRemoveConfirm(String name) {
    return 'Remove $name?';
  }

  @override
  String get kindAccount => 'Account';

  @override
  String get kindDebit => 'Debit card';

  @override
  String get kindCredit => 'Credit card';

  @override
  String get kindWallet => 'Wallet';

  @override
  String get welcomeTitle => 'Get started';

  @override
  String get welcomeHide => 'Hide';

  @override
  String welcomeProgress(String done, String total) {
    return '$done of $total done';
  }

  @override
  String get welcomeAccounts => 'Add your bank accounts';

  @override
  String get welcomeCapture => 'Set up SMS capture';

  @override
  String get welcomeBudget => 'Set a monthly budget';

  @override
  String get deleteAccountRow => 'Delete my account';

  @override
  String get deleteTitle => 'Delete account';

  @override
  String get deleteWarn =>
      'This permanently deletes your account and all your data: transactions, bills, budgets and settings. It cannot be undone.';

  @override
  String get deleteWord => 'DELETE';

  @override
  String deleteTypeWord(String word) {
    return 'Type $word to confirm';
  }

  @override
  String deleteWordMismatch(String word) {
    return 'Type $word exactly to confirm.';
  }

  @override
  String get deletePassword => 'Your password';

  @override
  String get deleteButton => 'Delete my account';

  @override
  String get deleteWrongPassword => 'The password is wrong.';

  @override
  String get deleteTooMany => 'Too many tries. Try again tomorrow.';

  @override
  String get deleteFailed =>
      'Could not delete. Check your connection and try again.';
}
