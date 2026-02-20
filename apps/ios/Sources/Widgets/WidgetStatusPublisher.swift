import ActivityKit
import Foundation
import OpenClawKit
import OSLog
import WidgetKit

@MainActor
enum WidgetStatusPublisher {
    private static let logger = Logger(subsystem: "ai.openclaw.ios", category: "WidgetStatus")
    private static var liveActivity: Activity<OpenClawLiveActivityAttributes>?

    static func publish(gatewayTitle: String, activityTitle: String?) {
        let trimmedGateway = gatewayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let gateway = trimmedGateway.isEmpty ? "Offline" : trimmedGateway
        let trimmedActivity = activityTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = (trimmedActivity?.isEmpty == false) ? trimmedActivity : nil

        let snapshot = OpenClawWidgetSnapshot(
            gatewayTitle: gateway,
            activityTitle: activity,
            updatedAt: Date())
        OpenClawWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        if #available(iOS 16.2, *) {
            self.updateLiveActivity(snapshot: snapshot)
        }
    }

    @available(iOS 16.2, *)
    private static func updateLiveActivity(snapshot: OpenClawWidgetSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = OpenClawLiveActivityAttributes.ContentState(
            gatewayTitle: snapshot.gatewayTitle,
            activityTitle: snapshot.activityTitle ?? "Standing by",
            updatedAt: snapshot.updatedAt)
        let content = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(30 * 60))

        if let liveActivity {
            Task {
                await liveActivity.update(content)
            }
            return
        }

        do {
            let attributes = OpenClawLiveActivityAttributes(name: "OpenClaw")
            let liveActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil)
            self.liveActivity = liveActivity
        } catch {
            self.logger.warning("live activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
