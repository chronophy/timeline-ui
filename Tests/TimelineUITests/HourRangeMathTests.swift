import Foundation
import Testing

@testable import TimelineUI

private func utcCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "UTC")!
	return calendar
}

private func time(_ hour: Int, _ minute: Int, day: Int = 21, calendar: Calendar) -> Date {
	calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
}

@Test func `hoursSinceBase does not truncate a base date with non-zero minutes`() throws {
	let calendar = utcCalendar()
	let baseDate = time(9, 5, calendar: calendar)
	let date = time(10, 0, calendar: calendar)

	let hours = HourRangeMath.hoursSinceBase(date, baseDate: baseDate, calendar: calendar)

	#expect(hours == 10)
}

@Test func `hoursSinceBase returns the base date's own hour when they're the same moment`() throws {
	let calendar = utcCalendar()
	let baseDate = time(9, 5, calendar: calendar)

	let hours = HourRangeMath.hoursSinceBase(baseDate, baseDate: baseDate, calendar: calendar)

	#expect(hours == 9)
}

@Test func `hoursSinceBase adds 24 for a date on the day after baseDate`() throws {
	let calendar = utcCalendar()
	let baseDate = time(9, 5, day: 21, calendar: calendar)
	let date = time(1, 0, day: 22, calendar: calendar)

	let hours = HourRangeMath.hoursSinceBase(date, baseDate: baseDate, calendar: calendar)

	#expect(hours == 25)
}

@Test func `hoursSinceBase subtracts 24 for a date on the day before baseDate`() throws {
	let calendar = utcCalendar()
	let baseDate = time(9, 5, day: 21, calendar: calendar)
	let date = time(23, 0, day: 20, calendar: calendar)

	let hours = HourRangeMath.hoursSinceBase(date, baseDate: baseDate, calendar: calendar)

	#expect(hours == -1)
}
