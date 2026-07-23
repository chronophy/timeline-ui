import Foundation
import SwiftUI
import Testing

@testable import TimelineUI

private func item() -> TimelineItem {
	TimelineItem(
		title: "Event",
		startDate: Date(),
		endDate: Date().addingTimeInterval(3600),
		color: .blue
	)
}

@Test func `resolved keeps a current id that still matches an item`() throws {
	let matching = item()
	let items = [matching, item()]

	let resolved = EditingItemReset.resolved(current: matching.id, items: items)

	#expect(resolved == matching.id)
}

@Test func `resolved clears a current id that matches nothing in items`() throws {
	let staleID = UUID()
	let items = [item(), item()]

	let resolved = EditingItemReset.resolved(current: staleID, items: items)

	#expect(resolved == nil)
}

@Test func `resolved clears a current id when items is empty`() throws {
	let staleID = UUID()

	let resolved = EditingItemReset.resolved(current: staleID, items: [])

	#expect(resolved == nil)
}

@Test func `resolved leaves nil unchanged regardless of items`() throws {
	let resolved = EditingItemReset.resolved(current: nil, items: [item()])

	#expect(resolved == nil)
}
