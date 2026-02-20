import CoreLocation
import Foundation
import Testing
@testable import OpenClaw

@Suite struct LocationSceneModeTests {
    @Test func manualModesMapDirectly() {
        #expect(OpenClawSceneClassifier.profile(mode: .off, location: nil, previous: nil) == nil)
        #expect(OpenClawSceneClassifier.profile(mode: .focus, location: nil, previous: nil) == .focus)
        #expect(OpenClawSceneClassifier.profile(mode: .commute, location: nil, previous: nil) == .commute)
    }

    @Test func autoModeUsesSpeedThreshold() {
        let now = Date()
        let moving = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 30,
            verticalAccuracy: 30,
            course: 0,
            speed: OpenClawSceneClassifier.commuteSpeedThresholdMps + 0.4,
            timestamp: now)
        let stationary = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: 20,
            course: 0,
            speed: 0.3,
            timestamp: now)

        #expect(OpenClawSceneClassifier.profile(mode: .auto, location: moving, now: now, previous: nil) == .commute)
        #expect(OpenClawSceneClassifier.profile(mode: .auto, location: stationary, now: now, previous: nil) == .focus)
    }

    @Test func autoModeFallsBackToPreviousWhenSampleUnusable() {
        let now = Date()
        let unknownSpeed = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: 20,
            course: 0,
            speed: -1,
            timestamp: now)
        let stale = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: 20,
            course: 0,
            speed: 6,
            timestamp: now.addingTimeInterval(-(OpenClawSceneClassifier.staleLocationWindowSeconds + 30)))

        #expect(
            OpenClawSceneClassifier.profile(
                mode: .auto,
                location: unknownSpeed,
                now: now,
                previous: .focus) == .focus)
        #expect(
            OpenClawSceneClassifier.profile(
                mode: .auto,
                location: stale,
                now: now,
                previous: .commute) == .commute)
    }
}
