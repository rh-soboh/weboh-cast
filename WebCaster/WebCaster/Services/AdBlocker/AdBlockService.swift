import Foundation
import WebKit

final class AdBlockService {
    static let shared = AdBlockService()

    private var contentRuleList: WKContentRuleList?
    private var isCompiled = false
    private let compilationQueue = DispatchQueue(label: "com.weboh.webcaster.adblock")

    private static let remoteBlocklistURL = "https://raw.githubusercontent.com/nicehash/nicehashquickfixes/master/nicehash_easylist.json"
    private static let cachedBlocklistKey = "cachedBlocklist"
    private static let lastUpdateKey = "blocklistLastUpdate"
    private static let updateIntervalHours: Double = 24

    private init() {}

    func compileRules(completion: @escaping (WKContentRuleList?) -> Void) {
        if let existing = contentRuleList {
            completion(existing)
            return
        }

        compilationQueue.async { [weak self] in
            guard let jsonString = self?.loadBlocklistJSON() else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "WebCasterAdBlock",
                encodedContentRuleList: jsonString
            ) { [weak self] ruleList, error in
                if let error = error {
                    print("[AdBlock] Compilation error: \(error.localizedDescription)")
                }
                self?.contentRuleList = ruleList
                self?.isCompiled = ruleList != nil
                DispatchQueue.main.async { completion(ruleList) }
            }
        }
    }

    func applyRules(to configuration: WKWebViewConfiguration) {
        if let ruleList = contentRuleList {
            configuration.userContentController.add(ruleList)
        }
    }

    func removeRules(from configuration: WKWebViewConfiguration) {
        configuration.userContentController.removeAllContentRuleLists()
    }

    func injectAdBlockScripts() -> WKUserScript {
        let script = """
        (function() {
            // Block popup windows
            window.__open = window.open;
            window.open = function() { return null; };

            // Remove ad-related elements
            const adSelectors = [
                '[id*="ad-"]', '[id*="ad_"]', '[class*="ad-"]', '[class*="ad_"]',
                '[id*="banner"]', '[class*="banner"]',
                '[id*="sponsor"]', '[class*="sponsor"]',
                'iframe[src*="ad"]', 'iframe[src*="doubleclick"]',
                'iframe[src*="googlesyndication"]',
                '[data-ad]', '[data-ads]', '[data-ad-slot]',
                '.adsbygoogle', '#google_ads_frame',
                '[id*="taboola"]', '[id*="outbrain"]',
                '[class*="taboola"]', '[class*="outbrain"]',
                'div[aria-label="advertisement"]'
            ];

            function removeAds() {
                adSelectors.forEach(function(selector) {
                    document.querySelectorAll(selector).forEach(function(el) {
                        el.style.display = 'none';
                        el.remove();
                    });
                });
            }

            removeAds();

            var adObserver = new MutationObserver(function(mutations) {
                removeAds();
            });
            adObserver.observe(document.documentElement || document.body, {
                childList: true, subtree: true
            });

            // Strip tracking params from links
            document.addEventListener('click', function(e) {
                var link = e.target.closest('a');
                if (link && link.href) {
                    try {
                        var url = new URL(link.href);
                        var trackingParams = ['utm_source','utm_medium','utm_campaign','utm_term','utm_content','fbclid','gclid','mc_cid','mc_eid'];
                        trackingParams.forEach(function(p) { url.searchParams.delete(p); });
                        link.href = url.toString();
                    } catch(err) {}
                }
            }, true);

            // Block WebRTC
            if (\(AppSettings.shared.blockWebRTC)) {
                Object.defineProperty(window, 'RTCPeerConnection', { value: undefined, writable: false });
                Object.defineProperty(window, 'webkitRTCPeerConnection', { value: undefined, writable: false });
                Object.defineProperty(window, 'mozRTCPeerConnection', { value: undefined, writable: false });
            }

            // Neuter autoplay video ads
            document.addEventListener('play', function(e) {
                var vid = e.target;
                if (vid.tagName === 'VIDEO') {
                    var isAd = vid.closest('[class*="ad"]') || vid.closest('[id*="ad"]') ||
                               vid.closest('[data-ad]') || (vid.duration && vid.duration < 31 && vid.muted);
                    if (isAd) {
                        vid.pause();
                        vid.src = '';
                        vid.remove();
                    }
                }
            }, true);
        })();
        """
        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    /// Fetch updated blocklist from remote URL. Merges with bundled list.
    func updateBlocklistFromRemote(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: Self.remoteBlocklistURL) else {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let remoteJSON = String(data: data, encoding: .utf8) else {
                print("[AdBlock] Remote update failed: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { completion(false) }
                return
            }

            if let remoteRules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let merged = self?.mergeWithBundled(remoteRules: remoteRules)
                if let mergedData = try? JSONSerialization.data(withJSONObject: merged ?? remoteRules),
                   let mergedString = String(data: mergedData, encoding: .utf8) {
                    UserDefaults.standard.set(mergedString, forKey: Self.cachedBlocklistKey)
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastUpdateKey)
                    print("[AdBlock] Remote blocklist cached: \(mergedString.count) bytes")
                }
            } else {
                UserDefaults.standard.set(remoteJSON, forKey: Self.cachedBlocklistKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastUpdateKey)
            }

            self?.contentRuleList = nil
            self?.isCompiled = false
            self?.compileRules { _ in
                DispatchQueue.main.async { completion(true) }
            }
        }.resume()
    }

    /// Auto-update if stale (older than 24 hours)
    func updateIfNeeded() {
        let lastUpdate = UserDefaults.standard.double(forKey: Self.lastUpdateKey)
        let hoursSinceUpdate = (Date().timeIntervalSince1970 - lastUpdate) / 3600
        if lastUpdate == 0 || hoursSinceUpdate > Self.updateIntervalHours {
            updateBlocklistFromRemote { success in
                if success { print("[AdBlock] Auto-updated blocklist from remote") }
            }
        }
    }

    private func loadBlocklistJSON() -> String? {
        if let cached = UserDefaults.standard.string(forKey: Self.cachedBlocklistKey), !cached.isEmpty {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "blocklist", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonString = String(data: data, encoding: .utf8) else {
            return fallbackBlocklist()
        }
        return jsonString
    }

    private func mergeWithBundled(remoteRules: [[String: Any]]) -> [[String: Any]] {
        guard let bundledURL = Bundle.main.url(forResource: "blocklist", withExtension: "json"),
              let bundledData = try? Data(contentsOf: bundledURL),
              let bundledRules = try? JSONSerialization.jsonObject(with: bundledData) as? [[String: Any]] else {
            return remoteRules
        }

        var seen = Set<String>()
        var merged: [[String: Any]] = []

        for rule in bundledRules {
            if let trigger = rule["trigger"] as? [String: Any],
               let filter = trigger["url-filter"] as? String {
                seen.insert(filter)
            }
            merged.append(rule)
        }

        for rule in remoteRules {
            if let trigger = rule["trigger"] as? [String: Any],
               let filter = trigger["url-filter"] as? String,
               !seen.contains(filter) {
                merged.append(rule)
            }
        }

        // WKContentRuleList has a ~50,000 rule limit
        if merged.count > 50000 {
            return Array(merged.prefix(50000))
        }
        return merged
    }

    private func fallbackBlocklist() -> String {
        return """
        [{"trigger":{"url-filter":".*","if-domain":["*googlesyndication.com","*doubleclick.net","*googleadservices.com"]},"action":{"type":"block"}},{"trigger":{"url-filter":".*","resource-type":["popup"]},"action":{"type":"block"}}]
        """
    }
}
