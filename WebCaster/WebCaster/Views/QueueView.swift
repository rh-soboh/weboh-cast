import SwiftUI

struct QueueView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var showPlayer = false
    @State private var showSavePlaylist = false
    @State private var playlists: [Playlist] = []

    private let persistence = PersistenceController.shared

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queue.isEmpty {
                    emptyState
                } else {
                    queueContent
                }
            }
            .background(Color.wcBackground)
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !playerVM.queue.isEmpty {
                        Menu {
                            Button("Save as Playlist", systemImage: "folder.badge.plus") {
                                showSavePlaylist = true
                            }
                            Button("Clear Queue", systemImage: "trash", role: .destructive) {
                                playerVM.clearQueue()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.wcOrange)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                PlayerView(playerVM: playerVM)
            }
            .sheet(isPresented: $showSavePlaylist) {
                SavePlaylistSheet { name in
                    let videos = playerVM.queue.map { $0.video }
                    var playlist = Playlist(name: name)
                    videos.forEach { playlist.addItem($0) }
                    playlists.append(playlist)
                    persistence.savePlaylists(playlists)
                }
            }
            .onAppear {
                playlists = persistence.loadPlaylists()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.wcTextSecondary)
            Text("Queue is empty")
                .font(.headline)
                .foregroundColor(.wcText)
            Text("Detected videos can be added\nto the queue for continuous playback")
                .font(.subheadline)
                .foregroundColor(.wcTextSecondary)
                .multilineTextAlignment(.center)

            if !playlists.isEmpty {
                Divider().padding(.vertical, 8)
                Text("Saved Playlists")
                    .font(.headline)
                    .foregroundColor(.wcText)

                ForEach(playlists) { playlist in
                    PlaylistRow(playlist: playlist) {
                        playerVM.queue = playlist.items
                        persistence.saveQueue(playerVM.queue)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var queueContent: some View {
        VStack(spacing: 0) {
            nowPlayingHeader

            List {
                Section {
                    ForEach(playerVM.queue) { item in
                        QueueItemRow(item: item, isPlaying: playerVM.currentVideo?.url == item.video.url)
                            .onTapGesture {
                                if let index = playerVM.queue.firstIndex(where: { $0.id == item.id }) {
                                    playerVM.currentQueueIndex = index
                                    playerVM.loadVideo(item.video)
                                    playerVM.play()
                                    showPlayer = true
                                }
                            }
                    }
                    .onDelete { offsets in
                        playerVM.removeFromQueue(at: offsets)
                    }
                    .onMove { source, destination in
                        playerVM.moveInQueue(from: source, to: destination)
                    }
                } header: {
                    Text("\(playerVM.queue.count) videos")
                        .foregroundColor(.wcTextSecondary)
                }

                if !playlists.isEmpty {
                    Section("Saved Playlists") {
                        ForEach(playlists) { playlist in
                            PlaylistRow(playlist: playlist) {
                                playerVM.queue = playlist.items
                                persistence.saveQueue(playerVM.queue)
                            }
                        }
                        .onDelete { offsets in
                            playlists.remove(atOffsets: offsets)
                            persistence.savePlaylists(playlists)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
    }

    private var nowPlayingHeader: some View {
        Button(action: {
            if playerVM.currentVideo == nil, let first = playerVM.queue.first {
                playerVM.loadVideo(first.video)
            }
            playerVM.play()
            showPlayer = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.wcOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Play Queue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.wcText)
                    Text("\(playerVM.queue.count) videos")
                        .font(.system(size: 13))
                        .foregroundColor(.wcTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.wcTextSecondary)
            }
            .padding(16)
            .background(Color.wcSurface)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

struct QueueItemRow: View {
    let item: PlaylistItem
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.wcOrange)
                    .frame(width: 24)
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14))
                    .foregroundColor(.wcTextSecondary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.video.title)
                    .font(.system(size: 14, weight: isPlaying ? .semibold : .regular))
                    .foregroundColor(isPlaying ? .wcOrange : .wcText)
                    .lineLimit(1)

                Text(item.video.displayFormat)
                    .font(.system(size: 11))
                    .foregroundColor(.wcTextSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
    let onLoad: () -> Void

    var body: some View {
        Button(action: onLoad) {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 20))
                    .foregroundColor(.wcOrange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.wcText)
                    Text("\(playlist.items.count) videos")
                        .font(.system(size: 12))
                        .foregroundColor(.wcTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.wcTextSecondary)
            }
        }
    }
}

struct SavePlaylistSheet: View {
    var onSave: (String) -> Void

    @State private var name = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist name", text: $name)
                }
            }
            .navigationTitle("Save Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .foregroundColor(.wcOrange)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
