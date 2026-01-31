import Foundation
import SQLite3

enum SQLiteDatabaseError: Error, CustomStringConvertible {
    case openDatabase(message: String)
    case execute(message: String)
    case prepare(message: String)

    var description: String {
        switch self {
        case .openDatabase(let message): return "SQLite open error: \(message)"
        case .execute(let message): return "SQLite exec error: \(message)"
        case .prepare(let message): return "SQLite prepare error: \(message)"
        }
    }
}

final class SQLiteDatabase {
    private(set) var dbPointer: OpaquePointer?

    init(url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var db: OpaquePointer?
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            defer { sqlite3_close(db) }
            throw SQLiteDatabaseError.openDatabase(message: SQLiteDatabase.lastErrorMessage(db))
        }

        self.dbPointer = db
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        if let dbPointer {
            sqlite3_close(dbPointer)
        }
    }

    func execute(_ sql: String) throws {
        guard let dbPointer else { return }
        var errorMessage: UnsafeMutablePointer<Int8>? = nil
        if sqlite3_exec(dbPointer, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.flatMap { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteDatabaseError.execute(message: message)
        }
    }

    func prepareStatement(_ sql: String) throws -> OpaquePointer {
        guard let dbPointer else {
            throw SQLiteDatabaseError.prepare(message: "Database not available")
        }
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepare(message: SQLiteDatabase.lastErrorMessage(dbPointer))
        }
        return statement!
    }

    func inTransaction(_ block: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try block()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private static func lastErrorMessage(_ db: OpaquePointer?) -> String {
        guard let db else { return "Unknown error" }
        if let errorPointer = sqlite3_errmsg(db) {
            return String(cString: errorPointer)
        }
        return "Unknown error"
    }
}

extension SQLiteDatabase {
    static func defaultDatabaseURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataDirectory = documents.appendingPathComponent("STS_Data", isDirectory: true)
        return dataDirectory.appendingPathComponent("projects.db")
    }
}
