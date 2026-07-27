import SwiftUI

struct DocumentView: View {
    @Bindable var workflow: CaseWorkflowStore
    @Bindable var profile: UserProfileStore
    @Bindable var archive: DocumentArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var createdAt = Date()
    @State private var shareURL: URL?
    @State private var isShareSheetPresented = false
    @State private var isExporting = false
    @State private var notice: ExportNotice?
    @State private var hasArchivedDocument = false

    private var legalCase: LegalCase { workflow.currentCase }

    private var draft: DocumentDraft {
        workflow.resolvedDocumentDraft(senderName: profile.name, createdAt: createdAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Label("Обращение", systemImage: "chevron.left")
                    }
                    Spacer()
                    SaulMascotView(state: .celebrating, size: 48)
                        .accessibilityHidden(false)
                        .accessibilityLabel("Сол радуется готовому документу")
                        .accessibilityIdentifier("documentCelebratingSaul")
                    BCSStatusBadge(title: legalCase.status.rawValue, isActive: true)
                }
                .font(.bcsBody(15))
                .foregroundStyle(BCSColor.ink)
                .frame(minHeight: 44)

                BCSEditorialTitle(text: "Претензия готова", size: 42)
                    .padding(.top, 10)
                Text("Проверьте данные перед отправкой.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 8)

                documentPaper
                    .padding(.top, 16)

                reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Подпись добавлена")
                    .padding(.top, 8)

                reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Данные добавлены")
                    .padding(.top, 6)

                if draft.requiresReview {
                    reviewRow(
                        icon: "exclamationmark",
                        color: BCSColor.yellow,
                        title: "\(reviewIssueCount) места требуют внимания",
                        isWarning: true
                    )
                    .padding(.top, 6)

                    reviewNoticePanel
                        .padding(.top, 6)
                } else {
                    reviewRow(icon: "checkmark", color: BCSColor.ink, title: "Факты проверены")
                        .padding(.top, 6)
                }

                BCSPrimaryButton(
                    isExporting ? "Создаём PDF…" : "Создать и отправить PDF",
                    systemImage: "square.and.arrow.up"
                ) {
                    exportPDF()
                }
                .disabled(isExporting)
                .accessibilityIdentifier("sendDocumentButton")
                .padding(.top, 8)

                Button("Скачать PDF") {
                    exportPDF()
                }
                .disabled(isExporting)
                .font(.bcsBody(16, weight: .medium))
                .foregroundStyle(BCSColor.ink)
                .underline()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)

                HStack {
                    Label("Всё по закону.", systemImage: "phone")
                    Spacer()
                    Text("S’all good")
                        .italic()
                }
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(BCSColor.secondary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            archiveDocumentIfNeeded()
        }
        .sheet(isPresented: $isShareSheetPresented, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ShareSheet(items: [shareURL]) { completed in
                    if completed {
                        workflow.markSent()
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("Готово"))
            )
        }
    }

    private var documentPaper: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "phone.fill")
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(BCSColor.ink))
                    Text("BetterCallSaul")
                        .font(.system(size: 11, design: .serif))
                    Text("Всё по закону.")
                        .font(.bcsBody(9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Исх. № \(draft.caseNumber)")
                    Text(createdAt.formatted(date: .long, time: .omitted))
                }
                .font(.bcsMeta(8))
            }

            Rectangle()
                .fill(BCSColor.yellow)
                .frame(width: 34, height: 4)

            Text(draft.title)
                .font(.bcsEditorial(20))

            Text("Кому: \(draft.recipient)")
                .font(.bcsBody(10))

            BCSDivider()

            Text(draft.body)
                .font(.bcsBody(10))
                .lineSpacing(2)

            Text(attachmentText)
                .font(.bcsBody(9))

            BCSDivider()

            HStack {
                Text("С уважением,\n\(draft.senderName)")
                    .font(.bcsBody(9))
                Spacer()
                DocumentSignatureView(signature: workflow.signature, lineWidth: 1.6)
                    .frame(width: 92, height: 42)
            }
        }
        .padding(16)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private var reviewIssueCount: Int {
        max(2, legalCase.extractedFields.filter(\.requiresReview).count)
    }

    private var attachmentText: String {
        if draft.attachmentCount == 0 {
            return "Приложения: отсутствуют."
        }
        return "Приложение: подтверждающие материалы — \(draft.attachmentCount) файл(а)."
    }

    private var reviewNoticePanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(BCSColor.ink)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Проверьте перед отправкой")
                    .font(.bcsBody(14, weight: .semibold))
                Text(draft.reviewNotice)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(BCSColor.paleYellow)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("documentReviewNotice")
    }

    private func exportPDF() {
        guard !workflow.signature.isEmpty else {
            notice = ExportNotice(
                title: "Добавьте подпись",
                message: "Вернитесь на предыдущий экран и подпишите обращение."
            )
            return
        }
        isExporting = true
        defer { isExporting = false }

        do {
            let document = try archive.save(
                draft: draft,
                signature: workflow.signature,
                caseID: legalCase.id
            )
            guard let url = archive.fileURL(for: document) else {
                throw DocumentArchiveError.documentNotFound
            }
            hasArchivedDocument = true
            workflow.prepareDocument()
            shareURL = url

            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                notice = ExportNotice(
                    title: "PDF создан",
                    message: "Документ готов к отправке."
                )
            } else {
                isShareSheetPresented = true
            }
        } catch {
            notice = ExportNotice(
                title: "Не удалось создать PDF",
                message: error.localizedDescription
            )
        }
    }

    private func archiveDocumentIfNeeded() {
        guard !hasArchivedDocument, !workflow.signature.isEmpty else { return }

        do {
            try archive.save(
                draft: draft,
                signature: workflow.signature,
                caseID: legalCase.id
            )
            hasArchivedDocument = true
            workflow.prepareDocument()
        } catch {
            notice = ExportNotice(
                title: "Не удалось сохранить обращение",
                message: error.localizedDescription
            )
        }
    }

    private func reviewRow(
        icon: String,
        color: Color,
        title: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 28, height: 28)
                .background(color)
                .foregroundStyle(isWarning ? BCSColor.ink : Color.white)
                .clipShape(Circle())
            Text(title)
                .font(.bcsBody(15))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BCSColor.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ExportNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
