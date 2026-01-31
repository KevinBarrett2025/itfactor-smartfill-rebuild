import SwiftUI
import AppIntents
import Foundation

@main
struct STSiPhoneApp: App {
    // CORE INTEGRATION FIX: Create repository instance to share across app
    private let repository: ProjectsRepository
    @StateObject private var themeManager = ThemeManager()
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appOrientationDelegate
    
    @Environment(\.scenePhase) private var scenePhase

    init() {
        self.repository = ProjectsRepositoryFactory.makeAppRepository()
    }

    var body: some Scene {
        WindowGroup {
            FlowHostView {
                // Onboarding-first experience guides actors into the app
                AppRootView(repo: repository)
                    .environmentObject(NavigationContextManager.shared)
            }
            .environmentObject(themeManager)
            .environmentObject(NavigationContextManager.shared)
            .onAppear {
                print("✅ Repository: Successfully loaded \(repository.fetchProjects().count) projects from disk")
                print("📂 Repository initialized with \(repository.fetchProjects().count) persisted projects")
                print("✅ Enterprise unified model support enabled")
                
                // 🚨 FIXED: Perform startup migrations using correct API
                Task { @MainActor in
                    MigrationAdapter.shared.performStartupMigrations()
                }
                
                // CORE INTEGRATION FIX: Configure SessionManager with repository AND enable unified models
                SessionManager.shared.configure(with: repository)
                
                // CRITICAL FIX: Enable unified models by default for all new sessions
                SessionManager.shared.enableUnifiedModels()
                
                repository.enableUnifiedModelSupport()
                ImportStore.shared.configure(with: repository)
                
                // FIXED: Register AppIntents for Siri shortcuts and metadata processing
                Task {
                    SelfTapeStudioIntents.updateAppShortcutParameters()
                }
                
                print("✅ App Launch: Repository configured, unified models enabled globally")
            }
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            switch newPhase {
            case .active:
                NavigationContextManager.shared.cleanupStaleContexts()
            case .background:
                // Optional: request a short BG task to flush queue
                Task { 
                    // Keep transport alive briefly to flush events
                    // BGTaskScheduler implementation could go here if needed
                }
                WatchBridge.shared.notifyCameraReady(false)
            case .inactive:
                // App is transitioning - keep transport alive
                WatchBridge.shared.notifyCameraReady(false)
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - AppIntents Configuration

struct SelfTapeStudioIntents: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "Begin audition in \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "video.circle"
        )
    }
}

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Quickly start a new audition recording")
    
    func perform() async throws -> some IntentResult {
        // This would trigger the main recording flow
        return .result()
    }
}

enum ProjectsRepositoryFactory {
    static func makeAppRepository() -> ProjectsRepository {
        do {
            return try makeSQLiteRepository(at: SQLiteDatabase.defaultDatabaseURL())
        } catch {
            fatalError("❌ Failed to initialize SQLite repository: \(error)")
        }
    }

    static func makePreviewRepository() -> ProjectsRepository {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("STS_Preview_\(UUID().uuidString)", isDirectory: false)
        do {
            return try makeSQLiteRepository(at: tempURL)
        } catch {
            fatalError("❌ Failed to initialize preview SQLite repository: \(error)")
        }
    }

    static func makeEphemeralRepository() -> ProjectsRepository {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("STS_Test_\(UUID().uuidString)", isDirectory: false)
        do {
            return try makeSQLiteRepository(at: tempURL)
        } catch {
            fatalError("❌ Failed to initialize test SQLite repository: \(error)")
        }
    }

    static func makeSQLiteRepository(at url: URL) throws -> ProjectsRepository {
        let database = try SQLiteDatabase(url: url)
        let store = try ProjectsStoreSQLite(database: database)
        print("📦 STS App: Using SQLiteProjectsRepository at \(url.path)")
        return SQLiteProjectsRepository(store: store)
    }
}
