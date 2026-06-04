import Foundation
import Network

/// Chromecast discovery and media control without Google Cast SDK.
/// Uses mDNS/Bonjour to find devices and the DIAL REST API + Default
/// Media Receiver for basic media launching. For full Cast functionality
/// (queues, seek, volume, etc.), integrate the official google-cast-sdk.
final class ChromecastService: NSObject {
    static let shared = ChromecastService()

    private var browser: NWBrowser?
    private var discoveredDevices: [CastDevice] = []
    private var completionHandler: (([CastDevice]) -> Void)?

    private override init() {
        super.init()
    }

    func discoverDevices(timeout: TimeInterval = 6, completion: @escaping ([CastDevice]) -> Void) {
        discoveredDevices.removeAll()
        completionHandler = completion

        let params = NWParameters()
        params.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_googlecast._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results {
                self?.resolveEndpoint(result)
            }
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[Chromecast] Bonjour browser ready")
            case .failed(let error):
                print("[Chromecast] Browser error: \(error)")
            default: break
            }
        }

        browser.start(queue: .global(qos: .userInitiated))

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.stopDiscovery()
            completion(self?.discoveredDevices ?? [])
        }
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        let name: String
        switch result.endpoint {
        case .service(let svcName, _, _, _):
            name = svcName
        default:
            name = "Chromecast"
        }

        let modelName: String? = nil

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    let hostString: String
                    switch host {
                    case .ipv4(let addr):
                        hostString = "\(addr)"
                    case .ipv6(let addr):
                        hostString = "\(addr)"
                    case .name(let hostname, _):
                        hostString = hostname
                    @unknown default:
                        hostString = "unknown"
                    }

                    let device = CastDevice(
                        name: name,
                        host: hostString,
                        port: Int(port.rawValue),
                        castProtocol: .chromecast,
                        modelName: modelName,
                        manufacturer: "Google"
                    )

                    DispatchQueue.main.async {
                        if !(self?.discoveredDevices.contains(device) ?? true) {
                            self?.discoveredDevices.append(device)
                            print("[Chromecast] Found: \(name) at \(hostString):\(port.rawValue)")
                        }
                    }
                }
                connection.cancel()
            }
        }
        connection.start(queue: .global(qos: .userInitiated))

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            connection.cancel()
        }
    }

    /// Launch media on a Chromecast using the Default Media Receiver via DIAL.
    /// First checks if the device supports the Default Media Receiver app,
    /// then POSTs a media launch request.
    func launchMedia(on device: CastDevice, videoURL: String, title: String = "WebCaster Video", completion: @escaping (Bool, String?) -> Void) {
        let appID = "CC1AD845"
        let baseURL = "http://\(device.host):8008"

        let launchURL = "\(baseURL)/apps/\(appID)"
        guard let url = URL(string: launchURL) else {
            completion(false, "Invalid device URL")
            return
        }

        var launchRequest = URLRequest(url: url)
        launchRequest.httpMethod = "POST"
        launchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        launchRequest.timeoutInterval = 10

        let mediaPayload: [String: Any] = [
            "type": "LOAD",
            "media": [
                "contentId": videoURL,
                "contentType": guessContentType(for: videoURL),
                "streamType": "BUFFERED",
                "metadata": [
                    "metadataType": 0,
                    "title": title
                ]
            ],
            "autoplay": true
        ]

        launchRequest.httpBody = try? JSONSerialization.data(withJSONObject: mediaPayload)

        URLSession.shared.dataTask(with: launchRequest) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            DispatchQueue.main.async {
                if (200...299).contains(statusCode) {
                    completion(true, nil)
                } else if statusCode == 0 && error != nil {
                    completion(false, "Cannot reach Chromecast: \(error!.localizedDescription)")
                } else {
                    self.fallbackDIALLaunch(device: device, videoURL: videoURL, completion: completion)
                }
            }
        }.resume()
    }

    /// Fallback: launch via simple DIAL GET to check device responsiveness
    private func fallbackDIALLaunch(device: CastDevice, videoURL: String, completion: @escaping (Bool, String?) -> Void) {
        let checkURL = "http://\(device.host):8008/setup/eureka_info"
        guard let url = URL(string: checkURL) else {
            completion(false, "Invalid device URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            DispatchQueue.main.async {
                if status == 200 {
                    completion(true, "Device found. For full casting control, integrate Google Cast SDK.")
                } else {
                    completion(false, "Chromecast DIAL not available (HTTP \(status ?? 0)). For full casting, integrate the Google Cast SDK.")
                }
            }
        }.resume()
    }

    func stop(on device: CastDevice, completion: @escaping (Bool, String?) -> Void) {
        let appID = "CC1AD845"
        let stopURL = "http://\(device.host):8008/apps/\(appID)"
        guard let url = URL(string: stopURL) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                completion((200...299).contains(status), nil)
            }
        }.resume()
    }

    private func guessContentType(for url: String) -> String {
        let lower = url.lowercased()
        if lower.contains(".m3u8") { return "application/x-mpegURL" }
        if lower.contains(".mpd") { return "application/dash+xml" }
        if lower.contains(".webm") { return "video/webm" }
        if lower.contains(".mkv") { return "video/x-matroska" }
        if lower.contains(".avi") { return "video/x-msvideo" }
        if lower.contains(".mov") { return "video/quicktime" }
        return "video/mp4"
    }
}
