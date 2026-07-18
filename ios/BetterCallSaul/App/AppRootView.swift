import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                currentTab
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                BCSBottomBar(selectedTab: $router.selectedTab)
            }
            .background(BCSColor.canvas.ignoresSafeArea())
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .evidence:
                    EvidenceView(router: router, legalCase: DemoFixtures.activeCase)
                case .document:
                    DocumentView(legalCase: DemoFixtures.activeCase)
                }
            }
        }
        .tint(BCSColor.ink)
    }

    @ViewBuilder
    private var currentTab: some View {
        switch router.selectedTab {
        case .home:
            HomeView(router: router)
        case .cases:
            CasesView(legalCase: DemoFixtures.activeCase)
        case .tools:
            ToolsView(items: DemoFixtures.tools)
        case .profile:
            ProfileView()
        }
    }
}

private struct BCSBottomBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? BCSColor.ink : BCSColor.secondary)
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
