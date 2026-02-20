import SwiftUI

enum AgentAvatarExpression: Equatable {
    case offline
    case connecting
    case ready
    case listening
    case busy
    case warning
    case error

    var accessibilityLabel: String {
        switch self {
        case .offline: "idle"
        case .connecting: "connecting"
        case .ready: "ready"
        case .listening: "listening"
        case .busy: "busy"
        case .warning: "attention"
        case .error: "error"
        }
    }

    static func resolve(
        gateway: StatusPill.GatewayState,
        voiceWakeEnabled: Bool,
        activity: StatusPill.Activity?
    ) -> Self {
        if gateway == .error {
            return .error
        }

        if let activity {
            let image = activity.systemImage.lowercased()
            let title = activity.title.lowercased()

            if image.contains("exclamationmark") || title.contains("permission") ||
                title.contains("foreground required")
            {
                return .warning
            }

            if image.contains("record") || image.contains("video") || title.contains("recording") {
                return .busy
            }

            if image.contains("mic") || title.contains("voice") {
                return .listening
            }

            if title.contains("approval") || title.contains("repair") || title.contains("pairing") {
                return .busy
            }
        }

        if gateway == .connecting {
            return .connecting
        }

        if gateway == .connected {
            return voiceWakeEnabled ? .listening : .ready
        }

        return .offline
    }
}

struct AgentAvatarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var expression: AgentAvatarExpression
    var size: CGFloat = 18

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(self.faceColor.gradient)

            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 0.6)

            if self.shouldPulse {
                Circle()
                    .stroke(self.featureColor.opacity(self.pulse ? 0.25 : 0.0), lineWidth: 1.4)
                    .scaleEffect(self.pulse ? 1.18 : 0.92)
                    .animation(
                        self.reduceMotion ? .none : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: self.pulse
                    )
            }

            VStack(spacing: self.size * 0.15) {
                HStack(spacing: self.size * 0.17) {
                    self.eye(scaleY: self.leftEyeScale)
                    self.eye(scaleY: self.rightEyeScale)
                }
                .offset(y: -self.size * 0.05)

                if self.expression == .busy {
                    Circle()
                        .stroke(self.featureColor, lineWidth: self.size * 0.07)
                        .frame(width: self.size * 0.19, height: self.size * 0.19)
                        .offset(y: self.size * 0.04)
                } else {
                    AgentMouthShape(curvature: self.mouthCurvature)
                        .stroke(self.featureColor, style: StrokeStyle(lineWidth: self.size * 0.08, lineCap: .round))
                        .frame(width: self.size * 0.43, height: self.size * 0.2)
                        .offset(y: self.size * 0.06)
                }
            }
        }
        .frame(width: self.size, height: self.size)
        .onAppear { self.updatePulse() }
        .onChange(of: self.expression) { _, _ in self.updatePulse() }
        .onChange(of: self.reduceMotion) { _, _ in self.updatePulse() }
        .accessibilityHidden(true)
    }

    private func eye(scaleY: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(self.featureColor)
            .frame(width: self.size * 0.14, height: self.size * 0.14)
            .scaleEffect(y: scaleY)
    }

    private var mouthCurvature: CGFloat {
        switch self.expression {
        case .ready, .listening:
            0.8
        case .connecting, .busy:
            0.0
        case .warning:
            -0.45
        case .error:
            -0.85
        case .offline:
            -0.2
        }
    }

    private var faceColor: Color {
        switch self.expression {
        case .offline:
            .gray.opacity(0.45)
        case .connecting:
            .yellow.opacity(0.82)
        case .ready:
            .green.opacity(0.8)
        case .listening:
            .mint.opacity(0.82)
        case .busy:
            .blue.opacity(0.78)
        case .warning:
            .orange.opacity(0.85)
        case .error:
            .red.opacity(0.85)
        }
    }

    private var featureColor: Color {
        switch self.expression {
        case .offline:
            .white.opacity(0.7)
        default:
            .white.opacity(0.92)
        }
    }

    private var leftEyeScale: CGFloat {
        switch self.expression {
        case .offline:
            0.55
        case .connecting:
            self.pulse ? 1.0 : 0.3
        case .error:
            0.85
        default:
            1.0
        }
    }

    private var rightEyeScale: CGFloat {
        switch self.expression {
        case .offline:
            0.55
        case .connecting:
            self.pulse ? 0.3 : 1.0
        case .error:
            0.85
        default:
            1.0
        }
    }

    private var shouldPulse: Bool {
        self.expression == .connecting || self.expression == .listening || self.expression == .busy
    }

    private func updatePulse() {
        guard self.shouldPulse, !self.reduceMotion else {
            self.pulse = false
            return
        }
        self.pulse = true
    }
}

private struct AgentMouthShape: Shape {
    var curvature: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.midY
        let offset = self.curvature * rect.height * 0.9
        let start = CGPoint(x: rect.minX, y: baseline + offset * 0.25)
        let end = CGPoint(x: rect.maxX, y: baseline + offset * 0.25)
        let control = CGPoint(x: rect.midX, y: baseline - offset)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}
