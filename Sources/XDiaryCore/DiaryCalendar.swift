import Foundation

public struct DiaryCalendar: Sendable {
    private var calendar: Calendar

    public init(timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func validate(_ dateString: String) throws {
        _ = try date(from: dateString)
    }

    public func date(from dateString: String) throws -> Date {
        guard dateString.utf8.count == 10 else {
            throw XDiaryError.invalidDate(dateString)
        }
        let characters = Array(dateString)
        guard characters[4] == "-", characters[7] == "-",
              characters.enumerated().allSatisfy({ index, character in
                  index == 4 || index == 7 || character.isNumber
              }),
              let year = Int(String(characters[0...3])),
              let month = Int(String(characters[5...6])),
              let day = Int(String(characters[8...9])) else {
            throw XDiaryError.invalidDate(dateString)
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else {
            throw XDiaryError.invalidDate(dateString)
        }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == year, verified.month == month, verified.day == day else {
            throw XDiaryError.invalidDate(dateString)
        }
        return date
    }

    public func dateString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public func addingDays(_ days: Int, to dateString: String) throws -> String {
        let source = try date(from: dateString)
        guard let result = calendar.date(byAdding: .day, value: days, to: source) else {
            throw XDiaryError.invalidDate(dateString)
        }
        return self.dateString(for: result)
    }

    public func monthKey(for dateString: String) throws -> String {
        try validate(dateString)
        return String(dateString.prefix(7))
    }

    public func dates(inMonthContaining dateString: String) throws -> [String] {
        let source = try date(from: dateString)
        guard let days = calendar.range(of: .day, in: .month, for: source) else {
            throw XDiaryError.invalidDate(dateString)
        }
        let components = calendar.dateComponents([.year, .month], from: source)
        guard let year = components.year, let month = components.month else {
            throw XDiaryError.invalidDate(dateString)
        }
        return days.map { day in
            String(
                format: "%04d-%02d-%02d",
                locale: Locale(identifier: "en_US_POSIX"),
                year,
                month,
                day
            )
        }
    }
}
