import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            Text(router.selectedTab.title)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .evidence:
                        Text("Добавьте доказательства")
                    case .document:
                        Text("Претензия готова")
                    }
                }
        }
    }
}
