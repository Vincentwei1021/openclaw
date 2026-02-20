import Foundation

struct SharedMemoryRecord: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var key: String
    var value: String
    var updatedAt: Date
    var sourcePeerID: String

    init(
        id: String = UUID().uuidString,
        key: String,
        value: String,
        updatedAt: Date = Date(),
        sourcePeerID: String)
    {
        self.id = id
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
        self.sourcePeerID = sourcePeerID
    }

    var normalizedKey: String {
        self.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func sanitized() -> SharedMemoryRecord? {
        let cleanedKey = self.key.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedValue = self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSource = self.sourcePeerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty, !cleanedValue.isEmpty, !cleanedSource.isEmpty else { return nil }

        var copy = self
        copy.key = cleanedKey
        copy.value = cleanedValue
        copy.sourcePeerID = cleanedSource
        return copy
    }
}

struct SharedMemoryPacket: Codable, Equatable, Sendable {
    var version: Int
    var records: [SharedMemoryRecord]
    var exportedAt: Date

    init(version: Int = 1, records: [SharedMemoryRecord], exportedAt: Date = Date()) {
        self.version = version
        self.records = records
        self.exportedAt = exportedAt
    }
}

struct SharedMemoryMergeResult: Equatable, Sendable {
    var inserted: Int
    var updated: Int
    var ignored: Int

    var summaryText: String {
        "inserted \(self.inserted), updated \(self.updated), ignored \(self.ignored)"
    }
}

enum SharedMemoryCodec {
    private static let queryItemNames = ["memory", "payload"]

    static func encode(packet: SharedMemoryPacket) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(packet) else { return nil }
        return MemoryBase64URL.encode(data)
    }

    static func decode(code: String) -> SharedMemoryPacket? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = MemoryBase64URL.decode(trimmed) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(SharedMemoryPacket.self, from: data)
    }

    static func deepLinkString(for packet: SharedMemoryPacket) -> String? {
        guard let code = self.encode(packet: packet) else { return nil }
        var components = URLComponents()
        components.scheme = "openclaw"
        components.host = "memory"
        components.queryItems = [URLQueryItem(name: "memory", value: code)]
        return components.string
    }

    static func decode(fromInput input: String) -> SharedMemoryPacket? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let code = self.extractCode(from: url) {
            return self.decode(code: code)
        }
        return self.decode(code: trimmed)
    }

    static func extractCode(from url: URL) -> String? {
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

enum SharedMemoryMerger {
    static func upsert(
        local: [SharedMemoryRecord],
        key: String,
        value: String,
        sourcePeerID: String,
        now: Date = Date()) -> [SharedMemoryRecord]
    {
        let candidate = SharedMemoryRecord(
            key: key,
            value: value,
            updatedAt: now,
            sourcePeerID: sourcePeerID)
        return self.merge(local: local, incoming: [candidate]).records
    }

    static func merge(
        local: [SharedMemoryRecord],
        incoming: [SharedMemoryRecord]) -> (records: [SharedMemoryRecord], result: SharedMemoryMergeResult)
    {
        var table: [String: SharedMemoryRecord] = [:]
        var inserted = 0
        var updated = 0
        var ignored = 0

        for item in local.compactMap({ $0.sanitized() }) {
            table[item.normalizedKey] = item
        }

        for rawIncoming in incoming {
            guard let incomingItem = rawIncoming.sanitized() else {
                ignored += 1
                continue
            }
            let key = incomingItem.normalizedKey
            if let existing = table[key] {
                if incomingItem.updatedAt > existing.updatedAt {
                    table[key] = incomingItem
                    updated += 1
                } else if incomingItem.updatedAt == existing.updatedAt, incomingItem.value != existing.value {
                    if incomingItem.value > existing.value {
                        table[key] = incomingItem
                        updated += 1
                    } else {
                        ignored += 1
                    }
                } else {
                    ignored += 1
                }
            } else {
                table[key] = incomingItem
                inserted += 1
            }
        }

        let merged = table.values.sorted {
            if $0.normalizedKey == $1.normalizedKey {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.normalizedKey < $1.normalizedKey
        }

        return (
            merged,
            SharedMemoryMergeResult(inserted: inserted, updated: updated, ignored: ignored))
    }
}

private enum MemoryBase64URL {
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
