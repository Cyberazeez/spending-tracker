import Security
import SwiftUI
import UIKit
import WidgetKit

// Home-screen and lock-screen widget. The app saves its numbers in the shared App Group (AppDelegate
// "spending_tracker/widget") and also hands the widget a read-only token. Every refresh the widget asks the
// `widget-summary` function for fresh numbers; if that fails (offline, no token yet) it shows what the app last saved.
private let appGroup = "group.com.cyberazeez.spendingtracker"
private let riyadh = TimeZone(identifier: "Asia/Riyadh") ?? TimeZone.current

struct SpendingEntry: TimelineEntry {
    let date: Date
    let today: Int?      // halalas; nil when the saved figure is from an earlier day
    let month: Int?      // halalas; nil when the saved figure is from an earlier month
    let budget: Int?     // halalas; nil when no monthly budget is set
    let arabic: Bool

    var percent: Int? {
        guard let month = month, let budget = budget, budget > 0 else { return nil }
        return (month * 100) / budget
    }

    static let sample = SpendingEntry(date: Date(), today: 4_500, month: 58_055, budget: 800_000, arabic: false)
}

struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(context.isPreview ? .sample : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        // iOS decides the real schedule (a few dozen refreshes a day); 15 minutes is only our request.
        let next = Date().addingTimeInterval(15 * 60)
        fetchRemote { remote in
            if let remote = remote {
                let defaults = UserDefaults(suiteName: appGroup)
                defaults?.set(remote.today, forKey: "today")
                defaults?.set(remote.month, forKey: "month")
                if let budget = remote.budget {
                    defaults?.set(budget, forKey: "budget")
                } else {
                    defaults?.removeObject(forKey: "budget")
                }
                defaults?.set(Int(Date().timeIntervalSince1970), forKey: "updated")
            }
            // A second entry at the next Riyadh midnight, so "today" turns into "--" even if iOS refreshes late.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = riyadh
            let now = Date()
            var entries = [self.load(at: now)]
            if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
                entries.append(self.load(at: midnight))
            }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }

    private func load(at now: Date = Date()) -> SpendingEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = riyadh

        var today: Int? = nil
        var month: Int? = nil
        if let seconds = defaults?.object(forKey: "updated") as? NSNumber {
            let saved = Date(timeIntervalSince1970: seconds.doubleValue)
            if calendar.isDate(saved, inSameDayAs: now) {
                today = defaults?.integer(forKey: "today") ?? 0
            }
            if calendar.isDate(saved, equalTo: now, toGranularity: .month) {
                month = defaults?.integer(forKey: "month") ?? 0
            }
        }
        let budget = (defaults?.object(forKey: "budget") as? NSNumber)?.intValue
        let arabic = (defaults?.string(forKey: "lang") ?? "en") == "ar"
        return SpendingEntry(date: now, today: today, month: month, budget: budget, arabic: arabic)
    }
}

// MARK: - Fresh numbers from the server

private struct Remote {
    let today: Int
    let month: Int
    let budget: Int?
}

