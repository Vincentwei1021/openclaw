import Foundation
import Testing
@testable import OpenClaw

@Suite struct SocialPeerTXTRecordCodecTests {
    @Test func encodeDictionaryIncludesCoreFields() {
        let profile = AgentProfile(
            id: "peer-xyz",
            displayName: "Nearby Agent",
            bio: "Runs automations",
            capabilities: ["voice", "share"],
            updatedAt: Date())

        let dictionary = SocialPeerTXTRecordCodec.encodeDictionary(profile: profile, cardCode: "card123")
        #expect(dictionary["id"] == "peer-xyz")
        #expect(dictionary["name"] == "Nearby Agent")
        #expect(dictionary["cap"] == "voice,share")
        #expect(dictionary["card"] == "card123")
    }

    @Test func encodeTXTDataCanDecodeBackToRecord() {
        let profile = AgentProfile(
            id: "peer-abc",
            displayName: "Social Node",
            bio: "on wifi",
            capabilities: ["nfc", "widget"],
            updatedAt: Date())
        let data = SocialPeerTXTRecordCodec.encodeTXTData(profile: profile, cardCode: "card-abc")
        let decoded = SocialPeerTXTRecordCodec.decode(data: data)

        #expect(decoded?.peerID == "peer-abc")
        #expect(decoded?.displayName == "Social Node")
        #expect(decoded?.bio == "on wifi")
        #expect(decoded?.capabilities == ["nfc", "widget"])
        #expect(decoded?.cardCode == "card-abc")
    }
}
