import Foundation
import XCTest
@testable import XDiaryCore

final class FileStoreTests: XCTestCase {
    func testSaveLoadAndAtomicReplacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xdiary-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("diary.json")
        let store = DiaryFileStore()
        let first = makeData()

        try store.save(first, to: url)
        XCTAssertEqual(try store.load(from: url), first)

        var second = first
        second.entries = [DiaryEntry(
            date: "2026-09-11",
            template: TemplateSnapshot(template: first.templates[0], capturedAt: fixedDate()),
            answers: [:],
            createdAt: fixedDate(),
            updatedAt: fixedDate()
        )]
        try store.save(second, to: url)

        XCTAssertEqual(try store.load(from: url), second)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".tmp") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testLoadMissingFileAndSaveFailureAreThrown() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xdiary-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiaryFileStore()
        let missing = directory.appendingPathComponent("missing.json")

        XCTAssertThrowsError(try store.load(from: missing)) { error in
            guard case XDiaryError.fileNotFound(missing) = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        let blockedParent = directory.appendingPathComponent("parent-is-file")
        try Data("blocked".utf8).write(to: blockedParent)
        let impossibleDestination = blockedParent.appendingPathComponent("diary.json")
        XCTAssertThrowsError(try store.save(makeData(), to: impossibleDestination))
    }
}
