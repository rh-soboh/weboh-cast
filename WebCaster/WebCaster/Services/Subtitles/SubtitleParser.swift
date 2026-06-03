import Foundation

struct SubtitleCue: Identifiable {
    let id: Int
    let startTime: Double
    let endTime: Double
    let text: String
}

final class SubtitleParser {

    // MARK: - Public API

    static func parse(from url: URL, completion: @escaping ([SubtitleCue]) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let cues: [SubtitleCue]
            if url.pathExtension.lowercased() == "srt" {
                cues = parseSRT(content)
            } else {
                cues = parseVTT(content)
            }
            DispatchQueue.main.async { completion(cues) }
        }.resume()
    }

    static func parse(content: String, format: SubtitleFormat) -> [SubtitleCue] {
        switch format {
        case .srt: return parseSRT(content)
        case .vtt: return parseVTT(content)
        }
    }

    enum SubtitleFormat {
        case srt, vtt
    }

    // MARK: - SRT Parser

    static func parseSRT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

            let timeParts = lines[1].components(separatedBy: " --> ")
            guard timeParts.count == 2,
                  let start = parseSRTTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces)),
                  let end = parseSRTTimestamp(timeParts[1].trimmingCharacters(in: .whitespaces)) else {
                continue
            }

            let text = lines[2...].joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }
            cues.append(SubtitleCue(id: index, startTime: start, endTime: end, text: text))
        }
        return cues
    }

    // MARK: - VTT Parser

    static func parseVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var i = 0
        var cueIndex = 1

        // Skip WEBVTT header
        while i < lines.count && !lines[i].contains("-->") {
            i += 1
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.contains("-->") {
                let timeParts = line.components(separatedBy: " --> ")
                guard timeParts.count == 2 else { i += 1; continue }

                let endPart = timeParts[1].components(separatedBy: " ").first ?? timeParts[1]

                guard let start = parseVTTTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces)),
                      let end = parseVTTTimestamp(endPart.trimmingCharacters(in: .whitespaces)) else {
                    i += 1
                    continue
                }

                var textLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    let textLine = lines[i]
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !textLine.isEmpty {
                        textLines.append(textLine)
                    }
                    i += 1
                }

                let text = textLines.joined(separator: "\n")
                if !text.isEmpty {
                    cues.append(SubtitleCue(id: cueIndex, startTime: start, endTime: end, text: text))
                    cueIndex += 1
                }
            } else {
                i += 1
            }
        }
        return cues
    }

    // MARK: - Timestamp Parsing

    /// Parses "HH:MM:SS,mmm" format (SRT)
    private static func parseSRTTimestamp(_ str: String) -> Double? {
        let cleaned = str.replacingOccurrences(of: ",", with: ".")
        return parseTimestamp(cleaned)
    }

    /// Parses "HH:MM:SS.mmm" or "MM:SS.mmm" format (VTT)
    private static func parseVTTTimestamp(_ str: String) -> Double? {
        parseTimestamp(str)
    }

    private static func parseTimestamp(_ str: String) -> Double? {
        let parts = str.components(separatedBy: ":")
        switch parts.count {
        case 3:
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        case 2:
            guard let m = Double(parts[0]),
                  let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        default:
            return nil
        }
    }
}
