import Foundation
import Observation

@MainActor
@Observable
final class SocialHub {
    private let store: SocialProfileStore
    private let discoveryService: SocialPeerDiscoveryService

    var profile: AgentProfile
    var wifiDiscoveryEnabled: Bool
    var nfcEnabled: Bool
    var authorizationPolicy: SocialAuthorizationPolicy
    var trustedPeerIDs: Set<String>
    var blockedPeerIDs: Set<String>
    var discoveredPeers: [SocialPeerDiscoveryService.DiscoveredPeer] = []
    var discoveryStatusText: String = "Stopped"
    var importStatusText: String?

    init(
        store: SocialProfileStore = SocialProfileStore(),
        discoveryService: SocialPeerDiscoveryService = SocialPeerDiscoveryService())
    {
        self.store = store
        self.discoveryService = discoveryService

        let defaults = UserDefaults.standard
        let fallbackDisplayName = defaults.string(forKey: "node.displayName") ?? "iOS Agent"
        let fallbackInstanceID = defaults.string(forKey: "node.instanceId") ?? "ios-agent"

        self.profile = store.loadProfile(displayName: fallbackDisplayName, instanceID: fallbackInstanceID)
        self.wifiDiscoveryEnabled = store.loadWiFiDiscoveryEnabled()
        self.nfcEnabled = store.loadNFCEnabled()
        self.authorizationPolicy = store.loadAuthorizationPolicy()
        self.trustedPeerIDs = store.loadTrustedPeerIDs()
        self.blockedPeerIDs = store.loadBlockedPeerIDs()

        self.discoveryService.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.discoveredPeers = snapshot.peers
            self.discoveryStatusText = snapshot.statusText
        }

        self.applyDiscoveryState()
    }

    func bootstrap(displayName: String, instanceID: String) {
        var next = self.profile
        let trimmedID = next.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = next.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedID.isEmpty {
            next.id = instanceID
        }
        if trimmedName.isEmpty {
            next.displayName = displayName
        }
        self.setProfile(next)
    }

    func updateProfile(displayName: String, bio: String, capabilitiesCSV: String) {
        var next = self.profile
        next.displayName = displayName
        next.bio = bio
        next.capabilities = AgentProfile.parseCapabilitiesCSV(capabilitiesCSV)
        self.setProfile(next)
        self.importStatusText = "Profile updated."
    }

    func setWiFiDiscoveryEnabled(_ enabled: Bool) {
        guard self.wifiDiscoveryEnabled != enabled else { return }
        self.wifiDiscoveryEnabled = enabled
        self.store.saveWiFiDiscoveryEnabled(enabled)
        self.applyDiscoveryState()
    }

    func setNFCEnabled(_ enabled: Bool) {
        guard self.nfcEnabled != enabled else { return }
        self.nfcEnabled = enabled
        self.store.saveNFCEnabled(enabled)
    }

    func setAuthorizationPolicy(_ policy: SocialAuthorizationPolicy) {
        guard self.authorizationPolicy != policy else { return }
        self.authorizationPolicy = policy
        self.store.saveAuthorizationPolicy(policy)
    }

    func trust(peerID: String) {
        let normalized = self.normalizePeerID(peerID)
        guard !normalized.isEmpty else { return }
        self.blockedPeerIDs.remove(normalized)
        self.trustedPeerIDs.insert(normalized)
        self.persistAuthorizationLists()
    }

    func untrust(peerID: String) {
        let normalized = self.normalizePeerID(peerID)
        guard !normalized.isEmpty else { return }
        self.trustedPeerIDs.remove(normalized)
        self.persistAuthorizationLists()
    }

    func block(peerID: String) {
        let normalized = self.normalizePeerID(peerID)
        guard !normalized.isEmpty else { return }
        self.trustedPeerIDs.remove(normalized)
        self.blockedPeerIDs.insert(normalized)
        self.persistAuthorizationLists()
    }

    func unblock(peerID: String) {
        let normalized = self.normalizePeerID(peerID)
        guard !normalized.isEmpty else { return }
        self.blockedPeerIDs.remove(normalized)
        self.persistAuthorizationLists()
    }

    func clearAuthorizationLists() {
        self.trustedPeerIDs = []
        self.blockedPeerIDs = []
        self.persistAuthorizationLists()
    }

    func isPeerTrusted(_ peerID: String) -> Bool {
        self.trustedPeerIDs.contains(self.normalizePeerID(peerID))
    }

    func isPeerBlocked(_ peerID: String) -> Bool {
        self.blockedPeerIDs.contains(self.normalizePeerID(peerID))
    }

    func authorizationDecision(for peerID: String) -> SocialAuthorizationDecision {
        SocialAuthorizationEvaluator.decide(
            policy: self.authorizationPolicy,
            peerID: peerID,
            trustedPeerIDs: self.trustedPeerIDs,
            blockedPeerIDs: self.blockedPeerIDs)
    }

    @discardableResult
    func importAgentCard(from input: String) -> Bool {
        guard self.nfcEnabled else {
            self.importStatusText = "NFC card exchange is disabled."
            return false
        }
        guard let payload = AgentCardCodec.decode(fromInput: input) else {
            self.importStatusText = "Card payload not recognized."
            return false
        }

        let peerID = payload.profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !peerID.isEmpty else {
            self.importStatusText = "Card payload is missing peer ID."
            return false
        }

        self.trust(peerID: peerID)
        self.importStatusText = "Imported \(payload.profile.displayName) and marked as trusted."
        return true
    }

    var localCardCode: String {
        AgentCardCodec.encode(payload: AgentCardPayload(profile: self.profile.sanitized())) ?? ""
    }

    var localCardDeepLink: String {
        AgentCardCodec.deepLinkString(for: AgentCardPayload(profile: self.profile.sanitized())) ?? ""
    }

    var capabilitiesCSV: String {
        self.profile.capabilitiesCSV
    }

    var nfcAvailabilityText: String {
        NFCAgentCardService.availabilityText
    }

    private func normalizePeerID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setProfile(_ candidate: AgentProfile) {
        let normalized = candidate.sanitized()
        let old = self.profile.sanitized()
        let hasMaterialChange =
            old.id != normalized.id ||
            old.displayName != normalized.displayName ||
            old.bio != normalized.bio ||
            old.capabilities != normalized.capabilities
        guard hasMaterialChange else { return }

        var next = normalized
        next.updatedAt = Date()
        self.profile = next
        self.store.saveProfile(next)
        self.refreshDiscovery()
    }

    private func persistAuthorizationLists() {
        self.store.saveTrustedPeerIDs(self.trustedPeerIDs)
        self.store.saveBlockedPeerIDs(self.blockedPeerIDs)
    }

    private func applyDiscoveryState() {
        if self.wifiDiscoveryEnabled {
            self.discoveryService.start(profile: self.profile, cardCode: self.localCardCode)
            let snapshot = self.discoveryService.latestSnapshot
            self.discoveredPeers = snapshot.peers
            self.discoveryStatusText = snapshot.statusText
            return
        }

        self.discoveryService.stop()
        self.discoveredPeers = []
        self.discoveryStatusText = "Stopped"
    }

    private func refreshDiscovery() {
        guard self.wifiDiscoveryEnabled else { return }
        self.discoveryService.refresh(profile: self.profile, cardCode: self.localCardCode)
    }
}
