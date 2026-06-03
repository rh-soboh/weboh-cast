import Foundation
import Combine

final class CastingManager: ObservableObject {
    static let shared = CastingManager()

    @Published var discoveredDevices: [CastDevice] = []
    @Published var connectedDevice: CastDevice?
    @Published var isDiscovering = false
    @Published var isCasting = false
    @Published var castError: String?

    private let dlnaService = DLNAService.shared
    private let chromecastService = ChromecastService.shared
    private let persistence = PersistenceController.shared
    private let discoveryGroup = DispatchGroup()

    private init() {
        loadRecentDevices()
    }

    func startDiscovery() {
        guard !isDiscovering else { return }
        isDiscovering = true
        castError = nil
        discoveredDevices.removeAll()

        var allDevices: [CastDevice] = []
        let lock = NSLock()

        discoveryGroup.enter()
        dlnaService.discoverDevices(timeout: 8) { devices in
            lock.lock()
            allDevices.append(contentsOf: devices)
            lock.unlock()
            self.discoveryGroup.leave()
        }

        discoveryGroup.enter()
        chromecastService.discoverDevices(timeout: 6) { devices in
            lock.lock()
            allDevices.append(contentsOf: devices)
            lock.unlock()
            self.discoveryGroup.leave()
        }

        discoveryGroup.notify(queue: .main) { [weak self] in
            self?.discoveredDevices = allDevices
            self?.isDiscovering = false
            self?.mergeWithRecentDevices()
        }
    }

    func stopDiscovery() {
        dlnaService.stopDiscovery()
        chromecastService.stopDiscovery()
        isDiscovering = false
    }

    func connect(to device: CastDevice) {
        var updatedDevice = device
        updatedDevice.state = .connected
        updatedDevice.lastConnected = Date()
        connectedDevice = updatedDevice
        persistence.saveRecentDevice(updatedDevice)

        if let index = discoveredDevices.firstIndex(where: { $0 == device }) {
            discoveredDevices[index] = updatedDevice
        }
    }

    func disconnect() {
        if let device = connectedDevice {
            dlnaService.stop(device: device) { _, _ in }
        }
        connectedDevice?.state = .available
        connectedDevice = nil
        isCasting = false
    }

    func cast(video: DetectedVideo) {
        guard let device = connectedDevice else {
            castError = "No device connected"
            return
        }

        isCasting = true
        castError = nil

        switch device.castProtocol {
        case .dlna:
            dlnaService.cast(video: video, to: device) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.connectedDevice?.state = .playing
                    } else {
                        self?.castError = error ?? "Failed to cast"
                        self?.isCasting = false
                    }
                }
            }
        case .airplay:
            break
        case .chromecast:
            chromecastService.launchMedia(on: device, videoURL: video.url) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.connectedDevice?.state = .playing
                    } else {
                        self?.castError = error ?? "Chromecast casting failed. For full support, integrate google-cast-sdk."
                        self?.isCasting = false
                    }
                }
            }
        }
    }

    func pauseCasting() {
        guard let device = connectedDevice, device.castProtocol == .dlna else { return }
        dlnaService.pause(device: device) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.connectedDevice?.state = .paused
                }
            }
        }
    }

    func resumeCasting() {
        guard let device = connectedDevice, device.castProtocol == .dlna else { return }
        dlnaService.play(device: device) { [weak self] success, _ in
            if success {
                DispatchQueue.main.async {
                    self?.connectedDevice?.state = .playing
                }
            }
        }
    }

    func stopCasting() {
        guard let device = connectedDevice, device.castProtocol == .dlna else { return }
        dlnaService.stop(device: device) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.connectedDevice?.state = .connected
                self?.isCasting = false
            }
        }
    }

    var devicesByProtocol: [CastProtocol: [CastDevice]] {
        Dictionary(grouping: discoveredDevices, by: \.castProtocol)
    }

    private func loadRecentDevices() {
        let recent = persistence.loadRecentDevices()
        discoveredDevices = recent
    }

    private func mergeWithRecentDevices() {
        let recent = persistence.loadRecentDevices()
        for device in recent {
            if !discoveredDevices.contains(device) {
                var stale = device
                stale.state = .available
                discoveredDevices.append(stale)
            }
        }
    }
}
