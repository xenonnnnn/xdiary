import Foundation

public protocol DiaryDataStoring: Sendable {
    func load(from url: URL) throws -> DiaryData
    func save(_ data: DiaryData, to url: URL) throws
}

public struct DiaryFileStore: DiaryDataStoring, Sendable {
    public init() {}

    public static func load(from url: URL) throws -> DiaryData {
        try Self().load(from: url)
    }

    public static func save(_ data: DiaryData, to url: URL) throws {
        try Self().save(data, to: url)
    }

    public func load(from url: URL) throws -> DiaryData {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XDiaryError.fileNotFound(url)
        }
        return try DiaryBackup.decode(Data(contentsOf: url))
    }

    public func save(_ data: DiaryData, to url: URL) throws {
        let encoded = try DiaryBackup.encode(data)
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        )

        do {
            try encoded.write(to: temporaryURL, options: .withoutOverwriting)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
