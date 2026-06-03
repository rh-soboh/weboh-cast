import Foundation

struct Bookmark: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var url: String
    var favicon: String?
    let createdAt: Date
    var folder: String?

    init(title: String, url: String, favicon: String? = nil, folder: String? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.favicon = favicon
        self.createdAt = Date()
        self.folder = folder
    }
}

struct BookmarkFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
