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
            StaticTabScreen(title: "Обращения")
        case .tools:
            StaticTabScreen(title: "Инструменты")
        case .profile:
            ProfileView()
        }
    }
}

private struct StaticTabScreen: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.bcsEditorial(44))
            .foregroundStyle(BCSColor.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .padding(.bottom, 80)
            .background(BCSColor.canvas)
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
