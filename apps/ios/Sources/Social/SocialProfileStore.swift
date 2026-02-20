import Foundation

struct SocialProfileStore {
    static let profileDefaultsKey = "social.profile.v1"
    static let authorizationPolicyDefaultsKey = "social.authorization.policy.v1"
    static let trustedPeerIDsDefaultsKey = "social.authorization.trustedPeers.v1"
    static let blockedPeerIDsDefaultsKey = "social.authorization.blockedPeers.v1"
    static let wifiDiscoveryEnabledDefaultsKey = "social.discovery.wifi.enabled"
    static let nfcEnabledDefaultsKey = "social.discovery.nfc.enabled"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProfile(displayName: String, instanceID: String) -> AgentProfile {
        guard let data = self.defaults.data(forKey: Self.profileDefaultsKey) else {
            return AgentProfile.bootstrap(displayName: displayName, instanceID: instanceID)
        }

        guard let decoded = try? JSONDecoder().decode(AgentProfile.self, from: data) else {
            return AgentProfile.bootstrap(displayName: displayName, instanceID: instanceID)
        }

        return decoded.sanitized()
    }

    func saveProfile(_ profile: AgentProfile) {
        let normalized = profile.sanitized()
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        self.defaults.set(data, forKey: Self.profileDefaultsKey)
    }

    func loadAuthorizationPolicy() -> SocialAuthorizationPolicy {
        guard let raw = self.defaults.string(forKey: Self.authorizationPolicyDefaultsKey),
              let policy = SocialAuthorizationPolicy(rawValue: raw)
        else {
            return .trustedOnly
        }
        return policy
    }

    func saveAuthorizationPolicy(_ policy: SocialAuthorizationPolicy) {
        self.defaults.set(policy.rawValue, forKey: Self.authorizationPolicyDefaultsKey)
    }

    func loadTrustedPeerIDs() -> Set<String> {
        self.loadNormalizedIDSet(forKey: Self.trustedPeerIDsDefaultsKey)
    }

    func saveTrustedPeerIDs(_ peerIDs: Set<String>) {
        self.saveNormalizedIDSet(peerIDs, forKey: Self.trustedPeerIDsDefaultsKey)
    }

    func loadBlockedPeerIDs() -> Set<String> {
        self.loadNormalizedIDSet(forKey: Self.blockedPeerIDsDefaultsKey)
    }

    func saveBlockedPeerIDs(_ peerIDs: Set<String>) {
        self.saveNormalizedIDSet(peerIDs, forKey: Self.blockedPeerIDsDefaultsKey)
    }

    func loadWiFiDiscoveryEnabled() -> Bool {
        if self.defaults.object(forKey: Self.wifiDiscoveryEnabledDefaultsKey) == nil {
            return true
        }
        return self.defaults.bool(forKey: Self.wifiDiscoveryEnabledDefaultsKey)
    }

    func saveWiFiDiscoveryEnabled(_ enabled: Bool) {
        self.defaults.set(enabled, forKey: Self.wifiDiscoveryEnabledDefaultsKey)
    }

    func loadNFCEnabled() -> Bool {
        if self.defaults.object(forKey: Self.nfcEnabledDefaultsKey) == nil {
            return true
        }
        return self.defaults.bool(forKey: Self.nfcEnabledDefaultsKey)
    }

    func saveNFCEnabled(_ enabled: Bool) {
        self.defaults.set(enabled, forKey: Self.nfcEnabledDefaultsKey)
    }

    private func loadNormalizedIDSet(forKey key: String) -> Set<String> {
        let values = self.defaults.stringArray(forKey: key) ?? []
        return Set(
            values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
    }

    private func saveNormalizedIDSet(_ values: Set<String>, forKey key: String) {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        self.defaults.set(normalized, forKey: key)
    }
}
