import Foundation

enum SocialGraphRelation: String, Codable, CaseIterable, Sendable {
    case local
    case trusted
    case known
    case blocked
}

enum SocialGraphEdgeKind: String, Codable, CaseIterable, Sendable {
    case trusted
    case blocked
    case memoryShare = "memory.share"
    case meeting
}

struct SocialGraphNode: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var displayName: String
    var relation: SocialGraphRelation
    var memoryCount: Int
    var meetingCount: Int
}

struct SocialGraphEdge: Codable, Equatable, Sendable, Identifiable {
    var fromPeerID: String
    var toPeerID: String
    var kind: SocialGraphEdgeKind
    var weight: Int

    var id: String {
        "\(self.fromPeerID)|\(self.toPeerID)|\(self.kind.rawValue)"
    }

    var summaryText: String {
        "\(self.fromPeerID) -> \(self.toPeerID) (\(self.kind.rawValue), \(self.weight))"
    }
}

struct SocialGraphSnapshot: Codable, Equatable, Sendable {
    var nodes: [SocialGraphNode]
    var edges: [SocialGraphEdge]
    var generatedAt: Date

    var summaryText: String {
        "\(self.nodes.count) nodes / \(self.edges.count) edges"
    }
}

enum SocialGraphBuilder {
    static func build(
        localPeerID: String,
        localDisplayName: String,
        trustedPeerIDs: Set<String>,
        blockedPeerIDs: Set<String>,
        sharedMemories: [SharedMemoryRecord],
        meetingSessions: [AgentMeetingSession],
        now: Date = Date()) -> SocialGraphSnapshot
    {
        let normalizedLocalPeerID = self.normalize(localPeerID)
        guard !normalizedLocalPeerID.isEmpty else {
            return SocialGraphSnapshot(nodes: [], edges: [], generatedAt: now)
        }

        let trusted = Set(trustedPeerIDs.compactMap(self.nonEmptyNormalized))
        let blocked = Set(blockedPeerIDs.compactMap(self.nonEmptyNormalized))

        var peerIDs: Set<String> = [normalizedLocalPeerID]
        var memoryCountByPeerID: [String: Int] = [:]
        var meetingCountByPeerID: [String: Int] = [:]
        var edgeWeights: [GraphEdgeKey: Int] = [:]

        for peerID in trusted where peerID != normalizedLocalPeerID {
            peerIDs.insert(peerID)
            let key = GraphEdgeKey(
                fromPeerID: normalizedLocalPeerID,
                toPeerID: peerID,
                kind: .trusted)
            edgeWeights[key, default: 0] += 1
        }

        for peerID in blocked where peerID != normalizedLocalPeerID {
            peerIDs.insert(peerID)
            let key = GraphEdgeKey(
                fromPeerID: normalizedLocalPeerID,
                toPeerID: peerID,
                kind: .blocked)
            edgeWeights[key, default: 0] += 1
        }

        for record in sharedMemories {
            guard let sanitized = record.sanitized() else { continue }
            let sourcePeerID = self.normalize(sanitized.sourcePeerID)
            guard !sourcePeerID.isEmpty else { continue }

            peerIDs.insert(sourcePeerID)
            memoryCountByPeerID[sourcePeerID, default: 0] += 1

            guard sourcePeerID != normalizedLocalPeerID else { continue }
            let key = GraphEdgeKey(
                fromPeerID: sourcePeerID,
                toPeerID: normalizedLocalPeerID,
                kind: .memoryShare)
            edgeWeights[key, default: 0] += 1
        }

        for session in meetingSessions {
            let normalizedHost = self.normalize(session.hostPeerID)
            guard !normalizedHost.isEmpty else { continue }

            var participantIDs = Set(session.participantPeerIDs.compactMap(self.nonEmptyNormalized))
            participantIDs.insert(normalizedHost)
            guard !participantIDs.isEmpty else { continue }

            for peerID in participantIDs {
                peerIDs.insert(peerID)
                meetingCountByPeerID[peerID, default: 0] += 1
            }

            let sortedParticipants = participantIDs.sorted()
            for index in sortedParticipants.indices {
                let fromPeerID = sortedParticipants[index]
                for nextIndex in sortedParticipants.indices where nextIndex > index {
                    let toPeerID = sortedParticipants[nextIndex]
                    let key = GraphEdgeKey(
                        fromPeerID: fromPeerID,
                        toPeerID: toPeerID,
                        kind: .meeting)
                    edgeWeights[key, default: 0] += 1
                }
            }
        }

        let nodes = peerIDs
            .map { peerID in
                SocialGraphNode(
                    id: peerID,
                    displayName: peerID == normalizedLocalPeerID ? localDisplayName : peerID,
                    relation: self.relation(
                        peerID: peerID,
                        localPeerID: normalizedLocalPeerID,
                        trustedPeerIDs: trusted,
                        blockedPeerIDs: blocked),
                    memoryCount: memoryCountByPeerID[peerID, default: 0],
                    meetingCount: meetingCountByPeerID[peerID, default: 0])
            }
            .sorted {
                if Self.relationSortRank($0.relation) == Self.relationSortRank($1.relation) {
                    return $0.id.caseInsensitiveCompare($1.id) == .orderedAscending
                }
                return Self.relationSortRank($0.relation) < Self.relationSortRank($1.relation)
            }

        let edges = edgeWeights
            .map { key, weight in
                SocialGraphEdge(
                    fromPeerID: key.fromPeerID,
                    toPeerID: key.toPeerID,
                    kind: key.kind,
                    weight: weight)
            }
            .sorted {
                if Self.edgeSortRank($0.kind) == Self.edgeSortRank($1.kind) {
                    if $0.fromPeerID.caseInsensitiveCompare($1.fromPeerID) == .orderedSame {
                        return $0.toPeerID.caseInsensitiveCompare($1.toPeerID) == .orderedAscending
                    }
                    return $0.fromPeerID.caseInsensitiveCompare($1.fromPeerID) == .orderedAscending
                }
                return Self.edgeSortRank($0.kind) < Self.edgeSortRank($1.kind)
            }

        return SocialGraphSnapshot(nodes: nodes, edges: edges, generatedAt: now)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nonEmptyNormalized(_ value: String) -> String? {
        let cleaned = self.normalize(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func relation(
        peerID: String,
        localPeerID: String,
        trustedPeerIDs: Set<String>,
        blockedPeerIDs: Set<String>) -> SocialGraphRelation
    {
        if peerID == localPeerID {
            return .local
        }
        if blockedPeerIDs.contains(peerID) {
            return .blocked
        }
        if trustedPeerIDs.contains(peerID) {
            return .trusted
        }
        return .known
    }

    private static func relationSortRank(_ relation: SocialGraphRelation) -> Int {
        switch relation {
        case .local:
            return 0
        case .trusted:
            return 1
        case .known:
            return 2
        case .blocked:
            return 3
        }
    }

    private static func edgeSortRank(_ kind: SocialGraphEdgeKind) -> Int {
        switch kind {
        case .trusted:
            return 0
        case .blocked:
            return 1
        case .memoryShare:
            return 2
        case .meeting:
            return 3
        }
    }
}

private struct GraphEdgeKey: Hashable {
    var fromPeerID: String
    var toPeerID: String
    var kind: SocialGraphEdgeKind
}
