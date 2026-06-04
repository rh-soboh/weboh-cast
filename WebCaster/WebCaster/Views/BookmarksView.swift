import SwiftUI

struct BookmarksView: View {
    var switchToBrowser: () -> Void

    @State private var bookmarks: [Bookmark] = []
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var editingBookmark: Bookmark?

    private let persistence = PersistenceController.shared

    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty { return bookmarks }
        return bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    emptyState
                } else {
                    bookmarksList
                }
            }
            .background(Color.wcBackground)
            .navigationTitle("Bookmarks")
            .searchable(text: $searchText, prompt: "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.wcOrange)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddBookmarkSheet { title, url in
                    let bookmark = Bookmark(title: title, url: url)
                    persistence.addBookmark(bookmark)
                    bookmarks = persistence.loadBookmarks()
                }
            }
            .sheet(item: $editingBookmark) { bookmark in
                EditBookmarkSheet(bookmark: bookmark) { updated in
                    if let index = bookmarks.firstIndex(where: { $0.id == updated.id }) {
                        bookmarks[index] = updated
                        persistence.saveBookmarks(bookmarks)
                    }
                }
            }
            .onAppear {
                bookmarks = persistence.loadBookmarks()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(.wcTextSecondary)
            Text("No bookmarks yet")
                .font(.headline)
                .foregroundColor(.wcText)
            Text("Tap the star icon while browsing\nto save your favorite pages")
                .font(.subheadline)
                .foregroundColor(.wcTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bookmarksList: some View {
        List {
            ForEach(filteredBookmarks) { bookmark in
                BookmarkRow(bookmark: bookmark)
                    .onTapGesture {
                        if let url = URL(string: bookmark.url) {
                            NotificationCenter.default.post(
                                name: .init("NavigateToURL"),
                                object: nil,
                                userInfo: ["url": url]
                            )
                            switchToBrowser()
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteBookmark(bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            editingBookmark = bookmark
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.wcOrange)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        persistence.removeBookmark(bookmark)
        bookmarks = persistence.loadBookmarks()
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundColor(.wcOrange)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.wcText)
                    .lineLimit(1)

                Text(URL(string: bookmark.url)?.host ?? bookmark.url)
                    .font(.system(size: 12))
                    .foregroundColor(.wcTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct AddBookmarkSheet: View {
    var onSave: (String, String) -> Void

    @State private var title = ""
    @State private var url = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalURL = url.hasPrefix("http") ? url : "https://\(url)"
                        onSave(title.isEmpty ? finalURL : title, finalURL)
                        dismiss()
                    }
                    .foregroundColor(.wcOrange)
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct EditBookmarkSheet: View {
    let bookmark: Bookmark
    var onSave: (Bookmark) -> Void

    @State private var title: String
    @State private var url: String
    @Environment(\.dismiss) var dismiss

    init(bookmark: Bookmark, onSave: @escaping (Bookmark) -> Void) {
        self.bookmark = bookmark
        self.onSave = onSave
        _title = State(initialValue: bookmark.title)
        _url = State(initialValue: bookmark.url)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = bookmark
                        updated.title = title
                        updated.url = url
                        onSave(updated)
                        dismiss()
                    }
                    .foregroundColor(.wcOrange)
                }
            }
        }
    }
}
