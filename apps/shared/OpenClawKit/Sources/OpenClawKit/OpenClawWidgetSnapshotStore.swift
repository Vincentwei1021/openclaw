import Foundation

public struct OpenClawWidgetSnapshot: Codable, Sendable, Equatable {
    public var gatewayTitle: String
    public var activityTitle: String?
    public var updatedAt: Date

    public init(gatewayTitle: String, activityTitle: String?, updatedAt: Date) {
        self.gatewayTitle = gatewayTitle
        self.activityTitle = activityTitle
        self.updatedAt = updatedAt
    }
}

public enum OpenClawWidgetSnapshotStore {
    private static let suiteName = "group.ai.openclaw.shared"
    private static let snapshotKey = "widget.snapshot.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: self.suiteName) ?? .standard
    }

    public static func load() -> OpenClawWidgetSnapshot? {
        guard let data = self.defaults.data(forKey: self.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(OpenClawWidgetSnapshot.self, from: data)
    }

    public static func save(_ snapshot: OpenClawWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        self.defaults.set(data, forKey: self.snapshotKey)
    }

    public static func clear() {
        self.defaults.removeObject(forKey: self.snapshotKey)
    }
}