private func fetchRemote(completion: @escaping (Remote?) -> Void) {
    guard let credentials = WidgetKeychain.load(),
          let url = URL(string: credentials.url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/functions/v1/widget-summary")
    else {
        completion(nil)
        return
    }
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.httpMethod = "GET"
    request.setValue(credentials.token, forHTTPHeaderField: "x-widget-token")
    URLSession.shared.dataTask(with: request) { data, response, _ in
        guard let http = response as? HTTPURLResponse else {
            completion(nil)  // offline: keep showing the last numbers
            return
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            // Forget the token only when OUR function says it is invalid (revoked or replaced); a gateway or proxy
            // 401 must not wipe a good token. The app then provisions a new one the next time it opens.
            let error = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["error"] as? String
            if error == "unauthorized" {
                WidgetKeychain.clear()
            }
            completion(nil)
            return
        }
        guard http.statusCode == 200, let data = data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let today = (object["today"] as? NSNumber)?.intValue,
              let month = (object["month"] as? NSNumber)?.intValue
        else {
            completion(nil)
            return
        }
        completion(Remote(today: today, month: month, budget: (object["budget"] as? NSNumber)?.intValue))
    }.resume()
}

// MARK: - Text

/// The riyal sign (U+20C1) comes from the bundled SaudiRiyal font, as in the app: no iOS system font has it yet.
/// If the font did not load, amounts fall back to "SAR" / "ر.س" rather than an empty box.
private let riyalFontName = "saudi_riyalbold"
private let riyalFontLoaded = UIFont(name: riyalFontName, size: 12) != nil

/// "1,234.50": Western digits and halalas in both languages, like `formatAmountPlain` in the app.
private func plain(_ halalas: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    let whole = formatter.string(from: NSNumber(value: abs(halalas) / 100)) ?? "0"
    let frac = String(format: "%02d", abs(halalas) % 100)
    return "\(halalas < 0 ? "-" : "")\(whole).\(frac)"
}

/// An amount with the riyal sign: before the number in English, after it in Arabic (`formatSar` in the app).
private func amount(_ halalas: Int?, arabic: Bool, size: CGFloat) -> Text {
    guard let halalas = halalas else { return Text("--").font(rubik(size, heavy: true)) }
    let number = Text(plain(halalas)).font(rubik(size, heavy: true))
    guard riyalFontLoaded else {
        return arabic ? number + Text(" ر.س").font(rubik(size * 0.7, heavy: true))
            : Text("SAR ").font(rubik(size * 0.7, heavy: true)) + number
    }
    let sign = Text("\u{20C1}").font(.custom(riyalFontName, size: size * 0.85))
    return arabic ? number + Text(" ") + sign : sign + Text(" ") + number
}

private func words(_ arabic: Bool) -> (today: String, month: String, budget: String, setBudget: String, openApp: String,
                                       left: String, over: String, todayShort: String) {
    if arabic {
        return ("المصروف اليوم", "مصروف الشهر", "من الميزانية", "حدد ميزانية شهرية", "افتح التطبيق للتحديث",
                "المتبقي للصرف", "فوق الميزانية", "اليوم")
    }
    return ("Spent today", "Spent this month", "of budget", "Set a monthly budget", "Open the app to refresh",
            "Left to spend", "Over by", "Today")
}

// MARK: - Look (Halala rebrand, docs/superpowers/specs/2026-11-11-rebrand-design.md; same values as app/lib/ui/tokens.dart)

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Light and dark colours. Text on the emerald or mint fill is ink, as in the app (`onAccent`).
private struct Palette {
    let card: Color    // white / moss
    let text: Color    // ink / paper
    let muted: Color
    let accent: Color  // emerald / mint
    let line: Color    // outlines and hard shadows: ink / paper
    let track: Color
    let gold = Color(hex: 0xFFC93C)
    let ink = Color(hex: 0x0D1F17)
    let danger: Color

    init(_ scheme: ColorScheme) {
        let dark = scheme == .dark
        card = Color(hex: dark ? 0x173326 : 0xFFFFFF)
        text = Color(hex: dark ? 0xF0F5E6 : 0x0D1F17)
        muted = Color(hex: dark ? 0xA9BBAF : 0x45564B)
        accent = Color(hex: dark ? 0x3FD79B : 0x00A86B)
        line = Color(hex: dark ? 0xF0F5E6 : 0x0D1F17)
        track = Color(hex: dark ? 0x2B4C3D : 0xDCE5CC)
        danger = Color(hex: dark ? 0xFF9DB0 : 0xD11A3F)
    }
}

/// Rubik, bundled in the widget (renamed copies of the app's files, see docs/brand/README.md). If it did not load,
/// iOS falls back to the system font, so text never disappears.
private func rubik(_ size: CGFloat, heavy: Bool = false) -> Font {
    .custom(heavy ? "Rubik-ExtraBold" : "Rubik-Bold", size: size)
}

/// The هللة logo (paper letters, gold coins, ink outline and shadow), drawn from docs/brand/logo.svg as
/// HalalaLogo@2x/@3x.png. Nothing is shown if the image is missing.
private struct Logo: View {
    let width: CGFloat

    var body: some View {
        if let image = UIImage(named: "HalalaLogo") {
            Image(uiImage: image).resizable().scaledToFit().frame(width: width).accessibilityHidden(true)
        }
    }
}

/// Alignment for the language of the text. The widget follows the phone's layout direction, so Arabic text is
/// aligned to the right by hand; hard shadows stay to the right and down in both languages, as in the mockup.
private func lead(_ arabic: Bool) -> HorizontalAlignment { arabic ? .trailing : .leading }
private func corner(_ arabic: Bool, top: Bool) -> Alignment {
    switch (arabic, top) {
    case (true, true): return .topTrailing
    case (true, false): return .bottomTrailing
    case (false, true): return .topLeading
    case (false, false): return .bottomLeading
    }
}

/// The budget bar: gold share on a track with an outline, red when over budget (like the Home hero). In Arabic it
/// fills from the right.
private struct BudgetBar: View {
    let percent: Int
    let palette: Palette
    let arabic: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: arabic ? .trailing : .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(percent > 100 ? palette.danger : palette.gold)
                    .frame(width: max(geo.size.width * CGFloat(min(percent, 100)) / 100, percent > 0 ? 10 : 0))
                Capsule().strokeBorder(palette.line, lineWidth: 2)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Views

/// Small: the emerald (mint in dark mode) tile from the mockup: logo on top, then spent today and the share of the
/// month's budget at the bottom, in ink. Where iOS removes the widget's background (StandBy on iOS 17+) the text
/// switches to the normal text colour, so it never sits as ink on black.
struct SmallView: View {
    let entry: SpendingEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            BackgroundAware { shown in SmallContent(entry: entry, onFill: shown) }
        } else {
            SmallContent(entry: entry, onFill: true)
        }
    }
}

