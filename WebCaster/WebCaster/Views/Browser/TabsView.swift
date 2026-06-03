import SwiftUI

struct TabsView: View {
    @ObservedObject var browserVM: BrowserViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(browserVM.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabCard(
                            tab: tab,
                            isActive: index == browserVM.activeTabIndex,
                            onTap: {
                                browserVM.switchToTab(index)
                                dismiss()
                            },
                            onClose: {
                                browserVM.closeTab(at: index)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.wcBackground)
            .navigationTitle("Tabs (\(browserVM.tabs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.wcOrange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        browserVM.createNewTab()
                        dismiss()
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.wcOrange)
                    }
                }
            }
        }
    }
}

struct TabCard: View {
    let tab: BrowserTab
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tab.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.wcText)
                    .lineLimit(2)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.wcTextSecondary)
                        .padding(4)
                        .background(Color.wcSurfaceElevated)
                        .clipShape(Circle())
                }
            }

            if let host = tab.url?.host {
                Text(host)
                    .font(.system(size: 11))
                    .foregroundColor(.wcTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? Color.wcOrange.opacity(0.15) : Color.wcSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.wcOrange : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onTap)
    }
}
