import Foundation
import Testing
@testable import OpenClaw

@Suite struct SharedMemoryMergerTests {
    @Test func mergePrefersNewestRecordForSameKey() {
        let local = [
            SharedMemoryRecord(
                id: "r1",
                key: "city",
                value: "Shanghai",
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                sourcePeerID: "peer-a")
        ]
        let incoming = [
            SharedMemoryRecord(
                id: "r2",
                key: "city",
                value: "San Francisco",
                updatedAt: Date(timeIntervalSince1970: 1_700_000_200),
                sourcePeerID: "peer-b")
        ]

        let result = SharedMemoryMerger.merge(local: local, incoming: incoming)
        #expect(result.records.count == 1)
        #expect(result.records.first?.value == "San Francisco")
        #expect(result.result.updated == 1)
        #expect(result.result.inserted == 0)
    }

    @Test func codecDecodesFromMemoryDeepLink() {
        let packet = SharedMemoryPacket(
            records: [
                SharedMemoryRecord(
                    key: "trip",
                    value: "next week",
                    sourcePeerID: "peer-a")
            ])
        let deepLink = SharedMemoryCodec.deepLinkString(for: packet)
        #expect(deepLink != nil)
        guard let deepLink else { return }

        let decoded = SharedMemoryCodec.decode(fromInput: deepLink)
        #expect(decoded?.records.count == 1)
        #expect(decoded?.records.first?.key == "trip")
    }
}
