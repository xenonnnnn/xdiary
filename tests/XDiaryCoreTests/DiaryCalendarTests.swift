import Foundation
import XCTest
@testable import XDiaryCore

final class DiaryCalendarTests: XCTestCase {
    func testCanonicalDateValidationRejectsMalformedAndImpossibleDates() throws {
        let calendar = DiaryCalendar(timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai")))

        XCTAssertNoThrow(try calendar.validate("2024-02-29"))
        for invalid in ["2026-2-03", "2026/02/03", "2026-02-30", "not-a-date"] {
            XCTAssertThrowsError(try calendar.validate(invalid), "应拒绝 \(invalid)") { error in
                guard case XDiaryError.invalidDate(invalid) = error else {
                    return XCTFail("意外错误：\(error)")
                }
            }
        }
    }

    func testDayArithmeticIsStableAcrossDaylightSavingBoundary() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let calendar = DiaryCalendar(timeZone: timeZone)

        XCTAssertEqual(try calendar.addingDays(1, to: "2026-03-08"), "2026-03-09")
        XCTAssertEqual(try calendar.addingDays(-1, to: "2026-11-01"), "2026-10-31")
        XCTAssertEqual(try calendar.dateString(for: calendar.date(from: "2026-03-08")), "2026-03-08")
    }

    func testMonthDatesIncludeLeapDayAndMonthKey() throws {
        let calendar = DiaryCalendar(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let dates = try calendar.dates(inMonthContaining: "2024-02-17")

        XCTAssertEqual(try calendar.monthKey(for: "2024-02-17"), "2024-02")
        XCTAssertEqual(dates.first, "2024-02-01")
        XCTAssertEqual(dates.last, "2024-02-29")
        XCTAssertEqual(dates.count, 29)
    }
}
