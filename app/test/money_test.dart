import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/money.dart';

void main() {
  group('formatSar', () {
    test(
      'English puts SAR first, Arabic puts it after, digits stay Western',
      () {
        expect(formatSar(123456, arabic: false), '⃁ 1,234.56');
        expect(formatSar(123456, arabic: true), '1,234.56 ⃁');
        expect(formatSar(5, arabic: false), '⃁ 0.05');
        expect(formatSar(1410000, arabic: false), '⃁ 14,100.00');
      },
    );
  });

  group('formatSar negative', () {
    test('a net-negative total keeps its sign in every form', () {
      expect(formatSar(-500, arabic: false), '-⃁ 5.00');
      expect(formatSar(-500, arabic: true), '-5.00 ⃁');
      expect(formatSar(-500, arabic: false, symbol: false), '-SAR 5.00');
      expect(formatSar(500, arabic: false), '⃁ 5.00');
    });
  });

  group('parseHalalas', () {
    test('accepts plain, decimal, grouped and Arabic-Indic input', () {
      expect(parseHalalas('25'), 2500);
      expect(parseHalalas('25.5'), 2550);
      expect(parseHalalas('25.50'), 2550);
      expect(parseHalalas('1,250.05'), 125005);
      expect(parseHalalas('12,345,678.9'), 1234567890);
      expect(parseHalalas('٢٥٫٥'), 2550);
      expect(parseHalalas('  0.10 '), 10);
    });
    test('rejects empty, zero, negative, letters and three decimals', () {
      for (final s in [
        '',
        '0',
        '0.00',
        '-5',
        'abc',
        '1.234',
        '1..2',
        '5 SAR',
      ]) {
        expect(parseHalalas(s), isNull, reason: s);
      }
    });
    test('is exact (no float drift)', () {
      expect(parseHalalas('4.35'), 435);
      expect(parseHalalas('19.99'), 1999);
      expect(parseHalalas('0.29'), 29);
    });
  });

  group('guessAmountFromSms', () {
    test('finds the one amount written next to the riyal', () {
      expect(
        guessAmountFromSms('حوالة صادرة داخلية ب384 SAR \nل0102* PERSON X'),
        '384',
      );
      expect(guessAmountFromSms('Purchase SAR 1,250.50 at Shop'), '1,250.50');
      expect(guessAmountFromSms('مبلغ ٣٨٤٫٥٠ ريال'), '384.50');
      expect(guessAmountFromSms('خصم 45 ر.س من حسابك'), '45');
    });

    test('gives nothing when there is no amount or two different ones', () {
      expect(guessAmountFromSms('رمز التحقق 123456'), isNull);
      expect(guessAmountFromSms('Paid SAR 100 balance SAR 2,500.00'), isNull);
      expect(guessAmountFromSms(''), isNull);
    });

    test('the same amount written twice still counts as one', () {
      expect(guessAmountFromSms('SAR 90 ... 90 SAR'), '90');
    });
  });
}
