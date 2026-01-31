import Foundation

public struct SmartFillJobResult: Sendable {
    public let success: Bool
    public let compositorUsed: String       // e.g., "SmartFillPreviewCompositor" or "Legacy SmartFillExporter"
    public let processingTime: TimeInterval // seconds
    public let inputURL: URL
    public let outputURL: URL?              // final exported smartfill file (if any)
    public let bytesWritten: Int64?         // optional: export file size
    public let notes: String?               // optional: diagnostic note

    public init(success: Bool,
                compositorUsed: String,
                processingTime: TimeInterval,
                inputURL: URL,
                outputURL: URL?,
                bytesWritten: Int64? = nil,
                notes: String? = nil) {
        self.success = success
        self.compositorUsed = compositorUsed
        self.processingTime = processingTime
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.bytesWritten = bytesWritten
        self.notes = notes
    }
}