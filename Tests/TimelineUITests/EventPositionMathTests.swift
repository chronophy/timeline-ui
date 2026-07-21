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
