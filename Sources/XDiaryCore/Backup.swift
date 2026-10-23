import Foundation

public enum DiaryBackup {
    public static let currentSchemaVersion = 1

    public static func encode(_ data: DiaryData) throws -> Data {
        try data.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalISO8601Formatter().string(from: date))
        }
        return try encoder.encode(data)
    }

    public static func decode(_ encoded: Data) throws -> DiaryData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                if let date = fractionalISO8601Formatter().date(from: value)
                    ?? basicISO8601Formatter().date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "无效的 ISO 8601 时间：\(value)"
                )
            }
            if let value = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: value)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无效时间")
        }

        let data: DiaryData
        do {
            data = try decoder.decode(DiaryData.self, from: encoded)
        } catch {
            throw XDiaryError.invalidBackup(String(describing: error))
        }
        try data.validate()
        return data
    }

    private static func fractionalISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .gmt
        return formatter
    }

    private static func basicISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .gmt
        return formatter
    }
}
