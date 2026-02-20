import Foundation
import OpenClawKit
import Testing

@Suite struct OpenClawWidgetSnapshotStoreTests {
    @Test func snapshotStoreRoundTripAndClear() {
        let snapshot = OpenClawWidgetSnapshot(
            gatewayTitle: "Connected",
            activityTitle: "Listening",
            updatedAt: Date(timeIntervalSince1970: 1_736_056_800))

        OpenClawWidgetSnapshotStore.save(snapshot)
        #expect(OpenClawWidgetSnapshotStore.load() == snapshot)

        OpenClawWidgetSnapshotStore.clear()
        #expect(OpenClawWidgetSnapshotStore.load() == nil)
    }
}
