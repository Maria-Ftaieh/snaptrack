import SwiftUI

struct AddUserSheet: View {
    let onSubmit: (_ name: String, _ snapchatUsername: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var snapchatUsername = ""
    @State private var submitting = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name", text: $name)
                        .focused($nameFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    TextField("Snapchat username (optional)", text: $snapchatUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("New user")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            submitting = true
                            let ok = await onSubmit(name.trimmingCharacters(in: .whitespaces),
                                                    snapchatUsername.trimmingCharacters(in: .whitespaces))
                            submitting = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                }
            }
            .onAppear { nameFocused = true }
        }
    }
}
