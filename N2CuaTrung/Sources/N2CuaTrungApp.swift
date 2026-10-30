import SwiftUI
import WidgetKit

@main
struct N2CuaTrungApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StudyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.blue)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { state in
                    if state == .active {
                        // iOS quyết định thời điểm hiển thị; không thể ép widget đổi ngay khi mở khóa.
                        WidgetCenter.shared.reloadTimelines(ofKind: "N2TrungWordWidget")
                    }
                }
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