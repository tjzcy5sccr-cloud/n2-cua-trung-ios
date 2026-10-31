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
                        Task {
                            await StudyReminders.shared.refreshIfNeeded(using: store.course)
                            if #available(iOS 16.1, *) {
                                await WideStudyController.shared.tick(course: store.course)
                            }
                        }
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    private let rotationTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Hôm nay", systemImage: "house.fill") }
            NavigationStack { FlashcardDeckView() }
                .tabItem { Label("Flashcard", systemImage: "rectangle.on.rectangle.angled") }
            NavigationStack { PracticeHubView() }
                .tabItem { Label("Luyện tập", systemImage: "book.closed.fill") }
            NavigationStack {
                if store.selectedSeries == .souMatome {
                    SouMatomeWholeBooksView()
                } else {
                    PlanView()
                }
            }
                .tabItem { Label(store.selectedSeries == .souMatome ? "Toàn bộ sách" : "Lộ trình", systemImage: store.selectedSeries == .souMatome ? "books.vertical" : "calendar") }
            NavigationStack { ProgressDashboardView() }
                .tabItem { Label("Tiến độ", systemImage: "chart.bar.fill") }
        }
        .background(Palette.pale)
        .onReceive(rotationTicker) { _ in
            // Đổi từ khi ứng dụng đang hoạt động, ở bất kỳ tab nào.
            // iOS có thể ngừng timer này khi app vào nền hoặc thiết bị khóa.
            if #available(iOS 16.1, *) {
                Task { await WideStudyController.shared.tick(course: store.course) }
            }
        }
    }
}