import SwiftUI

struct AddressBar: View {
    @ObservedObject var browserVM: BrowserViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(action: browserVM.goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(browserVM.canGoBack ? .wcOrange : .wcTextSecondary)
            }
            .disabled(!browserVM.canGoBack)

            Button(action: browserVM.goForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(browserVM.canGoForward ? .wcOrange : .wcTextSecondary)
            }
            .disabled(!browserVM.canGoForward)

            HStack(spacing: 6) {
                if browserVM.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.wcOrange)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.wcTextSecondary)
                }

                TextField("Search or enter URL", text: $browserVM.urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.wcText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($isFocused)
                    .onSubmit {
                        browserVM.navigateTo(browserVM.urlText)
                        isFocused = false
                    }

                if !browserVM.urlText.isEmpty && isFocused {
                    Button(action: { browserVM.urlText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.wcTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.wcSurface)
            .cornerRadius(10)

            Button(action: {
                if browserVM.isLoading {
                    NotificationCenter.default.post(name: .init("WebViewStopLoading"), object: nil)
                } else {
                    browserVM.reload()
                }
            }) {
                Image(systemName: browserVM.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.wcOrange)
            }

            Button(action: browserVM.goHome) {
                Image(systemName: "house")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.wcOrange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.wcBackground)
    }
}

struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.wcOrange)
                .frame(width: geo.size.width * progress)
                .animation(.linear(duration: 0.2), value: progress)
        }
        .frame(height: 2)
        .opacity(progress < 1.0 ? 1 : 0)
    }
}
