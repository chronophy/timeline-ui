import Foundation

struct TimelineLayoutItem: Identifiable {
	let id: UUID
	let item: TimelineItem
	var column: Int = 0
	var totalColumns: Int = 1
}

enum TimelineEventLayout {
	static func build(items: [TimelineItem]) -> [TimelineLayoutItem] {
		var layoutItems = items.map { TimelineLayoutItem(id: $0.id, item: $0) }
		layoutItems.sort { $0.item.startDate < $1.item.startDate }

		// Column assignment (which column an item lands in) and the `totalColumns` stamp (how many
		// columns wide the row is) both run per connected overlap group — a maximal run of items
		// transitively overlapping via a shared chain, tracked below with a running `groupEnd`
		// watermark — rather than once globally across the whole day. Otherwise two events
		// overlapping only each other would inherit the day's peak concurrency (e.g. rendering at
		// 1/3 width with empty gaps) just because an unrelated cluster of 3 overlapping events
		// exists elsewhere the same day.
		var groupStart = 0
		var groupEnd: Date?
		for i in layoutItems.indices {
			if let currentGroupEnd = groupEnd, layoutItems[i].item.startDate < currentGroupEnd {
				groupEnd = max(currentGroupEnd, layoutItems[i].item.endDate)
			} else {
				if groupEnd != nil {
					assignColumns(&layoutItems, range: groupStart..<i)
				}
				groupStart = i
				groupEnd = layoutItems[i].item.endDate
			}
		}
		if !layoutItems.isEmpty {
			assignColumns(&layoutItems, range: groupStart..<layoutItems.count)
		}

		return layoutItems
	}

	private static func assignColumns(_ layoutItems: inout [TimelineLayoutItem], range: Range<Int>) {
		var columns: [[Int]] = []
		for i in range {
			var placed = false
			for colIndex in columns.indices {
				guard let lastIndex = columns[colIndex].last else { continue }
				if layoutItems[i].item.startDate >= layoutItems[lastIndex].item.endDate {
					columns[colIndex].append(i)
					layoutItems[i].column = colIndex
					placed = true
					break
				}
			}
			if !placed {
				layoutItems[i].column = columns.count
				columns.append([i])
			}
		}

		let totalCols = max(columns.count, 1)
		for i in range {
			layoutItems[i].totalColumns = totalCols
		}
	}
}
