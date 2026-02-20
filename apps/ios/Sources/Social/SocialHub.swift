import Foundation
import Observation

@MainActor
@Observable
final class SocialHub {
    private let store: SocialProfileStore
    private let discoveryService: SocialPeerDiscoveryService
    private static let maxStoredProtocolMessages = 120
    private static let maxStoredMeetingSessions = 40

    var profile: AgentProfile
    var wifiDiscoveryEnabled: Bool
    var nfcEnabled: Bool
    var authorizationPolicy: SocialAuthorizationPolicy
    var trustedPeerIDs: Set<String>
    var blockedPeerIDs: Set<String>
    var discoveredPeers: [SocialPeerDiscoveryService.DiscoveredPeer] = []
    var discoveryStatusText: String = "Stopped"
    var importStatusText: String?

    var protocolInbox: [SocialProtocolEnvelope]
    var protocolOutbox: [SocialProtocolEnvelope]
    var sharedMemories: [SharedMemoryRecord]
    var meetingSessions: [AgentMeetingSession]
    var activeMeetingID: String?

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

        self.protocolInbox = store.loadProtocolInbox()
        self.protocolOutbox = store.loadProtocolOutbox()
        self.sharedMemories = store.loadSharedMemories()
        self.meetingSessions = store.loadMeetingSessions()
        self.activeMeetingID = self.meetingSessions.first(where: \.isActive)?.id

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

    @discardableResult
    func sendProtocolMessage(
        type: SocialProtocolMessageType,
        recipientsCSV: String,
        payloadText: String) -> Bool
    {
        let recipients = AgentMeetingCoordinator.parseParticipantsCSV(recipientsCSV)
        guard !recipients.isEmpty else {
            self.importStatusText = "Protocol recipients are required."
            return false
        }

        let fromPeerID = self.profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fromPeerID.isEmpty else {
            self.importStatusText = "Local peer ID is missing."
            return false
        }

        let payload = self.parsePayloadText(payloadText)
        let envelope = SocialProtocolEnvelope(
            type: type,
            fromPeerID: fromPeerID,
            toPeerIDs: recipients,
            payload: payload)
        self.protocolOutbox = self.prependLimited(
            envelope,
            to: self.protocolOutbox,
            limit: Self.maxStoredProtocolMessages)
        self.store.saveProtocolOutbox(self.protocolOutbox)

        self.importStatusText = "Protocol message queued for \(recipients.count) peer(s)."
        return true
    }

    @discardableResult
    func importProtocolMessage(from input: String) -> Bool {
        guard let envelope = SocialProtocolCodec.decode(fromInput: input) else {
            self.importStatusText = "Protocol payload not recognized."
            return false
        }

        self.protocolInbox = self.prependLimited(
            envelope,
            to: self.protocolInbox,
            limit: Self.maxStoredProtocolMessages)
        self.store.saveProtocolInbox(self.protocolInbox)

        if envelope.type == .memorySync,
           let memoryCode = envelope.payload["memory"],
           let packet = SharedMemoryCodec.decode(code: memoryCode)
        {
            let mergeResult = self.mergeSharedMemory(packet.records)
            self.importStatusText = "Imported memory sync from \(envelope.fromPeerID): \(mergeResult.summaryText)."
            return true
        }

        self.importStatusText = "Protocol message imported (\(envelope.type.rawValue))."
        return true
    }

    @discardableResult
    func upsertSharedMemory(key: String, value: String, sourcePeerID: String) -> Bool {
        let normalizedSource = sourcePeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = normalizedSource.isEmpty ? self.profile.id : normalizedSource
        let next = SharedMemoryMerger.upsert(local: self.sharedMemories, key: key, value: value, sourcePeerID: source)
        guard next != self.sharedMemories else {
            self.importStatusText = "Memory unchanged."
            return false
        }

        self.sharedMemories = next
        self.store.saveSharedMemories(next)
        self.importStatusText = "Shared memory updated."
        return true
    }

    @discardableResult
    func importSharedMemory(from input: String) -> Bool {
        guard let packet = SharedMemoryCodec.decode(fromInput: input) else {
            self.importStatusText = "Memory payload not recognized."
            return false
        }

        let mergeResult = self.mergeSharedMemory(packet.records)
        self.importStatusText = "Shared memory merged: \(mergeResult.summaryText)."
        return true
    }

    func clearSharedMemory() {
        guard !self.sharedMemories.isEmpty else { return }
        self.sharedMemories = []
        self.store.saveSharedMemories([])
        self.importStatusText = "Shared memory cleared."
    }

    var sharedMemoryCode: String {
        let packet = SharedMemoryPacket(records: self.sharedMemories)
        return SharedMemoryCodec.encode(packet: packet) ?? ""
    }

