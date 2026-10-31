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
  String get ingestToken => 'Ingest token';

  @override
  String get tokenScreenTitle => 'Ingest token';

  @override
  String get tokenIntro =>
      'The iOS Shortcut sends each bank SMS to this URL with the token in the X-Ingest-Token header.';

  @override
  String get ingestUrl => 'URL';

  @override
  String get ingestHeader => 'Header';

  @override
  String get tokenStatus => 'Status';

  @override
  String get tokenNone => 'No active token';

  @override
  String tokenActive(String created) {
    return 'Active, created $created';
  }

  @override
  String tokenLastUsed(String time) {
    return 'Last message received $time';
  }

  @override
  String get tokenNeverUsed => 'No message received yet';

  @override
  String get tokenGenerate => 'Create new token';

  @override
  String get tokenRotate => 'Replace token';

  @override
  String get tokenConfirmTitle => 'Replace the token?';

  @override
  String get tokenConfirmBody =>
      'The old token stops working immediately. You will need to update your Shortcuts.';

  @override
  String get tokenShownOnce => 'Copy this token now. It is shown only once.';

  @override
  String get tokenCopied => 'Copied';

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
  String get gapsTitle => 'Possible gaps';

  @override
  String get gapsIntro =>
      'When each sender last reached the app. A long silence may mean a Shortcut is off.';

  @override
  String get gapsNever => 'Nothing received yet';

  @override
  String gapsLast(String when) {
    return 'Last message $when';
  }

  @override
  String gapsDays(int days) {
    return '$days days ago';
  }

  @override
  String get gapsToday => 'today';

  @override
  String get gapsEmpty => 'No messages yet';

  @override
  String get sar => 'SAR';

  @override
  String get loadFailed => 'Could not load. Pull to retry.';
}
