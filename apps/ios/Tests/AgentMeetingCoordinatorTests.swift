import Foundation
import Testing
@testable import OpenClaw

@Suite struct AgentMeetingCoordinatorTests {
    @Test func parseParticipantsCSVDeduplicatesAndTrims() {
        let participants = AgentMeetingCoordinator.parseParticipantsCSV(" peer-a,peer-b, peer-a, ,peer-c ")
        #expect(participants == ["peer-a", "peer-b", "peer-c"])
    }

    @Test func startAppendAndEndMeetingSession() {
        let started = AgentMeetingCoordinator.startSession(
            title: "Planning",
            hostPeerID: "peer-host",
            participantsCSV: "peer-a,peer-b",
            knownPeerIDs: ["peer-a", "peer-b"],
            now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(started != nil)
        guard let started else { return }
        #expect(started.isActive == true)
        #expect(started.participantPeerIDs == ["peer-a", "peer-b"])

        let messaged = AgentMeetingCoordinator.appendMessage(
            session: started,
            peerID: "peer-a",
            text: "sync memory")
        #expect(messaged.messages.count == 1)
        #expect(messaged.messages.first?.text == "sync memory")

        let ended = AgentMeetingCoordinator.endSession(messaged)
        #expect(ended.isActive == false)
        #expect(ended.messages.count == 1)
    }
}
