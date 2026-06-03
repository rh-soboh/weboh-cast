import Foundation
import Combine

final class CastingViewModel: ObservableObject {
    @Published var devices: [CastDevice] = []
    @Published var isScanning = false
    @Published var connectedDevice: CastDevice?
    @Published var isCasting = false
    @Published var error: String?

    private let castingManager = CastingManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        castingManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)

        castingManager.$isDiscovering
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        castingManager.$connectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedDevice)

        castingManager.$isCasting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCasting)

        castingManager.$castError
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }

    func scanForDevices() {
        castingManager.startDiscovery()
    }

    func stopScanning() {
        castingManager.stopDiscovery()
    }

    func connect(to device: CastDevice) {
        castingManager.connect(to: device)
    }

    func disconnect() {
        castingManager.disconnect()
    }

    func castVideo(_ video: DetectedVideo) {
        castingManager.cast(video: video)
    }

    func pauseCasting() {
        castingManager.pauseCasting()
    }

    func resumeCasting() {
        castingManager.resumeCasting()
    }

    func stopCasting() {
        castingManager.stopCasting()
    }

    var devicesByProtocol: [(protocol: CastProtocol, devices: [CastDevice])] {
        let grouped = Dictionary(grouping: devices, by: \.castProtocol)
        return CastProtocol.allCases.compactMap { proto in
            guard let devices = grouped[proto], !devices.isEmpty else { return nil }
            return (protocol: proto, devices: devices)
        }
    }

    var isConnected: Bool {
        connectedDevice != nil
    }
}
