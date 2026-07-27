import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Bindable var profile: UserProfileStore
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
                            DocumentView(workflow: workflow, profile: profile)
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
            CasesView(legalCase: workflow.currentCase)
        case .tools:
            ToolsView(items: DemoFixtures.tools)
        case .profile:
            ProfileView(profile: profile)
        }
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
