import ActivityKit
import OpenClawKit
import SwiftUI
import WidgetKit

struct OpenClawStatusEntry: TimelineEntry {
    var date: Date
    var snapshot: OpenClawWidgetSnapshot
}

struct OpenClawStatusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenClawStatusEntry {
        OpenClawStatusEntry(
            date: Date(),
            snapshot: OpenClawWidgetSnapshot(
                gatewayTitle: "Connected",
                activityTitle: "Listening",
                updatedAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenClawStatusEntry) -> Void) {
        completion(self.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenClawStatusEntry>) -> Void) {
        let entry = self.makeEntry()
        let next = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> OpenClawStatusEntry {
        let fallback = OpenClawWidgetSnapshot(
            gatewayTitle: "Offline",
            activityTitle: "Open the app to connect",
            updatedAt: Date())
        return OpenClawStatusEntry(
            date: Date(),
            snapshot: OpenClawWidgetSnapshotStore.load() ?? fallback)
    }
}

struct OpenClawStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OpenClawStatusEntry

    var body: some View {
        switch self.family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenClaw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(self.entry.snapshot.gatewayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(self.entry.snapshot.activityTitle ?? "Standing by")
                    .font(.caption)
                    .lineLimit(1)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                    Text("OpenClaw")
                        .font(.headline)
                    Spacer()
                    Text(self.timeText(self.entry.snapshot.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(self.entry.snapshot.gatewayTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(self.entry.snapshot.activityTitle ?? "Standing by")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(2)
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.circle.fill")
                    Text("OpenClaw")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Text(self.entry.snapshot.gatewayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(self.entry.snapshot.activityTitle ?? "Standing by")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(2)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct OpenClawStatusWidget: Widget {
    static let kind = "OpenClawStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: OpenClawStatusTimelineProvider()) { entry in
            OpenClawStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("OpenClaw Status")
        .description("Gateway and agent activity at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@available(iOSApplicationExtension 16.2, *)
struct OpenClawLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenClawLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text("OpenClaw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.state.gatewayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.activityTitle)
                    .font(.caption)
                    .lineLimit(2)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.gatewayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(self.shortActivity(context.state.activityTitle))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.activityTitle)
                        .font(.caption)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
            } compactTrailing: {
                Text(self.shortGateway(context.state.gatewayTitle))
                    .font(.caption2)
            } minimal: {
                Image(systemName: "bolt.fill")
            }
        }
    }

    private func shortGateway(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("connect") { return "ON" }
        if text.localizedCaseInsensitiveContains("offline") { return "OFF" }
        if text.localizedCaseInsensitiveContains("error") { return "ERR" }
        return String(text.prefix(3)).uppercased()
    }

    private func shortActivity(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Ready" }
        return String(trimmed.prefix(10))
    }
}

@main
struct OpenClawWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenClawStatusWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            OpenClawLiveActivityWidget()
        }
    }
}
