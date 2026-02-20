import Foundation
import Testing
@testable import OpenClaw

@Suite struct AgentCardCodecTests {
    @Test func roundTripEncodeDecodePreservesProfileFields() {
        let profile = AgentProfile(
            id: "ios-peer-123",
            displayName: "OpenClaw Peer",
            bio: "Nearby helper",
            capabilities: ["voice", "camera"],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let payload = AgentCardPayload(profile: profile, sharedAt: Date(timeIntervalSince1970: 1_700_000_100))

        let encoded = AgentCardCodec.encode(payload: payload)
        #expect(encoded != nil)
        guard let encoded else { return }
        let decoded = AgentCardCodec.decode(code: encoded)
        #expect(decoded == payload)
    }

    @Test func decodeFromDeepLinkInputReadsCardQueryParameter() {
        let profile = AgentProfile.bootstrap(displayName: "Peer", instanceID: "peer-01")
        let payload = AgentCardPayload(profile: profile)
        let deepLink = AgentCardCodec.deepLinkString(for: payload)
        #expect(deepLink != nil)
        guard let deepLink else { return }

        let decoded = AgentCardCodec.decode(fromInput: deepLink)
        #expect(decoded?.profile.id == profile.id)
        #expect(decoded?.profile.displayName == profile.displayName)
    }
}
