import SwiftUI
import UIKit
import WidgetKit

// Home-screen and lock-screen widget. It only reads numbers the app saved in the shared App Group
// (see AppDelegate "spending_tracker/widget"); it never talks to the network.
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
        // Ask for a refresh in 30 minutes; the app also reloads the widget every time it saves new numbers.
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func load() -> SpendingEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let now = Date()
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

// MARK: - Views

struct SmallView: View {
    let entry: SpendingEntry
    var body: some View {
        let w = words(entry.arabic)
        VStack(alignment: .leading, spacing: 6) {
            Text(w.today).font(.caption).foregroundColor(.secondary)
            Text(sar(entry.today, arabic: entry.arabic))
                .font(.title2).fontWeight(.semibold)
                .minimumScaleFactor(0.6).lineLimit(1)
            if entry.today == nil {
                Text(w.openApp).font(.caption2).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumView: View {
    let entry: SpendingEntry
    var body: some View {
        let w = words(entry.arabic)
        VStack(alignment: .leading, spacing: 8) {
            Text(w.month).font(.caption).foregroundColor(.secondary)
            Text(sar(entry.month, arabic: entry.arabic))
                .font(.title).fontWeight(.semibold)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let percent = entry.percent {
                ProgressView(value: Double(min(percent, 100)), total: 100)
                Text("\(percent)% \(w.budget) (\(sar(entry.budget, arabic: entry.arabic)))")
                    .font(.caption).foregroundColor(.secondary)
            } else if entry.month != nil {
                Text(w.setBudget).font(.caption).foregroundColor(.secondary)
            } else {
                Text(w.openApp).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    let entry: SpendingEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            SmallView(entry: entry)
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color(UIColor.systemBackground) }
        } else {
            self.padding().background(Color(UIColor.systemBackground))
        }
    }
}

@main
struct SpendingTrackerWidget: Widget {
    let kind = "SpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Spending")
        .description("Spent today, spent this month and your monthly budget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
