import SwiftUI

@main
struct TheCaddieApp: App {
    @StateObject private var viewModel = CaddieViewModel.noCourseLoaded()
    @State private var selectedTab = 3
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CaddieScreen(
                    viewModel: viewModel,
                    onChooseCourse: {
                        selectedTab = 3
                    }
                )
                    .tabItem {
                        Label("Caddie", systemImage: "target")
                    }
                    .tag(0)
                
                ScorecardScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Scorecard", systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                
                BagSettingsScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Bag", systemImage: "briefcase")
                    }
                    .tag(2)
                
                CourseSelectionScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Courses", systemImage: "map")
                    }
                    .tag(3)
            }
            .accentColor(Color(red: 0.06, green: 0.56, blue: 0.24))
        }
    }
}
