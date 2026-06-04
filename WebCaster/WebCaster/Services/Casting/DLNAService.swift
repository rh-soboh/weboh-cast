import Foundation
import Network

final class DLNAService: NSObject {
    static let shared = DLNAService()

    private var ssdpSocket: NWConnection?
    private var listener: NWListener?
    private var discoveredDevices: [CastDevice] = []
    private var completionHandler: (([CastDevice]) -> Void)?
    private let ssdpAddress = "239.255.255.250"
    private let ssdpPort: UInt16 = 1900
    private var searchTimer: Timer?

    private override init() {
        super.init()
    }

    func discoverDevices(timeout: TimeInterval = 5, completion: @escaping ([CastDevice]) -> Void) {
        discoveredDevices.removeAll()
        completionHandler = completion

        sendSSDPSearch()

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.stopDiscovery()
            completion(self?.discoveredDevices ?? [])
        }
    }

    func stopDiscovery() {
        ssdpSocket?.cancel()
        ssdpSocket = nil
        searchTimer?.invalidate()
        searchTimer = nil
    }

    private func sendSSDPSearch() {
        let searchMessage = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(ssdpAddress):\(ssdpPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
        USER-AGENT: WebCaster/1.0 UPnP/1.1\r
        \r

        """

        let host = NWEndpoint.Host(ssdpAddress)
        let port = NWEndpoint.Port(integerLiteral: ssdpPort)
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let connection = NWConnection(host: host, port: port, using: params)
        ssdpSocket = connection

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                let data = searchMessage.data(using: .utf8)!
                connection.send(content: data, completion: .contentProcessed({ _ in }))
                self?.receiveResponses(on: connection)
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func receiveResponses(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let data = data, error == nil else { return }

            if let response = String(data: data, encoding: .utf8) {
                self?.parseSSDPResponse(response)
            }

            self?.receiveResponses(on: connection)
        }
    }

    private func parseSSDPResponse(_ response: String) {
        var headers: [String: String] = [:]
        response.components(separatedBy: "\r\n").forEach { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).trimmingCharacters(in: .whitespaces).uppercased()] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        guard let location = headers["LOCATION"],
              let url = URL(string: location),
              let host = url.host else { return }

        fetchDeviceDescription(from: location, host: host, port: url.port ?? 80)
    }

    private func fetchDeviceDescription(from urlString: String, host: String, port: Int) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            let parser = DLNADeviceParser(data: data, host: host, port: port)
            if let device = parser.parse() {
                DispatchQueue.main.async {
                    if !(self?.discoveredDevices.contains(device) ?? true) {
                        self?.discoveredDevices.append(device)
                    }
                }
            }
        }.resume()
    }

    // MARK: - Casting

    private func avTransportURL(for device: CastDevice) -> String {
        if let ctrl = device.controlURL {
            if ctrl.hasPrefix("http") { return ctrl }
            let path = ctrl.hasPrefix("/") ? ctrl : "/\(ctrl)"
            return "http://\(device.host):\(device.port)\(path)"
        }
        return "http://\(device.host):\(device.port)/AVTransport/Control"
    }

    func cast(video: DetectedVideo, to device: CastDevice, completion: @escaping (Bool, String?) -> Void) {
        let controlEndpoint = avTransportURL(for: device)
        let setURIAction = buildSetAVTransportURIAction(videoURL: video.url, title: video.title)

        sendSOAPAction(
            url: controlEndpoint,
            action: "SetAVTransportURI",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: setURIAction
        ) { [weak self] success, error in
            if success {
                self?.play(device: device, completion: completion)
            } else {
                completion(false, error)
            }
        }
    }

    func play(device: CastDevice, completion: @escaping (Bool, String?) -> Void) {
        let url = avTransportURL(for: device)
        let body = """
        <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
            <Speed>1</Speed>
        </u:Play>
        """
        sendSOAPAction(url: url, action: "Play", serviceType: "urn:schemas-upnp-org:service:AVTransport:1", body: body, completion: completion)
    }

    func pause(device: CastDevice, completion: @escaping (Bool, String?) -> Void) {
        let url = avTransportURL(for: device)
        let body = """
        <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
        </u:Pause>
        """
        sendSOAPAction(url: url, action: "Pause", serviceType: "urn:schemas-upnp-org:service:AVTransport:1", body: body, completion: completion)
    }

    func stop(device: CastDevice, completion: @escaping (Bool, String?) -> Void) {
        let url = avTransportURL(for: device)
        let body = """
        <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
        </u:Stop>
        """
        sendSOAPAction(url: url, action: "Stop", serviceType: "urn:schemas-upnp-org:service:AVTransport:1", body: body, completion: completion)
    }

    func seek(device: CastDevice, to position: String, completion: @escaping (Bool, String?) -> Void) {
        let url = avTransportURL(for: device)
        let body = """
        <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
            <Unit>REL_TIME</Unit>
            <Target>\(position)</Target>
        </u:Seek>
        """
        sendSOAPAction(url: url, action: "Seek", serviceType: "urn:schemas-upnp-org:service:AVTransport:1", body: body, completion: completion)
    }

    private func buildSetAVTransportURIAction(videoURL: String, title: String) -> String {
        let escapedURL = videoURL
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let didl = "&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;&lt;item id=&quot;0&quot; parentID=&quot;-1&quot; restricted=&quot;1&quot;&gt;&lt;dc:title&gt;\(escapedTitle)&lt;/dc:title&gt;&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;&lt;res protocolInfo=&quot;http-get:*:video/mp4:*&quot;&gt;\(escapedURL)&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;"
        return """
        <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
            <CurrentURI>\(escapedURL)</CurrentURI>
            <CurrentURIMetaData>\(didl)</CurrentURIMetaData>
        </u:SetAVTransportURI>
        """
    }

    private func sendSOAPAction(url: String, action: String, serviceType: String, body: String, completion: @escaping (Bool, String?) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(false, "Invalid URL")
            return
        }

        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                \(body)
            </s:Body>
        </s:Envelope>
        """

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = envelope.data(using: .utf8)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            let httpResponse = response as? HTTPURLResponse
            let success = httpResponse?.statusCode == 200
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }.resume()
    }
}

// MARK: - Device Description XML Parser

private class DLNADeviceParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let host: String
    private let port: Int
    private var currentElement = ""
    private var friendlyName = ""
    private var modelName = ""
    private var manufacturer = ""
    private var controlURL = ""
    private var currentServiceType = ""
    private var currentControlURL = ""
    private var inService = false

    init(data: Data, host: String, port: Int) {
        self.data = data
        self.host = host
        self.port = port
    }

    func parse() -> CastDevice? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        guard !friendlyName.isEmpty else { return nil }
        return CastDevice(
            name: friendlyName,
            host: host,
            port: port,
            castProtocol: .dlna,
            modelName: modelName.isEmpty ? nil : modelName,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            controlURL: controlURL.isEmpty ? nil : controlURL
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "service" {
            inService = true
            currentServiceType = ""
            currentControlURL = ""
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "service" && inService {
            if currentServiceType.contains("AVTransport") && !currentControlURL.isEmpty {
                controlURL = currentControlURL
            }
            inService = false
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch currentElement {
        case "friendlyName": friendlyName += trimmed
        case "modelName": modelName += trimmed
        case "manufacturer": manufacturer += trimmed
        case "serviceType" where inService: currentServiceType += trimmed
        case "controlURL" where inService: currentControlURL += trimmed
        default: break
        }
    }
}
