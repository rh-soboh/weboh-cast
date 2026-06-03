import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showClearDataAlert = false
    @State private var showDataCleared = false
    @State private var isUpdatingBlocklist = false
    @State private var blocklistUpdateResult: String?

    var body: some View {
        NavigationStack {
            List {
                browsingSection
                adBlockSection
                playerSection
                privacySection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wcBackground)
            .navigationTitle("Settings")
            .alert("Clear Browsing Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    settings.clearBrowsingData()
                    PersistenceController.shared.clearHistory()
                    withAnimation { showDataCleared = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showDataCleared = false }
                    }
                }
            } message: {
                Text("This will clear your history, cookies, cache, and website data. This action cannot be undone.")
            }
            .overlay(alignment: .top) {
                if showDataCleared {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Browsing data cleared")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.wcSurface)
                    .cornerRadius(25)
                    .shadow(radius: 10)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var browsingSection: some View {
        Section {
            Picker("Search Engine", selection: $settings.searchEngine) {
                ForEach(SearchEngine.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }

            Picker("User Agent", selection: $settings.userAgent) {
                ForEach(UserAgentOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            if settings.userAgent == .custom {
                TextField("Custom User Agent", text: $settings.customUserAgent)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
        } header: {
            Label("Browsing", systemImage: "globe")
                .foregroundColor(.wcOrange)
        }
    }

    private var adBlockSection: some View {
        Section {
            Toggle(isOn: $settings.adBlockerEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.wcOrange)
                    Text("Enable Ad Blocker")
                }
            }
            .tint(.wcOrange)

            Toggle(isOn: $settings.blockWebRTC) {
                HStack(spacing: 10) {
                    Image(systemName: "network.slash")
                        .foregroundColor(.wcOrange)
                    Text("Block WebRTC Leaks")
                }
            }
            .tint(.wcOrange)

            Button(action: {
                isUpdatingBlocklist = true
                blocklistUpdateResult = nil
                AdBlockService.shared.updateBlocklistFromRemote { success in
                    isUpdatingBlocklist = false
                    blocklistUpdateResult = success ? "Blocklist updated successfully" : "Update failed — using cached list"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        blocklistUpdateResult = nil
                    }
                }
            }) {
                HStack(spacing: 10) {
                    if isUpdatingBlocklist {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.wcOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Blocklist")
                            .foregroundColor(.wcText)
                        if let result = blocklistUpdateResult {
                            Text(result)
                                .font(.system(size: 11))
                                .foregroundColor(result.contains("success") ? .green : .red)
                        } else {
                            Text("Fetch latest ad & tracker rules")
                                .font(.system(size: 11))
                                .foregroundColor(.wcTextSecondary)
                        }
                    }
                }
            }
            .disabled(isUpdatingBlocklist)
        } header: {
            Label("Privacy & Ad Blocking", systemImage: "shield")
                .foregroundColor(.wcOrange)
        } footer: {
            Text("Ad blocker removes ads, trackers, and popups. WebRTC blocking prevents IP address leaks. Blocklist auto-updates every 24 hours.")
        }
    }

    private var playerSection: some View {
        Section {
            Toggle(isOn: $settings.autoplayVideos) {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.wcOrange)
                    Text("Auto-play Videos")
                }
            }
            .tint(.wcOrange)

            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundColor(.wcOrange)
                Text("Default Speed")
                Spacer()
                Picker("", selection: $settings.defaultPlaybackSpeed) {
                    Text("0.5x").tag(Float(0.5))
                    Text("0.75x").tag(Float(0.75))
                    Text("1.0x").tag(Float(1.0))
                    Text("1.25x").tag(Float(1.25))
                    Text("1.5x").tag(Float(1.5))
                    Text("2.0x").tag(Float(2.0))
                }
                .labelsHidden()
            }
        } header: {
            Label("Player", systemImage: "play.rectangle")
                .foregroundColor(.wcOrange)
        }
    }

    private var privacySection: some View {
        Section {
            Button(action: { showClearDataAlert = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Clear Browsing Data")
                        .foregroundColor(.red)
                }
            }
        } header: {
            Label("Data", systemImage: "externaldrive")
                .foregroundColor(.wcOrange)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.wcTextSecondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.wcTextSecondary)
            }

            HStack {
                Image(systemName: "tv.and.mediabox.fill")
                    .foregroundColor(.wcOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WebCaster")
                        .font(.system(size: 15, weight: .medium))
                    Text("Cast web videos to your TV")
                        .font(.system(size: 12))
                        .foregroundColor(.wcTextSecondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("About", systemImage: "info.circle")
                .foregroundColor(.wcOrange)
        }
    }
}
