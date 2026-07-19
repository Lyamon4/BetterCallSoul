import SwiftUI

enum SaulMascotState: String, CaseIterable {
    case idle
    case thinking
    case talking
    case celebrating

    var assetName: String {
        switch self {
        case .idle:
            "SaulIdle"
        case .thinking:
            "SaulThinking"
        case .talking:
            "SaulTalking"
        case .celebrating:
            "SaulCelebrating"
        }
    }
}

enum SaulHelpCopy {
    static let lines = [
        "Расскажите как было — я помогу собрать главное.",
        "Чеки и скриншоты сделают обращение сильнее.",
        "Перед отправкой всё можно проверить."
    ]

    static func line(at index: Int) -> String {
        lines[index % lines.count]
    }
}

struct SaulMascotView: View {
    let state: SaulMascotState
    let size: CGFloat
    var isDecorative = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    var body: some View {
        Image(state.assetName)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: verticalOffset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .accessibilityHidden(isDecorative)
            .accessibilityLabel(isDecorative ? "" : "Сол, помощник")
            .accessibilityIdentifier("saulMascot.\(state.rawValue)")
            .onAppear(perform: startAnimation)
            .onChange(of: state) { _, _ in
                restartAnimation()
            }
            .onChange(of: reduceMotion) { _, _ in
                restartAnimation()
            }
    }

    private var verticalOffset: CGFloat {
        state == .idle && isAnimated && !reduceMotion ? -2 : 0
    }

    private var rotation: Double {
        state == .thinking && isAnimated && !reduceMotion ? 1 : 0
    }

    private var scale: CGFloat {
        (state == .talking || state == .celebrating) && isAnimated && !reduceMotion
            ? 1.04
            : 1
    }

    private func restartAnimation() {
        isAnimated = false
        startAnimation()
    }

    private func startAnimation() {
        guard !reduceMotion else { return }

        switch state {
        case .idle:
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isAnimated = true
            }
        case .thinking:
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isAnimated = true
            }
        case .talking, .celebrating:
            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
                isAnimated = true
            }
        }
    }
}

struct SaulTipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.bcsBody(14, weight: .medium))
            .foregroundStyle(BCSColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BCSColor.paleYellow)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("saulTipBubble")
    }
}
