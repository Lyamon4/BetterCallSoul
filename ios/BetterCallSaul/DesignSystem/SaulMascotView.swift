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
