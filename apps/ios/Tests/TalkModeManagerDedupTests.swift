import Foundation
import Testing
@testable import OpenClaw

@Suite struct TalkModeManagerDedupTests {
    @Test func normalizedTranscriptKeyCollapsesWhitespaceAndCase() {
        let key = TalkModeManager.normalizedTranscriptKey("  Hello   \n  WORLD  ")
        #expect(key == "hello world")
    }

    @Test func isDuplicateTranscriptHonorsCooldown() {
        let key = "hello world"

        let withinCooldown = TalkModeManager.isDuplicateTranscript(
            candidateKey: key,
            lastKey: key,
            elapsedSeconds: 0.4,
            cooldownSeconds: 1.6)
        #expect(withinCooldown == true)

        let afterCooldown = TalkModeManager.isDuplicateTranscript(
            candidateKey: key,
            lastKey: key,
            elapsedSeconds: 2.0,
            cooldownSeconds: 1.6)
        #expect(afterCooldown == false)

        let differentKey = TalkModeManager.isDuplicateTranscript(
            candidateKey: "hello there",
            lastKey: key,
            elapsedSeconds: 0.2,
            cooldownSeconds: 1.6)
        #expect(differentKey == false)
    }
}
