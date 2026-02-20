import Foundation

enum SocialAuthorizationPolicy: String, Codable, CaseIterable, Sendable {
    case trustedOnly
    case promptEveryTime
    case allowAll

    var title: String {
        switch self {
        case .trustedOnly:
            "Trusted Only"
        case .promptEveryTime:
            "Prompt"
        case .allowAll:
            "Allow All"
        }
    }

    var helpText: String {
        switch self {
        case .trustedOnly:
            "Only trusted agent IDs are allowed. Unknown peers are denied by default."
        case .promptEveryTime:
            "Every peer requires explicit approval before actions are accepted."
        case .allowAll:
            "All peers on the local network are allowed unless blocked."
        }
    }
}

struct SocialAuthorizationDecision: Equatable, Sendable {
    var allowed: Bool
    var requiresPrompt: Bool
    var reason: String
}

enum SocialAuthorizationEvaluator {
    static func decide(
        policy: SocialAuthorizationPolicy,
        peerID: String,
        trustedPeerIDs: Set<String>,
        blockedPeerIDs: Set<String>) -> SocialAuthorizationDecision
    {
        let normalizedPeerID = peerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPeerID.isEmpty else {
            return SocialAuthorizationDecision(
                allowed: false,
                requiresPrompt: false,
                reason: "missing peer id")
        }

        if blockedPeerIDs.contains(normalizedPeerID) {
            return SocialAuthorizationDecision(
                allowed: false,
                requiresPrompt: false,
                reason: "blocked")
        }

        switch policy {
        case .allowAll:
            return SocialAuthorizationDecision(
                allowed: true,
                requiresPrompt: false,
                reason: "policy allowAll")
        case .promptEveryTime:
            return SocialAuthorizationDecision(
                allowed: false,
                requiresPrompt: true,
                reason: "policy prompt")
        case .trustedOnly:
            if trustedPeerIDs.contains(normalizedPeerID) {
                return SocialAuthorizationDecision(
                    allowed: true,
                    requiresPrompt: false,
                    reason: "trusted peer")
            }
            return SocialAuthorizationDecision(
                allowed: false,
                requiresPrompt: false,
                reason: "not trusted")
        }
    }
}
