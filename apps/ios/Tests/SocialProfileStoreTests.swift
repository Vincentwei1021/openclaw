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
}
