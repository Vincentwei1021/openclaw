import SwiftUI
import Testing
@testable import OpenClaw

@Suite struct AppCoverageTests {
    @Test @MainActor func nodeAppModelUpdatesBackgroundedState() {
        let appModel = NodeAppModel()

        appModel.setScenePhase(.background)
        #expect(appModel.isBackgrounded == true)

        appModel.setScenePhase(.inactive)
        #expect(appModel.isBackgrounded == false)

        appModel.setScenePhase(.active)
        #expect(appModel.isBackgrounded == false)
    }

    @Test @MainActor func voiceWakeStartReportsUnsupportedOnSimulator() async {
        let voiceWake = VoiceWakeManager()
        voiceWake.isEnabled = true

        await voiceWake.start()

        let isSimulator =
            ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ||
            ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil
        if isSimulator {
            #expect(voiceWake.isListening == false)
            #expect(voiceWake.statusText.contains("Simulator"))
        } else {
            // On real devices this path depends on runtime permissions/hardware availability.
            #expect(voiceWake.statusText != "Off")
        }

        voiceWake.stop()
        #expect(voiceWake.statusText == "Off")
    }
}
