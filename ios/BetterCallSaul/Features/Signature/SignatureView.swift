import SwiftUI

struct SignatureView: View {
    let router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var workingSignature: HandwrittenSignature
    @State private var isVisible = false

    init(router: AppRouter, workflow: CaseWorkflowStore) {
        self.router = router
        self.workflow = workflow
        _workingSignature = State(initialValue: workflow.signature)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar

                BCSEditorialTitle(text: "Оставьте подпись", size: 42)
                    .padding(.top, 12)
                Text("Подпишите обращение пальцем — как на бумаге.")
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                HStack(spacing: 14) {
                    SaulMascotView(state: .idle, size: 54)
                    Text("Подпись появится в готовой претензии и в PDF.")
                        .font(.bcsBody(14))
                        .foregroundStyle(BCSColor.ink)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(BCSColor.paleYellow)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 18)

                signatureCard
                    .padding(.top, 12)

                Label(
                    "Нажимая «Продолжить», вы подтверждаете, что это ваша подпись.",
                    systemImage: "checkmark.shield"
                )
                .font(.bcsBody(12))
                .foregroundStyle(BCSColor.secondary)
                .lineSpacing(2)
                .padding(.top, 14)

                BCSPrimaryButton("Продолжить", systemImage: "checkmark") {
                    confirm()
                }
                .disabled(workingSignature.isEmpty)
                .opacity(workingSignature.isEmpty ? 0.35 : 1)
                .accessibilityIdentifier("confirmSignatureButton")
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Проверка", systemImage: "chevron.left")
                    .font(.bcsBody(15))
            }
            Spacer()
            Text("4 из 5")
                .font(.bcsMeta())
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < 4 ? BCSColor.yellow : BCSColor.divider)
                        .frame(width: 14, height: 4)
                }
            }
        }
        .foregroundStyle(BCSColor.ink)
        .frame(minHeight: 44)
    }

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ВАША ПОДПИСЬ")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(BCSColor.secondary)
                Spacer()
                Button("Очистить") {
                    withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                        workingSignature = .empty
                    }
                }
                .disabled(workingSignature.isEmpty)
                .font(.bcsBody(13, weight: .medium))
                .foregroundStyle(BCSColor.ink)
                .accessibilityIdentifier("clearSignatureButton")
            }

            ZStack(alignment: .bottomLeading) {
                SignatureCanvasView(signature: $workingSignature)
                    .frame(height: 230)

                Rectangle()
                    .fill(BCSColor.divider)
                    .frame(height: 1)
                    .padding(.bottom, 30)
                    .allowsHitTesting(false)

                Text("Подпись")
                    .font(.bcsBody(11))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
            .background(BCSColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        workingSignature.isEmpty
                            ? BCSColor.divider
                            : BCSColor.ink.opacity(0.35),
                        lineWidth: workingSignature.isEmpty ? 1 : 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(BCSColor.surface.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func confirm() {
        guard !workingSignature.isEmpty else { return }
        workflow.confirmSignature(workingSignature)
        router.open(.document)
    }
}
