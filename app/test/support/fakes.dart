import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/core/capture_bridge.dart';
import 'package:spending_tracker/core/data_repository.dart';
import 'package:spending_tracker/core/lock.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/core/normalize.dart';
import 'package:spending_tracker/core/providers.dart';
import 'package:spending_tracker/core/reminder_bridge.dart';
import 'package:spending_tracker/core/token_repository.dart';
import 'package:spending_tracker/core/widget_bridge.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._signedIn = false});

  bool _signedIn;
  final _controller = StreamController<bool>.broadcast();
  SignInFailure? failWith;
  int signInCalls = 0;
  int reactivateCalls = 0;

  /// What the next sign-in reports as "cancelled a pending deletion".
  bool reactivateOnSignIn = false;

  @override
  bool get hasSession => _signedIn;

  String? currentUser = 'user-1';

  @override
  String? get userId => _signedIn ? currentUser : null;

  @override
  Stream<bool> get signedIn => _controller.stream;

  SignUpFailure? signUpFailWith;
  SignUpResult signUpResult = SignUpResult.signedIn;
  final signUpCalls = <(String, String, String)>[];

  @override
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (signUpFailWith != null) throw SignUpException(signUpFailWith!);
    signUpCalls.add((name, email, password));
    if (signUpResult == SignUpResult.signedIn) {
      _signedIn = true;
      fakeName = name;
      fakeEmail = email;
      _controller.add(true);
    }
    return signUpResult;
  }

  /// A recovery link signs the user in; this simulates just that part.
  void signedInNow() {
    _signedIn = true;
    _controller.add(true);
  }

  ResetFailure? resetFailWith;
  final resetCalls = <String>[];
  final newPasswordCalls = <String>[];
  final _recovery = StreamController<void>.broadcast();

  final _linkFailed = StreamController<void>.broadcast();

  /// Simulates opening an expired or already used email link.
  void emitLinkFailed() => _linkFailed.add(null);

  @override
  Stream<void> get linkFailed => _linkFailed.stream;

  /// Simulates the user opening the reset link from the email.
  void emitRecovery() => _recovery.add(null);

  @override
  Stream<void> get passwordRecovery => _recovery.stream;

  @override
  Future<void> sendPasswordReset(String email) async {
    if (resetFailWith != null) throw ResetException(resetFailWith!);
    resetCalls.add(email.trim());
  }

  @override
  Future<void> setNewPassword(String next) async {
    if (passwordFailWith != null) throw PasswordException(passwordFailWith!);
    newPasswordCalls.add(next);
  }

  DeleteFailure? deleteFailWith;
  final deleteCalls = <String>[];

  @override
  Future<void> deleteAccount(String password) async {
    if (deleteFailWith != null) throw DeleteAccountException(deleteFailWith!);
    deleteCalls.add(password);
    _signedIn = false;
    _controller.add(false);
  }

  String? fakeEmail = 'azeez@example.test';
  String? fakeName;
  PasswordFailure? passwordFailWith;
  final passwordCalls = <(String, String)>[];
  final emailCalls = <String>[];

  @override
  String? get email => fakeEmail;

  @override
  String? get displayName => fakeName;

  @override
  Future<void> updateName(String name) async => fakeName = name.trim();

  @override
  Future<void> changeEmail(String email) async => emailCalls.add(email.trim());

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    if (passwordFailWith != null) throw PasswordException(passwordFailWith!);
    passwordCalls.add((current, next));
  }

  @override
  Future<bool> signIn(String email, String password) async {
    signInCalls++;
    if (failWith != null) throw SignInException(failWith!);
    _signedIn = true;
    _controller.add(true);
    return reactivateOnSignIn;
  }

  @override
  Future<bool> reactivateIfPending() async {
    reactivateCalls++;
    return false;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _controller.add(false);
  }
}

