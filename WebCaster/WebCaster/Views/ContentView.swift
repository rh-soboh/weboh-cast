import SwiftUI

enum AppTab: String, CaseIterable {
    case browser = "Browser"
    case history = "History"
    case bookmarks = "Bookmarks"
    case queue = "Queue"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .browser: return "globe"
        case .history: return "clock"
        case .bookmarks: return "star"
        case .queue: return "list.bullet"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .browser: return "globe"
        case .history: return "clock.fill"
        case .bookmarks: return "star.fill"
        case .queue: return "list.bullet"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .browser
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var sharedPlayerVM = PlayerViewModel()
    @StateObject private var sharedCastingVM = CastingViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowserView(playerVM: sharedPlayerVM, castingVM: sharedCastingVM)
                .tabItem {
                    Label(AppTab.browser.rawValue,
                          systemImage: selectedTab == .browser ? AppTab.browser.selectedIcon : AppTab.browser.icon)
                }
                .tag(AppTab.browser)

            HistoryView(switchToBrowser: switchToBrowser)
                .tabItem {
                    Label(AppTab.history.rawValue,
                          systemImage: selectedTab == .history ? AppTab.history.selectedIcon : AppTab.history.icon)
                }
                .tag(AppTab.history)

            BookmarksView(switchToBrowser: switchToBrowser)
                .tabItem {
                    Label(AppTab.bookmarks.rawValue,
                          systemImage: selectedTab == .bookmarks ? AppTab.bookmarks.selectedIcon : AppTab.bookmarks.icon)
                }
                .tag(AppTab.bookmarks)

            QueueView(playerVM: sharedPlayerVM)
                .tabItem {
                    Label(AppTab.queue.rawValue,
                          systemImage: selectedTab == .queue ? AppTab.queue.selectedIcon : AppTab.queue.icon)
                }
                .tag(AppTab.queue)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue,
                          systemImage: selectedTab == .settings ? AppTab.settings.selectedIcon : AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.wcOrange)
        .preferredColorScheme(settings.theme.colorScheme)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func switchToBrowser() {
        selectedTab = .browser
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let darkBG = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.95)
        appearance.backgroundColor = darkBG
        appearance.shadowColor = .clear

        let orange = UIColor(red: 1.0, green: 0.427, blue: 0.0, alpha: 1.0)
        let gray = UIColor(white: 0.5, alpha: 1.0)

        let normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: gray]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: orange]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = gray
        appearance.stackedLayoutAppearance.selected.iconColor = orange

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
