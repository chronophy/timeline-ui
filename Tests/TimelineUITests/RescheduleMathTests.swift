import Foundation
import Testing

@testable import TimelineUI

private func utcCalendar() -> Calendar {
	var calendar = Calendar(identifier: .gregorian)
	calendar.locale = Locale(identifier: "en_US_POSIX")
	calendar.timeZone = TimeZone(identifier: "UTC")!
	return calendar
}

private func time(_ hour: Int, _ minute: Int, calendar: Calendar) -> Date {
	calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: hour, minute: minute))!
}

// MARK: - snapMinutes

@Test func `snapMinutes returns 60 for a full day and just above the upper boundary`() throws {
	#expect(RescheduleMath.snapMinutes(visibleHours: 24) == 60)
	#expect(RescheduleMath.snapMinutes(visibleHours: 16) == 60)
}

@Test func `snapMinutes returns 30 between the 16 and 10 hour boundaries`() throws {
	#expect(RescheduleMath.snapMinutes(visibleHours: 15.9) == 30)
	#expect(RescheduleMath.snapMinutes(visibleHours: 12) == 30)
	#expect(RescheduleMath.snapMinutes(visibleHours: 10) == 30)
}

@Test func `snapMinutes returns 15 between the 10 and 6 hour boundaries`() throws {
	#expect(RescheduleMath.snapMinutes(visibleHours: 9.9) == 15)
	#expect(RescheduleMath.snapMinutes(visibleHours: 8) == 15)
	#expect(RescheduleMath.snapMinutes(visibleHours: 6) == 15)
}

@Test func `snapMinutes returns 5 below the 6 hour boundary`() throws {
	#expect(RescheduleMath.snapMinutes(visibleHours: 5.9) == 5)
	#expect(RescheduleMath.snapMinutes(visibleHours: 4) == 5)
	#expect(RescheduleMath.snapMinutes(visibleHours: 0) == 5)
}

// MARK: - snapped

@Test func `snapped rounds down to the nearer boundary`() throws {
	let calendar = utcCalendar()
	let snapped = RescheduleMath.snapped(time(10, 7, calendar: calendar), toNearestMinutes: 15, calendar: calendar)
	#expect(snapped == time(10, 0, calendar: calendar))
}

@Test func `snapped rounds up to the nearer boundary`() throws {
	let calendar = utcCalendar()
	let snapped = RescheduleMath.snapped(time(10, 8, calendar: calendar), toNearestMinutes: 15, calendar: calendar)
	#expect(snapped == time(10, 15, calendar: calendar))
}

@Test func `snapped leaves an already-aligned time unchanged`() throws {
	let calendar = utcCalendar()
	let snapped = RescheduleMath.snapped(time(10, 30, calendar: calendar), toNearestMinutes: 15, calendar: calendar)
	#expect(snapped == time(10, 30, calendar: calendar))
}

@Test func `snapped rolls over into the next day`() throws {
	let calendar = utcCalendar()
	let snapped = RescheduleMath.snapped(time(23, 50, calendar: calendar), toNearestMinutes: 60, calendar: calendar)
	let expected = calendar.date(
		byAdding: .day,
		value: 1,
		to: calendar.startOfDay(for: time(23, 50, calendar: calendar))
	)!
	#expect(snapped == expected)
}

// MARK: - movedDates

@Test func `movedDates preserves duration exactly across a snap`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(11, 0, calendar: calendar)

	// hourHeight of 60 means 1pt == 1 minute; +65pt moves 65 minutes, snapping to the nearest 15.
	let moved = RescheduleMath.movedDates(
		originalStart: start,
		originalEnd: end,
		translationY: 65,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(moved.start == time(11, 0, calendar: calendar))
	#expect(moved.end.timeIntervalSince(moved.start) == end.timeIntervalSince(start))
}

@Test func `movedDates returns the original dates unchanged at zero translation`() throws {
	let calendar = utcCalendar()
	let start = time(10, 7, calendar: calendar)
	let end = time(10, 37, calendar: calendar)

	let moved = RescheduleMath.movedDates(
		originalStart: start,
		originalEnd: end,
		translationY: 0,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(moved.start == start)
	#expect(moved.end == end)
}

// MARK: - resizedStart / resizedEnd

@Test func `resizedStart produces zero displacement at zero translation even for a short event`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 10, calendar: calendar)

	let resized = RescheduleMath.resizedStart(
		originalStart: start,
		originalEnd: end,
		translationY: 0,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == start)
}

