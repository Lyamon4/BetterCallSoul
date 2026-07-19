import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct EvidenceView: View {
    let router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                BCSEditorialTitle(text: "Добавьте\nдоказательства", size: 42)
                    .padding(.top, 14)
                Text("Чек, списание или переписка помогут составить точное требование.")
                    .font(.bcsBody(16))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 12)

                narrativeField
                    .padding(.top, 18)

                uploadArea
                    .padding(.top, 16)

                if isProcessing {
                    processingState
                        .padding(.top, 10)
                }
                if let errorMessage {
                    errorState(errorMessage)
                        .padding(.top, 10)
                }
                if let evidence = workflow.currentCase.evidence.first {
                    uploadedFile(evidence)
                        .padding(.top, 12)
                }

                if workflow.evidencePayload != nil {
                    disclosure
                        .padding(.top, 10)
                }

                extractedData
                    .padding(.top, 14)

                HStack {
                    Spacer()
                    PayphoneIllustration(lineColor: BCSColor.secondary.opacity(0.18), lineWidth: 0.9)
                        .frame(width: 48, height: 56)
                }
                .padding(.top, 8)

                BCSPrimaryButton("Проанализировать ситуацию", systemImage: "sparkles") {
                    router.open(.aiAnalysis)
                }
                .accessibilityIdentifier("continueToAIButton")
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 112)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .pdf]
        ) { result in
            guard case let .success(url) = result else {
                if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                }
                return
            }
            Task { await processFile(at: url) }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task { await processPhoto(photo) }
        }
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var narrativeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Что произошло")
                .font(.bcsBody(15, weight: .medium))
            TextEditor(text: Binding(
                get: { workflow.narrative },
                set: { workflow.updateNarrative($0) }
            ))
            .font(.bcsBody(16))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: 112)
            .background(BCSColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("caseNarrativeField")
        }
    }

    private var disclosure: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
            Text("Загружая документ, вы разрешаете обработать его для извлечения данных и подготовки обращения.")
                .font(.bcsBody(12))
                .foregroundStyle(BCSColor.secondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(BCSColor.paleYellow)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("evidenceAITransferDisclosure")
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
        Menu {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Выбрать фото", systemImage: "photo")
            }
            Button {
                isFileImporterPresented = true
            } label: {
                Label("Выбрать файл или PDF", systemImage: "folder")
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 28, weight: .regular))
                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.currentCase.evidence.isEmpty ? "Добавить документ" : "Заменить документ")
                        .font(.bcsBody(17, weight: .medium))
                    Text("Фото, PNG, JPG или PDF")
                        .font(.bcsBody(12))
                        .foregroundStyle(BCSColor.secondary)
                }
                Spacer()
            }
            .padding(18)
            .frame(minHeight: 76)
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
        .accessibilityIdentifier("addEvidenceButton")
    }

    private var processingState: some View {
        HStack(spacing: 12) {
            SaulMascotView(state: .thinking, size: 52)
            Text("Проверяем документ…")
                .font(.bcsBody(14, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(BCSColor.paleYellow)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("evidenceProcessingState")
    }

    private func errorState(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(.bcsBody(13))
            Spacer()
        }
        .padding(12)
        .background(BCSColor.paleYellow)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func uploadedFile(_ evidence: EvidenceItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 3) {
                Text(evidence.fileName)
                    .font(.bcsBody(16, weight: .medium))
                    .lineLimit(1)
                Text(evidence.fileSize)
                    .font(.bcsBody(13))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            Button {
                workflow.removeEvidence()
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Удалить документ")
        }
        .padding(12)
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
                .padding(.vertical, 5)
                .background(BCSColor.paleYellow)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(12)

            ForEach(workflow.currentCase.extractedFields) { field in
                HStack {
                    Text(field.label)
                        .foregroundStyle(BCSColor.secondary)
                    Spacer()
                    TextField(field.label, text: binding(for: field))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(BCSColor.ink)
                        .accessibilityValue(field.value)
                }
                .font(.bcsBody(16))
                .frame(minHeight: 38)
                .padding(.horizontal, 14)
                BCSDivider().padding(.horizontal, 14)
            }
        }
        .background(BCSColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BCSColor.divider))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func binding(for field: ExtractedField) -> Binding<String> {
        Binding(
            get: {
                workflow.currentCase.extractedFields
                    .first(where: { $0.id == field.id })?
                    .value ?? ""
            },
            set: { workflow.updateField(label: field.label, value: $0) }
        )
    }

    private func processPhoto(_ photo: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            guard let data = try await photo.loadTransferable(type: Data.self) else {
                throw EvidenceImportError.unreadableFile
            }
            let fileName = "Фото-\(Date.now.formatted(.iso8601.year().month().day())).png"
            let imported = try EvidenceImporter().importImageData(data, fileName: fileName)
            try await recognize(imported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processFile(at url: URL) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let imported = try EvidenceImporter().importFile(at: url)
            try await recognize(imported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognize(_ imported: ImportedEvidence) async throws {
        let parser = ReceiptFieldParser()
        workflow.attachEvidence(imported)
        workflow.applyExtraction(
            evidence: imported.item,
            fields: parser.parse("", caseType: workflow.currentCase.type)
        )

        do {
            let text = try await VisionTextRecognizer().recognizeText(in: imported.image)
            workflow.applyExtraction(
                evidence: imported.item,
                fields: parser.parse(text, caseType: workflow.currentCase.type)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
