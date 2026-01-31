import os

enum ImportLog {
    static let files = Logger(subsystem: "com.selftapestudio.app", category: "FilesImport")
    static let queue = Logger(subsystem: "com.selftapestudio.app", category: "ImportQueue")
}