class FakeAuthenticator implements Authenticator {
  bool result = true;
  bool throws = false;
  int calls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    if (throws) throw StateError('platform error');
    return result;
  }
}

class FakeTokenRepository implements TokenRepository {
  IngestTokenInfo? active;
  int rotateCalls = 0;
  int appRotateCalls = 0;
  int appRevokeCalls = 0;
  int widgetRotateCalls = 0;

  /// When set, a widget-token rotation waits for it (to test sign-out in the middle of provisioning).
  Completer<void>? widgetGate;
  final List<String> revokedKinds = [];
  int loadCalls = 0;
  bool failLoad = false;

  @override
  Future<IngestTokenInfo?> activeToken() async {
    loadCalls++;
    if (failLoad) throw StateError('offline');
    return active;
  }

  @override
  Future<String> rotate({
    String label = 'iPhone',
    String kind = 'shortcut',
  }) async {
    if (kind == 'app') {
      appRotateCalls++;
      return 'stk_APPTOKEN';
    }
    if (kind == 'widget') {
      widgetRotateCalls++;
      await widgetGate?.future;
      return 'stk_WIDGETTOKEN';
    }
    rotateCalls++;
    active = IngestTokenInfo(
      label: label,
      createdAt: DateTime.utc(2026, 10, 30, 12),
    );
    return 'stk_TESTTOKEN';
  }

  @override
  Future<void> revoke({String kind = 'app'}) async {
    revokedKinds.add(kind);
    if (kind == 'app') appRevokeCalls++;
  }
}

class FakeCaptureBridge implements CaptureBridge {
  @override
  bool get hasShortcuts => true;

  bool hasToken = false;
  String? tokenUser;
  int pending = 0;
  String last = '';
  int flushes = 0;
  int clears = 0;
  int shortcutsOpened = 0;
  final List<(String, String, String)> saved = [];

  @override
  Future<CaptureStatus> status() async => CaptureStatus(
    hasToken: hasToken,
    pending: pending,
    userId: tokenUser,
    last: last,
  );

  @override
  Future<void> saveCredentials(String url, String token, String userId) async {
    saved.add((url, token, userId));
    hasToken = true;
    tokenUser = userId;
  }

  @override
  Future<void> clearCredentials() async {
    clears++;
    hasToken = false;
    tokenUser = null;
  }

  @override
  Future<void> flush() async {
    flushes++;
  }

  @override
  Future<void> openShortcuts() async {
    shortcutsOpened++;
  }
}

class FakeDataRepository implements DataRepository {
  List<Txn> txns = [];
  List<Category> cats = const [
    Category(id: 'c-din', name: 'Dining', nameAr: 'مطاعم'),
    Category(id: 'c-gro', name: 'Groceries', nameAr: 'بقالة'),
  ];
  TxFilter lastFilter = const TxFilter();
  final categoryCalls = <(String, String?, String?, bool)>[];
  List<Txn> history = [];
  List<Budget> budgetList = [];
  final budgetCalls = <String>[];
  List<ObligationInstance> instances = [];
  int monthSpend = 0;
  int todaySpend = 0;
  int? monthlyBudget;
  int refreshCalls = 0;
  final instanceCalls = <String>[];
  List<RawMessage> review = [];
  List<SenderGap> gaps = [];
  bool failLoad = false;
  final added = <ManualTxn>[];
  final converted = <String, ManualTxn>{};
  final dismissed = <String>[];

