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

		var columns: [[TimelineLayoutItem]] = []
		for i in layoutItems.indices {
			var placed = false
			for colIndex in columns.indices {
				guard let lastInColumn = columns[colIndex].last else { continue }
				if layoutItems[i].item.startDate >= lastInColumn.item.endDate {
					columns[colIndex].append(layoutItems[i])
					layoutItems[i].column = colIndex
					placed = true
					break
				}
			}
			if !placed {
				layoutItems[i].column = columns.count
				columns.append([layoutItems[i]])
			}
		}

		let totalCols = max(columns.count, 1)
		for i in layoutItems.indices {
			layoutItems[i].totalColumns = totalCols
		}

		return layoutItems
	}
}
