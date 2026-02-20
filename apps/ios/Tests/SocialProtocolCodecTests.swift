import Foundation
import Testing
@testable import OpenClaw

@Suite struct SocialProtocolCodecTests {
    @Test func roundTripEncodeDecodePreservesEnvelopeFields() {
        let envelope = SocialProtocolEnvelope(
            version: 1,
            id: "msg-01",
            type: .meetingInvite,
            fromPeerID: "peer-host",
            toPeerIDs: ["peer-a", "peer-b"],
            sentAt: Date(timeIntervalSince1970: 1_700_000_000),
            payload: ["title": "daily sync"])

        let code = SocialProtocolCodec.encode(envelope)
        #expect(code != nil)
        guard let code else { return }

        let decoded = SocialProtocolCodec.decode(code)
        #expect(decoded == envelope)
    }

    @Test func decodeFromDeepLinkReadsQueryMessage() {
        let envelope = SocialProtocolEnvelope(
            type: .meetingMessage,
            fromPeerID: "peer-host",
            toPeerIDs: ["peer-a"],
            payload: ["text": "hello"])
        let deepLink = SocialProtocolCodec.deepLinkString(for: envelope)
        #expect(deepLink != nil)
        guard let deepLink else { return }

        let decoded = SocialProtocolCodec.decode(fromInput: deepLink)
        #expect(decoded?.type == .meetingMessage)
        #expect(decoded?.fromPeerID == "peer-host")
        #expect(decoded?.payload["text"] == "hello")
    }
}
