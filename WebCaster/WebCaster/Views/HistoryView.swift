import SwiftUI

struct HistoryView: View {
    @State private var history: [HistoryEntry] = []
    @State private var searchText = ""
    @State private var showClearAlert = false

    private let persistence = PersistenceController.shared

    var filteredHistory: [HistoryEntry] {
        if searchText.isEmpty { return history }
        return history.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedHistory: [(String, [HistoryEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: filteredHistory) { entry in
            formatter.string(from: entry.visitedAt)
        }

        return grouped.sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.visitedAt,
                  let rhsDate = rhs.value.first?.visitedAt else { return false }
            return lhsDate > rhsDate
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .background(Color.wcBackground)
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !history.isEmpty {
                        Button(action: { showClearAlert = true }) {
                            Text("Clear")
                                .foregroundColor(.wcOrange)
                        }
                    }
                }
            }
            .alert("Clear History", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    persistence.clearHistory()
                    history = []
                }
            } message: {
                Text("This will permanently delete your browsing history.")
            }
            .onAppear {
                history = persistence.loadHistory()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.wcTextSecondary)
            Text("No browsing history")
                .font(.headline)
                .foregroundColor(.wcText)
            Text("Pages you visit will appear here")
                .font(.subheadline)
                .foregroundColor(.wcTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.0) { dateString, entries in
                Section {
                    ForEach(entries) { entry in
                        HistoryRow(entry: entry)
                            .onTapGesture {
                                NotificationCenter.default.post(
                                    name: .init("NavigateToURL"),
                                    object: nil,
                                    userInfo: ["url": URL(string: entry.url)!]
                                )
                            }
                    }
                    .onDelete { offsets in
                        deleteEntries(entries: entries, at: offsets)
                    }
                } header: {
                    Text(dateString)
                        .foregroundColor(.wcOrange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func deleteEntries(entries: [HistoryEntry], at offsets: IndexSet) {
        let idsToDelete = offsets.map { entries[$0].id }
        history.removeAll { idsToDelete.contains($0.id) }
        persistence.saveHistory(history)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.wcText)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(entry.domain)
                    .font(.system(size: 12))
                    .foregroundColor(.wcOrange)
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(.wcTextSecondary)
                Text(entry.displayDate)
                    .font(.system(size: 12))
                    .foregroundColor(.wcTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
