import Foundation
import Testing

@testable import TimelineUI

private func mondayFirstCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "UTC")!
	calendar.firstWeekday = 2
	return calendar
}

private func sundayFirstCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "UTC")!
	calendar.firstWeekday = 1
	return calendar
}

private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
	calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

@Test func `weekDates returns 7 consecutive days starting on the configured first weekday`() throws {
	let calendar = mondayFirstCalendar()
	// 2026-07-22 is a Wednesday.
	let wednesday = date(2026, 7, 22, calendar: calendar)

	let week = WeekDateMath.weekDates(containing: wednesday, calendar: calendar)

	#expect(week.count == 7)
	#expect(calendar.component(.weekday, from: week[0]) == 2)  // Monday
	#expect(calendar.isDate(week[0], inSameDayAs: date(2026, 7, 20, calendar: calendar)))
	#expect(calendar.isDate(week[6], inSameDayAs: date(2026, 7, 26, calendar: calendar)))
	#expect(week.contains { calendar.isDate($0, inSameDayAs: wednesday) })
}

@Test func `weekStart respects a Sunday-first calendar`() throws {
	let calendar = sundayFirstCalendar()
	// 2026-07-22 is a Wednesday; the Sunday-first week start is 2026-07-19.
	let wednesday = date(2026, 7, 22, calendar: calendar)

	let start = WeekDateMath.weekStart(containing: wednesday, calendar: calendar)

	#expect(calendar.isDate(start, inSameDayAs: date(2026, 7, 19, calendar: calendar)))
}

@Test func `orderedWeekdaySymbols starts with Monday for a Monday-first calendar`() throws {
	let symbols = WeekDateMath.orderedWeekdaySymbols(calendar: mondayFirstCalendar())
	#expect(symbols == ["M", "T", "W", "T", "F", "S", "S"])
}

@Test func `orderedWeekdaySymbols starts with Sunday for a Sunday-first calendar`() throws {
	let symbols = WeekDateMath.orderedWeekdaySymbols(calendar: sundayFirstCalendar())
	#expect(symbols == ["S", "M", "T", "W", "T", "F", "S"])
}

@Test func `shifted moves forward and backward by whole weeks`() throws {
	let calendar = mondayFirstCalendar()
	let start = date(2026, 7, 22, calendar: calendar)

	let nextWeek = WeekDateMath.shifted(start, byWeeks: 1, calendar: calendar)
	let twoWeeksAhead = WeekDateMath.shifted(start, byWeeks: 2, calendar: calendar)
	let previousWeek = WeekDateMath.shifted(start, byWeeks: -1, calendar: calendar)

	#expect(calendar.isDate(nextWeek, inSameDayAs: date(2026, 7, 29, calendar: calendar)))
	#expect(calendar.isDate(twoWeeksAhead, inSameDayAs: date(2026, 8, 5, calendar: calendar)))
	#expect(calendar.isDate(previousWeek, inSameDayAs: date(2026, 7, 15, calendar: calendar)))
}

@Test func `shifted round-trips forward then backward`() throws {
	let calendar = mondayFirstCalendar()
	let start = date(2026, 7, 22, calendar: calendar)

	let roundTripped = WeekDateMath.shifted(
		WeekDateMath.shifted(start, byWeeks: 1, calendar: calendar),
		byWeeks: -1,
		calendar: calendar
	)

	#expect(calendar.isDate(roundTripped, inSameDayAs: start))
}
