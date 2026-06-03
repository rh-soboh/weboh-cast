import Foundation

enum CastProtocol: String, Codable, CaseIterable {
    case airplay = "AirPlay"
    case dlna = "DLNA"
    case chromecast = "Chromecast"

    var iconName: String {
        switch self {
        case .airplay: return "airplayvideo"
        case .dlna: return "tv"
        case .chromecast: return "tv.and.mediabox"
        }
    }
}

enum CastDeviceState: String, Codable {
    case available
    case connecting
    case connected
    case playing
    case paused
    case error
}

struct CastDevice: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let host: String
    let port: Int
    let castProtocol: CastProtocol
    var state: CastDeviceState
    var lastConnected: Date?
    var modelName: String?
    var manufacturer: String?

    init(
        name: String,
        host: String,
        port: Int,
        castProtocol: CastProtocol,
        modelName: String? = nil,
        manufacturer: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.castProtocol = castProtocol
        self.state = .available
        self.lastConnected = nil
        self.modelName = modelName
        self.manufacturer = manufacturer
    }

    var displayName: String {
        if let model = modelName {
            return "\(name) (\(model))"
        }
        return name
    }

    static func == (lhs: CastDevice, rhs: CastDevice) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port && lhs.castProtocol == rhs.castProtocol
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(castProtocol)
    }
}
