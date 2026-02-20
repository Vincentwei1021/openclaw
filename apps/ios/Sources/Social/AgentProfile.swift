import Foundation

struct AgentProfile: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var displayName: String
    var bio: String
    var capabilities: [String]
    var updatedAt: Date

    static func bootstrap(displayName: String, instanceID: String) -> AgentProfile {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = instanceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentProfile(
            id: trimmedID.isEmpty ? "ios-agent" : trimmedID,
            displayName: trimmedName.isEmpty ? "iOS Agent" : trimmedName,
            bio: "",
            capabilities: [],
            updatedAt: Date())
    }

    func sanitized() -> AgentProfile {
        let normalizedID = self.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = self.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let normalizedBio = self.bio
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        var copy = self
        copy.id = normalizedID.isEmpty ? "ios-agent" : normalizedID
        copy.displayName = normalizedName.isEmpty ? "iOS Agent" : normalizedName
        copy.bio = normalizedBio
        copy.capabilities = Self.normalizeCapabilities(self.capabilities)
        return copy
    }

    static func parseCapabilitiesCSV(_ raw: String) -> [String] {
        Self.normalizeCapabilities(raw.split(separator: ",").map(String.init))
    }

    var capabilitiesCSV: String {
        self.capabilities.joined(separator: ", ")
    }

    private static func normalizeCapabilities(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(cleaned)
            if output.count == 8 { break }
        }
        return output
    }
}

struct AgentCardPayload: Codable, Equatable, Sendable {
    var version: Int
    var profile: AgentProfile
    var sharedAt: Date

    init(version: Int = 1, profile: AgentProfile, sharedAt: Date = Date()) {
        self.version = version
        self.profile = profile
        self.sharedAt = sharedAt
    }
}

enum AgentCardCodec {
    private static let queryItemNames = ["card", "payload"]

    static func encode(payload: AgentCardPayload) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(payload) else { return nil }
        return Base64URL.encode(data)
    }

    static func decode(code: String) -> AgentCardPayload? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = Base64URL.decode(trimmed) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(AgentCardPayload.self, from: data)
    }

    static func deepLinkString(for payload: AgentCardPayload) -> String? {
        guard let code = self.encode(payload: payload) else { return nil }
        var components = URLComponents()
        components.scheme = "openclaw"
        components.host = "agent-card"
        components.queryItems = [URLQueryItem(name: "card", value: code)]
        return components.string
    }

    static func decode(fromInput input: String) -> AgentCardPayload? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let cardCode = self.extractCardCode(from: url) {
            return self.decode(code: cardCode)
        }

        return self.decode(code: trimmed)
    }

    static func extractCardCode(from url: URL) -> String? {
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

private enum Base64URL {
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
