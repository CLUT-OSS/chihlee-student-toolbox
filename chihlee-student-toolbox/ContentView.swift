import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    private enum MainTab: Int, Hashable {
        case homework = 0
        case schedule
        case attendance
        case toolkit
        case profile
    }

    @State private var auth = AuthViewModel()
    @State private var selectedTab: MainTab = .homework
    @State private var profileTabTapCount = 0
    @State private var showTokenDebug = false

    var body: some View {
        Group {
            if auth.isAuthenticated {
                mainTabView
            } else {
                LoginView()
                    .environment(auth)
            }
        }
        .sheet(isPresented: $showTokenDebug) {
            AuthTokenDebugView(token: auth.wrapperToken, metrics: auth.debugMetrics)
        }
        .task {
            await auth.validateSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await auth.validateSession() }
        }
    }

    private var mainTabView: some View {
        TabView(selection: tabSelection) {
            Tab("作業", systemImage: "book.closed", value: MainTab.homework) {
                HomeworkTabView()
            }
            Tab("課表", systemImage: "calendar", value: MainTab.schedule) {
                ScheduleTabView()
            }
            Tab("出席", systemImage: "checkmark.circle", value: MainTab.attendance) {
                AttendanceTabView()
            }
            Tab("工具", systemImage: "wrench.and.screwdriver", value: MainTab.toolkit) {
                ToolkitTabView()
            }
            Tab("個人", systemImage: "person.circle", value: MainTab.profile) {
                ProfileTabView()
            }
        }
        .environment(auth)
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .profile {
                    if selectedTab == .profile {
                        profileTabTapCount += 1
                    } else {
                        profileTabTapCount = 1
                    }
                    if profileTabTapCount >= 5 {
                        profileTabTapCount = 0
                        showTokenDebug = true
                    }
                } else {
                    profileTabTapCount = 0
                }
                selectedTab = newTab
            }
        )
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
#endif
