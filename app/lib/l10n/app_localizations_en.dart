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
  String get tabTransactions => 'Activity';

  @override
  String get tabObligations => 'Bills';

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
  String get emailNotConfirmed =>
      'Confirm your email first. Open the link we sent to your inbox.';

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
      'Set up SMS capture once and every purchase shows up here by itself.';

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
  String captureLastOk(String time) {
    return 'Last sent $time';
  }

  @override
  String captureLastFailed(String code) {
    return 'Last send failed ($code)';
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
  String get txTitle => 'Activity';

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
  String get qaAmount => 'Amount (⃁)';

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
  String get aiParseTitle => 'Read unknown banks with AI';

  @override
  String get aiParseSubtitle =>
      'For banks the app does not know yet. The text of that one message is sent to the AI with numbers and names removed. Transfers are never sent.';

  @override
  String get aiParseAskTitle => 'Let AI read unknown bank messages?';

  @override
  String get aiParseAskBody =>
      'When a message comes from a bank the app does not know yet, its text is sent to Anthropic\'s AI so it can become a transaction. Balances, account and phone numbers, IBANs, emails and links are removed first. Transfers and one-time codes are never sent. You check each reading before it is trusted. You can turn this off at any time.';

  @override
  String get aiParseAskConfirm => 'Turn on';

  @override
  String get aiReadHeader => 'Read by AI: please check';

  @override
  String get aiReadOk => 'Looks right';

  @override
  String get aiReadWrong => 'Wrong: remove it';

  @override
  String get aiReadSheetBody =>
      'The AI made this transaction from the message below. Is it right?';

  @override
  String get reviewConvert => 'Add as transaction';

  @override
  String get reviewDismiss => 'Not a transaction';

  @override
  String get reviewLoadFailed => 'Could not load messages.';

  @override
  String get sar => '⃁';

  @override
  String get loadFailed => 'Could not load';

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
  String get obEditAmountPrompt => 'Amount in ⃁';

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
  String get insMonthlyBudgetPrompt => 'Monthly budget in ⃁';

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
  String get insBudgetPrompt => 'Monthly limit in ⃁';

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
  String get captureGuideOpen => 'Show me how, step by step';

  @override
  String get captureGuideTitle => 'Add the shortcut';

  @override
  String get captureGuideNext => 'Next';

  @override
  String get captureGuideSkip => 'Skip';

  @override
  String get captureGuideBack => 'Back';

  @override
  String get captureGuideDone => 'Done';

  @override
  String captureGuideStepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get captureGuide1Title => 'Open Automation';

  @override
  String get captureGuide1Body =>
      'In the Shortcuts app, tap Automation, then the + button.';

  @override
  String get captureGuide2Title => 'Choose Message';

  @override
  String get captureGuide2Body =>
      'Pick Message (“When I get a message from…”).';

  @override
  String get captureGuide3Title => 'Set the filter';

  @override
  String get captureGuide3Body =>
      'Change the filter to Message contains and type SAR. Turn Automation on (Run Immediately) and Confirm Before Run off, then tap Next.';

  @override
  String get captureGuide4Title => 'Add the action';

  @override
  String get captureGuide4Body =>
      'Tap New Blank Automation, search “Add bank” and pick Add bank message (the Halala icon).';

  @override
  String get captureGuide5Title => 'Fill the two fields';

  @override
  String get captureGuide5Body =>
      'Add Message from Sender: tap the first field and choose the Message variable, then tap the second field to choose Sender.';

  @override
  String get captureGuide6Title => 'Pick Sender';

  @override
  String get captureGuide6Body =>
      'Choose the Message variable, then tick Sender in the list and tap Done.';

  @override
  String get captureGuide7Title => 'All set';

  @override
  String get captureGuide7Body =>
      'Your automation is in the list with the switch on. Messages that write the currency as ريال or SR need their own copy with that word instead of SAR.';

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
  String homeBudgetLine(String percent, String amount) {
    return '$percent% of your $amount budget';
  }

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
  String get groupFamily => 'Family';

  @override
  String get groupHorse => 'Horse';

  @override
  String get groupLifestyle => 'Lifestyle';

  @override
  String get groupSubscriptions => 'Subscriptions';

  @override
  String get groupHealth => 'Health and care';

  @override
  String get groupMoney => 'Money and fees';

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
  String get insTrendNoLast =>
      'No spending last month on these days, so only this month is drawn.';

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
  String get obfAmount => 'Amount in ⃁';

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
  String get aiPaidOnly => 'Part of the paid plan. Coming soon.';

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
  String get txDelete => 'Delete';

  @override
  String get txDeleteTitle => 'Delete this transaction?';

  @override
  String get txDeleteBody =>
      'It will no longer be counted in your budget, your insights or anywhere else in the app. This can\'t be undone.';

  @override
  String get txDeleteFailed =>
      'Could not delete it. Check your connection and try again.';

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
  String get legalTermsOfUse => 'Terms of Use';

  @override
  String get legalPrivacyPolicy => 'Privacy policy';

  @override
  String get legalSupport => 'Support';

  @override
  String get signUpAgreePrefix => 'I agree to the';

  @override
  String get signUpAgreeAnd => 'and the';

  @override
  String get signUpAgreeRequired =>
      'Tick the box to agree before creating an account.';

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
  String get secDone => 'Password changed';

  @override
  String get secNote =>
      'This also resets SMS capture and the widget on this phone. They reconnect by themselves.';

  @override
  String get privacyBody =>
      'Your data is stored in your own account and only you can read it. More options will appear here soon.';

  @override
  String get moreAccount => 'Account';

  @override
  String get forgotLink => 'Forgot password?';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotIntro =>
      'Enter the email you signed up with. We will send you a link to choose a new password.';

  @override
  String get forgotSend => 'Send reset link';

  @override
  String get forgotSent =>
      'If that email has an account, a reset link is on its way. Check your inbox and spam folder.';

  @override
  String forgotWait(int seconds) {
    return 'Send again in $seconds s';
  }

  @override
  String get forgotTryLater =>
      'Too many requests right now. Try again in a few minutes.';

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetSave => 'Save password';

  @override
  String get orDivider => 'or';

  @override
  String get appleSignIn => 'Sign in with Apple';

  @override
  String get appleFailed => 'Could not sign in with Apple. Try again.';

  @override
  String get linkExpiredTitle => 'This link has expired';

  @override
  String get linkExpiredBody =>
      'The email link was already used or is too old. Request a new one and open only the newest email.';

  @override
  String get linkExpiredOk => 'Request a new link';

  @override
  String get resetDone => 'Password changed. You are signed in.';

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
  String get signUpResend => 'Send the email again';

  @override
  String signUpCheckEmailTo(String email) {
    return 'We sent a confirmation link to $email. Tap it, and you are signed in.';
  }

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
  String get bankEdit => 'Edit account';

  @override
  String get bankSaveEdit => 'Save';

  @override
  String get bankRemoveNote =>
      'Your past transactions are kept and keep counting.';

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
  String get welcomeTitle => 'Getting started';

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
      'Your account and all your data (transactions, bills, budgets and settings) will be permanently deleted after 30 days. Sign in again before then and nothing is deleted.';

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
  String get deleteApple =>
      'You signed in with Apple, so there is no password. After you confirm, Apple asks you to sign in once more to prove it is you.';

  @override
  String get deleteWrongApple =>
      'That Apple ID is not the one for this account.';

  @override
  String get secNoPassword =>
      'You sign in with Apple, so this account has no password to change.';

  @override
  String get deleteWrongPassword => 'The password is wrong.';

  @override
  String get deleteTooMany => 'Too many tries. Try again tomorrow.';

  @override
  String get deleteFailed =>
      'Could not delete. Check your connection and try again.';

  @override
  String get deleteSureTitle => 'Are you sure?';

  @override
  String get deleteSureBody =>
      'All your data will be lost. Signing in again within 30 days cancels the deletion.';

  @override
  String get deleteSureConfirm => 'Yes, delete it';

  @override
  String get reactivatedTitle => 'Welcome back';

  @override
  String get reactivatedBody =>
      'Your account is active again and the deletion is cancelled. All your data is still here.';

  @override
  String get reactivatedOk => 'OK';

  @override
  String get categorySearch => 'Search categories';

  @override
  String get categorySuggested => 'Suggested for this merchant';

  @override
  String get categoryNoMatch => 'No category matches';

  @override
  String get aiChatTitle => 'Ask about your spending';

  @override
  String get aiChatOpen => 'Ask a question';

  @override
  String get aiChatHint => 'Ask about a category or a budget';

  @override
  String get aiChatSend => 'Send';

  @override
  String get aiChatIntro =>
      'Ask about this month\'s spending, a category or a budget. I only see totals, never merchants or messages.';

  @override
  String get aiChatThinking => 'Thinking…';

  @override
  String get aiChatNoData =>
      'There is nothing to talk about yet. Come back once some spending is recorded.';

  @override
  String get aiChatPromptCut => 'Where can I cut spending?';

  @override
  String get aiChatPromptBudget => 'Am I on track with my budgets?';

  @override
  String get aiChatPromptLast => 'How does this month compare with last month?';

  @override
  String aiChatPromptCategory(String category) {
    return 'Why is $category so high?';
  }

  @override
  String get aiChatRetry => 'Try again';

  @override
  String get aiTipsTapHint => 'Tap to ask about a category or a budget';

  @override
  String obCycleStill(String month) {
    return '$month · still to pay';
  }

  @override
  String obCyclePaid(String paid, String total, String done, String count) {
    return 'Paid $paid of $total · $done of $count bills';
  }

  @override
  String obUnpaidBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unpaid from earlier months',
      one: '1 unpaid from an earlier month',
    );
    return '$_temp0';
  }

  @override
  String obNextSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills',
      one: '1 bill',
    );
    return '$_temp0';
  }

  @override
  String obNextNote(String amount) {
    return 'About $amount · tap to see them';
  }

  @override
  String get homeAddByHand => 'Add one by hand';

  @override
  String homeChipBudget(String name, String pct) {
    return '$name at $pct%';
  }

  @override
  String homeChipOver(String name) {
    return '$name over budget';
  }

  @override
  String homeChipMonthly(String pct) {
    return 'Budget at $pct%';
  }

  @override
  String get homeChipMonthlyOver => 'Over budget';

  @override
  String get loadFailedBody =>
      'Check your connection. Your saved numbers are still on Home.';

  @override
  String get filterDate => 'Date';

  @override
  String get filterThisMonth => 'This month';

  @override
  String get filterLastMonth => 'Last month';

  @override
  String get filterCustom => 'Custom';

  @override
  String get filterAllTime => 'All time';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterBankCard => 'Bank or card';

  @override
  String get filterAllAccounts => 'All';

  @override
  String get filterNoCategoryOnly => 'No category only';

  @override
  String get filterIncludeTransfers => 'Include transfers between my accounts';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterFrom => 'From';

  @override
  String get filterTo => 'To';

  @override
  String get txChipAllBanks => 'All banks';

  @override
  String filterShow(int count) {
    return 'Show $count';
  }

  @override
  String txChipNoCategoryCount(int count) {
    return 'No category · $count';
  }

  @override
  String get txnTitle => 'Transaction';

  @override
  String get txnChangeCategory => 'Change category';

  @override
  String get txnCard => 'Card';

  @override
  String get txnSource => 'Source';

  @override
  String get txnLinkedBill => 'Linked bill';

  @override
  String get txnNone => 'None';

  @override
  String get txnNote => 'Note';

  @override
  String get txnAddNote => 'Add a note';

  @override
  String get txnOriginal => 'Original message';

  @override
  String get txnReport => 'Report a reading problem';

  @override
  String get txnSourceSms => 'Bank SMS';

  @override
  String get txnSourceManual => 'Added by hand';

  @override
  String get txnSourceAi => 'Read by AI';

  @override
  String get txnSourceCsv => 'Statement';

  @override
  String get txnNoCategory => 'No category';

  @override
  String get txnNoteFailed => 'Could not save the note. Try again.';

  @override
  String get txnMessageGone => 'The message is no longer stored.';

  @override
  String get qaAmountLabel => 'Amount';

  @override
  String get qaMerchantLabel => 'Merchant';

  @override
  String get qaMerchantHint => 'Where you paid';

  @override
  String get qaCategory => 'Category';

  @override
  String get qaDate => 'Date';

  @override
  String get qaTime => 'Time';

  @override
  String get qaPaidWith => 'Paid with';

  @override
  String get qaNote => 'Note';

  @override
  String get qaOptional => 'Optional';

  @override
  String get qaChoose => 'Choose';

  @override
  String get qaNotSet => 'Not set';

  @override
  String get txEmptyMonth => 'Nothing yet this month';

  @override
  String get addBillTitle => 'Add a bill';

  @override
  String get addBillIntro =>
      'Pick a starting point. You can change everything later.';

  @override
  String get addBillBill => 'Bill';

  @override
  String get addBillBillHint => 'Electricity, mobile, internet';

  @override
  String get addBillFixed => 'Fixed cost';

  @override
  String get addBillFixedHint => 'Rent, stable, school';

  @override
  String get addBillLoan => 'Loan';

  @override
  String get addBillLoanHint => 'Same amount each month';

  @override
  String get addBillScratch => 'Start from scratch';

  @override
  String bsDaysLate(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String get bsEveryMonth => 'Every month';

  @override
  String get bsRemindMe => 'Remind me';

  @override
  String get bsRemindOnDay => 'On the day';

  @override
  String bsRemindDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get bsActive => 'Active';

  @override
  String get bsSkipMonth => 'Skip this month';

  @override
  String get bsStopBill => 'Stop this bill';

  @override
  String bsPaidTitle(String name) {
    return 'Mark $name as paid?';
  }

  @override
  String bsPaidMatch(String amount, String date) {
    return 'A payment of $amount on $date looks like this bill.';
  }

  @override
  String bsPaidMatchNoDate(String amount) {
    return 'A payment of $amount looks like this bill.';
  }

  @override
  String bsPaidPlain(String amount, String date) {
    return '$amount due $date.';
  }

  @override
  String get bsYesPaid => 'Yes, mark as paid';

  @override
  String get bsNotThis => 'Not this payment';

  @override
  String get moreYourAccount => 'Your account';

  @override
  String get moreCategoriesRules => 'Categories and rules';

  @override
  String get secDoneBody =>
      'This phone reconnects SMS capture and the widget by itself.';

  @override
  String get deleteKeep => 'Keep my account';

  @override
  String get capWorking => 'Working';

  @override
  String get capNotSetUp => 'Not set up yet';

  @override
  String get capNotSetUpBody =>
      'Follow the steps to forward your bank messages.';

  @override
  String get capWaitingFirst => 'Waiting for the first message';

  @override
  String get capFailing => 'Not sending';

  @override
  String get capConnected => 'Connected';

  @override
  String get capNoMessages => 'No messages yet';

  @override
  String get capBills => 'Bill messages (900)';

  @override
  String get capPrivacy =>
      'Halala reads only bank messages your iPhone forwards with the shortcut. Nothing else leaves the phone.';

  @override
  String get rulesIntro =>
      'Purchases from these places always get this category. Delete a rule to stop it; past purchases keep their category.';

  @override
  String get rulesEmpty =>
      'No rules yet. When you change a category, Halala asks whether to always file that place there.';

  @override
  String rulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
      zero: 'No rules',
    );
    return '$_temp0';
  }

  @override
  String get rulesDeleteTitle => 'Delete this rule?';

  @override
  String rulesDeleteBody(String place, String category) {
    return '\"$place\" will no longer go to $category by itself. Past purchases keep their category.';
  }

  @override
  String get rulesDeleteYes => 'Delete rule';

  @override
  String get capOffline => 'No connection';

  @override
  String get capOfflineBody =>
      'Messages wait on the phone and go out when it is online.';

  @override
  String get capQueued => 'Waiting to send';

  @override
  String get aiAskTitle => 'Turn on the AI assistant?';

  @override
  String get aiAskConfirm => 'Turn on';

  @override
  String get aiAskBody =>
      'To answer questions and suggest savings, your totals and merchant names are sent to Anthropic\'s AI. Never message text, names or account numbers. You can turn this off at any time.';

  @override
  String get insBudgetRemoveThe => 'Remove the budget';

  @override
  String get reviewCouldNotRead => 'Could not read';

  @override
  String get reviewAdd => 'Add';

  @override
  String get reviewNotPurchase => 'Not a purchase';

  @override
  String get reviewTagNew => 'New message format';

  @override
  String get reviewTagUnsure => 'Not sure';

  @override
  String get reviewTagFailed => 'Could not read it';

  @override
  String get aiChatTry => 'Try asking';

  @override
  String get reviewDismissAsk => 'Not a purchase?';

  @override
  String get reviewDismissYes => 'Yes, hide it';
}
