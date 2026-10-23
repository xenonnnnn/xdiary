import Foundation
import Testing
@testable import xdiary

@MainActor
struct NativeFilePanelsTests {
    @Test("未选择保存位置时返回 false")
    func cancelledSaveReturnsFalse() throws {
        let didWrite = try NativeFilePanels.write(Data("日记".utf8), to: nil)

        #expect(didWrite == false)
    }

    @Test("写入文件后返回 true")
    func completedSaveReturnsTrue() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xdiary-native-save-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }

        let didWrite = try NativeFilePanels.write(Data("日记".utf8), to: url)

        #expect(didWrite)
        #expect(try Data(contentsOf: url) == Data("日记".utf8))
    }
}
