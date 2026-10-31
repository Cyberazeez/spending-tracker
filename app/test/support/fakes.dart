import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/core/data_repository.dart';
import 'package:spending_tracker/core/lock.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/core/normalize.dart';
import 'package:spending_tracker/core/providers.dart';
import 'package:spending_tracker/core/token_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._signedIn = false});

  bool _signedIn;
  final _controller = StreamController<bool>.broadcast();
  SignInFailure? failWith;
  int signInCalls = 0;

  @override
  bool get hasSession => _signedIn;

  @override
  Stream<bool> get signedIn => _controller.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (failWith != null) throw SignInException(failWith!);
    _signedIn = true;
    _controller.add(true);
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
  int loadCalls = 0;
  bool failLoad = false;

  @override
  Future<IngestTokenInfo?> activeToken() async {
    loadCalls++;
    if (failLoad) throw StateError('offline');
    return active;
  }

  @override
  Future<String> rotate({String label = 'iPhone'}) async {
    rotateCalls++;
    active = IngestTokenInfo(
      label: label,
      createdAt: DateTime.utc(2026, 10, 30, 12),
    );
    return 'stk_TESTTOKEN';
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
  List<ObligationInstance> instances = [];
  int monthSpend = 0;
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
      return true;
    }).toList();
  }

  @override
  Future<List<Category>> categories() async => cats;

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
  }) => ObligationInstance(
    id: i.id,
    obligationId: i.obligationId,
    name: i.name,
    kind: i.kind,
    dueDate: i.dueDate,
    status: status ?? i.status,
    expectedHalalas: i.expectedHalalas,
    actualHalalas: clearTx ? null : i.actualHalalas,
    transactionId: clearTx ? null : i.transactionId,
    matchState: matchState ?? i.matchState,
    graceDays: i.graceDays,
    leadDays: i.leadDays,
  );

  @override
  Future<void> setInstanceStatus(String id, String status) async {
    instanceCalls.add('$status:$id');
    _patch(id, (i) => _copy(i, status: status, matchState: 'manual'));
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
  Future<List<SenderGap>> senderGaps() async {
    if (failLoad) throw StateError('offline');
    return gaps;
  }
}

class Harness {
  Harness({bool signedIn = false})
    : auth = FakeAuthRepository(signedIn: signedIn),
      authenticator = FakeAuthenticator(),
      tokens = FakeTokenRepository(),
      data = FakeDataRepository();

  final FakeAuthRepository auth;
  final FakeAuthenticator authenticator;
  final FakeTokenRepository tokens;
  final FakeDataRepository data;
  DateTime now = DateTime.utc(2026, 10, 30, 12);

  Future<ProviderScope> build({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authenticatorProvider.overrideWithValue(authenticator),
        tokenRepositoryProvider.overrideWithValue(tokens),
        dataRepositoryProvider.overrideWithValue(data),
        sharedPrefsProvider.overrideWithValue(sp),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const SpendingTrackerApp(),
    );
  }
}
