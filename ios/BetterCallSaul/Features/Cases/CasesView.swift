import SwiftUI

struct CasesView: View {
    let router: AppRouter
    @Bindable var archive: DocumentArchiveStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BCSEditorialTitle(text: "Обращения")
                Text("Все готовые документы — в одном месте.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                if archive.documents.isEmpty {
                    emptyState
                        .padding(.top, 54)
                } else {
                    VStack(spacing: 10) {
                        ForEach(archive.documents) { document in
                            archiveRow(document)
                        }
                    }
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 112)
        }
        .background(BCSColor.canvas)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BCSColor.surface)
                    .frame(width: 172, height: 138)
                    .overlay {
                        VStack(alignment: .leading, spacing: 10) {
                            Rectangle()
                                .fill(BCSColor.yellow)
                                .frame(width: 34, height: 4)
                            ForEach([0.82, 0.62, 0.74], id: \.self) { width in
                                Capsule()
                                    .fill(BCSColor.divider)
                                    .frame(width: 116 * width, height: 6)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BCSColor.divider)
                    )

                SaulMascotView(state: .idle, size: 82)
                    .offset(x: 26, y: 20)
            }

            VStack(spacing: 7) {
                Text("Здесь появятся готовые документы")
                    .font(.bcsBody(18, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("Создайте и подпишите обращение — мы сохраним PDF, чтобы вы могли вернуться к нему в любой момент.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("archiveEmptyState")
    }

    private func archiveRow(_ document: ArchivedDocument) -> some View {
        Button {
            router.open(.archivedDocument(document.id))
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(BCSColor.ink)
                        .frame(width: 42, height: 42)
                        .background(BCSColor.paleYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(document.title)
                            .font(.bcsBody(16, weight: .semibold))
                            .foregroundStyle(BCSColor.ink)
                            .multilineTextAlignment(.leading)
                        Text(document.recipient.isEmpty ? "Получатель не указан" : document.recipient)
                            .font(.bcsBody(13))
                            .foregroundStyle(BCSColor.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BCSColor.secondary)
                        .padding(.top, 4)
                }

                BCSDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.caseNumber)
                            .font(.bcsMeta(10))
                        Text(savedDate(document.savedAt))
                            .font(.bcsBody(12))
                            .foregroundStyle(BCSColor.secondary)
                    }
                    Spacer()
                    Text("PDF ГОТОВ")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(BCSColor.paleGreen)
                        .foregroundStyle(BCSColor.greenText)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(BCSColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BCSColor.divider)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(BCSPressButtonStyle())
        .accessibilityIdentifier("archivedDocumentRow")
    }

    private func savedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"
        return "Сохранено \(formatter.string(from: date))"
    }
}
