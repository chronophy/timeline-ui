import Foundation
import Testing

@testable import TimelineUI

@Test func `clampedHourHeight clamps to the minimum`() throws {
	let height = ZoomAnchor.clampedHourHeight(base: 60, gestureScale: 0.1, min: 24, max: 200)
	#expect(height == 24)
}

@Test func `clampedHourHeight clamps to the maximum`() throws {
	let height = ZoomAnchor.clampedHourHeight(base: 60, gestureScale: 10, min: 24, max: 200)
	#expect(height == 200)
}

@Test func `clampedHourHeight scales within bounds`() throws {
	let height = ZoomAnchor.clampedHourHeight(base: 60, gestureScale: 2, min: 24, max: 200)
	#expect(height == 120)
}

@Test func `anchorHour and scrollOffsetY are inverses`() throws {
	let hourHeight: CGFloat = 80
	let viewportHeight: CGFloat = 600
	let anchor = ZoomAnchor.anchorHour(scrollOffsetY: 240, viewportHeight: viewportHeight, hourHeight: hourHeight)
	let offset = ZoomAnchor.scrollOffsetY(forAnchorHour: anchor, hourHeight: hourHeight, viewportHeight: viewportHeight)
	#expect(offset == 240)
}

@Test func `zooming keeps the anchor hour's screen position constant`() throws {
	let viewportHeight: CGFloat = 600
	let originalHourHeight: CGFloat = 60
	let scrollOffsetY: CGFloat = 300

	let anchor = ZoomAnchor.anchorHour(
		scrollOffsetY: scrollOffsetY,
		viewportHeight: viewportHeight,
		hourHeight: originalHourHeight
	)

	let zoomedHourHeight = ZoomAnchor.clampedHourHeight(base: originalHourHeight, gestureScale: 2, min: 24, max: 200)
	let zoomedScrollOffsetY = ZoomAnchor.scrollOffsetY(
		forAnchorHour: anchor,
		hourHeight: zoomedHourHeight,
		viewportHeight: viewportHeight
	)

	let screenPositionBefore = anchor * originalHourHeight - scrollOffsetY
	let screenPositionAfter = anchor * zoomedHourHeight - zoomedScrollOffsetY
	#expect(screenPositionBefore == screenPositionAfter)
}