@Test func `resizedEnd produces zero displacement at zero translation even for a short event`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 10, calendar: calendar)

	let resized = RescheduleMath.resizedEnd(
		originalStart: start,
		originalEnd: end,
		translationY: 0,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == end)
}

@Test func `resizedStart clamps to the event's own duration when the snap increment would shrink it further`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 10, calendar: calendar)  // 10 minute event, shorter than the 15-minute snap.

	// Dragging start later (toward the end) should be fully clamped: the event is already at the
	// minimum allowed duration (its own 10 minutes), so start cannot move later at all.
	let resized = RescheduleMath.resizedStart(
		originalStart: start,
		originalEnd: end,
		translationY: 20,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == start)
}

@Test func `resizedStart clamps to one snap increment before the end for a longer event`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 30, calendar: calendar)  // 30 minute event.

	let resized = RescheduleMath.resizedStart(
		originalStart: start,
		originalEnd: end,
		translationY: 25,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == time(10, 15, calendar: calendar))
}

@Test func `resizedEnd clamps to the event's own duration when the snap increment would shrink it further`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 10, calendar: calendar)

	let resized = RescheduleMath.resizedEnd(
		originalStart: start,
		originalEnd: end,
		translationY: -20,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == end)
}

@Test func `resizedEnd allows shrinking down to one snap increment for a longer event`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 30, calendar: calendar)

	let resized = RescheduleMath.resizedEnd(
		originalStart: start,
		originalEnd: end,
		translationY: -25,
		hourHeight: 60,
		snapMinutes: 15,
		calendar: calendar
	)

	#expect(resized == time(10, 15, calendar: calendar))
}

// MARK: - orderedRange

@Test func `orderedRange leaves an already-ordered pair unchanged`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(11, 0, calendar: calendar)

	let ordered = RescheduleMath.orderedRange(start, end, minimumDuration: 900)

	#expect(ordered.start == start)
	#expect(ordered.end == end)
}

@Test func `orderedRange swaps a reversed pair`() throws {
	let calendar = utcCalendar()
	let earlier = time(10, 0, calendar: calendar)
	let later = time(11, 0, calendar: calendar)

	let ordered = RescheduleMath.orderedRange(later, earlier, minimumDuration: 900)

	#expect(ordered.start == earlier)
	#expect(ordered.end == later)
}

@Test func `orderedRange clamps a too-short pair up to the minimum duration`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 5, calendar: calendar)

	let ordered = RescheduleMath.orderedRange(start, end, minimumDuration: 900)

	#expect(ordered.start == start)
	#expect(ordered.end == time(10, 15, calendar: calendar))
}

@Test func `orderedRange passes through a pair exactly at the minimum duration unchanged`() throws {
	let calendar = utcCalendar()
	let start = time(10, 0, calendar: calendar)
	let end = time(10, 15, calendar: calendar)

	let ordered = RescheduleMath.orderedRange(start, end, minimumDuration: 900)

	#expect(ordered.start == start)
	#expect(ordered.end == end)
}

// MARK: - TimelineItem.rescheduled

@Test func `rescheduled preserves every field other than the dates`() throws {
	let original = TimelineItem(
		title: "Team Meeting",
		startDate: time(10, 0, calendar: utcCalendar()),
		endDate: time(11, 0, calendar: utcCalendar()),
		isAllDay: false,
		color: .blue,
		location: "Room 101",
		isPrimary: true,
		isEditable: true
	)

	let newStart = time(14, 0, calendar: utcCalendar())
	let newEnd = time(15, 0, calendar: utcCalendar())
	let rescheduled = original.rescheduled(startDate: newStart, endDate: newEnd)

	#expect(rescheduled.id == original.id)
	#expect(rescheduled.title == original.title)
	#expect(rescheduled.startDate == newStart)
	#expect(rescheduled.endDate == newEnd)
	#expect(rescheduled.isAllDay == original.isAllDay)
	#expect(rescheduled.location == original.location)
	#expect(rescheduled.isPrimary == original.isPrimary)
	#expect(rescheduled.isEditable == original.isEditable)
}
