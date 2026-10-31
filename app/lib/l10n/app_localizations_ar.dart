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

  @override
  String get txTitle => 'العمليات';

  @override
  String get txEmptyTitle => 'لا توجد عمليات بعد';

  @override
  String get txEmptyBody =>
      'تظهر رسائل البنك هنا بعد تشغيل الاختصار. ويمكنك أيضاً إضافة عملية يدوياً.';

  @override
  String get txInternal => 'داخلي';

  @override
  String get txFee => 'رسوم';

  @override
  String txOpenReview(int count) {
    return 'تحتاج مراجعة ($count)';
  }

  @override
  String get typePurchase => 'شراء';

  @override
  String get typeRefund => 'استرجاع';

  @override
  String get typeAtm => 'سحب نقدي';

  @override
  String get typeTransferOut => 'تحويل صادر';

  @override
  String get typeTransferIn => 'تحويل وارد';

  @override
  String get typeSalary => 'راتب';

  @override
  String get typeBill => 'سداد فاتورة';

  @override
  String get typeCardPayment => 'سداد بطاقة';

  @override
  String get typeWalletTopup => 'تعبئة محفظة';

  @override
  String get typeLoan => 'قسط تمويل';

  @override
  String get typeFee => 'رسوم';

  @override
  String get quickAdd => 'إضافة سريعة';

  @override
  String get qaAmount => 'المبلغ (ر.س)';

  @override
  String get qaMerchant => 'المتجر أو ملاحظة';

  @override
  String get qaSpent => 'صرف';

  @override
  String get qaReceived => 'استلام';

  @override
  String get qaWhen => 'الوقت';

  @override
  String get qaSave => 'حفظ';

  @override
  String get qaAmountInvalid => 'أدخل مبلغاً مثل 25 أو 25.50';

  @override
  String get qaSaveFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get reviewTitle => 'تحتاج مراجعة';

  @override
  String get reviewEmpty => 'لا شيء للمراجعة';

  @override
  String get reviewEmptyBody => 'تمت قراءة كل الرسائل بشكل صحيح.';

  @override
  String reviewFrom(String sender) {
    return 'من $sender';
  }

  @override
  String get reviewConvert => 'إضافة كعملية';

  @override
  String get reviewDismiss => 'ليست عملية';

  @override
  String get reviewLoadFailed => 'تعذّر تحميل الرسائل.';

  @override
  String get gapsTitle => 'فجوات محتملة';

  @override
  String get gapsIntro =>
      'آخر مرة وصلت فيها رسالة من كل جهة. الصمت الطويل قد يعني أن الاختصار متوقف.';

  @override
  String get gapsNever => 'لم تصل أي رسالة بعد';

  @override
  String gapsLast(String when) {
    return 'آخر رسالة $when';
  }

  @override
  String gapsDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'قبل $days يوم',
      few: 'قبل $days أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get gapsToday => 'اليوم';

  @override
  String get gapsEmpty => 'لا توجد رسائل بعد';

  @override
  String get sar => 'ر.س';

  @override
  String get loadFailed => 'تعذّر التحميل. اسحب لإعادة المحاولة.';

  @override
  String get searchHint => 'ابحث عن متجر';

  @override
  String get filterTitle => 'تصفية';

  @override
  String get filterAll => 'كل الفئات';

  @override
  String get filterUncategorized => 'بدون فئة فقط';

  @override
  String get filterHideInternal => 'إخفاء التحويلات الداخلية';

  @override
  String get filterShowInternal => 'إظهار التحويلات الداخلية';

  @override
  String get filterClear => 'مسح التصفية';

  @override
  String get categoryNone => 'بدون فئة';

  @override
  String get categoryPickTitle => 'الفئة';

  @override
  String get categoryRemove => 'إزالة الفئة';

  @override
  String applyPastTitle(int count) {
    return 'تطبيق على $count عملية أخرى؟';
  }

  @override
  String applyPastBody(String merchant, String category) {
    return 'تصنيف \"$merchant\" دائماً ضمن $category، وتغيير العمليات السابقة أيضاً؟';
  }

  @override
  String get applyPastYes => 'تغيير الكل';

  @override
  String get applyPastNo => 'المستقبلية فقط';

  @override
  String get categorySaveFailed => 'تعذّر تغيير الفئة. حاول مرة أخرى.';

  @override
  String get noMatches => 'لا توجد عمليات مطابقة';

  @override
  String get obSegUpcoming => 'القادمة';

  @override
  String get obSegOverdue => 'المتأخرة';

  @override
  String get obSegHistory => 'السجل';

  @override
  String get obCommitted => 'المتبقي للدفع خلال 30 يوماً';

  @override
  String obDue(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String obExpected(String amount) {
    return 'المتوقع $amount';
  }

  @override
  String obPaidAmount(String amount) {
    return 'المدفوع $amount';
  }

  @override
  String get obStatusPending => 'قيد الانتظار';

  @override
  String get obStatusOverdue => 'متأخر';

  @override
  String get obStatusPaid => 'مدفوع';

  @override
  String get obStatusSkipped => 'تم التخطي';

  @override
  String get obMarkPaid => 'تحديد كمدفوع';

  @override
  String get obSkip => 'تخطي هذه المرة';

  @override
  String get obReopen => 'إعادة الفتح';

  @override
  String obSuggestTitle(String name) {
    return 'هل تحدد \"$name\" كمدفوع بهذه الدفعة؟';
  }

  @override
  String get obConfirm => 'تأكيد';

  @override
  String get obNotThis => 'ليست هذه';

  @override
  String get obEmptyUpcoming => 'لا شيء مستحق خلال 30 يوماً';

  @override
  String get obEmptyOverdue => 'لا شيء متأخر';

  @override
  String get obEmptyHistory => 'لا يوجد سجل بعد';

  @override
  String get obMonthTitle => 'هذا الشهر';

  @override
  String get obMonthCommitted => 'الالتزامات';

  @override
  String get obMonthOther => 'بقية المصروفات';

  @override
  String get obSaveFailed => 'تعذر الحفظ. حاول مرة أخرى.';
}
