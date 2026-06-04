import Foundation
import WebKit
import Combine

final class BrowserViewModel: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabIndex: Int = 0
    @Published var urlText: String = ""
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var showTabs: Bool = false
    @Published var pageTitle: String = ""

    private let settings = AppSettings.shared
    private let persistence = PersistenceController.shared

    var activeTab: BrowserTab? {
        guard tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    var homeURL: URL {
        URL(string: settings.searchEngine.homeURL) ?? URL(string: "https://www.google.com")!
    }

    init() {
        createNewTab(url: nil)
    }

    func createNewTab(url: URL? = nil) {
        let tab = BrowserTab(url: url, title: url == nil ? "New Tab" : "Loading...")
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        if let url = url {
            urlText = url.absoluteString
        } else {
            urlText = ""
        }
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        tabs.remove(at: index)
        if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        }
        updateURLText()
    }

    func switchToTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
        updateURLText()
    }

    func navigateTo(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL
        if let directURL = URL(string: trimmed), directURL.scheme != nil,
           trimmed.contains(".") || trimmed.hasPrefix("http") {
            url = directURL
        } else if trimmed.contains(".") && !trimmed.contains(" "),
                  let httpsURL = URL(string: "https://\(trimmed)") {
            url = httpsURL
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            guard let searchURL = URL(string: "\(settings.searchEngine.searchURL)\(encoded)") else { return }
            url = searchURL
        }

        if tabs.indices.contains(activeTabIndex) {
            tabs[activeTabIndex].url = url
        }
        urlText = url.absoluteString

        NotificationCenter.default.post(
            name: .init("NavigateToURL"),
            object: nil,
            userInfo: ["url": url, "tabIndex": activeTabIndex]
        )
    }

    func goHome() {
        navigateTo(settings.searchEngine.homeURL)
    }

    func goBack() {
        NotificationCenter.default.post(name: .init("WebViewGoBack"), object: nil)
    }

    func goForward() {
        NotificationCenter.default.post(name: .init("WebViewGoForward"), object: nil)
    }

    func reload() {
        NotificationCenter.default.post(name: .init("WebViewReload"), object: nil)
    }

    func updateTab(title: String?, url: URL?, canGoBack: Bool, canGoForward: Bool) {
        guard tabs.indices.contains(activeTabIndex) else { return }
        if let title = title, !title.isEmpty {
            tabs[activeTabIndex].title = title
            pageTitle = title
        }
        if let url = url {
            tabs[activeTabIndex].url = url
            urlText = url.absoluteString
        }
        tabs[activeTabIndex].canGoBack = canGoBack
        tabs[activeTabIndex].canGoForward = canGoForward
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }

    func updateProgress(_ progress: Double) {
        self.progress = progress
        isLoading = progress < 1.0
        if tabs.indices.contains(activeTabIndex) {
            tabs[activeTabIndex].estimatedProgress = progress
            tabs[activeTabIndex].isLoading = progress < 1.0
        }
    }

    func addToHistory(title: String, url: String) {
        let entry = HistoryEntry(title: title, url: url)
        persistence.addHistoryEntry(entry)
    }

    func addBookmark() {
        guard let tab = activeTab, let url = tab.url else { return }
        guard !isBookmarked() else { return }
        let bookmark = Bookmark(title: tab.title, url: url.absoluteString)
        persistence.addBookmark(bookmark)
    }

    func isBookmarked() -> Bool {
        guard let url = activeTab?.url?.absoluteString else { return false }
        return persistence.loadBookmarks().contains { $0.url == url }
    }

    private func updateURLText() {
        urlText = activeTab?.url?.absoluteString ?? ""
        pageTitle = activeTab?.title ?? ""
        canGoBack = activeTab?.canGoBack ?? false
        canGoForward = activeTab?.canGoForward ?? false
    }
}
