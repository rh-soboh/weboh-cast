import Foundation
import AVFoundation
import Combine

final class PlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var isBuffering = false
    @Published var error: String?
    @Published var currentVideo: DetectedVideo?
    @Published var pipEnabled = false

    @Published var queue: [PlaylistItem] = []
    @Published var currentQueueIndex: Int = 0

    @Published var subtitleCues: [SubtitleCue] = []
    @Published var currentSubtitle: String?
    @Published var subtitlesEnabled = true
    @Published var subtitleURL: String = ""

    var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let persistence = PersistenceController.shared

    let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    init() {
        queue = persistence.loadQueue()
        playbackSpeed = AppSettings.shared.defaultPlaybackSpeed
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Player] Audio session error: \(error)")
        }
    }

    func loadVideo(_ video: DetectedVideo) {
        cleanup()
        currentVideo = video
        error = nil
        isBuffering = true

        guard let url = URL(string: video.url) else {
            error = "Invalid video URL"
            return
        }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        player = AVPlayer(playerItem: item)
        player?.rate = playbackSpeed

        if let savedPosition = persistence.getPosition(for: video.url), savedPosition > 5 {
            let time = CMTime(seconds: savedPosition, preferredTimescale: 600)
            player?.seek(to: time)
        }

        observePlayer(item: item)

        if AppSettings.shared.autoplayVideos {
            play()
        }
    }

    func play() {
        player?.play()
        player?.rate = playbackSpeed
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
        savePosition()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func skipForward(_ seconds: Double = 10) {
        let target = min(currentTime + seconds, duration)
        seek(to: target)
    }

    func skipBackward(_ seconds: Double = 10) {
        let target = max(currentTime - seconds, 0)
        seek(to: target)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    func playNext() {
        guard currentQueueIndex + 1 < queue.count else { return }
        currentQueueIndex += 1
        loadVideo(queue[currentQueueIndex].video)
        play()
    }

    func playPrevious() {
        guard currentQueueIndex > 0 else {
            seek(to: 0)
            return
        }
        currentQueueIndex -= 1
        loadVideo(queue[currentQueueIndex].video)
        play()
    }

    func addToQueue(_ video: DetectedVideo) {
        let item = PlaylistItem(video: video, order: queue.count)
        queue.append(item)
        persistence.saveQueue(queue)
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
        for i in queue.indices {
            queue[i].order = i
        }
        persistence.saveQueue(queue)
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        for i in queue.indices {
            queue[i].order = i
        }
        persistence.saveQueue(queue)
    }

    func clearQueue() {
        queue.removeAll()
        currentQueueIndex = 0
        persistence.saveQueue(queue)
    }

    func cleanup() {
        savePosition()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isBuffering = false
    }

    var formattedCurrentTime: String { formatTime(currentTime) }
    var formattedDuration: String { formatTime(duration) }
    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    func loadSubtitles(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        subtitleURL = urlString
        SubtitleParser.parse(from: url) { [weak self] cues in
            self?.subtitleCues = cues
        }
    }

    func loadSubtitles(content: String, format: SubtitleParser.SubtitleFormat) {
        subtitleCues = SubtitleParser.parse(content: content, format: format)
    }

    func toggleSubtitles() {
        subtitlesEnabled.toggle()
        if !subtitlesEnabled { currentSubtitle = nil }
    }

    private func updateSubtitle(at time: Double) {
        guard subtitlesEnabled, !subtitleCues.isEmpty else {
            if currentSubtitle != nil { currentSubtitle = nil }
            return
        }
        let activeCue = subtitleCues.first { cue in
            time >= cue.startTime && time <= cue.endTime
        }
        let newText = activeCue?.text
        if newText != currentSubtitle {
            currentSubtitle = newText
        }
    }

    private func observePlayer(item: AVPlayerItem) {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
            self?.isBuffering = false
            self?.updateSubtitle(at: time.seconds)
        }

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self?.isBuffering = false
                case .failed:
                    self?.error = item.error?.localizedDescription ?? "Playback failed"
                    self?.isBuffering = false
                default: break
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.savePosition()
                if let self = self, self.currentQueueIndex + 1 < self.queue.count {
                    self.playNext()
                }
            }
            .store(in: &cancellables)
    }

    private func savePosition() {
        guard let video = currentVideo, currentTime > 5 else { return }
        persistence.savePosition(currentTime, for: video.url)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    deinit {
        cleanup()
    }
}
