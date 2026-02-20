import Testing
@testable import OpenClaw

@Suite struct StatusActivityBuilderSceneTests {
    @Test @MainActor func sceneProfileAppearsWhenNoHigherPriorityActivity() {
        let appModel = NodeAppModel()
        appModel.sceneModeState = OpenClawSceneState(
            mode: .auto,
            profile: .commute,
            reason: "test",
            updatedAt: .now)

        let activity = StatusActivityBuilder.build(
            appModel: appModel,
            voiceWakeEnabled: false,
            cameraHUDText: nil,
            cameraHUDKind: nil)

        #expect(activity?.title == OpenClawSceneProfile.commute.title)
        #expect(activity?.systemImage == OpenClawSceneProfile.commute.systemImage)
    }
}
