import Foundation
import Testing
@testable import OpenClaw

@Suite struct SocialGraphBuilderTests {
    @Test func graphIncludesTrustedBlockedMemoryAndMeetingEdges() {
        let memories = [
            SharedMemoryRecord(
                key: "agenda",
                value: "ship phase 3",
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
                sourcePeerID: "peer-a")
        ]
        let meetings = [
            AgentMeetingSession(
                id: "meeting-1",
                title: "Phase 3",
                hostPeerID: "local-peer",
                participantPeerIDs: ["peer-a", "peer-b"],
                messages: [],
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_120),
                isActive: true)
        ]

        let snapshot = SocialGraphBuilder.build(
            localPeerID: "local-peer",
            localDisplayName: "Local Agent",
            trustedPeerIDs: ["peer-a"],
            blockedPeerIDs: ["peer-c"],
            sharedMemories: memories,
            meetingSessions: meetings,
            now: Date(timeIntervalSince1970: 1_700_000_200))

        #expect(snapshot.nodes.contains(where: { $0.id == "local-peer" && $0.relation == .local }))
        #expect(snapshot.nodes.contains(where: { $0.id == "peer-a" && $0.relation == .trusted }))
        #expect(snapshot.nodes.contains(where: { $0.id == "peer-c" && $0.relation == .blocked }))
        #expect(snapshot.edges.contains(where: { $0.kind == .trusted && $0.toPeerID == "peer-a" }))
        #expect(snapshot.edges.contains(where: { $0.kind == .blocked && $0.toPeerID == "peer-c" }))
        #expect(snapshot.edges.contains(where: { $0.kind == .memoryShare && $0.fromPeerID == "peer-a" }))
        #expect(snapshot.edges.contains(where: { $0.kind == .meeting }))
    }
}
