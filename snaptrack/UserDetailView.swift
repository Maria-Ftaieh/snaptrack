import SwiftUI

struct UserDetailView: View {
    let user: User
    @Environment(APIClient.self) private var api
    @State private var viewModel: UserDetailViewModel?
    @State private var showLog = false

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView().task {
                    viewModel = UserDetailViewModel(user: user, api: api)
                    await viewModel?.reload()
                }
            }
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLog) {
            LogScoreSheet(
                userName: user.name,
                previousScore: viewModel?.stats?.currentScore ?? user.latestScore
            ) { score in
                guard let vm = viewModel else { return false }
                return await vm.logScore(score)
            }
        }
    }

    @ViewBuilder
    private func content(vm: UserDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(vm: vm)
                if let stats = vm.stats {
                    if stats.timeSeries.isEmpty {
                        ContentUnavailableView(
                            "No scores yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log the first snapscore and stats will show up here.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        StatsSection(stats: stats)
                    }
                } else if vm.isLoading {
                    ProgressView()
                } else if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
                if !vm.recentScores.isEmpty {
                    recentScoresSection(vm: vm)
                }
            }
            .padding()
        }
        .refreshable { await vm.reload() }
    }

    private func recentScoresSection(vm: UserDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent entries").font(.headline)
            Text("Made a mistake? Tap the trash icon next to the row.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(vm.recentScores) { log in
                    ScoreLogRow(log: log) {
                        Task { await vm.deleteScore(log) }
                    }
                    if log.id != vm.recentScores.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func header(vm: UserDetailViewModel) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Current snapscore").font(.caption).foregroundStyle(.secondary)
                Text(vm.stats?.currentScore?.formatted() ?? user.latestScore?.formatted() ?? "—")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let t = vm.stats?.lastRecordedAt ?? user.latestRecordedAt {
                    Text("Last updated: \(t.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button {
                showLog = true
            } label: {
                Label("Update score", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

private struct ScoreLogRow: View {
    let log: ScoreLog
    let onDelete: () -> Void
    @State private var showConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.score.formatted())
                    .font(.system(.body, design: .rounded).monospacedDigit())
                Text(log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete (\(log.score.formatted()))", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(log.recordedAt.formatted(date: .complete, time: .shortened))
        }
    }
}