@available(iOS 17.0, *)
private struct BackgroundAware<Content: View>: View {
    @Environment(\.showsWidgetContainerBackground) private var shown
    let content: (Bool) -> Content

    var body: some View { content(shown) }
}

private struct SmallContent: View {
    let entry: SpendingEntry
    let onFill: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let w = words(entry.arabic)
        let p = Palette(scheme)
        let ink = onFill ? p.ink : p.text
        VStack(alignment: lead(entry.arabic), spacing: 2) {
            Logo(width: 56)
            Spacer(minLength: 4)
            Text(w.today).font(rubik(13)).foregroundColor(ink).lineLimit(1)
            amount(entry.today, arabic: entry.arabic, size: 26)
                .foregroundColor(ink)
                .minimumScaleFactor(0.5).lineLimit(1)
            if entry.today == nil {
                Text(w.openApp).font(rubik(11)).foregroundColor(ink).lineLimit(2)
            } else if let percent = entry.percent {
                Text("\(percent)% \(w.budget)").font(rubik(12)).foregroundColor(ink).lineLimit(1)
            } else {
                Text(w.setBudget).font(rubik(11)).foregroundColor(ink).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .multilineTextAlignment(entry.arabic ? .trailing : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner(entry.arabic, top: true))
    }
}

/// Medium: a white (moss) card. The month total sits on an emerald tile with the logo, an outline and a hard shadow;
/// beside it the share of the budget, the bar, and the two facts of the Home hero: left to spend (or how far over)
/// and today. In Arabic the tile is on the right.
struct MediumView: View {
    let entry: SpendingEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette(scheme)
        HStack(alignment: .center, spacing: 14) {
            if entry.arabic {
                details(p)
                tile(p)
            } else {
                tile(p)
                details(p)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(_ p: Palette) -> some View {
        let w = words(entry.arabic)
        return VStack(alignment: lead(entry.arabic), spacing: 1) {
            Logo(width: 48)
            Spacer(minLength: 2)
            Text(w.month).font(rubik(11)).foregroundColor(p.ink).lineLimit(1).minimumScaleFactor(0.8)
            amount(entry.month, arabic: entry.arabic, size: 20)
                .foregroundColor(p.ink)
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .padding(10)
        .frame(width: 136)
        .frame(maxHeight: .infinity, alignment: corner(entry.arabic, top: true))
        // Fill first, then the hard shadow behind it (a later .background sits further back).
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(p.accent))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(p.line)
                .offset(x: 3, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(p.line, lineWidth: 2))
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
        .padding(entry.arabic ? .leading : .trailing, 3)
    }

    @ViewBuilder
    private func details(_ p: Palette) -> some View {
        let w = words(entry.arabic)
        VStack(alignment: lead(entry.arabic), spacing: 8) {
            if let percent = entry.percent, let budget = entry.budget, let month = entry.month {
                Text("\(percent)% \(w.budget)")
                    .font(rubik(15, heavy: true)).foregroundColor(p.text)
                    .minimumScaleFactor(0.7).lineLimit(1)
                BudgetBar(percent: percent, palette: p, arabic: entry.arabic)
                facts(p, month: month, budget: budget)
            } else if entry.month != nil {
                Text(w.setBudget).font(rubik(13)).foregroundColor(p.muted)
            } else {
                Text(w.openApp).font(rubik(13)).foregroundColor(p.muted)
            }
        }
        .multilineTextAlignment(entry.arabic ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: entry.arabic ? .trailing : .leading)
    }

    /// The Home hero's white panel: left to spend (red "over by" past the budget) | today.
    private func facts(_ p: Palette, month: Int, budget: Int) -> some View {
        let w = words(entry.arabic)
        let over = month > budget
        let left = fact(p, label: over ? w.over : w.left, value: over ? month - budget : budget - month,
                        color: over ? p.danger : p.text)
        let today = fact(p, label: w.todayShort, value: entry.today, color: p.text)
        return HStack(spacing: 0) {
            if entry.arabic { today } else { left }
            Rectangle().fill(p.line).frame(width: 2).padding(.vertical, 6)
            if entry.arabic { left } else { today }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.line, lineWidth: 2))
    }

    private func fact(_ p: Palette, label: String, value: Int?, color: Color) -> some View {
        VStack(alignment: lead(entry.arabic), spacing: 1) {
            Text(label).font(rubik(10)).foregroundColor(p.muted).lineLimit(1).minimumScaleFactor(0.7)
            Text(value.map(plain) ?? "--")
                .font(rubik(14, heavy: true)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: entry.arabic ? .trailing : .leading)
    }
}

struct CircularView: View {
    let entry: SpendingEntry
    var body: some View {
        if let percent = entry.percent {
            Gauge(value: Double(min(percent, 100)), in: 0...100) {
                Text("%")
            } currentValueLabel: {
                Text("\(percent)")
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            Text("--").font(.title3)
        }
    }
}

struct RectangularView: View {
    let entry: SpendingEntry
    var body: some View {
        let w = words(entry.arabic)
        VStack(alignment: .leading, spacing: 2) {
            if let percent = entry.percent {
                Text("\(percent)% \(w.budget)").font(.headline)
                ProgressView(value: Double(min(percent, 100)), total: 100)
            } else {
                Text(w.setBudget).font(.headline)
            }
        }
    }
}

struct InlineView: View {
    let entry: SpendingEntry
    var body: some View {
        let w = words(entry.arabic)
        if let percent = entry.percent {
            Text("\(percent)% \(w.budget)")
        } else {
            Text(w.setBudget)
        }
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) private var scheme
    let entry: SpendingEntry

    var body: some View {
        let p = Palette(scheme)
        switch family {
        // Home screen widgets are laid out left to right whatever the phone's language: the views mirror themselves
        // for Arabic text, so an Arabic phone does not flip them a second time.
        case .systemMedium:
            MediumView(entry: entry)
                .environment(\.layoutDirection, .leftToRight)
                .widgetBackground(fill: p.card, line: p.line)
        case .accessoryCircular:
            CircularView(entry: entry).widgetBackground(fill: nil, line: nil)
        case .accessoryRectangular:
            RectangularView(entry: entry).widgetBackground(fill: nil, line: nil)
        case .accessoryInline:
            InlineView(entry: entry).widgetBackground(fill: nil, line: nil)
        default:
            SmallView(entry: entry)
                .environment(\.layoutDirection, .leftToRight)
                .widgetBackground(fill: p.accent, line: p.line)
        }
    }
}

extension View {
    /// Home screen widgets get the brand fill and an outline along the system's own corner shape (iOS clips the
    /// widget, so the mockup's outer hard shadow cannot be drawn). Lock screen widgets keep the system background.
    @ViewBuilder
    func widgetBackground(fill: Color?, line: Color?) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                if let fill = fill, let line = line {
                    ZStack {
                        fill
                        ContainerRelativeShape().strokeBorder(line, lineWidth: 2.5)
                    }
                } else {
                    Color(UIColor.systemBackground)
                }
            }
        } else {
            if let fill = fill, let line = line {
                self.padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fill)
                    .overlay(ContainerRelativeShape().strokeBorder(line, lineWidth: 2.5))
            } else {
                self.padding().background(Color(UIColor.systemBackground))
            }
        }
    }
}

