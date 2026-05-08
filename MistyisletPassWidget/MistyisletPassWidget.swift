import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry

struct DoorEntry: TimelineEntry {
    let date: Date
    let doorName: String
    let doorId: String
    let isOnline: Bool
}

// MARK: - Timeline Provider

struct DoorTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoorEntry {
        DoorEntry(date: .now, doorName: "Main Entrance", doorId: "door-001", isOnline: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoorEntry) -> Void) {
        let entry = DoorEntry(date: .now, doorName: "Main Entrance", doorId: "door-001", isOnline: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoorEntry>) -> Void) {
        // Load favorite door from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.mistyislet.pass")
        let doorName = defaults?.string(forKey: "widget.favoriteDoorName") ?? "Main Entrance"
        let doorId = defaults?.string(forKey: "widget.favoriteDoorId") ?? "door-001"
        let isOnline = defaults?.bool(forKey: "widget.favoriteDoorOnline") ?? true

        let entry = DoorEntry(date: .now, doorName: doorName, doorId: doorId, isOnline: isOnline)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - App Intent for Quick Unlock

struct QuickUnlockIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Unlock"
    static let description = IntentDescription("Unlock your favorite door")

    @Parameter(title: "Door ID")
    var doorId: String

    init() {
        self.doorId = "door-001"
    }

    init(doorId: String) {
        self.doorId = doorId
    }

    func perform() async throws -> some IntentResult {
        // This opens the app with a deep link to trigger unlock
        // The actual BLE/remote unlock happens in the main app
        return .result()
    }

    static let openAppWhenRun: Bool = true
}

// MARK: - Lock Screen Widget View

struct LockScreenWidgetView: View {
    let entry: DoorEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            rectangularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "lock.open.fill")
                    .font(.title3)
                Text("Unlock")
                    .font(.caption2)
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isOnline ? "lock.open.fill" : "lock.fill")
                .font(.title2)
                .foregroundStyle(entry.isOnline ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.doorName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.isOnline ? "Tap to unlock" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.open.fill")
            Text(entry.doorName)
        }
    }
}

// MARK: - Widget Configuration

struct MistyisletPassLockScreenWidget: Widget {
    let kind = "MistyisletPassLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoorTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Unlock")
        .description("Quickly unlock your favorite door from the Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Home Screen Widget

struct HomeScreenWidgetView: View {
    let entry: DoorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.310, green: 0.333, blue: 1.0))
                Spacer()
                Circle()
                    .fill(entry.isOnline ? .green : .gray)
                    .frame(width: 8, height: 8)
            }

            Spacer()

            Text(entry.doorName)
                .font(.headline)
                .lineLimit(2)

            Text(entry.isOnline ? "Hold to unlock" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct MistyisletPassHomeWidget: Widget {
    let kind = "MistyisletPassHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoorTimelineProvider()) { entry in
            HomeScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Door Unlock")
        .description("Quick access to your favorite door.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

@main
struct MistyisletPassWidgetBundle: WidgetBundle {
    var body: some Widget {
        MistyisletPassLockScreenWidget()
        MistyisletPassHomeWidget()
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    MistyisletPassLockScreenWidget()
} timeline: {
    DoorEntry(date: .now, doorName: "Main Entrance", doorId: "door-001", isOnline: true)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    MistyisletPassLockScreenWidget()
} timeline: {
    DoorEntry(date: .now, doorName: "Main Entrance", doorId: "door-001", isOnline: true)
}

#Preview("Small", as: .systemSmall) {
    MistyisletPassHomeWidget()
} timeline: {
    DoorEntry(date: .now, doorName: "Main Entrance", doorId: "door-001", isOnline: true)
}
