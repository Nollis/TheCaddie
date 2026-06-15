import SwiftUI
import TheCaddieDomain

@main
struct TheCaddieApp: App {
    var body: some Scene {
        WindowGroup {
            CaddieScreen(viewModel: CaddieViewModel.sample())
        }
    }
}
