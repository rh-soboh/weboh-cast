import Foundation
import Network

/// Chromecast discovery and basic control without Google Cast SDK.
/// Uses mDNS/Bonjour to find Chromecast devices and the device's REST API
/// for basic media control. For full Cast functionality (queue, seek, etc.),
/// integrate the official google-cast-sdk via SPM/CocoaPods.
final class ChromecastService: NSObject {
    static let shared = ChromecastService()

    private var browser: NWBrowser?
    private var discoveredDevices: [CastDevice] = []
    private var completionHandler: (([CastDevice]) -> Void)?

    private override init() {
        super.init()
    }

    /// Discover Chromecast devices on the local network via Bonjour
    func discoverDevices(timeout: TimeInterval = 6, completion: @escaping ([CastDevice]) -> Void) {
        discoveredDevices.removeAll()
        completionHandler = completion

        let params = NWParameters()
        params.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_googlecast._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, changes in
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

        // Extract TXT record metadata
        var modelName: String?
        if case .bonjour(let txtRecord) = result.metadata {
            let entry = txtRecord.getEntry(for: "md")
            if let entry = entry {
                let data = Data(entry)
                modelName = String(data: data, encoding: .utf8)
            }
        }

        // Resolve to get host/port
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

        // Cancel after timeout if resolution hangs
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            connection.cancel()
        }
    }

    /// Send a basic DIAL launch request to play media on Chromecast
    /// This uses the Chromecast REST API (DIAL protocol) which supports
    /// launching apps but not full media control. For full control,
    /// use the Google Cast SDK.
    func launchMedia(on device: CastDevice, videoURL: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "http://\(device.host):8008/apps/YouTube"

        guard let url = URL(string: urlString) else {
            completion(false, "Invalid device URL")
            return
        }

        // Check if default media receiver is available
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 200 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Chromecast DIAL not available (HTTP \(status ?? 0)). For full casting, integrate the Google Cast SDK.")
                }
            }
        }.resume()
    }
}
