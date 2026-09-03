import Foundation
import Observation

@Observable
final class UserDetailViewModel {
    let user: User
    var stats: Stats?
    var recentScores: [ScoreLog] = []
    var isLoading = false
    var errorMessage: String?

    private let api: APIClient

    init(user: User, api: APIClient) {
        self.user = user
        self.api = api
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let s = api.stats(userId: user.id)
            async let logs = api.listScores(userId: user.id, limit: 50)
            stats = try await s
            recentScores = try await logs
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logScore(_ score: Int) async -> Bool {
        do {
            _ = try await api.logScore(userId: user.id, score: score)
            await reload()
            return true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteScore(_ log: ScoreLog) async {
        do {
            try await api.deleteScore(userId: user.id, scoreId: log.id)
            await reload()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
