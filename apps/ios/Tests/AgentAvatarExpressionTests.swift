import Testing
@testable import OpenClaw

@Suite struct AgentAvatarExpressionTests {
    @Test func gatewayErrorAlwaysMapsToErrorExpression() {
        let activity = StatusPill.Activity(title: "Recording screen…", systemImage: "record.circle.fill", tint: nil)
        let expression = AgentAvatarExpression.resolve(gateway: .error, voiceWakeEnabled: true, activity: activity)
        #expect(expression == .error)
    }

    @Test func recordingActivityMapsToBusyExpression() {
        let activity = StatusPill.Activity(title: "Recording screen…", systemImage: "record.circle.fill", tint: nil)
        let expression = AgentAvatarExpression.resolve(gateway: .connected, voiceWakeEnabled: false, activity: activity)
        #expect(expression == .busy)
    }

    @Test func connectedVoiceWakeMapsToListeningExpression() {
        let expression = AgentAvatarExpression.resolve(gateway: .connected, voiceWakeEnabled: true, activity: nil)
        #expect(expression == .listening)
    }

    @Test func disconnectedMapsToOfflineExpression() {
        let expression = AgentAvatarExpression.resolve(gateway: .disconnected, voiceWakeEnabled: false, activity: nil)
        #expect(expression == .offline)
    }
}
