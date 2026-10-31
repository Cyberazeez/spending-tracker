/// Mirror of supabase/functions/_shared/normalize.ts. Both are tested against the same examples.
String normalizeMerchant(String s) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  return s
      .replaceAll(RegExp('[\u064b-\u065f\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => arabicDigits.indexOf(m[0]!).toString(),
      )
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
