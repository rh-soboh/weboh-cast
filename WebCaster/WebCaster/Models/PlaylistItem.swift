import Foundation

struct PlaylistItem: Identifiable, Codable, Hashable {
    let id: UUID
    let video: DetectedVideo
    var order: Int
    let addedAt: Date

    init(video: DetectedVideo, order: Int = 0) {
        self.id = UUID()
        self.video = video
        self.order = order
        self.addedAt = Date()
    }
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [PlaylistItem]
    let createdAt: Date
    var updatedAt: Date

    init(name: String, items: [PlaylistItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func addItem(_ video: DetectedVideo) {
        let item = PlaylistItem(video: video, order: items.count)
        items.append(item)
        updatedAt = Date()
    }

    mutating func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        for i in items.indices {
            items[i].order = i
        }
        updatedAt = Date()
    }

    mutating func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        for i in items.indices {
            items[i].order = i
        }
        updatedAt = Date()
    }
}
