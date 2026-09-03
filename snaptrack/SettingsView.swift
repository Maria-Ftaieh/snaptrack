import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://snaptrack.example.com", text: $baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        if testing { ProgressView() } else { Text("Test connection") }
                    }
                    .disabled(testing || baseURL.isEmpty || apiKey.isEmpty)
                    if let r = testResult {
                        Text(r).font(.footnote)
                    }
                } footer: {
                    Text("The API key must match the value in the server's .env file. If you're using HTTP you may need to add an ATS exception to the iOS Info.plist.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
                        settings.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                }
            }
            .onAppear {
                baseURL = settings.baseURL
                apiKey = settings.apiKey
            }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        // Apply temporarily so APIClient picks up new values.
        let oldURL = settings.baseURL
        let oldKey = settings.apiKey
        settings.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        settings.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await api.listUsers()
            testResult = "Connection successful."
        } catch {
            testResult = (error as? APIError)?.errorDescription ?? error.localizedDescription
            // Revert if test failed and user hasn't saved.
            settings.baseURL = oldURL
            settings.apiKey = oldKey
        }
    }
}
