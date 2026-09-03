import Foundation
import Observation

@Observable
final class UsersViewModel {
    var users: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await api.listUsers()
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addUser(name: String, snapchatUsername: String?) async -> Bool {
        do {
            _ = try await api.createUser(name: name, snapchatUsername: snapchatUsername)
            await reload()
            return true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func delete(user: User) async {
        do {
            try await api.deleteUser(id: user.id)
            await reload()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
