import SwiftUI
import AVKit

struct DeviceDiscoveryView: View {
    @ObservedObject var castingVM: CastingViewModel
    var onDeviceSelected: (CastDevice) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if castingVM.isScanning {
                    scanningHeader
                }

                if castingVM.devices.isEmpty && !castingVM.isScanning {
                    emptyState
                } else {
                    deviceList
                }

                airplaySection
            }
            .background(Color.wcBackground)
            .navigationTitle("Cast To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { castingVM.scanForDevices() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.wcOrange)
                    }
                    .disabled(castingVM.isScanning)
                }
            }
            .onAppear {
                castingVM.scanForDevices()
            }
        }
    }

    private var scanningHeader: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.wcOrange)
            Text("Scanning for devices...")
                .font(.system(size: 14))
                .foregroundColor(.wcTextSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.wcSurface)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.slash")
                .font(.system(size: 48))
                .foregroundColor(.wcTextSecondary)
            Text("No devices found")
                .font(.headline)
                .foregroundColor(.wcText)
            Text("Make sure your TV or streaming device\nis on the same Wi-Fi network")
                .font(.subheadline)
                .foregroundColor(.wcTextSecondary)
                .multilineTextAlignment(.center)
            Button(action: { castingVM.scanForDevices() }) {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.wcOrange)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var deviceList: some View {
        List {
            ForEach(castingVM.devicesByProtocol, id: \.protocol) { group in
                Section {
                    ForEach(group.devices) { device in
                        DeviceRow(
                            device: device,
                            isConnected: castingVM.connectedDevice?.id == device.id
                        )
                        .onTapGesture {
                            onDeviceSelected(device)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: group.protocol.iconName)
                            .font(.system(size: 12))
                        Text(group.protocol.rawValue)
                    }
                    .foregroundColor(.wcOrange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var airplaySection: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "airplayvideo")
                    .font(.system(size: 16))
                    .foregroundColor(.wcOrange)
                Text("AirPlay")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.wcText)
                Spacer()
                AVRoutePickerViewRepresentable()
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Text("Tap the AirPlay icon to stream to Apple TV or AirPlay-compatible devices")
                .font(.system(size: 12))
                .foregroundColor(.wcTextSecondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Color.wcSurface)
    }
}

struct DeviceRow: View {
    let device: CastDevice
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.castProtocol.iconName)
                .font(.system(size: 24))
                .foregroundColor(isConnected ? .wcOrange : .wcTextSecondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.wcText)

                HStack(spacing: 6) {
                    if let model = device.modelName {
                        Text(model)
                            .font(.system(size: 12))
                            .foregroundColor(.wcTextSecondary)
                    }
                    if let mfg = device.manufacturer {
                        Text("• \(mfg)")
                            .font(.system(size: 12))
                            .foregroundColor(.wcTextSecondary)
                    }
                }
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.wcOrange)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.wcTextSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
