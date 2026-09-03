import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case badURL
    case unauthorized
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Enter the server address and API key in Settings first."
        case .badURL: return "Invalid URL."
        case .unauthorized: return "API key was rejected (401)."
        case .http(let s, let b): return "Server error \(s): \(b)"
        case .decoding(let e): return "Couldn't decode the response: \(e.localizedDescription)"
        case .transport(let e): return "Connection error: \(e.localizedDescription)"
        }
    }
}

@Observable
final class APIClient {
    let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = isoFormatter.date(from: s) { return date }
            if let date = isoFormatterNoFrac.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Bad ISO date: \(s)")
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(isoFormatter.string(from: date))
        }
        return e
    }()

    private func makeRequest(_ method: String, _ path: String, body: Data? = nil) throws -> URLRequest {
        guard settings.isConfigured else { throw APIError.notConfigured }
        let base = settings.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        let http = response as! HTTPURLResponse
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode,
                                body: String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func sendVoid(_ req: URLRequest) async throws {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        let http = response as! HTTPURLResponse
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode,
                                body: String(data: data, encoding: .utf8) ?? "")
        }
    }

    // MARK: - Users

    func listUsers() async throws -> [User] {
        let req = try makeRequest("GET", "/users")
        return try await send(req, as: [User].self)
    }

    func createUser(name: String, snapchatUsername: String?) async throws -> User {
        let payload = CreateUserRequest(name: name,
                                        snapchatUsername: snapchatUsername?.isEmpty == false ? snapchatUsername : nil)
        let body = try Self.encoder.encode(payload)
        let req = try makeRequest("POST", "/users", body: body)
        return try await send(req, as: User.self)
    }

    func deleteUser(id: Int) async throws {
        let req = try makeRequest("DELETE", "/users/\(id)")
        try await sendVoid(req)
    }

    // MARK: - Scores

    func logScore(userId: Int, score: Int) async throws -> ScoreLog {
        let payload = CreateScoreRequest(score: score, recordedAt: nil)
        let body = try Self.encoder.encode(payload)
        let req = try makeRequest("POST", "/users/\(userId)/scores", body: body)
        return try await send(req, as: ScoreLog.self)
    }

    func listScores(userId: Int, limit: Int = 50) async throws -> [ScoreLog] {
        let req = try makeRequest("GET", "/users/\(userId)/scores?limit=\(limit)")
        return try await send(req, as: [ScoreLog].self)
    }

    func deleteScore(userId: Int, scoreId: Int) async throws {
        let req = try makeRequest("DELETE", "/users/\(userId)/scores/\(scoreId)")
        try await sendVoid(req)
    }

    // MARK: - Stats

    func stats(userId: Int) async throws -> Stats {
        let tzOffset = TimeZone.current.secondsFromGMT() / 60
        let req = try makeRequest("GET", "/users/\(userId)/stats?tz_offset_minutes=\(tzOffset)")
        return try await send(req, as: Stats.self)
    }
}
