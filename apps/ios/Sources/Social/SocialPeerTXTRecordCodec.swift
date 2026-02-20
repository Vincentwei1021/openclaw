import Foundation

struct SocialPeerRecord: Equatable, Sendable {
    var peerID: String
    var displayName: String
    var bio: String
    var capabilities: [String]
    var cardCode: String?
}

enum SocialPeerTXTRecordCodec {
    static func encodeDictionary(profile: AgentProfile, cardCode: String?) -> [String: String] {
        let normalized = profile.sanitized()
        var dict: [String: String] = [
            "v": "1",
            "id": normalized.id,
            "name": normalized.displayName,
        ]
        if !normalized.bio.isEmpty {
            dict["bio"] = self.clamp(normalized.bio, maxLength: 120)
        }
        if !normalized.capabilities.isEmpty {
            dict["cap"] = self.clamp(normalized.capabilities.joined(separator: ","), maxLength: 160)
        }
        if let cardCode {
            let trimmed = cardCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                dict["card"] = self.clamp(trimmed, maxLength: 240)
            }
        }
        return dict
    }

    static func encodeTXTData(profile: AgentProfile, cardCode: String?) -> Data {
        let dict = self.encodeDictionary(profile: profile, cardCode: cardCode)
        let dataRecord = dict.reduce(into: [String: Data]()) { output, pair in
            output[pair.key] = Data(pair.value.utf8)
        }
        return NetService.data(fromTXTRecord: dataRecord)
    }

    static func decode(data: Data) -> SocialPeerRecord? {
        let decodedData = NetService.dictionary(fromTXTRecord: data)
        let dictionary = decodedData.reduce(into: [String: String]()) { output, pair in
            output[pair.key] = String(bytes: pair.value, encoding: .utf8) ?? ""
        }
        return self.decode(dictionary: dictionary)
    }

    static func decode(dictionary: [String: String]) -> SocialPeerRecord? {
        let peerID = dictionary["id"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = dictionary["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !peerID.isEmpty, !displayName.isEmpty else { return nil }

        let bio = dictionary["bio"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let capabilitiesRaw = dictionary["cap"] ?? ""
        let capabilities = AgentProfile.parseCapabilitiesCSV(capabilitiesRaw)
        let cardCode = dictionary["card"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        return SocialPeerRecord(
            peerID: peerID,
            displayName: displayName,
            bio: bio,
            capabilities: capabilities,
            cardCode: cardCode?.isEmpty == true ? nil : cardCode)
    }

    private static func clamp(_ value: String, maxLength: Int) -> String {
        if value.count <= maxLength { return value }
        return String(value.prefix(maxLength))
    }
}
