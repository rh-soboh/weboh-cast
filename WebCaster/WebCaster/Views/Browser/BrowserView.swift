import SwiftUI

struct BrowserView: View {
    @StateObject private var browserVM = BrowserViewModel()
    @StateObject private var videoDetectorVM = VideoDetectorViewModel()
    @ObservedObject var playerVM: PlayerViewModel
    @ObservedObject var castingVM: CastingViewModel

    @State private var showTabs = false
    @State private var showVideoList = false
    @State private var showPlayer = false
    @State private var showCastPicker = false
    @State private var selectedVideoForAction: DetectedVideo?
    @State private var showBookmarkAdded = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                AddressBar(browserVM: browserVM)
                ProgressBar(progress: browserVM.progress)

                WebView(browserVM: browserVM, videoDetectorVM: videoDetectorVM)
                    .ignoresSafeArea(edges: .bottom)

                if castingVM.isCasting, let device = castingVM.connectedDevice {
                    nowCastingBar(device: device)
                }

                browserToolbar
            }

            if videoDetectorVM.hasVideos {
                castFloatingButton
            }
        }
        .background(Color.wcBackground)
        .sheet(isPresented: $showTabs) {
            TabsView(browserVM: browserVM)
        }
        .sheet(isPresented: $showVideoList) {
            VideoDetectionOverlay(
                videoDetectorVM: videoDetectorVM,
                playerVM: playerVM,
                castingVM: castingVM,
                onPlayLocally: { video in
                    showVideoList = false
                    playerVM.loadVideo(video)
                    showPlayer = true
                },
                onCast: { video in
                    showVideoList = false
                    selectedVideoForAction = video
                    showCastPicker = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(playerVM: playerVM)
        }
        .sheet(isPresented: $showCastPicker) {
            DeviceDiscoveryView(
                castingVM: castingVM,
                onDeviceSelected: { device in
                    castingVM.connect(to: device)
                    if let video = selectedVideoForAction {
                        castingVM.castVideo(video)
                    }
                    showCastPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .overlay(alignment: .top) {
            if showBookmarkAdded {
                bookmarkToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showBookmarkAdded = false }
                        }
                    }
            }
            if let error = castingVM.error {
                castErrorBanner(error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func nowCastingBar(device: CastDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tv.fill")
                .font(.system(size: 14))
                .foregroundColor(.wcOrange)

            VStack(alignment: .leading, spacing: 1) {
                Text("Casting to \(device.name)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.wcText)
                    .lineLimit(1)
                Text(device.state == .paused ? "Paused" : "Playing")
                    .font(.system(size: 11))
                    .foregroundColor(.wcTextSecondary)
            }

            Spacer()

            if device.state == .paused {
                Button(action: { castingVM.resumeCasting() }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.wcOrange)
                }
            } else {
                Button(action: { castingVM.pauseCasting() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.wcOrange)
                }
            }

            Button(action: { castingVM.stopCasting() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.wcTextSecondary)
            }

            Button(action: { castingVM.disconnect() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.wcSurface)
    }

    private func castErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.wcText)
                .lineLimit(2)
            Spacer()
            Button(action: { castingVM.error = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.wcTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 12)
        .padding(.top, 60)
    }

    private var browserToolbar: some View {
        HStack {
            Spacer()

            Button(action: {
                browserVM.addBookmark()
                withAnimation { showBookmarkAdded = true }
            }) {
                VStack(spacing: 2) {
                    Image(systemName: browserVM.isBookmarked() ? "star.fill" : "star")
                        .font(.system(size: 18))
                    Text("Bookmark")
                        .font(.system(size: 9))
                }
                .foregroundColor(browserVM.isBookmarked() ? .wcOrange : .wcTextSecondary)
            }

            Spacer()

            Button(action: { showTabs = true }) {
                VStack(spacing: 2) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.wcTextSecondary, lineWidth: 1.5)
                            .frame(width: 20, height: 16)
                        Text("\(browserVM.tabs.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.wcTextSecondary)
                    }
                    Text("Tabs")
                        .font(.system(size: 9))
                }
                .foregroundColor(.wcTextSecondary)
            }

            Spacer()

            if videoDetectorVM.hasVideos {
                Button(action: { showVideoList = true }) {
                    VStack(spacing: 2) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 18))
                            Text("\(videoDetectorVM.detectedVideos.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.wcOrange)
                                .clipShape(Circle())
                                .offset(x: 6, y: -4)
                        }
                        Text("Videos")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.wcOrange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.wcBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var castFloatingButton: some View {
        Button(action: { showVideoList = true }) {
            Image(systemName: "tv.and.mediabox.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.wcOrange)
                .clipShape(Circle())
                .shadow(color: .wcOrange.opacity(0.4), radius: 8, y: 4)
                .scaleEffect(videoDetectorVM.isPulsing ? 1.1 : 1.0)
                .animation(
                    videoDetectorVM.isPulsing ?
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                        .default,
                    value: videoDetectorVM.isPulsing
                )
        }
        .padding(.trailing, 16)
        .padding(.bottom, 70)
    }

    private var bookmarkToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.wcOrange)
            Text("Bookmark added")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.wcText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.wcSurface)
        .cornerRadius(25)
        .shadow(radius: 10)
        .padding(.top, 60)
    }
}