@main
struct SpendingTrackerWidget: Widget {
    let kind = "SpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingProvider()) { entry in
            SpendingWidgetView(entry: entry)
        }
        .configurationDisplayName("Halala")
        .description("Spent today, spent this month and your monthly budget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// The widget's read-only token lives in the Keychain, in an access group shared by the app and the widget extension
/// (not in the App Group's UserDefaults, which is a plain file any process with the group can read and which is
/// included in unencrypted-backup tooling). The group name comes from Info.plist (`SharedKeychainGroup`, expanded
/// from $(AppIdentifierPrefix) at build time). The same helper exists in the other target (they cannot share a file
/// without a project change); keep both in step.
enum WidgetKeychain {
  struct Credentials: Codable {
    let url: String
    let token: String
    let userId: String
  }

  private static let service = "spending_tracker.widget"
  private static let account = "credentials"

  private static func baseQuery() -> [String: Any]? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "SharedKeychainGroup") as? String,
      !group.isEmpty, !group.hasPrefix("."), !group.contains("$(")
    else { return nil }
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessGroup as String: group,
    ]
  }

  @discardableResult
  static func save(_ credentials: Credentials) -> Bool {
    guard var query = baseQuery(), let data = try? JSONEncoder().encode(credentials) else { return false }
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = data
    // Readable after the first unlock so a refresh can run while the phone is locked; never leaves this device.
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    if SecItemAdd(query as CFDictionary, nil) == errSecSuccess { return true }
    SecItemDelete(baseQuery()! as CFDictionary)  // leave no half state
    return false
  }

  static func load() -> Credentials? {
    guard var query = baseQuery() else { return nil }
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  static func clear() {
    if let query = baseQuery() { SecItemDelete(query as CFDictionary) }
  }
}
