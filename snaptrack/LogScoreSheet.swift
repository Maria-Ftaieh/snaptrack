import SwiftUI

struct LogScoreSheet: View {
    let userName: String
    let previousScore: Int?
    let onSubmit: (_ score: Int) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var scoreText = ""
    @State private var submitting = false
    @FocusState private var focused: Bool

    private var parsed: Int? {
        Int(scoreText.filter { $0.isNumber })
    }

    private var warning: String? {
        guard let new = parsed, let prev = previousScore else { return nil }
        if new < prev { return "Lower than the previous score (\(prev.formatted())) — you can still save it." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New snapscore for \(userName)") {
                    TextField("e.g. 41023", text: $scoreText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .focused($focused)
                    if let prev = previousScore {
                        LabeledContent("Previous", value: prev.formatted())
                    }
                    if let w = warning {
                        Label(w, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Log score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let v = parsed else { return }
                        Task {
                            submitting = true
                            let ok = await onSubmit(v)
                            submitting = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(parsed == nil || submitting)
                }
            }
            .onAppear { focused = true }
        }
    }
}
