import SwiftUI

struct UsersListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(APIClient.self) private var api

    @State private var viewModel: UsersViewModel?
    @State private var showAdd = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView().task {
                    viewModel = UsersViewModel(api: api)
                    await viewModel?.reload()
                }
            }
        }
        .navigationTitle("SnapTrack")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!settings.isConfigured)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .onDisappear {
                    Task { await viewModel?.reload() }
                }
        }
        .sheet(isPresented: $showAdd) {
            AddUserSheet { name, username in
                guard let vm = viewModel else { return false }
                return await vm.addUser(name: name, snapchatUsername: username)
            }
        }
    }

    @ViewBuilder
    private func content(vm: UsersViewModel) -> some View {
        if !settings.isConfigured {
            ContentUnavailableView(
                "Connection not set up",
                systemImage: "antenna.radiowaves.left.and.right.slash",
                description: Text("Enter the server address and API key from the gear icon in the top right first.")
            )
        } else if vm.isLoading && vm.users.isEmpty {
            ProgressView()
        } else if let err = vm.errorMessage, vm.users.isEmpty {
            ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(err))
        } else if vm.users.isEmpty {
            ContentUnavailableView("Nobody here yet",
                systemImage: "person.crop.circle.badge.plus",
                description: Text("Add a new user with the + in the top right."))
        } else {
            list(vm: vm)
        }
    }

    private func list(vm: UsersViewModel) -> some View {
        List {
            ForEach(vm.users) { user in
                NavigationLink(value: user) {
                    UserRow(user: user)
                }
            }
            .onDelete { offsets in
                Task {
                    for idx in offsets {
                        await vm.delete(user: vm.users[idx])
                    }
                }
            }
        }
        .refreshable { await vm.reload() }
        .navigationDestination(for: User.self) { user in
            UserDetailView(user: user)
        }
    }
}

private struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.body)
                if let u = user.snapchatUsername, !u.isEmpty {
                    Text("@\(u)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let s = user.latestScore {
                    Text(s.formatted()).font(.system(.body, design: .rounded)).monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
                if let t = user.latestRecordedAt {
                    Text(t, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
