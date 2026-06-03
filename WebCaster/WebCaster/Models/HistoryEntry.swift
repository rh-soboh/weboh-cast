import Foundation

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let visitedAt: Date
    var favicon: String?

    init(title: String, url: String, favicon: String? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.visitedAt = Date()
        self.favicon = favicon
    }

    var displayDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: visitedAt, relativeTo: Date())
    }

    var domain: String {
        URL(string: url)?.host ?? url
    }
}
