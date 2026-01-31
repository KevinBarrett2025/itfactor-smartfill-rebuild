import Foundation

public final class MigrationAdapter {
    public static let shared = MigrationAdapter()
    private init() {}

    /// Idempotent startup migrations. Safe to call multiple times.
    /// Keep ultra-fast when there's nothing to do.
    public func performStartupMigrations() {
        let env = ProcessInfo.processInfo.environment
        let enableSmartFillMigration = env["STS_ENABLE_SMARTFILL_MIGRATION"] == "1"

        if enableSmartFillMigration {
            print("📦 SmartFill migration enabled via STS_ENABLE_SMARTFILL_MIGRATION")
            SmartFillPathMigrator.shared.runIfNeeded()
        } else {
            // Keep quiet by default during fresh-install debugging.
        }

        // 2) Future migrations register here...
        // e.g., AssetIndexMigrator.shared.runIfNeeded()
    }
}
