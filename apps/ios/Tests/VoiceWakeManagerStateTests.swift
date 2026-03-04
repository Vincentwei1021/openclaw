import Foundation
import SwabbleKit
import Testing
@testable import OpenClaw

@Suite(.serialized) struct VoiceWakeManagerStateTests {
    @MainActor
    private func waitForStatusChange(
        manager: VoiceWakeManager,
        from originalStatus: String,
        timeoutNanoseconds: UInt64 = 2_500_000_000
    ) async -> String {
        let pollInterval: UInt64 = 100_000_000
        var waited: UInt64 = 0
        while waited < timeoutNanoseconds {
            try? await Task.sleep(nanoseconds: pollInterval)
            if manager.statusText != originalStatus {
                return manager.statusText
            }
            waited += pollInterval
        }
        return manager.statusText
    }

    @Test @MainActor func suspendAndResumeCycleUpdatesState() async {
        let manager = VoiceWakeManager()
        manager.isEnabled = true
        manager.isListening = true
        manager.statusText = "Listening"

        let suspended = manager.suspendForExternalAudioCapture()
        #expect(suspended == true)
        #expect(manager.isListening == false)
        #expect(manager.statusText == "Paused")

        manager.resumeAfterExternalAudioCapture(wasSuspended: true)
        let resumedStatus = await self.waitForStatusChange(manager: manager, from: "Paused")
        #expect(resumedStatus != "Paused")
    }

    @Test @MainActor func handleRecognitionCallbackRestartsOnError() async {
        let manager = VoiceWakeManager()
        manager.isEnabled = true
        manager.isListening = true

        manager._test_handleRecognitionCallback(transcript: nil, segments: [], errorText: "boom")
        #expect(manager.statusText.contains("Recognizer error") == true)
        #expect(manager.isListening == false)

        let recoveredStatus = await self.waitForStatusChange(
            manager: manager,
            from: "Recognizer error: boom"
        )
        #expect(recoveredStatus != "Recognizer error: boom")
    }

    @Test @MainActor func handleRecognitionCallbackDispatchesCommand() async {
        let manager = VoiceWakeManager()
        manager.triggerWords = ["openclaw"]
        manager.isEnabled = true

        actor CaptureBox {
            var value: String?
            func set(_ next: String) { self.value = next }
        }
        let capture = CaptureBox()
        manager.configure { cmd in
            await capture.set(cmd)
        }

        let transcript = "openclaw hello"
        let triggerRange = transcript.range(of: "openclaw")!
        let helloRange = transcript.range(of: "hello")!
        let segments = [
            WakeWordSegment(text: "openclaw", start: 0.0, duration: 0.2, range: triggerRange),
            WakeWordSegment(text: "hello", start: 0.8, duration: 0.2, range: helloRange),
        ]

        manager._test_handleRecognitionCallback(transcript: transcript, segments: segments, errorText: nil)
        #expect(manager.lastTriggeredCommand == "hello")
        #expect(manager.statusText == "Triggered")

        try? await Task.sleep(nanoseconds: 300_000_000)
        #expect(await capture.value == "hello")
    }

    @Test @MainActor func duplicateCommandIsSuppressedOnlyWithinCooldownWindow() async {
        let manager = VoiceWakeManager()
        manager.triggerWords = ["openclaw"]
        manager.isEnabled = false

        actor CaptureCount {
            var count = 0
            func bump() { self.count += 1 }
            func value() -> Int { self.count }
        }
        let capture = CaptureCount()
        manager.configure { _ in
            await capture.bump()
        }

        let transcript = "openclaw hello"
        let triggerRange = transcript.range(of: "openclaw")!
        let helloRange = transcript.range(of: "hello")!
        let segments = [
            WakeWordSegment(text: "openclaw", start: 0.0, duration: 0.2, range: triggerRange),
            WakeWordSegment(text: "hello", start: 0.8, duration: 0.2, range: helloRange),
        ]

        manager._test_handleRecognitionCallback(transcript: transcript, segments: segments, errorText: nil)
        manager._test_handleRecognitionCallback(transcript: transcript, segments: segments, errorText: nil)
        try? await Task.sleep(nanoseconds: 250_000_000)
        #expect(await capture.value() == 1)

        let waitNs = UInt64((VoiceWakeManager.duplicateCommandCooldownSeconds + 0.25) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: waitNs)
        manager._test_handleRecognitionCallback(transcript: transcript, segments: segments, errorText: nil)
        try? await Task.sleep(nanoseconds: 250_000_000)
        #expect(await capture.value() == 2)
    }

    @Test func restartDelayBackoffIncreasesAndCaps() {
        let d1 = VoiceWakeManager.restartDelaySeconds(forErrorCount: 1)
        let d2 = VoiceWakeManager.restartDelaySeconds(forErrorCount: 2)
        let d3 = VoiceWakeManager.restartDelaySeconds(forErrorCount: 3)
        let d10 = VoiceWakeManager.restartDelaySeconds(forErrorCount: 10)

        #expect(d1 > 0)
        #expect(d2 > d1)
        #expect(d3 > d2)
        #expect(d10 <= 5.0)
    }
}
