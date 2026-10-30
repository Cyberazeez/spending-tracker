// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'المصروفات';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabTransactions => 'العمليات';

  @override
  String get tabObligations => 'الالتزامات';

  @override
  String get tabInsights => 'التحليلات';

  @override
  String get tabMore => 'المزيد';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signIn => 'دخول';

  @override
  String get signingIn => 'جارٍ الدخول…';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get invalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get networkError =>
      'تعذّر الاتصال بالخادم. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get lockTitle => 'مقفل';

  @override
  String get lockBody => 'افتح القفل لعرض مصروفاتك.';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get unlockReason => 'فتح تطبيق المصروفات';

  @override
  String get unlockFailed => 'تعذّر فتح القفل. حاول مرة أخرى.';

  @override
  String get emptyHomeTitle => 'بانتظار أول رسالة نصية';

  @override
  String get emptyHomeBody =>
      'فعّل اختصار iOS من «المزيد» وستظهر هنا كل رسائل البنوك.';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get language => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get ingestToken => 'رمز الاستقبال';

  @override
  String get tokenScreenTitle => 'رمز الاستقبال';

  @override
  String get tokenIntro =>
      'يرسل اختصار iOS كل رسالة بنكية إلى هذا الرابط مع الرمز في ترويسة X-Ingest-Token.';

  @override
  String get ingestUrl => 'الرابط';

  @override
  String get ingestHeader => 'الترويسة';

  @override
  String get tokenStatus => 'الحالة';

  @override
  String get tokenNone => 'لا يوجد رمز فعّال';

  @override
  String tokenActive(String created) {
    return 'فعّال، أُنشئ $created';
  }

  @override
  String tokenLastUsed(String time) {
    return 'آخر رسالة وصلت $time';
  }

  @override
  String get tokenNeverUsed => 'لم تصل أي رسالة بعد';

  @override
  String get tokenGenerate => 'إنشاء رمز جديد';

  @override
  String get tokenRotate => 'استبدال الرمز';

  @override
  String get tokenConfirmTitle => 'استبدال الرمز؟';

  @override
  String get tokenConfirmBody =>
      'سيتوقف الرمز القديم فوراً وستحتاج إلى تحديث الاختصارات.';

  @override
  String get tokenShownOnce => 'انسخ الرمز الآن. يظهر مرة واحدة فقط.';

  @override
  String get tokenCopied => 'تم النسخ';

  @override
  String get copy => 'نسخ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get done => 'تم';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get genericError => 'حدث خطأ. حاول مرة أخرى.';
}
