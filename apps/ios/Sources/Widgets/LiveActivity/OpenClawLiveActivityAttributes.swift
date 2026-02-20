import ActivityKit
import Foundation

struct OpenClawLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var gatewayTitle: String
        var activityTitle: String
        var updatedAt: Date
    }

    var name: String
}
