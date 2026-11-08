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
  String get tabTransactions => 'النشاط';

  @override
  String get tabObligations => 'الفواتير';

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
  String get captureStatus => 'التقاط الرسائل';

  @override
  String captureWaiting(int count) {
    return '$count بالانتظار';
  }

  @override
  String captureLastOk(String time) {
    return 'آخر إرسال $time';
  }

  @override
  String captureLastFailed(String code) {
    return 'فشل آخر إرسال ($code)';
  }

  @override
  String get captureNone => 'لا شيء بالانتظار';

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
  String get txTitle => 'النشاط';

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
  String get qaAmount => 'المبلغ (⃁)';

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
  String get sar => '⃁';

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
  String get obMonthCommitted => 'التزامات هذا الشهر';

  @override
  String obGroupThis(String month) {
    return 'هذا الشهر · $month';
  }

  @override
  String obGroupNext(String month) {
    return 'الشهر القادم · $month';
  }

  @override
  String obGroupLater(String month, String year) {
    return '$month $year';
  }

  @override
  String get obMonthCommittedNote => 'المدفوعة والمتبقية';

  @override
  String obUsually(String min, String max) {
    return 'عادةً من $min إلى $max';
  }

  @override
  String get obEditAmount => 'تعديل المبلغ';

  @override
  String get obEditAmountPrompt => 'المبلغ بالريال';

  @override
  String get obAmountInvalid => 'أدخل مبلغاً مثل 700 أو 1,250.50';

  @override
  String get obMonthOther => 'بقية المصروفات';

  @override
  String get obSaveFailed => 'تعذر الحفظ. حاول مرة أخرى.';

  @override
  String get insMonthlyBudget => 'الميزانية الشهرية';

  @override
  String get insMonthlyBudgetNotSet => 'غير محددة';

  @override
  String insMonthlyBudgetUsed(String percent) {
    return 'تم استخدام $percent%';
  }

  @override
  String get insMonthlyBudgetPrompt => 'الميزانية الشهرية بالريال';

  @override
  String get homeToday => 'المصروف اليوم';

  @override
  String get homeBudgetUsed => 'المستخدم من الميزانية الشهرية';

  @override
  String homeMonthlyWarn(String percent) {
    return 'الميزانية الشهرية عند $percent%';
  }

  @override
  String get homeMonthlyOver => 'تجاوزت الميزانية الشهرية';

  @override
  String get remindersTitle => 'تذكير بالفواتير';

  @override
  String get remindersOn => 'مفعّل';

  @override
  String get remindersOff => 'متوقف';

  @override
  String get remindersHelp =>
      'إشعار الساعة 9:00 قبل موعد الفاتورة أو الدفعة بيومين تقريباً.';

  @override
  String get remindersDenied =>
      'الإشعارات متوقفة لهذا التطبيق. فعّلها من إعدادات الآيفون ثم حاول مرة أخرى.';

  @override
  String reminderBody(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String reminderBodyAmount(String date, String amount) {
    return 'الاستحقاق $date · نحو $amount';
  }

  @override
  String get insThisMonth => 'هذا الشهر';

  @override
  String get insSpent => 'المصروف حتى الآن';

  @override
  String get insVsLast => 'نفس اليوم من الشهر الماضي';

  @override
  String insUp(String amount) {
    return 'أعلى بـ $amount';
  }

  @override
  String insDown(String amount) {
    return 'أقل بـ $amount';
  }

  @override
  String get insSame => 'تقريباً نفسه';

  @override
  String get insNoCompare =>
      'لا يوجد ما يمكن مقارنته بعد: لا مصروفات مسجلة لنفس أيام الشهر الماضي';

  @override
  String get insSavings => 'نسبة الادخار';

  @override
  String insSavingsValue(String pct) {
    return '$pct٪';
  }

  @override
  String insSalaryAbove(String amount) {
    return 'الراتب أعلى من الأساس $amount';
  }

  @override
  String get insByCategory => 'حسب الفئة';

  @override
  String get insTopMerchants => 'أكثر المتاجر';

  @override
  String get insSpikes => 'ارتفاعات الإنفاق';

  @override
  String insSpikeLine(String amount, String avg) {
    return '$amount هذا الشهر، والمعتاد $avg';
  }

  @override
  String get insSubs => 'الاشتراكات';

  @override
  String insSubsTotal(String amount) {
    return '$amount شهرياً';
  }

  @override
  String get insBudgets => 'الميزانيات';

  @override
  String get insBudgetSet => 'تحديد ميزانية';

  @override
  String get insBudgetRemove => 'إزالة الميزانية';

  @override
  String get insBudgetPrompt => 'الحد الشهري بالريال';

  @override
  String get insBudgetInvalid => 'أدخل مبلغاً مثل 1500 أو 1,500.50';

  @override
  String insBudgetWarn(String name, String pct) {
    return '$name وصلت إلى $pct٪ من ميزانيتها';
  }

  @override
  String insBudgetOver(String name) {
    return '$name تجاوزت الميزانية';
  }

  @override
  String insOfLimit(String limit) {
    return 'من $limit';
  }

  @override
  String get insEmpty => 'لا توجد بيانات كافية بعد';

  @override
  String get insEmptyBody => 'سيظهر الإنفاق هنا بعد وصول أول عملياتك.';

  @override
  String get insSave => 'حفظ';

  @override
  String obPlanNote(String name, String n, String total, String amount) {
    return 'تشمل قسط $name $n من $total ($amount)';
  }

  @override
  String get homeNext => 'القادم';

  @override
  String get homeNothingDue => 'لا شيء مستحق قريباً';

  @override
  String homeStale(String days) {
    return 'لم تصل رسائل منذ $days أيام. تأكد أن الاختصارات ما زالت تعمل.';
  }

  @override
  String homeTop(String name, String amount) {
    return 'أعلى فئة: $name ($amount)';
  }

  @override
  String get homeAlerts => 'الميزانيات';

  @override
  String get homeAddTx => 'إضافة عملية';

  @override
  String get captureSetupTitle => 'إعداد التقاط الرسائل';

  @override
  String get captureIntro => 'افعل هذا مرة واحدة:';

  @override
  String get captureStep1 => 'الاختصارات > الأتمتة > + > رسالة';

  @override
  String get captureStep2 => 'الرسالة تحتوي «SAR»، تشغيل فوري';

  @override
  String get captureStep3 => 'أضف إجراء «Add bank message» (أيقونة التطبيق)';

  @override
  String get captureStep4 => 'اجعل Message وSender المتغيرين المطابقين';

  @override
  String get captureStep5 => 'تم. تُضاف رسائل البنك تلقائيًا.';

  @override
  String get captureGuideOpen => 'اعرض لي الخطوات';

  @override
  String get captureGuideTitle => 'إضافة الاختصار';

  @override
  String get captureGuideNext => 'التالي';

  @override
  String get captureGuideSkip => 'تخطي';

  @override
  String get captureGuideBack => 'السابق';

  @override
  String get captureGuideDone => 'تم';

  @override
  String captureGuideStepOf(int n, int total) {
    return 'الخطوة $n من $total';
  }

  @override
  String get captureGuide1Title => 'افتح الأتمتة';

  @override
  String get captureGuide1Body =>
      'في تطبيق الاختصارات اضغط على «الأتمتة» ثم على زر +.';

  @override
  String get captureGuide2Title => 'اختر «الرسالة»';

  @override
  String get captureGuide2Body => 'اختر «الرسالة» (عند استلام رسالة من…).';

  @override
  String get captureGuide3Title => 'اضبط الفلتر';

  @override
  String get captureGuide3Body =>
      'غيّر الفلتر إلى «الرسالة تحتوي» واكتب SAR. فعّل «الأتمتة» (تشغيل فوري) وأوقف «تأكيد قبل التشغيل» ثم اضغط التالي.';

  @override
  String get captureGuide4Title => 'أضف الإجراء';

  @override
  String get captureGuide4Body =>
      'اضغط «أتمتة فارغة جديدة» ثم ابحث عن «Add bank» واختر «Add bank message» (أيقونة Spending Tracker).';

  @override
  String get captureGuide5Title => 'املأ الحقلين';

  @override
  String get captureGuide5Body =>
      'Add Message from Sender: اضغط الحقل الأول واختر متغير الرسالة (Message)، ثم اضغط الحقل الثاني لاختيار المُرسل (Sender).';

  @override
  String get captureGuide6Title => 'اختر المُرسل';

  @override
  String get captureGuide6Body =>
      'اختر متغير الرسالة ثم علّم على Sender في القائمة واضغط تم.';

  @override
  String get captureGuide7Title => 'اكتمل الإعداد';

  @override
  String get captureGuide7Body =>
      'ستجد الأتمتة في القائمة والمفتاح مفعّل. الرسائل التي تكتب العملة «ريال» أو SR تحتاج نسخة خاصة بتلك الكلمة بدل SAR.';

  @override
  String get captureOpenShortcuts => 'فتح الاختصارات';

  @override
  String get captureStatusHeader => 'الحالة';

  @override
  String get captureSendNow => 'إرسال الرسائل المنتظرة الآن';

  @override
  String get homeOverview => 'نظرة عامة';

  @override
  String get homeSpentThisMonth => 'المصروف هذا الشهر';

  @override
  String get homeLast7 => 'آخر 7 أيام';

  @override
  String get homeWhereItWent => 'أين ذهب المال';

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get homeNextBills => 'الفواتير القادمة';

  @override
  String get homeAllBills => 'كل الفواتير';

  @override
  String get homeLeftToSpend => 'المتبقي للصرف';

  @override
  String get homeVsLastMonth => 'مقارنة بالشهر الماضي';

  @override
  String get homeSetBudget => 'حدد ميزانية شهرية';

  @override
  String get homeTodayShort => 'اليوم';

  @override
  String get homeSameShort => 'مماثل';

  @override
  String homeOfBudget(String amount) {
    return 'من ميزانية $amount';
  }

  @override
  String homeLower(String percent) {
    return 'أقل بنسبة $percent%';
  }

  @override
  String homeHigher(String percent) {
    return 'أعلى بنسبة $percent%';
  }

  @override
  String homeToReview(int count) {
    return '$count للمراجعة';
  }

  @override
  String homeBarLabel(String amount, String weekday) {
    return 'صُرف $amount يوم $weekday';
  }

  @override
  String homeDueIn(int days) {
    return 'مستحق خلال $days أيام';
  }

  @override
  String get homeDueTomorrow => 'مستحق غدًا';

  @override
  String get homeDueToday => 'مستحق اليوم';

  @override
  String get groupFood => 'طعام';

  @override
  String get groupTransport => 'تنقل';

  @override
  String get groupHomeBills => 'المنزل والفواتير';

  @override
  String get groupFamily => 'الأسرة';

  @override
  String get groupHorse => 'الخيل';

  @override
  String get groupLifestyle => 'نمط الحياة';

  @override
  String get groupSubscriptions => 'اشتراكات';

  @override
  String get groupHealth => 'الصحة والعناية';

  @override
  String get groupMoney => 'المال والرسوم';

  @override
  String get groupOther => 'أخرى';

  @override
  String get txToday => 'اليوم';

  @override
  String get txYesterday => 'أمس';

  @override
  String get txChooseCategory => 'اختر فئة';

  @override
  String get txChipAll => 'الكل';

  @override
  String get txChipNoCategory => 'بدون فئة';

  @override
  String get txChipHideInternal => 'إخفاء الداخلية';

  @override
  String get insTrendTitle => 'هذا الشهر مقابل الشهر الماضي';

  @override
  String get insTrendNoLast =>
      'لا إنفاق في الشهر الماضي لنفس الأيام، لذلك يُرسم هذا الشهر فقط.';

  @override
  String get insLegendThis => 'هذا الشهر';

  @override
  String get insLegendLast => 'الشهر الماضي';

  @override
  String get insMonthsTitle => 'آخر 4 أشهر';

  @override
  String insBudgetLine(String amount) {
    return 'الميزانية $amount';
  }

  @override
  String get insWhereTitle => 'أين ذهب المال';

  @override
  String insTrendLabel(String now, String before) {
    return '$now حتى الآن هذا الشهر، و$before في نفس اليوم من الشهر الماضي';
  }

  @override
  String insMonthBarLabel(String month, String amount) {
    return '$month: $amount';
  }

  @override
  String insVisits(int count) {
    return '$count زيارات';
  }

  @override
  String get insVisit => 'زيارة واحدة';

  @override
  String get insSavingsRateLabel => 'معدل الادخار';

  @override
  String get insSpikeBadge => 'ارتفاع في الصرف';

  @override
  String insSubsServices(int count) {
    return '$count خدمات شهريًا';
  }

  @override
  String get obNew => 'التزام جديد';

  @override
  String get obEditTitle => 'تعديل الالتزام';

  @override
  String get obfName => 'الاسم';

  @override
  String get obfType => 'النوع';

  @override
  String get obfKindBill => 'فاتورة';

  @override
  String get obfKindFixed => 'ثابت';

  @override
  String get obfKindLoan => 'قرض';

  @override
  String get obfAmountFixed => 'مبلغ ثابت';

  @override
  String get obfAmountEstimated => 'تقديري';

  @override
  String get obfAmount => 'المبلغ بالريال';

  @override
  String get obfAmountBillNote =>
      'اختياري للفاتورة: اتركه فارغاً وستحدد رسالة الفاتورة مبلغ كل شهر.';

  @override
  String get obfRepeats => 'التكرار';

  @override
  String get obfMonthly => 'شهري';

  @override
  String get obfQuarterly => 'كل 3 أشهر';

  @override
  String get obfAnnual => 'سنوي';

  @override
  String get obfDueDay => 'يوم الاستحقاق';

  @override
  String get obfDueDayNote => 'الأشهر القصيرة تستخدم آخر يوم فيها.';

  @override
  String get obfStartMonth => 'أول شهر استحقاق';

  @override
  String get obfGrace => 'أيام السماح';

  @override
  String get obfLead => 'التذكير قبل (أيام)';

  @override
  String get obfCategory => 'التصنيف';

  @override
  String get obfNoCategory => 'بدون';

  @override
  String get obfMatchWords => 'كلمات المطابقة';

  @override
  String get obfMatchHint => 'مثال: نادي، stc (حتى 5، تفصل بينها فاصلة)';

  @override
  String get obfTolerance => 'نسبة تفاوت المبلغ %';

  @override
  String get obfAuto => 'اعتبارها مدفوعة تلقائياً';

  @override
  String get obfAutoNote => 'إذا أُوقف: يُقترح الدفع المطابق فقط لتؤكده.';

  @override
  String get obfSave => 'حفظ';

  @override
  String get obfNameRequired => 'أدخل اسماً (حتى 60 حرفاً).';

  @override
  String get obfWordsInvalid => 'حتى 5 كلمات، كل كلمة حتى 30 حرفاً.';

  @override
  String get obEditDetails => 'تعديل التفاصيل';

  @override
  String get obStop => 'إيقاف المتابعة';

  @override
  String obStopConfirm(String name) {
    return '$name لن يظهر بعد الآن. يبقى سجل المدفوعات.';
  }

  @override
  String get obAddHint => 'إضافة التزام';

  @override
  String get obfNameTaken => 'لديك التزام بهذا الاسم بالفعل.';

  @override
  String get aiTitle => 'المساعد الذكي';

  @override
  String get aiPaidOnly => 'ضمن الباقة المدفوعة. قريبًا.';

  @override
  String get aiSubtitle =>
      'يرسل المجاميع وأسماء المتاجر فقط، وليس نص الرسائل أو الأسماء أو أرقام الحسابات.';

  @override
  String get aiTipsTitle => 'نصائح ذكية';

  @override
  String get aiTipsGet => 'احصل على نصائح';

  @override
  String get aiTipsRefresh => 'تحديث النصائح';

  @override
  String get aiTipsEmpty => 'احصل على نصائح توفير بناءً على مجاميع هذا الشهر.';

  @override
  String get aiTipsNote => 'مبنية على المجاميع فقط. راجع الأرقام قبل التصرف.';

  @override
  String get aiTipsNone => 'لا نصائح هذه المرة.';

  @override
  String aiSuggestTitle(String n) {
    return '$n عمليات بدون تصنيف';
  }

  @override
  String get aiSuggestAction => 'اقتراح بالذكاء الاصطناعي';

  @override
  String aiSuggestDone(String n) {
    return 'تم تصنيف $n عمليات. اضغط «اقتراح الذكاء» لمراجعتها.';
  }

  @override
  String get aiSuggestNone => 'لا شيء للتصنيف بعد.';

  @override
  String get aiReasonDisabled => 'الذكاء الاصطناعي متوقف. فعّله من المزيد.';

  @override
  String get aiReasonNoKey => 'الذكاء الاصطناعي غير مفعّل على الخادم بعد.';

  @override
  String get aiReasonCap =>
      'استُهلكت ميزانية الذكاء الاصطناعي لهذا الشهر. تتجدد الشهر القادم.';

  @override
  String get aiReasonOffline => 'لا يوجد اتصال. حاول مرة أخرى.';

  @override
  String get aiReasonFailed => 'تعذر الحصول على إجابة. حاول لاحقاً.';

  @override
  String get txAiTag => 'ذكاء';

  @override
  String get txChipAi => 'اقتراح الذكاء';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountProfile => 'الملف الشخصي';

  @override
  String get accountSecurity => 'الأمان';

  @override
  String get accountSecurityHint => 'تغيير كلمة المرور';

  @override
  String get accountPrivacy => 'الخصوصية';

  @override
  String get accountName => 'الاسم';

  @override
  String get accountNameHint => 'اسمك';

  @override
  String get accountSave => 'حفظ';

  @override
  String get accountNameTooLong => 'استخدم حتى 60 حرفاً.';

  @override
  String get accountEmailInvalid => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get accountEmailSent =>
      'تحقق من عنوانك الجديد لرابط التأكيد. يبقى القديم حتى تستخدمه.';

  @override
  String get accountSaveFailed => 'تعذر الحفظ. حاول مرة أخرى.';

  @override
  String get secChangePassword => 'تغيير كلمة المرور';

  @override
  String get secCurrent => 'كلمة المرور الحالية';

  @override
  String get secNew => 'كلمة المرور الجديدة';

  @override
  String get secConfirm => 'أعد كلمة المرور الجديدة';

  @override
  String get secRulesHint => '8 أحرف على الأقل.';

  @override
  String get secWrongCurrent => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get secTooShort => 'استخدم 8 أحرف على الأقل.';

  @override
  String get secMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get secSame => 'اختر كلمة مرور مختلفة.';

  @override
  String get secDone => 'تم تغيير كلمة المرور.';

  @override
  String get secNote =>
      'يعيد هذا ضبط التقاط الرسائل والودجت على هذا الهاتف. يعيدان الاتصال تلقائياً.';

  @override
  String get privacyBody =>
      'بياناتك محفوظة في حسابك ولا يقرأها غيرك. ستظهر خيارات أخرى هنا قريباً.';

  @override
  String get moreAccount => 'الحساب';

  @override
  String get forgotLink => 'نسيت كلمة المرور؟';

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotIntro =>
      'أدخل البريد الذي سجّلت به. سنرسل لك رابطًا لاختيار كلمة مرور جديدة.';

  @override
  String get forgotSend => 'إرسال رابط إعادة التعيين';

  @override
  String get forgotSent =>
      'إذا كان لهذا البريد حساب، فرابط إعادة التعيين في الطريق إليك. تحقق من البريد الوارد ومجلد الرسائل غير المرغوب فيها.';

  @override
  String forgotWait(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get forgotTryLater => 'طلبات كثيرة الآن. حاول مرة أخرى بعد بضع دقائق.';

  @override
  String get resetTitle => 'اختر كلمة مرور جديدة';

  @override
  String get resetSave => 'حفظ كلمة المرور';

  @override
  String get orDivider => 'أو';

  @override
  String get appleSignIn => 'تسجيل الدخول عبر Apple';

  @override
  String get appleFailed => 'تعذّر تسجيل الدخول عبر Apple. حاول مرة أخرى.';

  @override
  String get linkExpiredTitle => 'انتهت صلاحية هذا الرابط';

  @override
  String get linkExpiredBody =>
      'الرابط في البريد استُخدم من قبل أو أصبح قديمًا. اطلب رابطًا جديدًا وافتح أحدث رسالة فقط.';

  @override
  String get linkExpiredOk => 'اطلب رابطًا جديدًا';

  @override
  String get resetDone => 'تم تغيير كلمة المرور. أنت مسجّل الدخول.';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpLink => 'إنشاء حساب';

  @override
  String get signUpNameRequired => 'أدخل اسمك (حتى 60 حرفاً).';

  @override
  String get signUpEmailTaken => 'هذا البريد لديه حساب بالفعل. سجّل الدخول.';

  @override
  String get signUpDisabled => 'التسجيل مغلق حالياً. اسأل المالك.';

  @override
  String get signUpCheckEmail =>
      'تحقق من بريدك واضغط رابط التأكيد، ثم عد وسجّل الدخول.';

  @override
  String get signUpWeak =>
      'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل مع حروف وأرقام.';

  @override
  String get signUpTryLater => 'تعذر إنشاء الحساب الآن. حاول بعد دقائق.';

  @override
  String get signUpResend => 'أرسل الرسالة مرة أخرى';

  @override
  String signUpCheckEmailTo(String email) {
    return 'أرسلنا رابط التأكيد إلى $email. اضغط عليه وسيتم تسجيل دخولك.';
  }

  @override
  String get signUpBackToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get accountBanks => 'الحسابات البنكية';

  @override
  String get accountBanksShort => 'حساباتك وبطاقاتك';

  @override
  String get accountBanksHint =>
      'أضف حساباتك وبطاقاتك ومحافظك حتى لا يُحتسب تحويل المال بينها كمصروف.';

  @override
  String get banksEmpty => 'لا توجد حسابات بعد.';

  @override
  String get bankAdd => 'إضافة حساب';

  @override
  String get bankPick => 'البنك';

  @override
  String get bankKind => 'النوع';

  @override
  String get bankLast4 => 'آخر 4 أرقام';

  @override
  String get bankLabelOptional => 'الاسم (اختياري)';

  @override
  String get bankSave => 'إضافة';

  @override
  String get bankLast4Invalid => 'أدخل 4 أرقام بالضبط.';

  @override
  String get bankDuplicate => 'هذا الحساب موجود في القائمة.';

  @override
  String get bankRemove => 'حذف';

  @override
  String bankRemoveConfirm(String name) {
    return 'حذف $name؟';
  }

  @override
  String get kindAccount => 'حساب';

  @override
  String get kindDebit => 'بطاقة مدى';

  @override
  String get kindCredit => 'بطاقة ائتمان';

  @override
  String get kindWallet => 'محفظة';

  @override
  String get welcomeTitle => 'ابدأ من هنا';

  @override
  String get welcomeHide => 'إخفاء';

  @override
  String welcomeProgress(String done, String total) {
    return 'تم $done من $total';
  }

  @override
  String get welcomeAccounts => 'أضف حساباتك البنكية';

  @override
  String get welcomeCapture => 'فعّل التقاط الرسائل';

  @override
  String get welcomeBudget => 'حدد ميزانية شهرية';

  @override
  String get deleteAccountRow => 'حذف حسابي';

  @override
  String get deleteTitle => 'حذف الحساب';

  @override
  String get deleteWarn =>
      'سيتم حذف حسابك وكل بياناتك (العمليات والفواتير والميزانيات والإعدادات) نهائيًا بعد 30 يومًا. إذا سجّلت الدخول قبل ذلك فلن يُحذف شيء.';

  @override
  String get deleteWord => 'حذف';

  @override
  String deleteTypeWord(String word) {
    return 'اكتب $word للتأكيد';
  }

  @override
  String deleteWordMismatch(String word) {
    return 'اكتب $word بالضبط للتأكيد.';
  }

  @override
  String get deletePassword => 'كلمة المرور';

  @override
  String get deleteButton => 'حذف حسابي';

  @override
  String get deleteApple =>
      'سجّلت الدخول عبر Apple، لذلك لا توجد كلمة مرور. بعد التأكيد سيطلب منك Apple تسجيل الدخول مرة أخرى للتحقق أنك أنت.';

  @override
  String get deleteWrongApple =>
      'حساب Apple هذا ليس حساب Apple الخاص بهذا الحساب.';

  @override
  String get secNoPassword =>
      'تسجّل الدخول عبر Apple، لذلك لا توجد كلمة مرور لهذا الحساب لتغييرها.';

  @override
  String get deleteWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get deleteTooMany => 'محاولات كثيرة. حاول غداً.';

  @override
  String get deleteFailed => 'تعذر الحذف. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get deleteSureTitle => 'هل أنت متأكد؟';

  @override
  String get deleteSureBody =>
      'تم إغلاق حسابك الآن وسيُحذف كل شيء نهائيًا بعد 30 يومًا دون إمكانية الاستعادة. تسجيل الدخول خلال 30 يومًا يلغي الحذف.';

  @override
  String get deleteSureConfirm => 'احذف كل شيء';

  @override
  String get reactivatedTitle => 'أهلًا بعودتك';

  @override
  String get reactivatedBody =>
      'حسابك نشط مرة أخرى وتم إلغاء الحذف. كل بياناتك ما زالت موجودة.';

  @override
  String get reactivatedOk => 'حسنًا';

  @override
  String get categorySearch => 'ابحث في التصنيفات';

  @override
  String get categorySuggested => 'مقترح لهذا التاجر';

  @override
  String get categoryNoMatch => 'لا يوجد تصنيف مطابق';

  @override
  String get aiChatTitle => 'اسأل عن مصاريفك';

  @override
  String get aiChatOpen => 'اطرح سؤالًا';

  @override
  String get aiChatHint => 'اسأل عن تصنيف أو ميزانية';

  @override
  String get aiChatSend => 'إرسال';

  @override
  String get aiChatIntro =>
      'اسأل عن مصاريف هذا الشهر أو تصنيف أو ميزانية. أرى المجاميع فقط، ولا أرى التجار ولا الرسائل.';

  @override
  String get aiChatThinking => 'جارٍ التفكير…';

  @override
  String get aiChatNoData =>
      'لا يوجد ما نتحدث عنه بعد. عد عندما تُسجَّل بعض المصاريف.';

  @override
  String get aiChatPromptCut => 'أين يمكنني تقليل المصاريف؟';

  @override
  String get aiChatPromptBudget => 'هل أنا ملتزم بميزانياتي؟';

  @override
  String get aiChatPromptLast => 'كيف يقارن هذا الشهر بالشهر الماضي؟';

  @override
  String aiChatPromptCategory(String category) {
    return 'لماذا $category مرتفع جدًا؟';
  }

  @override
  String get aiChatRetry => 'حاول مرة أخرى';

  @override
  String get aiTipsTapHint => 'اضغط لتسأل عن تصنيف أو ميزانية';

  @override
  String obCycleStill(String month) {
    return '$month · المتبقي للدفع';
  }

  @override
  String obCyclePaid(String paid, String total, String done, String count) {
    return 'مدفوع $paid من $total · $done من $count فواتير';
  }

  @override
  String obUnpaidBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فواتير غير مدفوعة من أشهر سابقة',
      one: 'فاتورة واحدة غير مدفوعة من شهر سابق',
    );
    return '$_temp0';
  }

  @override
  String obNextSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فواتير',
      one: 'فاتورة واحدة',
    );
    return '$_temp0';
  }

  @override
  String obNextNote(String amount) {
    return 'حوالي $amount · اضغط لعرضها';
  }

  @override
  String get obAmountPending => 'المبلغ يصل مع كشف الحساب';
}
