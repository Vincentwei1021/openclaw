import Foundation

enum SocialProtocolMessageType: String, Codable, CaseIterable, Sendable {
    case memorySync = "memory.sync"
    case meetingInvite = "meeting.invite"
    case meetingMessage = "meeting.message"
    case meetingSummary = "meeting.summary"
}

struct SocialProtocolEnvelope: Codable, Equatable, Sendable, Identifiable {
    var version: Int
    var id: String
    var type: SocialProtocolMessageType
    var fromPeerID: String
    var toPeerIDs: [String]
    var sentAt: Date
    var payload: [String: String]

    init(
        version: Int = 1,
        id: String = UUID().uuidString,
        type: SocialProtocolMessageType,
        fromPeerID: String,
        toPeerIDs: [String],
        sentAt: Date = Date(),
        payload: [String: String])
    {
        self.version = version
        self.id = id
        self.type = type
        self.fromPeerID = fromPeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toPeerIDs = toPeerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sentAt = sentAt
        self.payload = payload
    }
}

enum SocialProtocolCodec {
    private static let queryItemNames = ["msg", "payload"]

    static func encode(_ envelope: SocialProtocolEnvelope) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(envelope) else { return nil }
        return SocialBase64URL.encode(data)
    }

    static func decode(_ code: String) -> SocialProtocolEnvelope? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = SocialBase64URL.decode(trimmed) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(SocialProtocolEnvelope.self, from: data)
    }

    static func deepLinkString(for envelope: SocialProtocolEnvelope) -> String? {
        guard let code = self.encode(envelope) else { return nil }
        var components = URLComponents()
        components.scheme = "openclaw"
        components.host = "social"
        components.queryItems = [URLQueryItem(name: "msg", value: code)]
        return components.string
    }

    static func decode(fromInput input: String) -> SocialProtocolEnvelope? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let messageCode = self.extractMessageCode(from: url) {
            return self.decode(messageCode)
        }

        return self.decode(trimmed)
    }

    static func extractMessageCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return nil
        }

        for name in self.queryItemNames {
            if let value = queryItems.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}

private enum SocialBase64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ text: String) -> Data? {
        let normalized = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        let padding = remainder == 0 ? "" : String(repeating: "=", count: 4 - remainder)
        return Data(base64Encoded: normalized + padding)
    }
}
