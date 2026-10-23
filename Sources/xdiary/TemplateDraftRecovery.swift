import Foundation
import XDiaryCore

struct TemplateDraftRecovery: Codable, Equatable {
    let draft: DiaryTemplate
    let original: DiaryTemplate
}

enum TemplateDraftRecoveryStore {
    private static let fileName = ".template-draft-recovery.json"

    static func recoveryURL(for dataURL: URL) -> URL {
        dataURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    static func restore(for dataURL: URL) throws -> TemplateDraftRecovery? {
        let url = recoveryURL(for: dataURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(TemplateDraftRecovery.self, from: Data(contentsOf: url))
    }

    static func sync(
        draft: DiaryTemplate?,
        original: DiaryTemplate?,
        dataURL: URL
    ) throws {
        let url = recoveryURL(for: dataURL)
        guard let draft, let original, draft != original else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoded = try JSONEncoder().encode(TemplateDraftRecovery(draft: draft, original: original))
        try encoded.write(to: url, options: .atomic)
    }
}
