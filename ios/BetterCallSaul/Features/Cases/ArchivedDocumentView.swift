import SwiftUI

struct ArchivedDocumentView: View {
    let document: ArchivedDocument
    @Bindable var archive: DocumentArchiveStore

    @Environment(\.dismiss) private var dismiss
    @State private var isShareSheetPresented = false

    private var fileURL: URL? {
        archive.fileURL(for: document)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("Обращения", systemImage: "chevron.left")
                    }
                    Spacer()
                    BCSStatusBadge(title: "PDF готов", isActive: false)
                }
                .font(.bcsBody(15))
                .foregroundStyle(BCSColor.ink)
                .frame(minHeight: 44)

                BCSEditorialTitle(text: "Готовый документ", size: 40)
                    .padding(.top, 10)

                Text(document.title)
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                metadata
                    .padding(.top, 18)

                if let fileURL {
                    PDFPreview(url: fileURL)
                        .frame(height: 430)
                        .background(BCSColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BCSColor.divider)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("archivedPDFPreview")
                        .padding(.top, 14)

                    BCSPrimaryButton("Скачать PDF", systemImage: "square.and.arrow.down") {
                        isShareSheetPresented = true
                    }
                    .accessibilityIdentifier("archiveDownloadButton")
                    .padding(.top, 14)
                } else {
                    missingFile
                        .padding(.top, 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShareSheetPresented) {
            if let fileURL {
                ShareSheet(items: [fileURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 0) {
            metadataItem(label: "НОМЕР", value: document.caseNumber)
            Rectangle()
                .fill(BCSColor.divider)
                .frame(width: 1, height: 42)
                .padding(.horizontal, 14)
            metadataItem(label: "СОХРАНЁН", value: formattedDate)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BCSColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BCSColor.divider)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(BCSColor.secondary)
            Text(value)
                .font(.bcsBody(12, weight: .medium))
                .lineLimit(1)
        }
    }

    private var missingFile: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
            Text("PDF не найден")
                .font(.bcsBody(17, weight: .semibold))
            Text("Файл мог быть удалён с устройства.")
                .font(.bcsBody(14))
                .foregroundStyle(BCSColor.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(BCSColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BCSColor.divider)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: document.savedAt)
    }
}
