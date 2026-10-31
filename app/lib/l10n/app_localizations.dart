import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get tabTransactions;

  /// No description provided for @tabObligations.
  ///
  /// In en, this message translates to:
  /// **'Obligations'**
  String get tabObligations;

  /// No description provided for @tabInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tabInsights;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get invalidCredentials;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get networkError;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your spending.'**
  String get lockBody;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Spending'**
  String get unlockReason;

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock. Try again.'**
  String get unlockFailed;

  /// No description provided for @emptyHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your first SMS'**
  String get emptyHomeTitle;

  /// No description provided for @emptyHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Set up the iOS Shortcut in More, then every bank SMS shows up here.'**
  String get emptyHomeBody;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @ingestToken.
  ///
  /// In en, this message translates to:
  /// **'Ingest token'**
  String get ingestToken;

  /// No description provided for @tokenScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingest token'**
  String get tokenScreenTitle;

  /// No description provided for @tokenIntro.
  ///
  /// In en, this message translates to:
  /// **'The iOS Shortcut sends each bank SMS to this URL with the token in the X-Ingest-Token header.'**
  String get tokenIntro;

  /// No description provided for @ingestUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get ingestUrl;

  /// No description provided for @ingestHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get ingestHeader;

  /// No description provided for @tokenStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tokenStatus;

  /// No description provided for @tokenNone.
  ///
  /// In en, this message translates to:
  /// **'No active token'**
  String get tokenNone;

  /// No description provided for @tokenActive.
  ///
  /// In en, this message translates to:
  /// **'Active, created {created}'**
  String tokenActive(String created);

  /// No description provided for @tokenLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last message received {time}'**
  String tokenLastUsed(String time);

  /// No description provided for @tokenNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'No message received yet'**
  String get tokenNeverUsed;

  /// No description provided for @tokenGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create new token'**
  String get tokenGenerate;

  /// No description provided for @tokenRotate.
  ///
  /// In en, this message translates to:
  /// **'Replace token'**
  String get tokenRotate;

  /// No description provided for @tokenConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the token?'**
  String get tokenConfirmTitle;

  /// No description provided for @tokenConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The old token stops working immediately. You will need to update your Shortcuts.'**
  String get tokenConfirmBody;

  /// No description provided for @tokenShownOnce.
  ///
  /// In en, this message translates to:
  /// **'Copy this token now. It is shown only once.'**
  String get tokenShownOnce;

  /// No description provided for @tokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get tokenCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get genericError;

  /// No description provided for @txTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get txTitle;

  /// No description provided for @txEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get txEmptyTitle;

  /// No description provided for @txEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Bank SMS appear here once your Shortcut is running. You can also add one by hand.'**
  String get txEmptyBody;

  /// No description provided for @txInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get txInternal;

  /// No description provided for @txFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get txFee;

  /// No description provided for @txOpenReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review ({count})'**
  String txOpenReview(int count);

  /// No description provided for @typePurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get typePurchase;

  /// No description provided for @typeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get typeRefund;

  /// No description provided for @typeAtm.
  ///
  /// In en, this message translates to:
  /// **'ATM withdrawal'**
  String get typeAtm;

  /// No description provided for @typeTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get typeTransferOut;

  /// No description provided for @typeTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get typeTransferIn;

  /// No description provided for @typeSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get typeSalary;

  /// No description provided for @typeBill.
  ///
  /// In en, this message translates to:
  /// **'Bill payment'**
  String get typeBill;

  /// No description provided for @typeCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card payment'**
  String get typeCardPayment;

  /// No description provided for @typeWalletTopup.
  ///
  /// In en, this message translates to:
  /// **'Wallet top-up'**
  String get typeWalletTopup;

  /// No description provided for @typeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan instalment'**
  String get typeLoan;

  /// No description provided for @typeFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get typeFee;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @qaAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (SAR)'**
  String get qaAmount;

  /// No description provided for @qaMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant or note'**
  String get qaMerchant;

  /// No description provided for @qaSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get qaSpent;

  /// No description provided for @qaReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get qaReceived;

  /// No description provided for @qaWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get qaWhen;

  /// No description provided for @qaSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get qaSave;

  /// No description provided for @qaAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 25 or 25.50'**
  String get qaAmountInvalid;

  /// No description provided for @qaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get qaSaveFailed;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get reviewTitle;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get reviewEmpty;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every message was read correctly.'**
  String get reviewEmptyBody;

  /// No description provided for @reviewFrom.
  ///
  /// In en, this message translates to:
  /// **'From {sender}'**
  String reviewFrom(String sender);

  /// No description provided for @reviewConvert.
  ///
  /// In en, this message translates to:
  /// **'Add as transaction'**
  String get reviewConvert;

  /// No description provided for @reviewDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not a transaction'**
  String get reviewDismiss;

  /// No description provided for @reviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages.'**
  String get reviewLoadFailed;

  /// No description provided for @gapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible gaps'**
  String get gapsTitle;

  /// No description provided for @gapsIntro.
  ///
  /// In en, this message translates to:
  /// **'When each sender last reached the app. A long silence may mean a Shortcut is off.'**
  String get gapsIntro;

  /// No description provided for @gapsNever.
  ///
  /// In en, this message translates to:
  /// **'Nothing received yet'**
  String get gapsNever;

  /// No description provided for @gapsLast.
  ///
  /// In en, this message translates to:
  /// **'Last message {when}'**
  String gapsLast(String when);

  /// No description provided for @gapsDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String gapsDays(int days);

  /// No description provided for @gapsToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get gapsToday;

  /// No description provided for @gapsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get gapsEmpty;

  /// No description provided for @sar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get sar;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Pull to retry.'**
  String get loadFailed;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search merchants'**
  String get searchHint;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get filterAll;

  /// No description provided for @filterUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized only'**
  String get filterUncategorized;

  /// No description provided for @filterHideInternal.
  ///
  /// In en, this message translates to:
  /// **'Hide internal moves'**
  String get filterHideInternal;

  /// No description provided for @filterShowInternal.
  ///
  /// In en, this message translates to:
  /// **'Show internal moves'**
  String get filterShowInternal;

  /// No description provided for @filterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filterClear;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get categoryNone;

  /// No description provided for @categoryPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryPickTitle;

  /// No description provided for @categoryRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove category'**
  String get categoryRemove;

  /// No description provided for @applyPastTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to {count} other transactions?'**
  String applyPastTitle(int count);

  /// No description provided for @applyPastBody.
  ///
  /// In en, this message translates to:
  /// **'Always file \"{merchant}\" under {category}, and change the past ones too?'**
  String applyPastBody(String merchant, String category);

  /// No description provided for @applyPastYes.
  ///
  /// In en, this message translates to:
  /// **'Change all'**
  String get applyPastYes;

  /// No description provided for @applyPastNo.
  ///
  /// In en, this message translates to:
  /// **'Only future ones'**
  String get applyPastNo;

  /// No description provided for @categorySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the category. Try again.'**
  String get categorySaveFailed;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No transactions match'**
  String get noMatches;

  /// No description provided for @obSegUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get obSegUpcoming;

  /// No description provided for @obSegOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get obSegOverdue;

  /// No description provided for @obSegHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get obSegHistory;

  /// No description provided for @obCommitted.
  ///
  /// In en, this message translates to:
  /// **'Still to pay in the next 30 days'**
  String get obCommitted;

  /// No description provided for @obDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String obDue(String date);

  /// No description provided for @obExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected {amount}'**
  String obExpected(String amount);

  /// No description provided for @obPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount}'**
  String obPaidAmount(String amount);

  /// No description provided for @obStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get obStatusPending;

  /// No description provided for @obStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get obStatusOverdue;

  /// No description provided for @obStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get obStatusPaid;

  /// No description provided for @obStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get obStatusSkipped;

  /// No description provided for @obMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get obMarkPaid;

  /// No description provided for @obSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get obSkip;

  /// No description provided for @obReopen.
  ///
  /// In en, this message translates to:
  /// **'Re-open'**
  String get obReopen;

  /// No description provided for @obSuggestTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{name}\" as paid with this payment?'**
  String obSuggestTitle(String name);

  /// No description provided for @obConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get obConfirm;

  /// No description provided for @obNotThis.
  ///
  /// In en, this message translates to:
  /// **'Not this'**
  String get obNotThis;

  /// No description provided for @obEmptyUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in the next 30 days'**
  String get obEmptyUpcoming;

  /// No description provided for @obEmptyOverdue.
  ///
  /// In en, this message translates to:
  /// **'Nothing overdue'**
  String get obEmptyOverdue;

  /// No description provided for @obEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get obEmptyHistory;

  /// No description provided for @obMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get obMonthTitle;

  /// No description provided for @obMonthCommitted.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get obMonthCommitted;

  /// No description provided for @obMonthOther.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get obMonthOther;

  /// No description provided for @obSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get obSaveFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
