import Foundation

struct BrowserTab: Identifiable, Hashable {
    let id: UUID
    var url: URL?
    var title: String
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var estimatedProgress: Double

    init(url: URL? = nil, title: String = "New Tab") {
        self.id = UUID()
        self.url = url
        self.title = title
        self.isLoading = false
        self.canGoBack = false
        self.canGoForward = false
        self.estimatedProgress = 0
    }

    var displayTitle: String {
        if title.isEmpty {
            return url?.host ?? "New Tab"
        }
        return title
    }

    var displayURL: String {
        url?.absoluteString ?? ""
    }
}
