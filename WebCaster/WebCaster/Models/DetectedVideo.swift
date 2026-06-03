import Foundation

enum VideoFormat: String, Codable, CaseIterable {
    case mp4 = "MP4"
    case webm = "WebM"
    case hls = "HLS"
    case dash = "DASH"
    case mkv = "MKV"
    case avi = "AVI"
    case mov = "MOV"
    case ts = "TS"
    case unknown = "Unknown"

    static func from(url: String) -> VideoFormat {
        let lower = url.lowercased()
        if lower.contains(".m3u8") { return .hls }
        if lower.contains(".mpd") { return .dash }
        if lower.contains(".mp4") { return .mp4 }
        if lower.contains(".webm") { return .webm }
        if lower.contains(".mkv") { return .mkv }
        if lower.contains(".avi") { return .avi }
        if lower.contains(".mov") { return .mov }
        if lower.contains(".ts") && !lower.contains(".tsx") { return .ts }
        return .unknown
    }
}

struct DetectedVideo: Identifiable, Codable, Hashable {
    let id: UUID
    let url: String
    let format: VideoFormat
    var title: String
    var resolution: String?
    var estimatedSize: String?
    var pageURL: String?
    var pageTitle: String?
    let detectedAt: Date
    var lastPosition: Double?

    init(
        url: String,
        format: VideoFormat? = nil,
        title: String? = nil,
        resolution: String? = nil,
        estimatedSize: String? = nil,
        pageURL: String? = nil,
        pageTitle: String? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.format = format ?? VideoFormat.from(url: url)
        self.title = title ?? Self.extractTitle(from: url)
        self.resolution = resolution
        self.estimatedSize = estimatedSize
        self.pageURL = pageURL
        self.pageTitle = pageTitle
        self.detectedAt = Date()
        self.lastPosition = nil
    }

    private static func extractTitle(from url: String) -> String {
        guard let urlObj = URL(string: url) else { return "Unknown Video" }
        let filename = urlObj.lastPathComponent
        if filename.isEmpty || filename == "/" {
            return urlObj.host ?? "Unknown Video"
        }
        return filename
            .replacingOccurrences(of: "%20", with: " ")
            .replacingOccurrences(of: "+", with: " ")
    }

    var displayFormat: String {
        var parts = [format.rawValue]
        if let res = resolution { parts.append(res) }
        if let size = estimatedSize { parts.append(size) }
        return parts.joined(separator: " • ")
    }
}
