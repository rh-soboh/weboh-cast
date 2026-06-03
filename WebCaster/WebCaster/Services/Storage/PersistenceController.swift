import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - History

    private var historyFileURL: URL { documentsDirectory.appendingPathComponent("history.json") }

    func loadHistory() -> [HistoryEntry] {
        load(from: historyFileURL) ?? []
    }

    func saveHistory(_ entries: [HistoryEntry]) {
        save(entries, to: historyFileURL)
    }

    func addHistoryEntry(_ entry: HistoryEntry) {
        var history = loadHistory()
        history.insert(entry, at: 0)
        if history.count > 500 { history = Array(history.prefix(500)) }
        saveHistory(history)
    }

    func clearHistory() {
        saveHistory([])
    }

    // MARK: - Bookmarks

    private var bookmarksFileURL: URL { documentsDirectory.appendingPathComponent("bookmarks.json") }

    func loadBookmarks() -> [Bookmark] {
        load(from: bookmarksFileURL) ?? []
    }

    func saveBookmarks(_ bookmarks: [Bookmark]) {
        save(bookmarks, to: bookmarksFileURL)
    }

    func addBookmark(_ bookmark: Bookmark) {
        var bookmarks = loadBookmarks()
        bookmarks.insert(bookmark, at: 0)
        saveBookmarks(bookmarks)
    }

    func removeBookmark(_ bookmark: Bookmark) {
        var bookmarks = loadBookmarks()
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks(bookmarks)
    }

    // MARK: - Playlists

    private var playlistsFileURL: URL { documentsDirectory.appendingPathComponent("playlists.json") }

    func loadPlaylists() -> [Playlist] {
        load(from: playlistsFileURL) ?? []
    }

    func savePlaylists(_ playlists: [Playlist]) {
        save(playlists, to: playlistsFileURL)
    }

    // MARK: - Queue

    private var queueFileURL: URL { documentsDirectory.appendingPathComponent("queue.json") }

    func loadQueue() -> [PlaylistItem] {
        load(from: queueFileURL) ?? []
    }

    func saveQueue(_ items: [PlaylistItem]) {
        save(items, to: queueFileURL)
    }

    // MARK: - Video Playback Positions

    private var positionsFileURL: URL { documentsDirectory.appendingPathComponent("positions.json") }

    func loadPositions() -> [String: Double] {
        load(from: positionsFileURL) ?? [:]
    }

    func savePosition(_ position: Double, for videoURL: String) {
        var positions = loadPositions()
        positions[videoURL] = position
        save(positions, to: positionsFileURL)
    }

    func getPosition(for videoURL: String) -> Double? {
        loadPositions()[videoURL]
    }

    // MARK: - Recent Devices

    private var devicesFileURL: URL { documentsDirectory.appendingPathComponent("recent_devices.json") }

    func loadRecentDevices() -> [CastDevice] {
        load(from: devicesFileURL) ?? []
    }

    func saveRecentDevice(_ device: CastDevice) {
        var devices = loadRecentDevices()
        devices.removeAll { $0.host == device.host && $0.port == device.port }
        var updated = device
        updated.lastConnected = Date()
        devices.insert(updated, at: 0)
        if devices.count > 20 { devices = Array(devices.prefix(20)) }
        save(devices, to: devicesFileURL)
    }

    // MARK: - Per-site Ad Block Toggle

    private var siteAdBlockFileURL: URL { documentsDirectory.appendingPathComponent("site_adblock.json") }

    func loadSiteAdBlockSettings() -> [String: Bool] {
        load(from: siteAdBlockFileURL) ?? [:]
    }

    func setSiteAdBlock(domain: String, enabled: Bool) {
        var settings = loadSiteAdBlockSettings()
        settings[domain] = enabled
        save(settings, to: siteAdBlockFileURL)
    }

    func isAdBlockEnabled(for domain: String) -> Bool {
        let settings = loadSiteAdBlockSettings()
        return settings[domain] ?? AppSettings.shared.adBlockerEnabled
    }

    // MARK: - Generic Helpers

    private func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ object: T, to url: URL) {
        guard let data = try? encoder.encode(object) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
