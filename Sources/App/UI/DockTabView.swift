import SwiftUI

struct WordBubble: Identifiable {
    let id = UUID()
    let text: String
    let xOffset: CGFloat
    let createdAt: Date = Date()
}

struct DockTabView: View {
    @ObservedObject var model: AppModel
    var onTap: @MainActor () -> Void

    @State private var bubbles: [WordBubble] = []
    @State private var lastTranscript = ""
    @State private var pendingWords: [String] = []

    private var isRecording: Bool {
        model.sessionState == .listeningPushToTalk || model.sessionState == .listeningLocked
    }

    private var isFinalizing: Bool {
        model.sessionState == .finalizing
    }

    private var isLocked: Bool {
        model.sessionState == .listeningLocked
    }

    private var isActive: Bool {
        isRecording || isFinalizing
    }

    private var pillFill: AnyShapeStyle {
        switch model.sessionState {
        case .listeningPushToTalk, .listeningLocked:
            return AnyShapeStyle(Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.97))
        case .finalizing:
            return AnyShapeStyle(Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.97))
        case .error:
            return AnyShapeStyle(Color.red.opacity(0.85))
        default:
            return AnyShapeStyle(Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.97))
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Bubbles floating up
            if model.settings.showWordBubbles {
                ForEach(bubbles) { bubble in
                    BubbleView(bubble: bubble) {
                        bubbles.removeAll { $0.id == bubble.id }
                    }
                }
            }

            // The pill
            pillView
        }
        .frame(width: 280, height: 240, alignment: .bottom)
        .onChange(of: model.visibleTranscript) { _, newValue in
            if model.settings.showWordBubbles {
                spawnBubbles(from: newValue)
            }
        }
        .onChange(of: model.sessionState) { _, newState in
            if newState == .idle || newState == .finalizing {
                // Flush any remaining pending words as a final bubble
                if !pendingWords.isEmpty {
                    let chunk = pendingWords.joined(separator: " ")
                    pendingWords.removeAll()
                    let xOffset = CGFloat.random(in: -20...20)
                    let bubble = WordBubble(text: chunk, xOffset: xOffset)
                    withAnimation(.easeOut(duration: 0.3)) {
                        bubbles.append(bubble)
                    }
                }
                if newState == .idle {
                    lastTranscript = ""
                }
            }
        }
    }

    private var pillView: some View {
        ZStack {
            if isRecording {
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
        .frame(width: isActive ? 52 : 40, height: 18)
        .padding(.horizontal, 8)
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
                                : AnyShapeStyle(.white.opacity(0.1)),
                            lineWidth: isLocked ? 1 : 0.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isRecording)
        .animation(.easeInOut(duration: 0.3), value: isLocked)
        .animation(.easeInOut(duration: 0.3), value: isFinalizing)
    }

    private func spawnBubbles(from transcript: String) {
        let newPortion: String
        if transcript.count > lastTranscript.count,
           transcript.hasPrefix(lastTranscript) || lastTranscript.isEmpty {
            let start = transcript.index(transcript.startIndex, offsetBy: lastTranscript.count)
            newPortion = String(transcript[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if transcript != lastTranscript {
            newPortion = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return
        }
        lastTranscript = transcript

        guard !newPortion.isEmpty else { return }

        let newWords = newPortion.split(separator: " ").map(String.init)
        pendingWords.append(contentsOf: newWords)

        // Wait until we have enough words for a fuller phrase (8-12 words)
        while pendingWords.count >= 8 {
            let chunkSize = min(Int.random(in: 8...12), pendingWords.count)
            let chunk = pendingWords[0..<chunkSize].joined(separator: " ")
            pendingWords.removeFirst(chunkSize)
            let xOffset = CGFloat.random(in: -20...20)
            let bubble = WordBubble(text: chunk, xOffset: xOffset)
            withAnimation(.easeOut(duration: 0.3)) {
                bubbles.append(bubble)
            }
        }
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

struct BubbleView: View {
    let bubble: WordBubble
    let onComplete: () -> Void

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85

    var body: some View {
        Text(bubble.text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: bubble.xOffset, y: offsetY)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    opacity = 1
                    scale = 1
                    offsetY = -30
                }
                withAnimation(.easeOut(duration: 2.5).delay(0.4)) {
                    offsetY = -90
                }
                withAnimation(.easeIn(duration: 0.8).delay(2.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    onComplete()
                }
            }
    }
}