    var sharedMemoryDeepLink: String {
        let packet = SharedMemoryPacket(records: self.sharedMemories)
        return SharedMemoryCodec.deepLinkString(for: packet) ?? ""
    }

    @discardableResult
    func startMeeting(title: String, participantsCSV: String) -> Bool {
        if self.activeMeeting != nil {
            self.importStatusText = "End the current meeting before starting a new one."
            return false
        }

        let parsedParticipants = AgentMeetingCoordinator.parseParticipantsCSV(participantsCSV)
        var knownPeerIDs = Set(parsedParticipants)
        knownPeerIDs.formUnion(self.trustedPeerIDs)
        knownPeerIDs.formUnion(self.discoveredPeers.map(\.peerID))

        guard let session = AgentMeetingCoordinator.startSession(
            title: title,
            hostPeerID: self.profile.id,
            participantsCSV: participantsCSV,
            knownPeerIDs: knownPeerIDs)
        else {
            self.importStatusText = "Meeting title and participants are required."
            return false
        }

        self.meetingSessions = self.prependLimited(session, to: self.meetingSessions, limit: Self.maxStoredMeetingSessions)
        self.activeMeetingID = session.id
        self.store.saveMeetingSessions(self.meetingSessions)
        self.importStatusText = "Meeting started: \(session.title)."
        return true
    }

    @discardableResult
    func appendActiveMeetingMessage(peerID: String, text: String) -> Bool {
        guard let index = self.activeMeetingIndex else {
            self.importStatusText = "No active meeting session."
            return false
        }

        let sender = self.normalizePeerID(peerID).isEmpty ? self.profile.id : peerID
        let existing = self.meetingSessions[index]
        let updated = AgentMeetingCoordinator.appendMessage(session: existing, peerID: sender, text: text)
        guard updated.messages.count > existing.messages.count else {
            self.importStatusText = "Meeting message was empty."
            return false
        }

        self.meetingSessions[index] = updated
        self.store.saveMeetingSessions(self.meetingSessions)
        self.importStatusText = "Meeting message appended."
        return true
    }

    @discardableResult
    func endActiveMeeting() -> Bool {
        guard let index = self.activeMeetingIndex else {
            self.importStatusText = "No active meeting to end."
            return false
        }

        self.meetingSessions[index] = AgentMeetingCoordinator.endSession(self.meetingSessions[index])
        self.activeMeetingID = nil
        self.store.saveMeetingSessions(self.meetingSessions)
        self.importStatusText = "Meeting ended."
        return true
    }

    var activeMeeting: AgentMeetingSession? {
        guard let index = self.activeMeetingIndex else { return nil }
        return self.meetingSessions[index]
    }

    var socialGraphSnapshot: SocialGraphSnapshot {
        SocialGraphBuilder.build(
            localPeerID: self.profile.id,
            localDisplayName: self.profile.displayName,
            trustedPeerIDs: self.trustedPeerIDs,
            blockedPeerIDs: self.blockedPeerIDs,
            sharedMemories: self.sharedMemories,
            meetingSessions: self.meetingSessions)
    }

    var latestProtocolCode: String {
        guard let latest = self.protocolOutbox.first else { return "" }
        return SocialProtocolCodec.encode(latest) ?? ""
    }

    var latestProtocolDeepLink: String {
        guard let latest = self.protocolOutbox.first else { return "" }
        return SocialProtocolCodec.deepLinkString(for: latest) ?? ""
    }

    var capabilitiesCSV: String {
        self.profile.capabilitiesCSV
    }

    var nfcAvailabilityText: String {
        NFCAgentCardService.availabilityText
    }

    private var activeMeetingIndex: Int? {
        guard let activeMeetingID else { return nil }
        return self.meetingSessions.firstIndex(where: { $0.id == activeMeetingID && $0.isActive })
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

    private func parsePayloadText(_ raw: String) -> [String: String] {
        var output: [String: String] = [:]
        for line in raw
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        {
            let segments = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard segments.count == 2 else { continue }
            let key = String(segments[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(segments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            output[key] = value
        }
        return output
    }

    private func mergeSharedMemory(_ incoming: [SharedMemoryRecord]) -> SharedMemoryMergeResult {
        let merged = SharedMemoryMerger.merge(local: self.sharedMemories, incoming: incoming)
        self.sharedMemories = merged.records
        self.store.saveSharedMemories(merged.records)
        return merged.result
    }

    private func prependLimited<T>(_ element: T, to values: [T], limit: Int) -> [T] {
        var next = values
        next.insert(element, at: 0)
        if next.count > limit {
            next.removeLast(next.count - limit)
        }
        return next
    }
}
