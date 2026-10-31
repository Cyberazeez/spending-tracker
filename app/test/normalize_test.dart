import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/normalize.dart';

// Same cases as supabase/functions/_shared/normalize_test.ts: the two implementations must agree.
void main() {
  test('case, punctuation and spacing', () {
    expect(normalizeMerchant('  MYSR*Jahez '), 'mysr jahez');
    expect(normalizeMerchant('HUNGERSTATION  LLC'), 'hungerstation llc');
  });

  test('Arabic diacritics, tatweel and letter variants fold together', () {
    expect(normalizeMerchant('مَطْعَم'), normalizeMerchant('مطعم'));
    expect(normalizeMerchant('أسواق'), normalizeMerchant('اسواق'));
    expect(normalizeMerchant('بقالـــة'), normalizeMerchant('بقاله'));
    expect(normalizeMerchant('مستشفى'), normalizeMerchant('مستشفي'));
  });

  test('Arabic-Indic digits become ASCII', () {
    expect(normalizeMerchant('فرع ١٢'), 'فرع 12');
  });
}
