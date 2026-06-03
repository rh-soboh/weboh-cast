import Foundation
import Combine

final class VideoDetectorViewModel: ObservableObject, VideoDetectionDelegate {
    @Published var detectedVideos: [DetectedVideo] = []
    @Published var hasVideos: Bool = false
    @Published var showVideoList: Bool = false
    @Published var isPulsing: Bool = false

    private let detectionService = VideoDetectionService.shared
    private let persistence = PersistenceController.shared

    init() {
        detectionService.delegate = self
    }

    func didDetectVideo(_ video: DetectedVideo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.detectedVideos.contains(where: { $0.url == video.url }) {
                self.detectedVideos.append(video)
                self.hasVideos = true
                self.isPulsing = true

                self.detectionService.probeVideoMetadata(url: video.url) { [weak self] size, contentType in
                    if let index = self?.detectedVideos.firstIndex(where: { $0.url == video.url }) {
                        self?.detectedVideos[index].estimatedSize = size
                    }
                }
            }
        }
    }

    func clearVideos() {
        detectedVideos.removeAll()
        hasVideos = false
        isPulsing = false
        detectionService.clearDetectedVideos()
    }

    func onNavigationStarted() {
        clearVideos()
    }

    func addToQueue(_ video: DetectedVideo) {
        var queue = persistence.loadQueue()
        let item = PlaylistItem(video: video, order: queue.count)
        queue.append(item)
        persistence.saveQueue(queue)
    }

    func removeVideo(at offsets: IndexSet) {
        detectedVideos.remove(atOffsets: offsets)
        hasVideos = !detectedVideos.isEmpty
        isPulsing = hasVideos
    }
}
