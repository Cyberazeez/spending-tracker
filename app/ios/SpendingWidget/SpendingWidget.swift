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

private func sar(_ halalas: Int?, arabic: Bool) -> String {
    guard let halalas = halalas else { return "--" }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    let number = formatter.string(from: NSNumber(value: halalas / 100)) ?? "0"
    return arabic ? "\(number) ر.س" : "SAR \(number)"
}

private func words(_ arabic: Bool) -> (today: String, month: String, budget: String, setBudget: String, openApp: String) {
    if arabic {
        return ("المصروف اليوم", "مصروف الشهر", "من الميزانية", "حدد ميزانية شهرية", "افتح التطبيق للتحديث")
    }
    return ("Spent today", "Spent this month", "of budget", "Set a monthly budget", "Open the app to refresh")
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

private func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}

/// The budget bar: gold share on a track with an outline, red when over budget (like the Home hero).
private struct BudgetBar: View {
    let percent: Int
    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
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

/// Small: the emerald (mint in dark mode) tile from the mockup, ink text. Where iOS removes the widget's background
/// (StandBy on iOS 17+) the text switches to the normal text colour, so it never sits as ink on black.
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
        VStack(alignment: .leading, spacing: 4) {
            Text(w.today).font(rounded(13, .bold)).foregroundColor(ink)
            Text(sar(entry.today, arabic: entry.arabic))
                .font(rounded(26, .heavy)).foregroundColor(ink)
                .minimumScaleFactor(0.6).lineLimit(1)
            if entry.today == nil {
                Text(w.openApp).font(rounded(11, .semibold)).foregroundColor(ink)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Medium: a white (moss) card with the month total on an emerald tile that has an outline and a hard shadow, and
/// the budget beside it.
struct MediumView: View {
    let entry: SpendingEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let w = words(entry.arabic)
        let p = Palette(scheme)
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(w.month).font(rounded(12, .bold)).foregroundColor(p.ink)
                Spacer(minLength: 0)
                Text(sar(entry.month, arabic: entry.arabic))
                    .font(rounded(22, .heavy)).foregroundColor(p.ink)
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Fill first, then the hard shadow behind it (a later .background sits further back).
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(p.accent))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(p.line)
                    .offset(x: 3, y: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(p.line, lineWidth: 2))
            .padding(.trailing, 3)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                if let percent = entry.percent {
                    // same text as before the rebrand: "N% of budget (SAR X)"
                    Text("\(percent)% \(w.budget) (\(sar(entry.budget, arabic: entry.arabic)))")
                        .font(rounded(14, .heavy)).foregroundColor(p.text)
                        .minimumScaleFactor(0.7).lineLimit(2)
                    BudgetBar(percent: percent, palette: p)
                } else if entry.month != nil {
                    Text(w.setBudget).font(rounded(13, .bold)).foregroundColor(p.muted)
                } else {
                    Text(w.openApp).font(rounded(13, .bold)).foregroundColor(p.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .systemMedium:
            MediumView(entry: entry).widgetBackground(fill: p.card, line: p.line)
        case .accessoryCircular:
            CircularView(entry: entry).widgetBackground(fill: nil, line: nil)
        case .accessoryRectangular:
            RectangularView(entry: entry).widgetBackground(fill: nil, line: nil)
        case .accessoryInline:
            InlineView(entry: entry).widgetBackground(fill: nil, line: nil)
        default:
            SmallView(entry: entry).widgetBackground(fill: p.accent, line: p.line)
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
