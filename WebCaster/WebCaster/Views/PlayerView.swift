import SwiftUI
import AVKit

struct PlayerView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var showSpeedPicker = false
    @State private var showSubtitleLoader = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playerVM.player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        resetControlsTimer()
                    }
            }

            if playerVM.isBuffering {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            if showControls {
                controlsOverlay
            }

            // Subtitle overlay
            if let subtitle = playerVM.currentSubtitle {
                VStack {
                    Spacer()
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, showControls ? 140 : 40)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if let error = playerVM.error {
                errorOverlay(error)
            }
        }
        .statusBarHidden(true)
        .onAppear { resetControlsTimer() }
        .onDisappear { playerVM.cleanup() }
        .sheet(isPresented: $showSpeedPicker) {
            speedPickerSheet
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSubtitleLoader) {
            SubtitleLoaderSheet(playerVM: playerVM)
                .presentationDetents([.height(250)])
        }
    }

    private var controlsOverlay: some View {
        VStack {
            topBar
            Spacer()
            centerControls
            Spacer()
            bottomControls
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .transition(.opacity)
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            if let title = playerVM.currentVideo?.title {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Playback Speed", systemImage: "gauge.with.dots.needle.67percent") {
                    showSpeedPicker = true
                }
                Button("Picture in Picture", systemImage: "pip") {
                    playerVM.pipEnabled.toggle()
                }
                Divider()
                Button(
                    playerVM.subtitlesEnabled ? "Hide Subtitles" : "Show Subtitles",
                    systemImage: playerVM.subtitlesEnabled ? "captions.bubble.fill" : "captions.bubble"
                ) {
                    playerVM.toggleSubtitles()
                }
                Button("Load Subtitles (.srt/.vtt)", systemImage: "doc.text") {
                    showSubtitleLoader = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var centerControls: some View {
        HStack(spacing: 48) {
            Button(action: { playerVM.skipBackward() }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            Button(action: { playerVM.togglePlayPause() }) {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            Button(action: { playerVM.skipForward() }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 8) {
            CustomSlider(
                value: Binding(
                    get: { playerVM.currentTime },
                    set: { playerVM.seek(to: $0) }
                ),
                range: 0...max(playerVM.duration, 1),
                isDragging: $isDragging
            )
            .frame(height: 20)
            .padding(.horizontal, 16)

            HStack {
                Text(playerVM.formattedCurrentTime)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                if playerVM.playbackSpeed != 1.0 {
                    Text("\(String(format: "%.1f", playerVM.playbackSpeed))x")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.wcOrange)
                        .onTapGesture { showSpeedPicker = true }
                }

                Spacer()

                Text(playerVM.formattedDuration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)

            HStack(spacing: 24) {
                if playerVM.queue.count > 1 {
                    Button(action: { playerVM.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .disabled(playerVM.currentQueueIndex == 0)

                    Button(action: { playerVM.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .disabled(playerVM.currentQueueIndex >= playerVM.queue.count - 1)
                }

                Spacer()

                AVRoutePickerViewRepresentable()
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.wcOrange)
            Text("Playback Error")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Dismiss") { dismiss() }
                .foregroundColor(.wcOrange)
                .padding(.top, 8)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var speedPickerSheet: some View {
        NavigationStack {
            List(playerVM.speedOptions, id: \.self) { speed in
                Button(action: {
                    playerVM.setSpeed(speed)
                    showSpeedPicker = false
                }) {
                    HStack {
                        Text(String(format: "%.1fx", speed))
                            .foregroundColor(.wcText)
                        Spacer()
                        if playerVM.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                                .foregroundColor(.wcOrange)
                        }
                    }
                }
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            if playerVM.isPlaying && !isDragging {
                withAnimation { showControls = false }
            }
        }
    }
}

// MARK: - AVPlayer UIView Wrapper

struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var player: AVPlayer? {
            get { (layer as? AVPlayerLayer)?.player }
            set {
                (layer as? AVPlayerLayer)?.player = newValue
                (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
            }
        }
    }
}

// MARK: - Custom Slider

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = range.upperBound > range.lowerBound
                ? (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.wcOrange)
                    .frame(width: max(width * progress, 0), height: 4)

                Circle()
                    .fill(Color.wcOrange)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .offset(x: max(width * progress - 6, 0))
                    .shadow(radius: 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let fraction = max(0, min(1, gesture.location.x / width))
                        value = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

// MARK: - Subtitle Loader Sheet

struct SubtitleLoaderSheet: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var urlText = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subtitle URL (.srt or .vtt)", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } footer: {
                    Text("Enter a direct link to an .srt or .vtt subtitle file")
                }

                Section {
                    Button(action: {
                        let finalURL = urlText.hasPrefix("http") ? urlText : "https://\(urlText)"
                        playerVM.loadSubtitles(from: finalURL)
                        dismiss()
                    }) {
                        Label("Load Subtitles", systemImage: "captions.bubble")
                            .foregroundColor(.wcOrange)
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !playerVM.subtitleCues.isEmpty {
                        Button(role: .destructive) {
                            playerVM.subtitleCues = []
                            playerVM.currentSubtitle = nil
                            dismiss()
                        } label: {
                            Label("Remove Current Subtitles", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
            }
            .onAppear {
                urlText = playerVM.subtitleURL
            }
        }
    }
}

// MARK: - AirPlay Route Picker

struct AVRoutePickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(Color.wcOrange)
        picker.activeTintColor = UIColor(Color.wcOrange)
        picker.prioritizesVideoDevices = true
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
