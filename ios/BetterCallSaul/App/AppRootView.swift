import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Bindable var profile: UserProfileStore
    @Bindable var archive: DocumentArchiveStore
    let problemClassifier: any ProblemClassifying

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $router.path) {
                currentTab
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BCSColor.canvas.ignoresSafeArea())
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .evidence:
                            EvidenceView(router: router, workflow: workflow)
                        case .aiAnalysis:
                            AIAnalysisView(router: router, workflow: workflow)
                        case .signature:
                            SignatureView(router: router, workflow: workflow)
                        case .document:
                            DocumentView(
                                workflow: workflow,
                                profile: profile,
                                archive: archive
                            )
                        case let .archivedDocument(id):
                            if let document = archive.document(id: id) {
                                ArchivedDocumentView(
                                    document: document,
                                    archive: archive
                                )
                            } else {
                                ArchiveMissingDocumentView()
                            }
                        }
                    }
            }

            BCSBottomBar(router: router)
                .zIndex(10)
        }
        .background(BCSColor.canvas.ignoresSafeArea())
        .tint(BCSColor.ink)
    }

    @ViewBuilder
    private var currentTab: some View {
        switch router.selectedTab {
        case .home:
            HomeView(
                router: router,
                workflow: workflow,
                profile: profile,
                problemClassifier: problemClassifier
            )
        case .cases:
            CasesView(router: router, archive: archive)
        case .tools:
            ToolsView(items: DemoFixtures.tools)
        case .profile:
            ProfileView(profile: profile)
        }
    }
}

private struct ArchiveMissingDocumentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 38, weight: .light))
            Text("Документ не найден")
                .font(.bcsEditorial(30))
            Text("Возможно, файл был удалён с устройства.")
                .font(.bcsBody(15))
                .foregroundStyle(BCSColor.secondary)
                .multilineTextAlignment(.center)
            Button("Вернуться к обращениям") {
                dismiss()
            }
            .font(.bcsBody(15, weight: .semibold))
        }
        .foregroundStyle(BCSColor.ink)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BCSColor.canvas)
        .navigationBarBackButtonHidden(true)
    }
}

private struct BCSBottomBar: View {
    let router: AppRouter

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    router.select(tab)
                    router.reset()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: router.selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: router.selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(router.selectedTab == tab ? BCSColor.ink : BCSColor.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                }
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(BCSColor.canvas.opacity(0.98))
        .overlay(alignment: .top) { BCSDivider() }
    }
}
