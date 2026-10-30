// One-time codes must never be stored. Matches English and Arabic bank wording seen in docs/07-sms-catalog.md.
const OTP_PATTERNS: RegExp[] = [
  /\botp\b/i,
  /verification\s+code/i,
  /security\s+code/i,
  /one[-\s]?time/i,
  /passcode/i,
  /رمز\s+(التأكيد|الأمان|السري)/,
  /كلمة\s+المرور\s+(المؤقتة|لمرة)/,
  /رمز\s*(ال)?(تحقق|تفعيل|دخول|مرور)/,
  /رمز\s+(التحقق|التفعيل)/,
];

export function isOtpLike(body: string): boolean {
  return OTP_PATTERNS.some((p) => p.test(body));
}

export const REDACTED_BODY = "[redacted]";
