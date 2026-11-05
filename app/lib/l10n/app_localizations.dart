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
  /// **'Activity'**
  String get tabTransactions;

  /// No description provided for @tabObligations.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
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

  /// No description provided for @captureStatus.
  ///
  /// In en, this message translates to:
  /// **'SMS capture'**
  String get captureStatus;

  /// No description provided for @captureWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String captureWaiting(int count);

  /// No description provided for @captureNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting'**
  String get captureNone;

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
  /// **'Activity'**
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
  /// **'Amount (⃁)'**
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

  /// No description provided for @sar.
  ///
  /// In en, this message translates to:
  /// **'⃁'**
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
  /// **'Obligations this month'**
  String get obMonthCommitted;

  /// No description provided for @obGroupThis.
  ///
  /// In en, this message translates to:
  /// **'This month · {month}'**
  String obGroupThis(String month);

  /// No description provided for @obGroupNext.
  ///
  /// In en, this message translates to:
  /// **'Next month · {month}'**
  String obGroupNext(String month);

  /// No description provided for @obGroupLater.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String obGroupLater(String month, String year);

  /// No description provided for @obMonthCommittedNote.
  ///
  /// In en, this message translates to:
  /// **'Paid and still to pay'**
  String get obMonthCommittedNote;

  /// No description provided for @obUsually.
  ///
  /// In en, this message translates to:
  /// **'Usually {min} to {max}'**
  String obUsually(String min, String max);

  /// No description provided for @obEditAmount.
  ///
  /// In en, this message translates to:
  /// **'Edit amount'**
  String get obEditAmount;

  /// No description provided for @obEditAmountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Amount in ⃁'**
  String get obEditAmountPrompt;

  /// No description provided for @obAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 700 or 1,250.50'**
  String get obAmountInvalid;

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

  /// No description provided for @insMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get insMonthlyBudget;

  /// No description provided for @insMonthlyBudgetNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get insMonthlyBudgetNotSet;

  /// No description provided for @insMonthlyBudgetUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String insMonthlyBudgetUsed(String percent);

  /// No description provided for @insMonthlyBudgetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget in ⃁'**
  String get insMonthlyBudgetPrompt;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Spent today'**
  String get homeToday;

  /// No description provided for @homeBudgetUsed.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget used'**
  String get homeBudgetUsed;

  /// No description provided for @homeMonthlyWarn.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget at {percent}%'**
  String homeMonthlyWarn(String percent);

  /// No description provided for @homeMonthlyOver.
  ///
  /// In en, this message translates to:
  /// **'Over the monthly budget'**
  String get homeMonthlyOver;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get remindersTitle;

  /// No description provided for @remindersOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get remindersOn;

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindersOff;

  /// No description provided for @remindersHelp.
  ///
  /// In en, this message translates to:
  /// **'A notification at 9:00 about two days before a bill or payment is due.'**
  String get remindersHelp;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app. Turn them on in iPhone Settings, then try again.'**
  String get remindersDenied;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String reminderBody(String date);

  /// No description provided for @reminderBodyAmount.
  ///
  /// In en, this message translates to:
  /// **'Due {date} · about {amount}'**
  String reminderBodyAmount(String date, String amount);

  /// No description provided for @insThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get insThisMonth;

  /// No description provided for @insSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent so far'**
  String get insSpent;

  /// No description provided for @insVsLast.
  ///
  /// In en, this message translates to:
  /// **'Same day last month'**
  String get insVsLast;

  /// No description provided for @insUp.
  ///
  /// In en, this message translates to:
  /// **'Up {amount}'**
  String insUp(String amount);

  /// No description provided for @insDown.
  ///
  /// In en, this message translates to:
  /// **'Down {amount}'**
  String insDown(String amount);

  /// No description provided for @insSame.
  ///
  /// In en, this message translates to:
  /// **'About the same'**
  String get insSame;

  /// No description provided for @insNoCompare.
  ///
  /// In en, this message translates to:
  /// **'Nothing to compare yet: no spending recorded for the same days last month'**
  String get insNoCompare;

  /// No description provided for @insSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get insSavings;

  /// No description provided for @insSavingsValue.
  ///
  /// In en, this message translates to:
  /// **'{pct}%'**
  String insSavingsValue(String pct);

  /// No description provided for @insSalaryAbove.
  ///
  /// In en, this message translates to:
  /// **'Salary is above your base of {amount}'**
  String insSalaryAbove(String amount);

  /// No description provided for @insByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get insByCategory;

  /// No description provided for @insTopMerchants.
  ///
  /// In en, this message translates to:
  /// **'Top merchants'**
  String get insTopMerchants;

  /// No description provided for @insSpikes.
  ///
  /// In en, this message translates to:
  /// **'Spending spikes'**
  String get insSpikes;

  /// No description provided for @insSpikeLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} this month, usually {avg}'**
  String insSpikeLine(String amount, String avg);

  /// No description provided for @insSubs.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get insSubs;

  /// No description provided for @insSubsTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} a month'**
  String insSubsTotal(String amount);

  /// No description provided for @insBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get insBudgets;

  /// No description provided for @insBudgetSet.
  ///
  /// In en, this message translates to:
  /// **'Set a budget'**
  String get insBudgetSet;

  /// No description provided for @insBudgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get insBudgetRemove;

  /// No description provided for @insBudgetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit in ⃁'**
  String get insBudgetPrompt;

  /// No description provided for @insBudgetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 1500 or 1,500.50'**
  String get insBudgetInvalid;

  /// No description provided for @insBudgetWarn.
  ///
  /// In en, this message translates to:
  /// **'{name} is at {pct}% of its budget'**
  String insBudgetWarn(String name, String pct);

  /// No description provided for @insBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'{name} is over budget'**
  String insBudgetOver(String name);

  /// No description provided for @insOfLimit.
  ///
  /// In en, this message translates to:
  /// **'of {limit}'**
  String insOfLimit(String limit);

  /// No description provided for @insEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get insEmpty;

  /// No description provided for @insEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Spending shows up here once your first transactions arrive.'**
  String get insEmptyBody;

  /// No description provided for @insSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get insSave;

  /// No description provided for @obPlanNote.
  ///
  /// In en, this message translates to:
  /// **'Includes {name} instalment {n} of {total} ({amount})'**
  String obPlanNote(String name, String n, String total, String amount);

  /// No description provided for @homeNext.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get homeNext;

  /// No description provided for @homeNothingDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due soon'**
  String get homeNothingDue;

  /// No description provided for @homeStale.
  ///
  /// In en, this message translates to:
  /// **'No SMS for {days} days. Check that your Shortcuts are still on.'**
  String homeStale(String days);

  /// No description provided for @homeTop.
  ///
  /// In en, this message translates to:
  /// **'Top category: {name} ({amount})'**
  String homeTop(String name, String amount);

  /// No description provided for @homeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get homeAlerts;

  /// No description provided for @homeAddTx.
  ///
  /// In en, this message translates to:
  /// **'Add a transaction'**
  String get homeAddTx;

  /// No description provided for @captureSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up SMS capture'**
  String get captureSetupTitle;

  /// No description provided for @captureIntro.
  ///
  /// In en, this message translates to:
  /// **'Do this once:'**
  String get captureIntro;

  /// No description provided for @captureStep1.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts > Automation > + > Message'**
  String get captureStep1;

  /// No description provided for @captureStep2.
  ///
  /// In en, this message translates to:
  /// **'Message contains “SAR”, Run Immediately'**
  String get captureStep2;

  /// No description provided for @captureStep3.
  ///
  /// In en, this message translates to:
  /// **'Add action “Add bank message” (this app\'s icon)'**
  String get captureStep3;

  /// No description provided for @captureStep4.
  ///
  /// In en, this message translates to:
  /// **'Set Message and Sender to the matching variables'**
  String get captureStep4;

  /// No description provided for @captureStep5.
  ///
  /// In en, this message translates to:
  /// **'Done. Bank SMS are added by themselves.'**
  String get captureStep5;

  /// No description provided for @captureOpenShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts'**
  String get captureOpenShortcuts;

  /// No description provided for @captureStatusHeader.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get captureStatusHeader;

  /// No description provided for @captureSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send waiting messages now'**
  String get captureSendNow;

  /// No description provided for @homeOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverview;

  /// No description provided for @homeSpentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get homeSpentThisMonth;

  /// No description provided for @homeLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get homeLast7;

  /// No description provided for @homeWhereItWent.
  ///
  /// In en, this message translates to:
  /// **'Where it went'**
  String get homeWhereItWent;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeNextBills.
  ///
  /// In en, this message translates to:
  /// **'Next bills'**
  String get homeNextBills;

  /// No description provided for @homeAllBills.
  ///
  /// In en, this message translates to:
  /// **'All bills'**
  String get homeAllBills;

  /// No description provided for @homeLeftToSpend.
  ///
  /// In en, this message translates to:
  /// **'Left to spend'**
  String get homeLeftToSpend;

  /// No description provided for @homeVsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get homeVsLastMonth;

  /// No description provided for @homeSetBudget.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly budget'**
  String get homeSetBudget;

  /// No description provided for @homeTodayShort.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTodayShort;

  /// No description provided for @homeSameShort.
  ///
  /// In en, this message translates to:
  /// **'Same'**
  String get homeSameShort;

  /// No description provided for @homeOfBudget.
  ///
  /// In en, this message translates to:
  /// **'of {amount} budget'**
  String homeOfBudget(String amount);

  /// No description provided for @homeLower.
  ///
  /// In en, this message translates to:
  /// **'{percent}% lower'**
  String homeLower(String percent);

  /// No description provided for @homeHigher.
  ///
  /// In en, this message translates to:
  /// **'{percent}% higher'**
  String homeHigher(String percent);

  /// No description provided for @homeToReview.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String homeToReview(int count);

  /// No description provided for @homeBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent {amount} on {weekday}'**
  String homeBarLabel(String amount, String weekday);

  /// No description provided for @homeDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String homeDueIn(int days);

  /// No description provided for @homeDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get homeDueTomorrow;

  /// No description provided for @homeDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get homeDueToday;

  /// No description provided for @groupFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get groupFood;

  /// No description provided for @groupTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get groupTransport;

  /// No description provided for @groupHomeBills.
  ///
  /// In en, this message translates to:
  /// **'Home and bills'**
  String get groupHomeBills;

  /// No description provided for @groupFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get groupFamily;

  /// No description provided for @groupHorse.
  ///
  /// In en, this message translates to:
  /// **'Horse'**
  String get groupHorse;

  /// No description provided for @groupLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get groupLifestyle;

  /// No description provided for @groupSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get groupSubscriptions;

  /// No description provided for @groupHealth.
  ///
  /// In en, this message translates to:
  /// **'Health and care'**
  String get groupHealth;

  /// No description provided for @groupMoney.
  ///
  /// In en, this message translates to:
  /// **'Money and fees'**
  String get groupMoney;

  /// No description provided for @groupOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groupOther;

  /// No description provided for @txToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get txToday;

  /// No description provided for @txYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get txYesterday;

  /// No description provided for @txChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get txChooseCategory;

  /// No description provided for @txChipAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get txChipAll;

  /// No description provided for @txChipNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get txChipNoCategory;

  /// No description provided for @txChipHideInternal.
  ///
  /// In en, this message translates to:
  /// **'Hide internal'**
  String get txChipHideInternal;

  /// No description provided for @insTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'This month vs last month'**
  String get insTrendTitle;

  /// No description provided for @insLegendThis.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get insLegendThis;

  /// No description provided for @insLegendLast.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get insLegendLast;

  /// No description provided for @insMonthsTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 4 months'**
  String get insMonthsTitle;

  /// No description provided for @insBudgetLine.
  ///
  /// In en, this message translates to:
  /// **'Budget {amount}'**
  String insBudgetLine(String amount);

  /// No description provided for @insWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where it goes'**
  String get insWhereTitle;

  /// No description provided for @insTrendLabel.
  ///
  /// In en, this message translates to:
  /// **'{now} so far this month, {before} by the same day last month'**
  String insTrendLabel(String now, String before);

  /// No description provided for @insMonthBarLabel.
  ///
  /// In en, this message translates to:
  /// **'{month}: {amount}'**
  String insMonthBarLabel(String month, String amount);

  /// No description provided for @insVisits.
  ///
  /// In en, this message translates to:
  /// **'{count} visits'**
  String insVisits(int count);

  /// No description provided for @insVisit.
  ///
  /// In en, this message translates to:
  /// **'1 visit'**
  String get insVisit;

  /// No description provided for @insSavingsRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get insSavingsRateLabel;

  /// No description provided for @insSpikeBadge.
  ///
  /// In en, this message translates to:
  /// **'Spending spike'**
  String get insSpikeBadge;

  /// No description provided for @insSubsServices.
  ///
  /// In en, this message translates to:
  /// **'{count} services a month'**
  String insSubsServices(int count);

  /// No description provided for @obNew.
  ///
  /// In en, this message translates to:
  /// **'New obligation'**
  String get obNew;

  /// No description provided for @obEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit obligation'**
  String get obEditTitle;

  /// No description provided for @obfName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get obfName;

  /// No description provided for @obfType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get obfType;

  /// No description provided for @obfKindBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get obfKindBill;

  /// No description provided for @obfKindFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get obfKindFixed;

  /// No description provided for @obfKindLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get obfKindLoan;

  /// No description provided for @obfAmountFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get obfAmountFixed;

  /// No description provided for @obfAmountEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get obfAmountEstimated;

  /// No description provided for @obfAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount in ⃁'**
  String get obfAmount;

  /// No description provided for @obfAmountBillNote.
  ///
  /// In en, this message translates to:
  /// **'Optional for a bill: leave it empty and the bill message sets each month\'s amount.'**
  String get obfAmountBillNote;

  /// No description provided for @obfRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get obfRepeats;

  /// No description provided for @obfMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get obfMonthly;

  /// No description provided for @obfQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Every 3 months'**
  String get obfQuarterly;

  /// No description provided for @obfAnnual.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get obfAnnual;

  /// No description provided for @obfDueDay.
  ///
  /// In en, this message translates to:
  /// **'Due day'**
  String get obfDueDay;

  /// No description provided for @obfDueDayNote.
  ///
  /// In en, this message translates to:
  /// **'Short months use their last day.'**
  String get obfDueDayNote;

  /// No description provided for @obfStartMonth.
  ///
  /// In en, this message translates to:
  /// **'First due month'**
  String get obfStartMonth;

  /// No description provided for @obfGrace.
  ///
  /// In en, this message translates to:
  /// **'Grace days'**
  String get obfGrace;

  /// No description provided for @obfLead.
  ///
  /// In en, this message translates to:
  /// **'Remind days before'**
  String get obfLead;

  /// No description provided for @obfCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get obfCategory;

  /// No description provided for @obfNoCategory.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get obfNoCategory;

  /// No description provided for @obfMatchWords.
  ///
  /// In en, this message translates to:
  /// **'Match words'**
  String get obfMatchWords;

  /// No description provided for @obfMatchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. gym club, stc (up to 5, separated by commas)'**
  String get obfMatchHint;

  /// No description provided for @obfTolerance.
  ///
  /// In en, this message translates to:
  /// **'Amount tolerance %'**
  String get obfTolerance;

  /// No description provided for @obfAuto.
  ///
  /// In en, this message translates to:
  /// **'Mark paid automatically'**
  String get obfAuto;

  /// No description provided for @obfAutoNote.
  ///
  /// In en, this message translates to:
  /// **'Off: a matching payment is only suggested for you to confirm.'**
  String get obfAutoNote;

  /// No description provided for @obfSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get obfSave;

  /// No description provided for @obfNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (up to 60 letters).'**
  String get obfNameRequired;

  /// No description provided for @obfWordsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 words, each up to 30 letters.'**
  String get obfWordsInvalid;

  /// No description provided for @obEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get obEditDetails;

  /// No description provided for @obStop.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking'**
  String get obStop;

  /// No description provided for @obStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will stop appearing. Paid history stays.'**
  String obStopConfirm(String name);

  /// No description provided for @obAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add an obligation'**
  String get obAddHint;

  /// No description provided for @obfNameTaken.
  ///
  /// In en, this message translates to:
  /// **'You already have an obligation with this name.'**
  String get obfNameTaken;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiTitle;

  /// No description provided for @aiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sends only totals and merchant names. Never message text, names or account numbers.'**
  String get aiSubtitle;

  /// No description provided for @aiTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI tips'**
  String get aiTipsTitle;

  /// No description provided for @aiTipsGet.
  ///
  /// In en, this message translates to:
  /// **'Get tips'**
  String get aiTipsGet;

  /// No description provided for @aiTipsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh tips'**
  String get aiTipsRefresh;

  /// No description provided for @aiTipsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Get savings tips based on this month\'s totals.'**
  String get aiTipsEmpty;

  /// No description provided for @aiTipsNote.
  ///
  /// In en, this message translates to:
  /// **'Based on totals only. Check the numbers before acting.'**
  String get aiTipsNote;

  /// No description provided for @aiTipsNone.
  ///
  /// In en, this message translates to:
  /// **'No tips this time.'**
  String get aiTipsNone;

  /// No description provided for @aiSuggestTitle.
  ///
  /// In en, this message translates to:
  /// **'{n} transactions have no category'**
  String aiSuggestTitle(String n);

  /// No description provided for @aiSuggestAction.
  ///
  /// In en, this message translates to:
  /// **'Suggest with AI'**
  String get aiSuggestAction;

  /// No description provided for @aiSuggestDone.
  ///
  /// In en, this message translates to:
  /// **'Categorised {n} transactions. Tap “AI suggested” to review them.'**
  String aiSuggestDone(String n);

  /// No description provided for @aiSuggestNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to categorise yet.'**
  String get aiSuggestNone;

  /// No description provided for @aiReasonDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI is off. Turn it on in More.'**
  String get aiReasonDisabled;

  /// No description provided for @aiReasonNoKey.
  ///
  /// In en, this message translates to:
  /// **'AI is not set up on the server yet.'**
  String get aiReasonNoKey;

  /// No description provided for @aiReasonCap.
  ///
  /// In en, this message translates to:
  /// **'This month\'s AI budget is used up. It resets next month.'**
  String get aiReasonCap;

  /// No description provided for @aiReasonOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get aiReasonOffline;

  /// No description provided for @aiReasonFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get an answer. Try again later.'**
  String get aiReasonFailed;

  /// No description provided for @txAiTag.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get txAiTag;

  /// No description provided for @txChipAi.
  ///
  /// In en, this message translates to:
  /// **'AI suggested'**
  String get txChipAi;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfile;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSecurity;

  /// No description provided for @accountSecurityHint.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountSecurityHint;

  /// No description provided for @accountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get accountPrivacy;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get accountNameHint;

  /// No description provided for @accountSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountSave;

  /// No description provided for @accountNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use up to 60 letters.'**
  String get accountNameTooLong;

  /// No description provided for @accountEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountEmailInvalid;

  /// No description provided for @accountEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Check your new address for a confirmation link. The old one stays until you use it.'**
  String get accountEmailSent;

  /// No description provided for @accountSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get accountSaveFailed;

  /// No description provided for @secChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get secChangePassword;

  /// No description provided for @secCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get secCurrent;

  /// No description provided for @secNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get secNew;

  /// No description provided for @secConfirm.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get secConfirm;

  /// No description provided for @secRulesHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get secRulesHint;

  /// No description provided for @secWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'The current password is wrong.'**
  String get secWrongCurrent;

  /// No description provided for @secTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get secTooShort;

  /// No description provided for @secMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match.'**
  String get secMismatch;

  /// No description provided for @secSame.
  ///
  /// In en, this message translates to:
  /// **'Choose a different password.'**
  String get secSame;

  /// No description provided for @secDone.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get secDone;

  /// No description provided for @secNote.
  ///
  /// In en, this message translates to:
  /// **'This also resets SMS capture and the widget on this phone. They reconnect by themselves.'**
  String get secNote;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored in your own account and only you can read it. More options will appear here soon.'**
  String get privacyBody;

  /// No description provided for @moreAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get moreAccount;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpTitle;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpLink;

  /// No description provided for @signUpNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name (up to 60 letters).'**
  String get signUpNameRequired;

  /// No description provided for @signUpEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in instead.'**
  String get signUpEmailTaken;

  /// No description provided for @signUpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sign-up is closed right now. Ask the owner.'**
  String get signUpDisabled;

  /// No description provided for @signUpCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email and tap the confirmation link, then come back and sign in.'**
  String get signUpCheckEmail;

  /// No description provided for @signUpWeak.
  ///
  /// In en, this message translates to:
  /// **'That password is too weak. Use at least 8 characters and mix letters and numbers.'**
  String get signUpWeak;

  /// No description provided for @signUpTryLater.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account right now. Try again in a few minutes.'**
  String get signUpTryLater;

  /// No description provided for @signUpBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get signUpBackToSignIn;

  /// No description provided for @accountBanks.
  ///
  /// In en, this message translates to:
  /// **'Bank accounts'**
  String get accountBanks;

  /// No description provided for @accountBanksShort.
  ///
  /// In en, this message translates to:
  /// **'Your own accounts and cards'**
  String get accountBanksShort;

  /// No description provided for @accountBanksHint.
  ///
  /// In en, this message translates to:
  /// **'List your own accounts, cards and wallets so moving money between them is not counted as spending.'**
  String get accountBanksHint;

  /// No description provided for @banksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet.'**
  String get banksEmpty;

  /// No description provided for @bankAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get bankAdd;

  /// No description provided for @bankPick.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bankPick;

  /// No description provided for @bankKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bankKind;

  /// No description provided for @bankLast4.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits'**
  String get bankLast4;

  /// No description provided for @bankLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get bankLabelOptional;

  /// No description provided for @bankSave.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get bankSave;

  /// No description provided for @bankLast4Invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 4 digits.'**
  String get bankLast4Invalid;

  /// No description provided for @bankDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This account is already in the list.'**
  String get bankDuplicate;

  /// No description provided for @bankRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bankRemove;

  /// No description provided for @bankRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String bankRemoveConfirm(String name);

  /// No description provided for @kindAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get kindAccount;

  /// No description provided for @kindDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get kindDebit;

  /// No description provided for @kindCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get kindCredit;

  /// No description provided for @kindWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get kindWallet;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeTitle;

  /// No description provided for @welcomeHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get welcomeHide;

  /// No description provided for @welcomeProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String welcomeProgress(String done, String total);

  /// No description provided for @welcomeAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add your bank accounts'**
  String get welcomeAccounts;

  /// No description provided for @welcomeCapture.
  ///
  /// In en, this message translates to:
  /// **'Set up SMS capture'**
  String get welcomeCapture;

  /// No description provided for @welcomeBudget.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly budget'**
  String get welcomeBudget;

  /// No description provided for @deleteAccountRow.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountRow;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteTitle;

  /// No description provided for @deleteWarn.
  ///
  /// In en, this message translates to:
  /// **'Your account and all your data (transactions, bills, budgets and settings) will be permanently deleted after 30 days. Sign in again before then and nothing is deleted.'**
  String get deleteWarn;

  /// No description provided for @deleteWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteWord;

  /// No description provided for @deleteTypeWord.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deleteTypeWord(String word);

  /// No description provided for @deleteWordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Type {word} exactly to confirm.'**
  String deleteWordMismatch(String word);

  /// No description provided for @deletePassword.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get deletePassword;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteButton;

  /// No description provided for @deleteWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is wrong.'**
  String get deleteWrongPassword;

  /// No description provided for @deleteTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again tomorrow.'**
  String get deleteTooMany;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete. Check your connection and try again.'**
  String get deleteFailed;

  /// No description provided for @deleteSureTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get deleteSureTitle;

  /// No description provided for @deleteSureBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is closed now and everything is permanently deleted after 30 days, with no way to restore it. Signing in again within 30 days cancels the deletion.'**
  String get deleteSureBody;

  /// No description provided for @deleteSureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteSureConfirm;

  /// No description provided for @reactivatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get reactivatedTitle;

  /// No description provided for @reactivatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is active again and the deletion is cancelled. All your data is still here.'**
  String get reactivatedBody;

  /// No description provided for @reactivatedOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get reactivatedOk;

  /// No description provided for @categorySearch.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get categorySearch;

  /// No description provided for @categorySuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested for this merchant'**
  String get categorySuggested;

  /// No description provided for @categoryNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No category matches'**
  String get categoryNoMatch;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about your spending'**
  String get aiChatTitle;

  /// No description provided for @aiChatOpen.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get aiChatOpen;

  /// No description provided for @aiChatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about a category or a budget'**
  String get aiChatHint;

  /// No description provided for @aiChatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiChatSend;

  /// No description provided for @aiChatIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask about this month\'s spending, a category or a budget. I only see totals, never merchants or messages.'**
  String get aiChatIntro;

  /// No description provided for @aiChatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get aiChatThinking;

  /// No description provided for @aiChatNoData.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to talk about yet. Come back once some spending is recorded.'**
  String get aiChatNoData;

  /// No description provided for @aiChatPromptCut.
  ///
  /// In en, this message translates to:
  /// **'Where can I cut spending?'**
  String get aiChatPromptCut;

  /// No description provided for @aiChatPromptBudget.
  ///
  /// In en, this message translates to:
  /// **'Am I on track with my budgets?'**
  String get aiChatPromptBudget;

  /// No description provided for @aiChatPromptLast.
  ///
  /// In en, this message translates to:
  /// **'How does this month compare with last month?'**
  String get aiChatPromptLast;

  /// No description provided for @aiChatPromptCategory.
  ///
  /// In en, this message translates to:
  /// **'Why is {category} so high?'**
  String aiChatPromptCategory(String category);

  /// No description provided for @aiChatRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get aiChatRetry;

  /// No description provided for @aiTipsTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to ask about a category or a budget'**
  String get aiTipsTapHint;

  /// No description provided for @obCycleStill.
  ///
  /// In en, this message translates to:
  /// **'{month} · still to pay'**
  String obCycleStill(String month);

  /// No description provided for @obCyclePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} of {total} · {done} of {count} bills'**
  String obCyclePaid(String paid, String total, String done, String count);

  /// No description provided for @obUnpaidBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unpaid from an earlier month} other{{count} unpaid from earlier months}}'**
  String obUnpaidBefore(int count);

  /// No description provided for @obNextSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill} other{{count} bills}}'**
  String obNextSummary(int count);

  /// No description provided for @obNextNote.
  ///
  /// In en, this message translates to:
  /// **'About {amount} · tap to see them'**
  String obNextNote(String amount);

  /// No description provided for @obAmountPending.
  ///
  /// In en, this message translates to:
  /// **'amount comes with the statement'**
  String get obAmountPending;
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