  @override
  Future<List<Txn>> recentTransactions({
    TxFilter filter = const TxFilter(),
    int limit = 200,
  }) async {
    if (failLoad) throw StateError('offline');
    lastFilter = filter;
    final q = normalizeMerchant(filter.query);
    return txns.where((t) {
      if (q.isNotEmpty && !(t.merchantNorm ?? '').contains(q)) return false;
      if (filter.uncategorizedOnly && t.categoryId != null) return false;
      if (filter.categoryId != null && t.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.hideInternal && t.isInternal) return false;
      if (filter.aiOnly && t.categorySource != 'ai') return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Category>> categories() async => cats;

  @override
  Future<int> uncategorizedSpendCount() async =>
      {
            for (final t in [...history, ...txns]) t.id: t,
          }.values
          .where(
            (x) =>
                x.categoryId == null &&
                !x.isInternal &&
                (x.type == 'purchase' || x.type == 'refund') &&
                x.merchantNorm != null,
          )
          .length;

  @override
  Future<int> sameMerchantCount(
    String merchantNorm, {
    required String excludingId,
  }) async => txns
      .where((t) => t.merchantNorm == merchantNorm && t.id != excludingId)
      .length;

  @override
  Future<void> setCategory(
    String txnId,
    String? categoryId, {
    String? rememberFor,
    bool alsoPast = false,
  }) async {
    categoryCalls.add((txnId, categoryId, rememberFor, alsoPast));
    txns = [
      for (final t in txns)
        if (t.id == txnId ||
            (alsoPast && rememberFor != null && t.merchantNorm == rememberFor))
          Txn(
            id: t.id,
            type: t.type,
            direction: t.direction,
            amountHalalas: t.amountHalalas,
            occurredAt: t.occurredAt,
            merchant: t.merchant,
            merchantNorm: t.merchantNorm,
            categoryId: categoryId,
            isInternal: t.isInternal,
          )
        else
          t,
    ];
  }

  @override
  Future<List<RawMessage>> needsReview() async {
    if (failLoad) throw StateError('offline');
    return review;
  }

  @override
  Future<void> addManual(ManualTxn t) async => added.add(t);

  @override
  Future<void> convertRaw(String rawId, ManualTxn t) async {
    converted[rawId] = t;
    review = review.where((m) => m.id != rawId).toList();
  }

  @override
  Future<void> dismissRaw(String rawId) async {
    dismissed.add(rawId);
    review = review.where((m) => m.id != rawId).toList();
  }

  @override
  Future<void> refreshObligations() async => refreshCalls++;

  @override
  Future<List<ObligationInstance>> obligationInstances() async {
    if (failLoad) throw StateError('offline');
    return instances;
  }

  void _patch(String id, ObligationInstance Function(ObligationInstance) f) {
    instances = [for (final i in instances) i.id == id ? f(i) : i];
  }

  ObligationInstance _copy(
    ObligationInstance i, {
    String? status,
    String? matchState,
    bool clearTx = false,
    int? expected,
    int? actual,
  }) => ObligationInstance(
    id: i.id,
    obligationId: i.obligationId,
    name: i.name,
    kind: i.kind,
    dueDate: i.dueDate,
    status: status ?? i.status,
    expectedHalalas: expected ?? i.expectedHalalas,
    actualHalalas: clearTx ? null : (actual ?? i.actualHalalas),
    transactionId: clearTx ? null : i.transactionId,
    matchState: matchState ?? i.matchState,
    graceDays: i.graceDays,
    leadDays: i.leadDays,
    plan: i.plan,
    periodStart: i.periodStart,
    usualMinHalalas: i.usualMinHalalas,
    usualMaxHalalas: i.usualMaxHalalas,
  );

  bool aiOn = false;
  AiOutcome suggestResult = const AiOutcome.ok(updated: 3);
  AiOutcome tipsResult = const AiOutcome.ok(
    tips: ['Cut dining: ⃁ 900 vs ⃁ 600 average.'],
  );
  List<String> saved = [];
  int suggestCalls = 0;
  final tipCalls = <(Map<String, dynamic>, String)>[];

  List<OwnAccount> accounts = [
    const OwnAccount(
      id: 'oa1',
      bank: 'alinma',
      last4: '6000',
      kind: 'account',
      label: 'Main',
    ),
  ];
  final accountCalls = <String>[];
  bool accountDuplicate = false;

  @override
  Future<List<OwnAccount>> ownAccounts() async {
    if (failLoad) throw StateError('offline');
    return accounts;
  }

  @override
  Future<void> addOwnAccount({
    required String bank,
    required String last4,
    required String kind,
    String? label,
  }) async {
    if (accountDuplicate) {
      throw const PostgrestException(message: 'dup', code: '23505');
    }
    accountCalls.add('add:$bank:$last4:$kind:${label ?? ''}');
    accounts = [
      ...accounts,
      OwnAccount(
        id: 'oa${accounts.length + 1}',
        bank: bank,
        last4: last4,
        kind: kind,
        label: label,
      ),
    ];
  }

  @override
  Future<void> deleteOwnAccount(String id) async {
    accountCalls.add('del:$id');
    accounts = [
      for (final a in accounts)
        if (a.id != id) a,
    ];
  }

  int baseSalary = 1410000;

  @override
  Future<int> baseSalaryHalalas() async => baseSalary;

  @override
  Future<bool> aiEnabled() async => aiOn;

  @override
  Future<void> setAiEnabled(bool on) async {
    if (failAiSave) throw StateError('offline');
    aiOn = on;
  }

  bool failAiSave = false;

  @override
  Future<AiOutcome> suggestCategories() async {
    suggestCalls++;
    return suggestResult;
  }

  @override
  Future<AiOutcome> aiTips(Map<String, dynamic> a, String language) async {
    tipCalls.add((a, language));
    return tipsResult;
  }

  final chatCalls = <(Map<String, dynamic>, List<Map<String, String>>)>[];
  AiOutcome chatResult = const AiOutcome.ok(reply: 'Dining is 900.00 SAR.');

  @override
  Future<AiOutcome> aiChat(
    Map<String, dynamic> a,
    List<Map<String, String>> turns,
    String language,
  ) async {
    chatCalls.add((a, turns));
    return chatResult;
  }

  @override
  Future<List<String>> savedAiTips(String month, {String? language}) async =>
      saved;

  final savedObligations = <(String?, ObligationDef)>[];
  final stoppedObligations = <String>[];
  ObligationDef? editing;
  bool failSave = false;
  bool nameTaken = false;

  @override
  Future<ObligationDef> obligation(String id) async =>
      editing ?? ObligationDef(id: id, name: 'Gym', amountHalalas: 15000);

  @override
  Future<String> saveObligation(String? id, ObligationDef d) async {
    if (nameTaken) {
      throw const PostgrestException(message: 'dup', code: '23505');
    }
    if (failSave) throw StateError('offline');
    savedObligations.add((id, d));
    return id ?? 'new-id';
  }

  @override
  Future<void> stopObligation(String id) async {
    stoppedObligations.add(id);
  }

  @override
  Future<void> setInstanceStatus(String id, String status) async {
    instanceCalls.add('$status:$id');
    _patch(id, (i) => _copy(i, status: status, matchState: 'manual'));
  }

  @override
  Future<void> setInstanceAmount(
    String id,
    int halalas, {
    required bool paid,
  }) async {
    instanceCalls.add('amount:$id:$halalas${paid ? ':paid' : ''}');
    _patch(
      id,
      (i) => paid ? _copy(i, actual: halalas) : _copy(i, expected: halalas),
    );
  }

  @override
  Future<void> confirmMatch(String id) async {
    instanceCalls.add('confirm:$id');
    _patch(id, (i) => _copy(i, status: 'paid', matchState: 'manual'));
  }

  @override
  Future<void> rejectMatch(String id) async {
    instanceCalls.add('reject:$id');
    _patch(id, (i) => _copy(i, matchState: 'none', clearTx: true));
  }

  @override
  Future<int> monthSpendHalalas() async => monthSpend;

  @override
  Future<int> todaySpendHalalas() async => todaySpend;

  @override
  Future<int?> monthlyBudgetHalalas() async => monthlyBudget;

  @override
  Future<void> setMonthlyBudget(int? halalas) async {
    instanceCalls.add('monthlybudget:$halalas');
    monthlyBudget = halalas;
  }

  @override
  Future<List<Txn>> spendingHistory() async {
    if (failLoad) throw StateError('offline');
    return history;
  }

  @override
  Future<List<Budget>> budgets() async => budgetList;

  @override
  Future<void> setBudget(String categoryId, int monthlyLimitHalalas) async {
    budgetCalls.add('set:$categoryId:$monthlyLimitHalalas');
    budgetList = [
      for (final b in budgetList)
        if (b.categoryId != categoryId) b,
      Budget(
        id: 'b-$categoryId',
        categoryId: categoryId,
        limitHalalas: monthlyLimitHalalas,
      ),
    ];
  }

  @override
  Future<void> removeBudget(String categoryId) async {
    budgetCalls.add('remove:$categoryId');
    budgetList = [
      for (final b in budgetList)
        if (b.categoryId != categoryId) b,
    ];
  }

  @override
  Future<List<SenderGap>> senderGaps() async {
    if (failLoad) throw StateError('offline');
    return gaps;
  }
}

class FakeWidgetBridge implements WidgetBridge {
  final List<WidgetSnapshot> saved = [];
  bool hasToken = false;
  String? tokenUser;
  int clears = 0;
  final List<(String, String, String)> savedCredentials = [];

  @override
  Future<WidgetCredentialStatus> credentialStatus() async =>
      WidgetCredentialStatus(hasToken: hasToken, userId: tokenUser);

  @override
  Future<void> saveCredentials(String url, String token, String userId) async {
    savedCredentials.add((url, token, userId));
    hasToken = true;
    tokenUser = userId;
  }

  @override
  Future<void> clearCredentials() async {
    clears++;
    hasToken = false;
    tokenUser = null;
  }

  @override
  Future<void> save(WidgetSnapshot snapshot, DateTime now) async {
    saved.add(snapshot);
  }
}

class FakeReminderBridge implements ReminderBridge {
  bool grant = true;
  int permissionAsks = 0;
  int clears = 0;
  final List<List<ReminderItem>> replaced = [];

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return grant;
  }

  @override
  Future<void> replace(List<ReminderItem> items) async {
    replaced.add(items);
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

class Harness {
  Harness({bool signedIn = false})
    : auth = FakeAuthRepository(signedIn: signedIn),
      authenticator = FakeAuthenticator(),
      tokens = FakeTokenRepository(),
      data = FakeDataRepository(),
      widget = FakeWidgetBridge(),
      reminders = FakeReminderBridge(),
      capture = FakeCaptureBridge();

  final FakeAuthRepository auth;
  final FakeAuthenticator authenticator;
  final FakeTokenRepository tokens;
  final FakeDataRepository data;
  final FakeWidgetBridge widget;
  final FakeReminderBridge reminders;
  final FakeCaptureBridge capture;
  DateTime now = DateTime.utc(2026, 10, 30, 12);

  Future<ProviderScope> build({
    Map<String, Object> prefs = const {},
    bool offerGuide = false,
  }) async {
    // The first-launch guide is marked as already offered so it does not cover the screen in other tests.
    SharedPreferences.setMockInitialValues({
      if (!offerGuide) 'guide.seen.user-1': true,
      ...prefs,
    });
    final sp = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authenticatorProvider.overrideWithValue(authenticator),
        tokenRepositoryProvider.overrideWithValue(tokens),
        dataRepositoryProvider.overrideWithValue(data),
        widgetBridgeProvider.overrideWithValue(widget),
        reminderBridgeProvider.overrideWithValue(reminders),
        captureBridgeProvider.overrideWithValue(capture),
        sharedPrefsProvider.overrideWithValue(sp),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const SpendingTrackerApp(),
    );
  }
}
