import SwiftUI

struct DockTabView: View {
    @ObservedObject var model: AppModel
    var onTap: @MainActor () -> Void

    private var isRecording: Bool {
        model.sessionState == .listeningPushToTalk || model.sessionState == .listeningLocked
    }

    private var isFinalizing: Bool {
        model.sessionState == .finalizing
    }

    private var isLocked: Bool {
        model.sessionState == .listeningLocked
    }

    private var isError: Bool {
        if case .error = model.sessionState { return true }
        return false
    }

    private var isActive: Bool {
        isRecording || isFinalizing
    }

    private var isExpanded: Bool {
        isActive || isError
    }

    private var errorMessage: String? {
        if case .error(let msg) = model.sessionState { return msg }
        return nil
    }

    private let darkPill = AnyShapeStyle(Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.97))

    private var pillFill: AnyShapeStyle {
        switch model.sessionState {
        case .error:
            return AnyShapeStyle(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.95))
        default:
            return darkPill
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            pillView
        }
        .frame(width: 280, height: 240, alignment: .bottom)
    }

    private var pillView: some View {
        HStack(spacing: 6) {
            if isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                if let msg = errorMessage {
                    Text(msg)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else if isRecording {
                WaveformView(
                    level: model.audioLevel,
                    style: .wave
                )
            } else if isFinalizing {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                IdleWaveView()
            }
        }
        .frame(width: isError ? nil : (isActive ? 52 : 40), height: 18)
        .padding(.horizontal, isError ? 10 : 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(pillFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isLocked
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.85, blue: 0.95),
                                        Color(red: 0.3, green: 0.95, blue: 0.4),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  ))
                                : isError
                                    ? AnyShapeStyle(Color.white.opacity(0.2))
                                    : AnyShapeStyle(.white.opacity(0.1)),
                            lineWidth: isLocked ? 1 : 0.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        )
        .frame(maxWidth: isError ? 260 : nil)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isRecording)
        .animation(.easeInOut(duration: 0.3), value: isLocked)
        .animation(.easeInOut(duration: 0.3), value: isFinalizing)
        .animation(.easeInOut(duration: 0.3), value: isError)
    }

}

struct IdleWaveView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2

            // Sharp waveform matching app icon:
            // flat → peaks → flat
            let points: [(CGFloat, CGFloat)] = [
                (0.00, 0.50),
                (0.12, 0.50),
                (0.20, 0.30),
                (0.28, 0.65),
                (0.36, 0.15),
                (0.44, 0.80),
                (0.52, 0.08),
                (0.60, 0.88),
                (0.68, 0.20),
                (0.76, 0.62),
                (0.84, 0.38),
                (0.92, 0.50),
                (1.00, 0.50),
            ]

            var path = Path()
            for (i, pt) in points.enumerated() {
                let p = CGPoint(x: pt.0 * w, y: pt.1 * h)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.0, green: 0.85, blue: 0.95),
                        Color(red: 0.3, green: 0.95, blue: 0.4),
                        Color(red: 1.0, green: 0.85, blue: 0.1),
                        Color(red: 1.0, green: 0.3, blue: 0.6),
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: w, y: midY)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 44, height: 16)
    }
}

