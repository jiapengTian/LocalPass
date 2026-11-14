import SwiftUI

@main
struct LocalPassApp: App {
    @StateObject private var session = VaultSession()

    var body: some Scene {
        WindowGroup {
            RootView(session: session, settings: session.settings)
        }
    }
}
