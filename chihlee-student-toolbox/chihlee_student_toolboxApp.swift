import SwiftUI
import SwiftData

@main
struct chihlee_student_toolboxApp: App {
    private static let appSchema = Schema([
        Student.self,
        Course.self,
        ClassSession.self,
        NonTimedScheduleEntry.self,
        Assignment.self,
        AttendanceRecord.self,
    ])

    @State private var themeStore = ThemeStore()

    var sharedModelContainer: ModelContainer = Self.makeSharedModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeStore)
                .preferredColorScheme(themeStore.appearance.colorScheme)
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeSharedModelContainer() -> ModelContainer {
        let modelConfiguration = ModelConfiguration(schema: appSchema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: appSchema, configurations: [modelConfiguration])
        } catch {
            #if DEBUG
            print("SwiftData container init failed: \(error)")
            removePotentialSwiftDataStoreFiles()

            do {
                return try ModelContainer(for: appSchema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not recreate ModelContainer after resetting local store: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }
    }

    private static func removePotentialSwiftDataStoreFiles() {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            guard fileManager.fileExists(atPath: applicationSupportURL.path) else { return }
            let urls = try fileManager.contentsOfDirectory(at: applicationSupportURL, includingPropertiesForKeys: nil)

            for url in urls where url.lastPathComponent.contains(".store") {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            print("Failed to inspect Application Support for SwiftData reset: \(error)")
        }
    }
}
