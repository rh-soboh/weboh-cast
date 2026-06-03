import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var browserVM: BrowserViewModel
    @ObservedObject var videoDetectorVM: VideoDetectorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(browserVM: browserVM, videoDetectorVM: videoDetectorVM)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "videoDetected")

        let detectorScript = VideoDetectionService.shared.injectDetectorScript()
        contentController.addUserScript(detectorScript)

        if AppSettings.shared.adBlockerEnabled {
            let adBlockScript = AdBlockService.shared.injectAdBlockScripts()
            contentController.addUserScript(adBlockScript)

            AdBlockService.shared.compileRules { ruleList in
                if let ruleList = ruleList {
                    contentController.add(ruleList)
                }
            }
        }

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = AppSettings.shared.effectiveUserAgent
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        context.coordinator.webView = webView

        context.coordinator.setupObservers(for: webView)
        context.coordinator.setupNotificationObservers()

        if let url = browserVM.activeTab?.url {
            webView.load(URLRequest(url: url))
        } else {
            let homeURL = browserVM.homeURL
            webView.load(URLRequest(url: homeURL))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // UserAgent changes
        let newUA = AppSettings.shared.effectiveUserAgent
        if webView.customUserAgent != newUA {
            webView.customUserAgent = newUA
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var browserVM: BrowserViewModel
        var videoDetectorVM: VideoDetectorViewModel
        weak var webView: WKWebView?
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var notificationObservers: [NSObjectProtocol] = []

        init(browserVM: BrowserViewModel, videoDetectorVM: VideoDetectorViewModel) {
            self.browserVM = browserVM
            self.videoDetectorVM = videoDetectorVM
        }

        deinit {
            notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func setupObservers(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.browserVM.updateProgress(wv.estimatedProgress)
                }
            }
            titleObservation = webView.observe(\.title) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.browserVM.updateTab(
                        title: wv.title,
                        url: wv.url,
                        canGoBack: wv.canGoBack,
                        canGoForward: wv.canGoForward
                    )
                }
            }
            urlObservation = webView.observe(\.url) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.browserVM.updateTab(
                        title: wv.title,
                        url: wv.url,
                        canGoBack: wv.canGoBack,
                        canGoForward: wv.canGoForward
                    )
                }
            }
        }

        func setupNotificationObservers() {
            let nav = NotificationCenter.default.addObserver(
                forName: .init("NavigateToURL"), object: nil, queue: .main
            ) { [weak self] notification in
                if let url = notification.userInfo?["url"] as? URL {
                    self?.webView?.load(URLRequest(url: url))
                }
            }
            notificationObservers.append(nav)

            let back = NotificationCenter.default.addObserver(
                forName: .init("WebViewGoBack"), object: nil, queue: .main
            ) { [weak self] _ in self?.webView?.goBack() }
            notificationObservers.append(back)

            let fwd = NotificationCenter.default.addObserver(
                forName: .init("WebViewGoForward"), object: nil, queue: .main
            ) { [weak self] _ in self?.webView?.goForward() }
            notificationObservers.append(fwd)

            let reload = NotificationCenter.default.addObserver(
                forName: .init("WebViewReload"), object: nil, queue: .main
            ) { [weak self] _ in self?.webView?.reload() }
            notificationObservers.append(reload)

            let clear = NotificationCenter.default.addObserver(
                forName: .init("ClearBrowsingData"), object: nil, queue: .main
            ) { [weak self] _ in
                let dataStore = WKWebsiteDataStore.default()
                let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                dataStore.fetchDataRecords(ofTypes: allTypes) { records in
                    dataStore.removeData(ofTypes: allTypes, for: records) { }
                }
                self?.webView?.load(URLRequest(url: URL(string: AppSettings.shared.searchEngine.homeURL)!))
            }
            notificationObservers.append(clear)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoDetected" {
                VideoDetectionService.shared.handleMessage(message)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            videoDetectorVM.onNavigationStarted()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in
                self?.browserVM.updateTab(
                    title: webView.title,
                    url: webView.url,
                    canGoBack: webView.canGoBack,
                    canGoForward: webView.canGoForward
                )
                if let title = webView.title, let url = webView.url?.absoluteString, !title.isEmpty {
                    self?.browserVM.addToHistory(title: title, url: url)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }

            if let url = navigationAction.request.url {
                let urlString = url.absoluteString.lowercased()
                let videoExts = [".m3u8", ".mp4", ".webm", ".mkv", ".avi", ".mov", ".mpd"]
                if videoExts.contains(where: { urlString.contains($0) }) {
                    let video = DetectedVideo(url: url.absoluteString, pageURL: webView.url?.absoluteString, pageTitle: webView.title)
                    videoDetectorVM.didDetectVideo(video)
                }
            }

            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
