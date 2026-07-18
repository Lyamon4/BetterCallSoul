import SwiftUI

struct EvidenceView: View {
    let router: AppRouter
    let legalCase: LegalCase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fields: [ExtractedField]
    @State private var isVisible = false

    init(router: AppRouter, legalCase: LegalCase) {
        self.router = router
        self.legalCase = legalCase
        _fields = State(initialValue: legalCase.extractedFields)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                BCSEditorialTitle(text: "Добавьте\nдоказательства")
                    .padding(.top, 30)
                Text("Чек, списание или переписка помогут составить точное требование.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 12)

                uploadArea
                    .padding(.top, 26)
                uploadedFile
                    .padding(.top, 12)
                extractedData
                    .padding(.top, 14)

                HStack {
                    Spacer()
                    PayphoneIllustration(lineColor: BCSColor.secondary.opacity(0.18), lineWidth: 0.9)
                        .frame(width: 94, height: 116)
                }
                .padding(.top, 14)

                BCSPrimaryButton("Продолжить") {
                    router.open(.document)
                }
                .accessibilityIdentifier("continueToDocumentButton")
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
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
                Label("Новое обращение", systemImage: "chevron.left")
                    .font(.bcsBody(15))
            }
            Spacer()
            Text("2 из 4")
                .font(.bcsMeta())
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < 2 ? BCSColor.yellow : BCSColor.divider)
                        .frame(width: 18, height: 4)
                }
            }
        }
        .foregroundStyle(BCSColor.ink)
        .frame(minHeight: 44)
    }

    private var uploadArea: some View {
        Button {} label: {
            HStack(spacing: 16) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 28, weight: .regular))
                Text("Добавить документ")
                    .font(.bcsBody(17, weight: .medium))
                Spacer()
            }
            .padding(22)
            .frame(minHeight: 100)
            .foregroundStyle(BCSColor.ink)
            .background(BCSColor.surface.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        BCSColor.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
    }

    private var uploadedFile: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 3) {
                Text(legalCase.evidence[0].fileName)
                    .font(.bcsBody(16, weight: .medium))
                Text(legalCase.evidence[0].fileSize)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Удалить документ")
        }
        .padding(16)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var extractedData: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ПРОВЕРЬТЕ ДАННЫЕ")
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(BCSColor.paleYellow)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(16)

            ForEach($fields) { $field in
                HStack {
                    Text(field.label)
                        .foregroundStyle(BCSColor.secondary)
                    Spacer()
                    TextField(field.label, text: $field.value)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(BCSColor.ink)
                        .accessibilityValue(field.value)
                }
                .font(.bcsBody(16))
                .frame(minHeight: 54)
                .padding(.horizontal, 16)
                BCSDivider().padding(.horizontal, 16)
            }
        }
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
