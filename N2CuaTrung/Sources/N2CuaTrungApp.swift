import SwiftUI

@main
struct N2CuaTrungApp: App {
    @StateObject private var store = StudyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.blue)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Hôm nay", systemImage: "house.fill") }
            NavigationStack { FlashcardDeckView() }
                .tabItem { Label("Flashcard", systemImage: "rectangle.on.rectangle.angled") }
            NavigationStack { PracticeHubView() }
                .tabItem { Label("Luyện tập", systemImage: "book.closed.fill") }
            NavigationStack { PlanView() }
                .tabItem { Label("Lộ trình", systemImage: "calendar") }
            NavigationStack { ProgressDashboardView() }
                .tabItem { Label("Tiến độ", systemImage: "chart.bar.fill") }
        }
        .background(Palette.pale)
    }
}
