import CoreLocation
import Foundation
import OpenClawKit

/// Monitors significant location changes and pushes `location.update`
/// events to the gateway so the severance hook can determine whether
/// the user is at their configured work location.
@MainActor
enum SignificantLocationMonitor {
    static func startIfNeeded(
        locationService: any LocationServicing,
        locationMode: OpenClawLocationMode,
        gateway: GatewayNodeSession
    ) {
        guard locationMode == .always else { return }
        let status = locationService.authorizationStatus()
        guard status == .authorizedAlways else { return }
        locationService.startMonitoringSignificantLocationChanges { location in
            struct Payload: Codable {
                var lat: Double
                var lon: Double
                var accuracyMeters: Double
                var source: String?
            }
            let payload = Payload(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy,
                source: "ios-significant-location")
            guard let data = try? JSONEncoder().encode(payload),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            Task { @MainActor in
                await gateway.sendEvent(event: "location.update", payloadJSON: json)
            }
        }
    }
}

enum OpenClawSceneMode: String, Codable, CaseIterable, Sendable {
    case off
    case auto
    case focus
    case commute

    var title: String {
        switch self {
        case .off: "Off"
        case .auto: "Auto"
        case .focus: "Focus"
        case .commute: "Commute"
        }
    }
}

enum OpenClawSceneProfile: String, Codable, Sendable, Equatable {
    case focus
    case commute

    var title: String {
        switch self {
        case .focus: "Scene: Focus"
        case .commute: "Scene: Commute"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "brain.head.profile"
        case .commute: "car.fill"
        }
    }
}

struct OpenClawSceneState: Equatable, Sendable {
    var mode: OpenClawSceneMode
    var profile: OpenClawSceneProfile?
    var reason: String
    var updatedAt: Date
}

enum OpenClawSceneClassifier {
    // Around brisk walking; above this we treat the user as moving/commuting.
    static let commuteSpeedThresholdMps: CLLocationSpeed = 2.2
    static let staleLocationWindowSeconds: TimeInterval = 10 * 60

    static func profile(
        mode: OpenClawSceneMode,
        location: CLLocation?,
        now: Date = Date(),
        previous: OpenClawSceneProfile?
    ) -> OpenClawSceneProfile?
    {
        switch mode {
        case .off:
            nil
        case .focus:
            .focus
        case .commute:
            .commute
        case .auto:
            self.autoProfile(location: location, now: now, previous: previous)
        }
    }

    static func reason(
        mode: OpenClawSceneMode,
        location: CLLocation?,
        now: Date = Date(),
        previous: OpenClawSceneProfile?
    ) -> String
    {
        switch mode {
        case .off:
            return "scene disabled"
        case .focus:
            return "manual focus mode"
        case .commute:
            return "manual commute mode"
        case .auto:
            guard let location else { return "auto mode without location sample" }
            let age = now.timeIntervalSince(location.timestamp)
            if age > self.staleLocationWindowSeconds {
                return "auto mode using stale sample"
            }
            if location.speed >= self.commuteSpeedThresholdMps {
                return "auto mode detected movement speed=\(String(format: "%.2f", location.speed))m/s"
            }
            if location.speed >= 0 {
                return "auto mode detected stationary speed=\(String(format: "%.2f", location.speed))m/s"
            }
            if previous != nil {
                return "auto mode retained previous profile"
            }
            return "auto mode defaulted to focus"
        }
    }

    private static func autoProfile(
        location: CLLocation?,
        now: Date,
        previous: OpenClawSceneProfile?
    ) -> OpenClawSceneProfile
    {
        guard let location else { return previous ?? .focus }

        let age = now.timeIntervalSince(location.timestamp)
        guard age <= self.staleLocationWindowSeconds else {
            return previous ?? .focus
        }

        // `speed < 0` means CoreLocation could not determine speed for this sample.
        if location.speed >= self.commuteSpeedThresholdMps {
            return .commute
        }
        if location.speed >= 0 {
            return .focus
        }
        return previous ?? .focus
    }
}
