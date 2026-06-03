import Foundation
import SwiftUI

enum SearchEngine: String, Codable, CaseIterable {
    case google = "Google"
    case duckduckgo = "DuckDuckGo"
    case bing = "Bing"

    var searchURL: String {
        switch self {
        case .google: return "https://www.google.com/search?q="
        case .duckduckgo: return "https://duckduckgo.com/?q="
        case .bing: return "https://www.bing.com/search?q="
        }
    }

    var homeURL: String {
        switch self {
        case .google: return "https://www.google.com"
        case .duckduckgo: return "https://duckduckgo.com"
        case .bing: return "https://www.bing.com"
        }
    }
}

enum UserAgentOption: String, Codable, CaseIterable {
    case mobile = "Mobile (Default)"
    case desktop = "Desktop"
    case custom = "Custom"

    var value: String {
        switch self {
        case .mobile:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        case .desktop:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        case .custom:
            return ""
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var adBlockerEnabled: Bool {
        didSet { UserDefaults.standard.set(adBlockerEnabled, forKey: "adBlockerEnabled") }
    }
    @Published var searchEngine: SearchEngine {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") }
    }
    @Published var userAgent: UserAgentOption {
        didSet { UserDefaults.standard.set(userAgent.rawValue, forKey: "userAgent") }
    }
    @Published var customUserAgent: String {
        didSet { UserDefaults.standard.set(customUserAgent, forKey: "customUserAgent") }
    }
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }
    @Published var autoplayVideos: Bool {
        didSet { UserDefaults.standard.set(autoplayVideos, forKey: "autoplayVideos") }
    }
    @Published var defaultPlaybackSpeed: Float {
        didSet { UserDefaults.standard.set(defaultPlaybackSpeed, forKey: "defaultPlaybackSpeed") }
    }
    @Published var blockWebRTC: Bool {
        didSet { UserDefaults.standard.set(blockWebRTC, forKey: "blockWebRTC") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.adBlockerEnabled = defaults.object(forKey: "adBlockerEnabled") as? Bool ?? true
        self.searchEngine = SearchEngine(rawValue: defaults.string(forKey: "searchEngine") ?? "") ?? .google
        self.userAgent = UserAgentOption(rawValue: defaults.string(forKey: "userAgent") ?? "") ?? .mobile
        self.customUserAgent = defaults.string(forKey: "customUserAgent") ?? ""
        self.theme = AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .dark
        self.autoplayVideos = defaults.object(forKey: "autoplayVideos") as? Bool ?? false
        self.defaultPlaybackSpeed = defaults.object(forKey: "defaultPlaybackSpeed") as? Float ?? 1.0
        self.blockWebRTC = defaults.object(forKey: "blockWebRTC") as? Bool ?? true
    }

    var effectiveUserAgent: String {
        if userAgent == .custom {
            return customUserAgent.isEmpty ? UserAgentOption.mobile.value : customUserAgent
        }
        return userAgent.value
    }

    func clearBrowsingData() {
        let websiteDataTypes = Set([
            "WKWebsiteDataTypeCookies",
            "WKWebsiteDataTypeLocalStorage",
            "WKWebsiteDataTypeSessionStorage",
            "WKWebsiteDataTypeIndexedDBDatabases",
            "WKWebsiteDataTypeWebSQLDatabases"
        ])
        UserDefaults.standard.removeObject(forKey: "history")
        UserDefaults.standard.removeObject(forKey: "recentDevices")
        NotificationCenter.default.post(name: .init("ClearBrowsingData"), object: websiteDataTypes)
    }
}
