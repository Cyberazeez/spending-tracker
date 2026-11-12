/// The banks and wallets that can be picked for an own account. Names are the official SAMA names (local and
/// digital banks, checked against the SAMA licensed-banks page on 2026-11-08); wallets are not banks and are
/// listed last. The codes must match the check on `own_accounts.bank` (migration 20261108200000).
class BankInfo {
  const BankInfo(this.code, this.en, this.ar, {this.wallet = false});

  final String code;
  final String en;
  final String ar;
  final bool wallet;
}

const bankList = <BankInfo>[
  BankInfo('snb', 'Saudi National Bank (SNB)', 'البنك الأهلي السعودي'),
  BankInfo('alrajhi', 'Al Rajhi Bank', 'مصرف الراجحي'),
  BankInfo('riyad', 'Riyad Bank', 'بنك الرياض'),
  BankInfo('sab', 'Saudi Awwal Bank (SAB)', 'البنك السعودي الأول'),
  BankInfo('anb', 'Arab National Bank (ANB)', 'البنك العربي الوطني'),
  BankInfo('alinma', 'Alinma Bank', 'مصرف الإنماء'),
  BankInfo('bsf', 'Banque Saudi Fransi (BSF)', 'البنك السعودي الفرنسي'),
  BankInfo('saib', 'Saudi Investment Bank', 'البنك السعودي للاستثمار'),
  BankInfo('aljazira', 'Bank AlJazira', 'بنك الجزيرة'),
  BankInfo('albilad', 'Bank AlBilad', 'بنك البلاد'),
  BankInfo(
    'gib',
    'Gulf International Bank - Saudi Arabia (GIB-SA)',
    'بنك الخليج الدولي - السعودية',
  ),
  BankInfo('stc', 'STC Bank', 'بنك إس تي سي'),
  BankInfo('vision', 'Vision Bank', 'بنك فيجن'),
  BankInfo('d360', 'D360 Bank', 'بنك دال ثلاثمائة وستون'),
  BankInfo('barq', 'barq', 'barq', wallet: true),
  BankInfo('urpay', 'Urpay', 'يوراباي', wallet: true),
  BankInfo('mobilypay', 'Mobily Pay', 'موبايلي بي', wallet: true),
  BankInfo('alinmapay', 'AlinmaPay', 'الانماء باي', wallet: true),
];

BankInfo? bankInfo(String code) {
  for (final b in bankList) {
    if (b.code == code) return b;
  }
  return null;
}

/// The display name of [code] in the app language ([arabic] true = Arabic); an unknown code shows as is.
String bankDisplayName(String code, {required bool arabic}) {
  final b = bankInfo(code);
  if (b == null) return code;
  return arabic ? b.ar : b.en;
}

/// The bank or wallet code a message sender belongs to (the sender IDs of `docs/07-sms-catalog.md`), or null for a
/// sender that is not a bank (`900`, STC telecom bills) or not known. Case, spaces and dashes are ignored.
String? bankCodeForSender(String sender) {
  final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return switch (s) {
    'alinma' => 'alinma',
    'barqapp' || 'barq' => 'barq',
    'd360bank' || 'd360' => 'd360',
    'stcbank' => 'stc',
    'snbalahli' || 'snb' => 'snb',
    'alrajhibank' || 'alrajhi' => 'alrajhi',
    _ => _bankByName(s),
  };
}

/// Another sender that spells a known bank's code or English name ("RiyadBank", "Riyad Bank"), so a bank never
/// shows twice on the SMS capture page (once as the sender, once as an account with no messages).
String? _bankByName(String s) {
  if (s.isEmpty || s == '900') return null;
  String norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final b in bankList) {
    final code = norm(b.code);
    final name = norm(b.en);
    if (s == code || s == '${code}bank' || s == name) return b.code;
  }
  return null;
}
