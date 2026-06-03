import SwiftUI

struct VideoDetectionOverlay: View {
    @ObservedObject var videoDetectorVM: VideoDetectorViewModel
    @ObservedObject var playerVM: PlayerViewModel
    @ObservedObject var castingVM: CastingViewModel

    var onPlayLocally: (DetectedVideo) -> Void
    var onCast: (DetectedVideo) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if videoDetectorVM.detectedVideos.isEmpty {
                    emptyState
                } else {
                    videoList
                }
            }
            .background(Color.wcBackground)
            .navigationTitle("Detected Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !videoDetectorVM.detectedVideos.isEmpty {
                        Menu {
                            Button("Add All to Queue", systemImage: "plus.rectangle.on.rectangle") {
                                videoDetectorVM.detectedVideos.forEach { video in
                                    playerVM.addToQueue(video)
                                }
                            }
                            Button("Clear All", systemImage: "trash", role: .destructive) {
                                videoDetectorVM.clearVideos()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.wcOrange)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.wcTextSecondary)
            Text("No videos detected")
                .font(.headline)
                .foregroundColor(.wcText)
            Text("Browse a webpage with video content\nand videos will appear here")
                .font(.subheadline)
                .foregroundColor(.wcTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var videoList: some View {
        List {
            ForEach(videoDetectorVM.detectedVideos) { video in
                VideoRow(
                    video: video,
                    isConnectedToDevice: castingVM.isConnected,
                    onPlay: { onPlayLocally(video) },
                    onCast: { onCast(video) },
                    onQueue: { playerVM.addToQueue(video) }
                )
                .listRowBackground(Color.wcSurface)
            }
            .onDelete { offsets in
                videoDetectorVM.removeVideo(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct VideoRow: View {
    let video: DetectedVideo
    let isConnectedToDevice: Bool
    let onPlay: () -> Void
    let onCast: () -> Void
    let onQueue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.wcText)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(video.format.rawValue, systemImage: "film")
                    .font(.system(size: 12))
                    .foregroundColor(.wcOrange)

                if let res = video.resolution {
                    Label(res, systemImage: "rectangle.arrowtriangle.2.outward")
                        .font(.system(size: 12))
                        .foregroundColor(.wcTextSecondary)
                }

                if let size = video.estimatedSize {
                    Label(size, systemImage: "doc")
                        .font(.system(size: 12))
                        .foregroundColor(.wcTextSecondary)
                }
            }

            if let pageTitle = video.pageTitle, !pageTitle.isEmpty {
                Text(pageTitle)
                    .font(.system(size: 11))
                    .foregroundColor(.wcTextSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.wcOrange)
                        .cornerRadius(8)
                }

                Button(action: onCast) {
                    Label("Cast", systemImage: "tv")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.wcOrange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.wcOrange.opacity(0.15))
                        .cornerRadius(8)
                }

                Spacer()

                Button(action: onQueue) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.wcTextSecondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}
