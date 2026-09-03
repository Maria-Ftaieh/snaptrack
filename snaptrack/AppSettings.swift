import Foundation
import Observation

@Observable
final class AppSettings {
    static let baseURLKey = "snaptrack.baseURL"
    static let apiKeyKey = "snaptrack.apiKey"

    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Self.baseURLKey) }
    }

    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Self.apiKeyKey) }
    }

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: Self.baseURLKey) ?? ""
        self.apiKey = UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? ""
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
