// Pure helpers shared by every bank parser. No I/O.

const BIDI = /[‎‏‪-‮⁦-⁩؜]/g;
const ARABIC_INDIC = "٠١٢٣٤٥٦٧٨٩";
const EXT_INDIC = "۰۱۲۳۴۵۶۷۸۹";

/** Strip direction marks, map Arabic digits to ASCII, normalise line breaks and spaces. */
export function normalizeText(s: string): string {
  return s
    .replace(BIDI, "")
    .replace(/[٠-٩]/g, (d) => String(ARABIC_INDIC.indexOf(d)))
    .replace(/[۰-۹]/g, (d) => String(EXT_INDIC.indexOf(d)))
    .replace(/\u066c/g, ",")
    .replace(/\u066b/g, ".")
    .replace(/\r\n?/g, "\n")
    .replace(/[\t\u00a0 ]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .trim();
}

const MAX_AGE_MS = 30 * 24 * 3600 * 1000;
export const MAX_HALALAS = 10_000_000_000;

/** "1,800" / "20000.50" / "5.5" -> halalas, with string maths (no floats). */
export function toHalalas(s: string): number {
  // Commas are thousands separators only: "1,234.50" is fine, "12,34,56" or "12,50" is not an amount.
  if (!/^(\d+|\d{1,3}(,\d{3})+)(\.\d+)?$/.test(s.trim())) throw new Error("bad amount");
  const t = s.replace(/,/g, "").trim();
  if (!/^\d{1,12}(\.\d+)?$/.test(t)) throw new Error("bad amount");
  const [i, f = ""] = t.split(".");
  const h = parseInt(i, 10) * 100 + parseInt((f + "00").slice(0, 2), 10);
  // Larger than 100 million SAR is a typo or a forgery, never a real SMS.
  if (!Number.isSafeInteger(h) || h > MAX_HALALAS) throw new Error("bad amount");
  return h;
}

/** Minor units of a foreign currency (2 decimals assumed; BHD has 3 but is only used for display). */
export function toMinor(s: string): number {
  return toHalalas(s);
}

export function fullYear(y: number): number {
  return y < 100 ? 2000 + y : y;
}

/** Riyadh local wall time (UTC+3, no DST) to an ISO UTC string. */
export function riyadhToIso(
  y: number,
  mo: number,
  d: number,
  h: number,
  mi: number,
  s = 0,
): string {
  const t = new Date(Date.UTC(fullYear(y), mo - 1, d, h - 3, mi, s));
  return t.toISOString();
}

/** Valid calendar date/time check, so an impossible reading (month 26) is dropped. */
function valid(y: number, mo: number, d: number, h: number, mi: number): boolean {
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return false;
  const t = new Date(Date.UTC(fullYear(y), mo - 1, d));
  return t.getUTCMonth() === mo - 1 && t.getUTCDate() === d;
}

/**
 * Banks print dates in several orders (HH:mm dd-MM-yy, yy/M/d HH:mm, M/d/yyyy h:mm PM...).
 * Every plausible reading is generated and the one closest to when the SMS arrived wins.
 * Readings more than a day in the future are dropped.
 */
export function pickDate(text: string, receivedAt: Date): string | null {
  const c: string[] = [];
  const add = (y: number, mo: number, d: number, h: number, mi: number, s = 0) => {
    if (!valid(y, mo, d, h, mi)) return;
    c.push(riyadhToIso(y, mo, d, h, mi, s));
  };
  let m: RegExpMatchArray | null;
  // HH:mm[:ss] dd-MM-yy(yy) or dd/MM/yy(yy)
  for (
    m of text.matchAll(
      /(\d{1,2}):(\d{2})(?::(\d{2}))?\s+(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})(?!\d)/g,
    )
  ) {
    add(+m[6], +m[5], +m[4], +m[1], +m[2], +(m[3] ?? 0));
  }
  // dd-MM-yy(yy) HH:mm
  for (
    m of text.matchAll(
      /(?<!\d)(\d{1,2})[-/](\d{1,2})[-/](\d{1,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/g,
    )
  ) {
    if (m[3].length >= 2) add(+m[3], +m[2], +m[1], +m[4], +m[5], +(m[6] ?? 0));
    // yy/M/d HH:mm (Al Rajhi transfers): first group is the 2-digit year
    if (m[1].length === 2 && m[3].length <= 2) add(+m[1], +m[2], +m[3], +m[4], +m[5]);
  }
  // yyyy-MM-dd HH:mm
  for (m of text.matchAll(/(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/g)) {
    add(+m[1], +m[2], +m[3], +m[4], +m[5], +(m[6] ?? 0));
  }
  // M/d/yyyy with a 12-hour clock and AM/PM (possibly garbled to "PM?")
  const ampm = text.match(/\b(AM|PM)\b/i);
  const clock = text.match(/(\d{1,2}):(\d{2})/);
  const mdy = text.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
  if (ampm && clock && mdy) {
    let h = +clock[1] % 12;
    if (ampm[1].toUpperCase() === "PM") h += 12;
    add(+mdy[3], +mdy[1], +mdy[2], h, +clock[2]);
  }
  const ref = receivedAt.getTime();
  // A reading far from the arrival time is a different date format, a typo or a forgery: never guess.
  const pool = c.filter((iso) => {
    const d = new Date(iso).getTime() - ref;
    return d < 24 * 3600 * 1000 && d > -MAX_AGE_MS;
  });
  if (!pool.length) return null;
  pool.sort((a, b) =>
    Math.abs(new Date(a).getTime() - ref) - Math.abs(new Date(b).getTime() - ref)
  );
  return pool[0];
}

/** Date with no time (barq refunds): keep the SMS arrival time of day when it is the same Riyadh day. */
export function dateOnlyIso(y: number, mo: number, d: number, receivedAt: Date): string {
  const r = new Date(receivedAt.getTime() + 3 * 3600 * 1000);
  const sameDay = r.getUTCFullYear() === y && r.getUTCMonth() === mo - 1 && r.getUTCDate() === d;
  return sameDay
    ? riyadhToIso(y, mo, d, r.getUTCHours(), r.getUTCMinutes())
    : riyadhToIso(y, mo, d, 12, 0);
}

export function lines(body: string): string[] {
  return normalizeText(body).split("\n").map((l) => l.trim()).filter(Boolean);
}

export function last4(s: string | undefined | null): string | undefined {
  const m = s?.match(/(\d{4})(?!\d)/);
  return m ? m[1] : undefined;
}

/** Merchant strings come as "*SA /OTTEN", "SA/Govyy", "* SA /ORANGE AL": drop the country prefix. */
export function cleanMerchant(s: string): string {
  return s.replace(/^\*?\s*SA\s*\/\s*/i, "").replace(/^\*+\s*/, "").replace(/\s+/g, " ").trim();
}

/** Merchants that are really wallet top-ups between the owner's own accounts. */
const WALLET_MERCHANT =
  /^(barq(\s*(app|sa))?|stc\s*bank|d360(\s*bank)?(\s*sa)?|mysr\s*[*]?\s*d360)$/i;
export function isWalletMerchant(m?: string): boolean {
  return !!m && WALLET_MERCHANT.test(m.trim());
}
