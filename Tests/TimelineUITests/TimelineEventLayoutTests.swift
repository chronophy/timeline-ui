import Foundation
import SwiftUI
import Testing

@testable import TimelineUI

private func utcCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "UTC")!
	return calendar
}

private func time(_ hour: Int, _ minute: Int) -> Date {
	utcCalendar().date(from: DateComponents(year: 2026, month: 7, day: 21, hour: hour, minute: minute))!
}

private func item(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int) -> TimelineItem {
	TimelineItem(
		title: "Event",
		startDate: time(startHour, startMinute),
		endDate: time(endHour, endMinute),
		color: .blue
	)
}

@Test func `build gives a single overlapping pair totalColumns matching only its own group`() throws {
	// A pair overlapping only each other (9:00-10:00 / 9:30-10:30, needs 2 columns) alongside an
	// unrelated 3-way overlapping cluster later the same day (14:00-15:00 / 14:15-15:15 /
	// 14:30-15:30, needs 3 columns) — the pair must not inherit the cluster's wider column count.
	let pairA = item(9, 0, 10, 0)
	let pairB = item(9, 30, 10, 30)
	let clusterA = item(14, 0, 15, 0)
	let clusterB = item(14, 15, 15, 15)
	let clusterC = item(14, 30, 15, 30)

	let layout = TimelineEventLayout.build(items: [pairA, pairB, clusterA, clusterB, clusterC])

	let pairLayout = layout.filter { $0.id == pairA.id || $0.id == pairB.id }
	let clusterLayout = layout.filter { $0.id == clusterA.id || $0.id == clusterB.id || $0.id == clusterC.id }

	#expect(pairLayout.allSatisfy { $0.totalColumns == 2 })
	#expect(clusterLayout.allSatisfy { $0.totalColumns == 3 })
}

@Test func `build assigns distinct columns within an overlapping pair`() throws {
	let pairA = item(9, 0, 10, 0)
	let pairB = item(9, 30, 10, 30)

	let layout = TimelineEventLayout.build(items: [pairA, pairB])

	let columnA = layout.first { $0.id == pairA.id }?.column
	let columnB = layout.first { $0.id == pairB.id }?.column

	#expect(columnA != columnB)
}

@Test func `build gives non-overlapping items a single column each`() throws {
	let morning = item(9, 0, 10, 0)
	let afternoon = item(14, 0, 15, 0)

	let layout = TimelineEventLayout.build(items: [morning, afternoon])

	#expect(layout.allSatisfy { $0.totalColumns == 1 && $0.column == 0 })
}

@Test func `build matches the day-wide column count when there's only a single overlap group`() throws {
	let a = item(9, 0, 10, 0)
	let b = item(9, 15, 10, 15)
	let c = item(9, 30, 10, 30)

	let layout = TimelineEventLayout.build(items: [a, b, c])

	#expect(layout.allSatisfy { $0.totalColumns == 3 })
}

@Test func `build handles an empty items array`() throws {
	let layout = TimelineEventLayout.build(items: [])

	#expect(layout.isEmpty)
}
