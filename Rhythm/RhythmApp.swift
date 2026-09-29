import SwiftUI
import MusicKit

@main
struct RhythmApp: App {
    @StateObject private var model = RhythmModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
