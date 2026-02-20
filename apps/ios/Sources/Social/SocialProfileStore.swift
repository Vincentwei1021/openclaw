import Foundation

struct SocialProfileStore {
    static let profileDefaultsKey = "social.profile.v1"
    static let authorizationPolicyDefaultsKey = "social.authorization.policy.v1"
    static let trustedPeerIDsDefaultsKey = "social.authorization.trustedPeers.v1"
    static let blockedPeerIDsDefaultsKey = "social.authorization.blockedPeers.v1"
    static let wifiDiscoveryEnabledDefaultsKey = "social.discovery.wifi.enabled"
    static let nfcEnabledDefaultsKey = "social.discovery.nfc.enabled"
    static let protocolInboxDefaultsKey = "social.protocol.inbox.v1"
    static let protocolOutboxDefaultsKey = "social.protocol.outbox.v1"
    static let sharedMemoriesDefaultsKey = "social.memory.records.v1"
    static let meetingSessionsDefaultsKey = "social.meeting.sessions.v1"

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

    func loadProtocolInbox() -> [SocialProtocolEnvelope] {
        let envelopes: [SocialProtocolEnvelope] = self.loadCodable(
            forKey: Self.protocolInboxDefaultsKey,
            defaultValue: [])
        return envelopes.compactMap(self.sanitizeEnvelope)
    }

    func saveProtocolInbox(_ inbox: [SocialProtocolEnvelope]) {
        let sanitized = inbox.compactMap(self.sanitizeEnvelope)
        self.saveCodable(sanitized, forKey: Self.protocolInboxDefaultsKey)
    }

    func loadProtocolOutbox() -> [SocialProtocolEnvelope] {
        let envelopes: [SocialProtocolEnvelope] = self.loadCodable(
            forKey: Self.protocolOutboxDefaultsKey,
            defaultValue: [])
        return envelopes.compactMap(self.sanitizeEnvelope)
    }

    func saveProtocolOutbox(_ outbox: [SocialProtocolEnvelope]) {
        let sanitized = outbox.compactMap(self.sanitizeEnvelope)
        self.saveCodable(sanitized, forKey: Self.protocolOutboxDefaultsKey)
    }

    func loadSharedMemories() -> [SharedMemoryRecord] {
        let records: [SharedMemoryRecord] = self.loadCodable(
            forKey: Self.sharedMemoriesDefaultsKey,
            defaultValue: [])
        return records.compactMap { $0.sanitized() }
    }

    func saveSharedMemories(_ records: [SharedMemoryRecord]) {
        let sanitized = records.compactMap { $0.sanitized() }
        self.saveCodable(sanitized, forKey: Self.sharedMemoriesDefaultsKey)
    }

    func loadMeetingSessions() -> [AgentMeetingSession] {
        let sessions: [AgentMeetingSession] = self.loadCodable(
            forKey: Self.meetingSessionsDefaultsKey,
            defaultValue: [])
        return sessions.compactMap(self.sanitizeMeetingSession)
    }

    func saveMeetingSessions(_ sessions: [AgentMeetingSession]) {
        let sanitized = sessions.compactMap(self.sanitizeMeetingSession)
        self.saveCodable(sanitized, forKey: Self.meetingSessionsDefaultsKey)
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

    private func loadCodable<T: Decodable>(forKey key: String, defaultValue: T) -> T {
        guard let data = self.defaults.data(forKey: key) else { return defaultValue }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let decoded = try? decoder.decode(T.self, from: data) else { return defaultValue }
        return decoded
    }

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(value) else { return }
        self.defaults.set(data, forKey: key)
    }

    private func sanitizeEnvelope(_ envelope: SocialProtocolEnvelope) -> SocialProtocolEnvelope? {
        let normalizedID = envelope.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFromPeerID = envelope.fromPeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPayload = envelope.payload.reduce(into: [String: String]()) { partial, pair in
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return }
            partial[key] = value
        }

        guard !normalizedFromPeerID.isEmpty else { return nil }
        return SocialProtocolEnvelope(
            version: envelope.version,
            id: normalizedID.isEmpty ? UUID().uuidString : normalizedID,
            type: envelope.type,
            fromPeerID: normalizedFromPeerID,
            toPeerIDs: envelope.toPeerIDs,
            sentAt: envelope.sentAt,
            payload: normalizedPayload)
    }

    private func sanitizeMeetingSession(_ session: AgentMeetingSession) -> AgentMeetingSession? {
        let normalizedID = session.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHostPeerID = session.hostPeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let participantPeerIDs = session.participantPeerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedTitle.isEmpty, !normalizedHostPeerID.isEmpty else { return nil }

        let messages: [AgentMeetingMessage] = session.messages.compactMap { message -> AgentMeetingMessage? in
            let peerID = message.peerID.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !peerID.isEmpty, !text.isEmpty else { return nil }
            return AgentMeetingMessage(id: message.id, peerID: peerID, text: text, sentAt: message.sentAt)
        }

        return AgentMeetingSession(
            id: normalizedID.isEmpty ? UUID().uuidString : normalizedID,
            title: normalizedTitle,
            hostPeerID: normalizedHostPeerID,
            participantPeerIDs: participantPeerIDs,
            messages: messages,
            startedAt: session.startedAt,
            updatedAt: session.updatedAt,
            isActive: session.isActive)
    }
}
