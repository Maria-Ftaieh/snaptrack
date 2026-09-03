//
//  ContentView.swift
//  snaptrack
//

import SwiftUI

struct ContentView: View {
    @State private var settings: AppSettings
    @State private var api: APIClient
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let s = AppSettings()
        _settings = State(wrappedValue: s)
        _api = State(wrappedValue: APIClient(settings: s))
    }

    var body: some View {
        NavigationStack {
            UsersListView()
        }
        .environment(settings)
        .environment(api)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await NotificationManager.shared.refresh() }
            }
        }
    }
}

#Preview {
    ContentView()
}
