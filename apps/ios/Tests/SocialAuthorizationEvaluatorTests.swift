import Testing
@testable import OpenClaw

@Suite struct SocialAuthorizationEvaluatorTests {
    @Test func blockedPeerIsDeniedForAnyPolicy() {
        let decision = SocialAuthorizationEvaluator.decide(
            policy: .allowAll,
            peerID: "peer-1",
            trustedPeerIDs: ["peer-1"],
            blockedPeerIDs: ["peer-1"])

        #expect(decision.allowed == false)
        #expect(decision.requiresPrompt == false)
        #expect(decision.reason == "blocked")
    }

    @Test func trustedOnlyAllowsTrustedPeerAndDeniesUnknown() {
        let trusted = SocialAuthorizationEvaluator.decide(
            policy: .trustedOnly,
            peerID: "peer-1",
            trustedPeerIDs: ["peer-1"],
            blockedPeerIDs: [])
        #expect(trusted.allowed == true)
        #expect(trusted.reason == "trusted peer")

        let unknown = SocialAuthorizationEvaluator.decide(
            policy: .trustedOnly,
            peerID: "peer-2",
            trustedPeerIDs: ["peer-1"],
            blockedPeerIDs: [])
        #expect(unknown.allowed == false)
        #expect(unknown.reason == "not trusted")
    }

    @Test func promptPolicyReturnsPromptDecision() {
        let decision = SocialAuthorizationEvaluator.decide(
            policy: .promptEveryTime,
            peerID: "peer-1",
            trustedPeerIDs: [],
            blockedPeerIDs: [])

        #expect(decision.allowed == false)
        #expect(decision.requiresPrompt == true)
        #expect(decision.reason == "policy prompt")
    }
}
