import Foundation
import WebKit

protocol VideoDetectionDelegate: AnyObject {
    func didDetectVideo(_ video: DetectedVideo)
}

final class VideoDetectionService: NSObject {
    static let shared = VideoDetectionService()

    weak var delegate: VideoDetectionDelegate?
    private(set) var detectedVideos: [DetectedVideo] = []
    private var detectedURLs: Set<String> = []
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    func injectDetectorScript() -> WKUserScript {
        let js = loadDetectorJS()
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    }

    func handleMessage(_ message: WKScriptMessage) {
        guard message.name == "videoDetected",
              let bodyString = message.body as? String,
              let data = bodyString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = json["url"] as? String else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        guard !detectedURLs.contains(url) else { return }
        detectedURLs.insert(url)

        let resolution = json["resolution"] as? String
        let type = json["type"] as? String

        let video = DetectedVideo(
            url: url,
            resolution: resolution,
            pageURL: (message.webView?.url ?? message.frameInfo.request.url)?.absoluteString,
            pageTitle: message.webView?.title
        )

        detectedVideos.append(video)
        print("[VideoDetector] Found \(video.format.rawValue): \(url) via \(type ?? "unknown")")

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didDetectVideo(video)
        }
    }

    func clearDetectedVideos() {
        lock.lock()
        detectedVideos.removeAll()
        detectedURLs.removeAll()
        lock.unlock()
    }

    func clearForNavigation() {
        lock.lock()
        detectedVideos.removeAll()
        detectedURLs.removeAll()
        lock.unlock()
    }

    private func loadDetectorJS() -> String {
        if let url = Bundle.main.url(forResource: "detector", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            return js
        }
        return fallbackDetectorJS()
    }

    private func fallbackDetectorJS() -> String {
        return """
        (function(){
            var exts=/\\.(m3u8|mp4|webm|mkv|avi|mov|ts|mpd)(\\?|$)/i;
            function check(u){if(u&&exts.test(u)){try{window.webkit.messageHandlers.videoDetected.postMessage(JSON.stringify({url:u,timestamp:Date.now()}))}catch(e){}}};
            document.querySelectorAll('video,source').forEach(function(e){check(e.src);check(e.currentSrc)});
            new MutationObserver(function(m){m.forEach(function(r){r.addedNodes.forEach(function(n){if(n.src)check(n.src)})})}).observe(document.documentElement,{childList:true,subtree:true});
            var xo=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){check(u);return xo.apply(this,arguments)};
            var fo=window.fetch;window.fetch=function(i){check(typeof i==='string'?i:i&&i.url);return fo.apply(this,arguments)};
        })();
        """
    }

    func probeVideoMetadata(url: String, completion: @escaping (String?, String?) -> Void) {
        guard let videoURL = URL(string: url) else {
            completion(nil, nil)
            return
        }

        var request = URLRequest(url: videoURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let httpResponse = response as? HTTPURLResponse
            let contentLength = httpResponse?.value(forHTTPHeaderField: "Content-Length")
            var sizeString: String?
            if let length = contentLength, let bytes = Int64(length) {
                sizeString = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
            let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
            DispatchQueue.main.async {
                completion(sizeString, contentType)
            }
        }.resume()
    }
}
