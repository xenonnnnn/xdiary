import Foundation

public enum XDiaryError: Error, Equatable, LocalizedError, Sendable {
    case invalidDate(String)
    case invalidDateRange
    case unsupportedSchemaVersion(Int)
    case duplicateTemplateID(UUID)
    case duplicateEntryID(UUID)
    case duplicateEntryDate(String)
    case duplicateSnapshotID(UUID)
    case duplicateBlockID(UUID)
    case defaultTemplateMissing(UUID)
    case templateNotFound(UUID)
    case entryAlreadyExists(String)
    case invalidTemplate(UUID, reason: String)
    case invalidBlock(UUID, reason: String)
    case invalidAnswer(entryID: UUID, blockID: UUID, reason: String)
    case invalidBackup(String)
    case fileNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidDate(date):
            "日期格式无效：\(date)，应为 yyyy-MM-dd"
        case .invalidDateRange:
            "开始日期不能晚于结束日期"
        case let .unsupportedSchemaVersion(version):
            "不支持的备份版本：\(version)"
        case let .duplicateTemplateID(id):
            "模板 ID 重复：\(id.uuidString)"
        case let .duplicateEntryID(id):
            "日记 ID 重复：\(id.uuidString)"
        case let .duplicateEntryDate(date):
            "同一日期有多篇日记：\(date)"
        case let .duplicateSnapshotID(id):
            "模板快照 ID 重复：\(id.uuidString)"
        case let .duplicateBlockID(id):
            "模板字段 ID 重复：\(id.uuidString)"
        case let .defaultTemplateMissing(id):
            "默认模板不存在：\(id.uuidString)"
        case let .templateNotFound(id):
            "找不到模板：\(id.uuidString)"
        case let .entryAlreadyExists(date):
            "\(date) 已有日记"
        case let .invalidTemplate(id, reason):
            "模板 \(id.uuidString) 无效：\(reason)"
        case let .invalidBlock(id, reason):
            "模板字段 \(id.uuidString) 无效：\(reason)"
        case let .invalidAnswer(entryID, blockID, reason):
            "日记 \(entryID.uuidString) 的回答 \(blockID.uuidString) 无效：\(reason)"
        case let .invalidBackup(reason):
            "备份数据无法读取：\(reason)"
        case let .fileNotFound(url):
            "找不到日记数据文件：\(url.path)"
        }
    }
}
