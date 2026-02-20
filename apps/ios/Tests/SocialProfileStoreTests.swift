import Foundation
import Testing
@testable import OpenClaw

@Suite struct SocialProfileStoreTests {
    @Test func loadProfileFallsBackToBootstrapWhenMissing() {
        let suiteName = "social.profile.store.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SocialProfileStore(defaults: defaults)

        let profile = store.loadProfile(displayName: "My Agent", instanceID: "ios-001")
        #expect(profile.displayName == "My Agent")
        #expect(profile.id == "ios-001")
    }

    @Test func savesAndLoadsPolicyListsAndSwitches() {
        let suiteName = "social.profile.store.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SocialProfileStore(defaults: defaults)

        store.saveAuthorizationPolicy(.promptEveryTime)
        store.saveTrustedPeerIDs(["peer-a", "peer-b"])
        store.saveBlockedPeerIDs(["peer-c"])
        store.saveWiFiDiscoveryEnabled(false)
        store.saveNFCEnabled(false)

        #expect(store.loadAuthorizationPolicy() == .promptEveryTime)
        #expect(store.loadTrustedPeerIDs() == ["peer-a", "peer-b"])
        #expect(store.loadBlockedPeerIDs() == ["peer-c"])
        #expect(store.loadWiFiDiscoveryEnabled() == false)
        #expect(store.loadNFCEnabled() == false)
    }

    @Test func savesAndLoadsPhase3Artifacts() {
        let suiteName = "social.profile.store.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SocialProfileStore(defaults: defaults)

        let protocolMessage = SocialProtocolEnvelope(
            id: "msg-1",
            type: .memorySync,
            fromPeerID: "peer-local",
            toPeerIDs: ["peer-a"],
            sentAt: Date(timeIntervalSince1970: 1_700_000_001),
            payload: ["memory": "abc"])
        let memory = SharedMemoryRecord(
            id: "mem-1",
            key: "task",
            value: "book tickets",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            sourcePeerID: "peer-a")
        let meeting = AgentMeetingSession(
            id: "meeting-1",
            title: "Trip Planning",
            hostPeerID: "peer-local",
            participantPeerIDs: ["peer-a", "peer-b"],
            messages: [
                AgentMeetingMessage(
                    id: "meeting-msg-1",
                    peerID: "peer-a",
                    text: "Let's sync memory.",
                    sentAt: Date(timeIntervalSince1970: 1_700_000_200))
            ],
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_300),
            isActive: true)

        store.saveProtocolInbox([protocolMessage])
        store.saveProtocolOutbox([protocolMessage])
        store.saveSharedMemories([memory])
        store.saveMeetingSessions([meeting])

        #expect(store.loadProtocolInbox().count == 1)
        #expect(store.loadProtocolOutbox().count == 1)
        #expect(store.loadSharedMemories().count == 1)
        #expect(store.loadMeetingSessions().count == 1)
        #expect(store.loadProtocolInbox().first?.payload["memory"] == "abc")
        #expect(store.loadSharedMemories().first?.key == "task")
        #expect(store.loadMeetingSessions().first?.title == "Trip Planning")
    }
}
