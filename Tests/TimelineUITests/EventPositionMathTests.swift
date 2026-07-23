import Foundation
import Testing

@testable import TimelineUI

@Test func `yOffset places an event at its own start time regardless of reference date minutes`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	// Reference date sits at :25 past the hour - the value that previously leaked into every
	// event's offset as a fixed error.
	let referenceDate = calendar.date(bySettingHour: 9, minute: 25, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(offset == 8 * hourHeight)
}

@Test func `yOffset matches the reference date's own offset when they're the same event`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	let referenceDate = calendar.date(bySettingHour: 8, minute: 25, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: referenceDate,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(offset == (8 + 25.0 / 60) * hourHeight)
}

@Test func `yOffset subtracts rangeStart in whole hours`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	let referenceDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 7,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(offset == 2.5 * hourHeight)
}

// MARK: - date(atYOffset:...)

@Test func `date(atYOffset:) round-trips with yOffset`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	let referenceDate = calendar.date(bySettingHour: 9, minute: 25, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 14, minute: 15, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)
	let roundTripped = EventPositionMath.date(
		atYOffset: offset,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(roundTripped == eventStart)
}

@Test func `date(atYOffset:) resolves a negative offset to a time before rangeStart`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	let referenceDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let date = EventPositionMath.date(
		atYOffset: -60,
		referenceDate: referenceDate,
		rangeStart: 7,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(date == calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day)!)
}

@Test func `date(atYOffset:) round-trips with a non-zero rangeStart`() throws {
	let calendar = Calendar.current
	let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!
	let referenceDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 7,
		hourHeight: hourHeight,
		calendar: calendar
	)
	let roundTripped = EventPositionMath.date(
		atYOffset: offset,
		referenceDate: referenceDate,
		rangeStart: 7,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(roundTripped == eventStart)
}

// MARK: - DST

private func losAngelesCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
	return calendar
}

@Test func `yOffset places a 16:00 event at hour 16 on the US spring-forward day`() throws {
	let calendar = losAngelesCalendar()
	// 2026-03-08 is a US "spring forward" day: 2:00 AM -> 3:00 AM, a 23-hour local day.
	let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
	let referenceDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(offset == 16 * hourHeight)
}

@Test func `date(atYOffset:) round-trips across the US spring-forward day`() throws {
	let calendar = losAngelesCalendar()
	let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
	let referenceDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
	let eventStart = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: day)!
	let hourHeight: CGFloat = 60

	let offset = EventPositionMath.yOffset(
		of: eventStart,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)
	let roundTripped = EventPositionMath.date(
		atYOffset: offset,
		referenceDate: referenceDate,
		rangeStart: 0,
		hourHeight: hourHeight,
		calendar: calendar
	)

	#expect(roundTripped == eventStart)
}
