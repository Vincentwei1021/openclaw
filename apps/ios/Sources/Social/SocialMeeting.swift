import Foundation

struct AgentMeetingMessage: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var peerID: String
    var text: String
    var sentAt: Date

    init(id: String = UUID().uuidString, peerID: String, text: String, sentAt: Date = Date()) {
        self.id = id
        self.peerID = peerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sentAt = sentAt
    }
}

struct AgentMeetingSession: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var hostPeerID: String
    var participantPeerIDs: [String]
    var messages: [AgentMeetingMessage]
    var startedAt: Date
    var updatedAt: Date
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        hostPeerID: String,
        participantPeerIDs: [String],
        messages: [AgentMeetingMessage] = [],
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true)
    {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostPeerID = hostPeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.participantPeerIDs = participantPeerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.messages = messages
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
}

enum AgentMeetingCoordinator {
    static func parseParticipantsCSV(_ raw: String) -> [String] {
        var seen = Set<String>()
        var participants: [String] = []
        for value in raw.split(separator: ",").map(String.init) {
            let id = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            participants.append(id)
        }
        return participants
    }

    static func startSession(
        title: String,
        hostPeerID: String,
        participantsCSV: String,
        knownPeerIDs: Set<String>,
        now: Date = Date()) -> AgentMeetingSession?
    {
        let normalizedHost = hostPeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else { return nil }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return nil }

        let parsed = self.parseParticipantsCSV(participantsCSV)
        let known = Set(parsed).intersection(knownPeerIDs)
        let participants = Array(known).sorted()
        guard !participants.isEmpty else { return nil }

        return AgentMeetingSession(
            title: cleanedTitle,
            hostPeerID: normalizedHost,
            participantPeerIDs: participants,
            startedAt: now,
            updatedAt: now,
            isActive: true)
    }

    static func appendMessage(
        session: AgentMeetingSession,
        peerID: String,
        text: String,
        now: Date = Date()) -> AgentMeetingSession
    {
        var copy = session
        let message = AgentMeetingMessage(peerID: peerID, text: text, sentAt: now)
        guard !message.peerID.isEmpty, !message.text.isEmpty else { return copy }
        copy.messages.append(message)
        copy.updatedAt = now
        return copy
    }

    static func endSession(_ session: AgentMeetingSession, now: Date = Date()) -> AgentMeetingSession {
        var copy = session
        copy.isActive = false
        copy.updatedAt = now
        return copy
    }
}
