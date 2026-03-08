import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var model: AppModel

    private var isRecording: Bool {
        model.sessionState == .listeningPushToTalk || model.sessionState == .listeningLocked
    }

    private var symbolName: String {
        switch model.sessionState {
        case .idle:
            return "waveform"
        case .listeningPushToTalk:
            return "mic.fill"
        case .listeningLocked:
            return "lock.fill"
        case .finalizing:
            return "ellipsis"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch model.sessionState {
        case .listeningLocked:
            return .orange
        case .error:
            return .red
        case .finalizing:
            return .blue
        default:
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(accentColor.opacity(0.15)))
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(
                            isRecording
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: isRecording
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.statusMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(model.settings.shortcutDescription)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isRecording {
                        WaveformView(
                            level: model.audioLevel,
                            barCount: 12,
                            barWidth: 2,
                            barSpacing: 1.5,
                            maxHeight: 18,
                            minHeight: 3
                        )
                    }
                }

                Text(model.visibleTranscript.isEmpty ? "Start speaking..." : model.visibleTranscript)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(model.visibleTranscript.isEmpty ? .secondary : .primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        )
        .padding(6)
    }
}
