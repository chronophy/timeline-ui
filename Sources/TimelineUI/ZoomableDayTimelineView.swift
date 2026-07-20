import SwiftUI

/// Pure anchor math for pinch-to-zoom: keeps whichever hour sits at the
/// viewport's vertical center fixed on screen as `hourHeight` changes.
enum ZoomAnchor {
	static func clampedHourHeight(base: CGFloat, gestureScale: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
		Swift.min(Swift.max(base * gestureScale, min), max)
	}

	static func anchorHour(scrollOffsetY: CGFloat, viewportHeight: CGFloat, hourHeight: CGFloat) -> CGFloat {
		(scrollOffsetY + viewportHeight / 2) / hourHeight
	}

	static func scrollOffsetY(forAnchorHour anchorHour: CGFloat, hourHeight: CGFloat, viewportHeight: CGFloat)
		-> CGFloat
	{
		anchorHour * hourHeight - viewportHeight / 2
	}
}

/// A full-day timeline view with pinch-to-zoom on the hour grid.
///
/// Unlike ``DayTimelineView``, which shrinks or expands the visible hour range to
/// avoid scrolling, `ZoomableDayTimelineView` always lays out the full 24-hour day
/// inside a `ScrollView` and lets the user pinch to change the vertical scale
/// (the distance between hour lines). Zooming keeps the hour centered in the
/// viewport fixed on screen.
///
/// ```swift
/// ZoomableDayTimelineView(items: events)
///     .frame(height: 500)
/// ```
public struct ZoomableDayTimelineView: View {
	/// The events to display on the timeline.
	public let items: [TimelineItem]

	/// Called when the user taps an event block, with the tapped item.
	public let onSelect: ((TimelineItem) -> Void)?

	/// Creates a zoomable day timeline view.
	///
	/// - Parameters:
	///   - items: The events to display. Pass an empty array to show just the hour grid.
	///     The view scrolls to the first event's time, or the current time if no events are provided.
	///   - onSelect: Called with the tapped item when the user taps an event block. Defaults to `nil`,
	///     which leaves event blocks non-interactive.
	///   - initialHourHeight: The vertical scale (points per hour) to start at, before any pinching.
	///     Clamped to the same range the pinch gesture allows. Defaults to `60`. Exposed mainly so
	///     previews/tests/screenshots can pin a zoom level without simulating a gesture.
	public init(
		items: [TimelineItem],
		onSelect: ((TimelineItem) -> Void)? = nil,
		initialHourHeight: CGFloat = 60
	) {
		self.items = items
		self.onSelect = onSelect
		_hourHeight = State(
			initialValue: ZoomAnchor.clampedHourHeight(
				base: initialHourHeight,
				gestureScale: 1,
				min: Self.minHourHeight,
				max: Self.maxHourHeight
			)
		)
	}

	@State private var hourHeight: CGFloat
	@State private var activeAnchorHour: CGFloat?
	@State private var scrollOffsetY: CGFloat = 0
	@State private var scrollPosition = ScrollPosition()
	@State private var hasScrolledToInitialPosition = false
	@GestureState private var pinchScale: CGFloat = 1

	private static let minHourHeight: CGFloat = 24
	private static let maxHourHeight: CGFloat = 200
	private let labelWidth: CGFloat = 48
	private let hours = Array(0...23)

	private var effectiveHourHeight: CGFloat {
		ZoomAnchor.clampedHourHeight(
			base: hourHeight,
			gestureScale: pinchScale,
			min: Self.minHourHeight,
			max: Self.maxHourHeight
		)
	}

	private var baseDate: Date {
		items.first(where: { $0.isPrimary })?.startDate ?? items.first?.startDate ?? Date()
	}

	private var allDayItems: [TimelineItem] {
		items.filter { $0.isAllDay }
	}

	private var timedItems: [TimelineItem] {
		items.filter { !$0.isAllDay }
	}

	private func initialAnchorHour() -> CGFloat {
		let calendar = Calendar.current
		guard let firstTimed = timedItems.first else {
			let hour = calendar.component(.hour, from: baseDate)
			return CGFloat(max(0, hour - 1))
		}

		var earliestHour = calendar.component(.hour, from: firstTimed.startDate)
		for item in timedItems {
			earliestHour = min(earliestHour, calendar.component(.hour, from: item.startDate))
		}
		return CGFloat(max(0, earliestHour - 1))
	}

	public var body: some View {
		GeometryReader { geometry in
			let allDayHeight = allDayItems.isEmpty ? 0 : CGFloat(min(allDayItems.count, 3)) * 24 + 16
			let viewportHeight = geometry.size.height - allDayHeight - 16
			let contentWidth = geometry.size.width - labelWidth

			VStack(alignment: .leading, spacing: 8) {
				if !allDayItems.isEmpty {
					allDaySection
				}

				ScrollView(.vertical) {
					ZStack(alignment: .topLeading) {
						hourLines(contentWidth: contentWidth)

						ForEach(TimelineEventLayout.build(items: timedItems)) { layoutItem in
							TimelineEventBlock(
								item: layoutItem.item,
								column: layoutItem.column,
								totalColumns: layoutItem.totalColumns,
								hourHeight: effectiveHourHeight,
								rangeStart: 0,
								baseDate: baseDate,
								labelWidth: labelWidth,
								contentWidth: contentWidth,
								onSelect: onSelect
							)
						}
					}
					.frame(height: effectiveHourHeight * 24)
				}
				.scrollPosition($scrollPosition)
				.onScrollGeometryChange(for: CGFloat.self) { geometry in
					geometry.contentOffset.y
				} action: { _, newValue in
					scrollOffsetY = newValue
				}
				.gesture(magnificationGesture(viewportHeight: viewportHeight))
				.onAppear {
					guard !hasScrolledToInitialPosition else { return }
					hasScrolledToInitialPosition = true
					let targetY = ZoomAnchor.scrollOffsetY(
						forAnchorHour: initialAnchorHour(),
						hourHeight: effectiveHourHeight,
						viewportHeight: viewportHeight
					)
					scrollPosition.scrollTo(y: max(0, targetY))
				}
			}
			.padding(.vertical, 8)
		}
	}

	private func magnificationGesture(viewportHeight: CGFloat) -> some Gesture {
		MagnificationGesture()
			.updating($pinchScale) { value, state, _ in
				state = value
			}
			.onChanged { value in
				if activeAnchorHour == nil {
					activeAnchorHour = ZoomAnchor.anchorHour(
						scrollOffsetY: scrollOffsetY,
						viewportHeight: viewportHeight,
						hourHeight: hourHeight
					)
				}
				guard let anchor = activeAnchorHour else { return }
				let effectiveHeight = ZoomAnchor.clampedHourHeight(
					base: hourHeight,
					gestureScale: value,
					min: Self.minHourHeight,
					max: Self.maxHourHeight
				)
				let targetY = ZoomAnchor.scrollOffsetY(
					forAnchorHour: anchor,
					hourHeight: effectiveHeight,
					viewportHeight: viewportHeight
				)
				scrollPosition.scrollTo(y: max(0, targetY))
			}
			.onEnded { value in
				hourHeight = ZoomAnchor.clampedHourHeight(
					base: hourHeight,
					gestureScale: value,
					min: Self.minHourHeight,
					max: Self.maxHourHeight
				)
				activeAnchorHour = nil
			}
	}

	private var allDaySection: some View {
		VStack(alignment: .leading, spacing: 4) {
			ForEach(allDayItems.prefix(3)) { item in
				HStack(spacing: 6) {
					RoundedRectangle(cornerRadius: 2)
						.fill(item.color)
						.frame(width: 4)
					Text(item.title)
						.font(.caption)
						.lineLimit(1)
				}
				.frame(height: 20)
			}
			if allDayItems.count > 3 {
				Text("+\(allDayItems.count - 3) more")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, labelWidth + 8)
	}

	private func hourLines(contentWidth: CGFloat) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(hours, id: \.self) { hour in
				HStack(alignment: .top, spacing: 0) {
					Text(formatHour(hour))
						.font(.caption)
						.foregroundStyle(.secondary)
						.frame(width: labelWidth, alignment: .trailing)
						.padding(.trailing, 8)
						.offset(y: -7)

					Rectangle()
						.fill(.quaternary)
						.frame(height: 1)
						.frame(maxWidth: .infinity)
				}
				.frame(height: effectiveHourHeight)
			}
		}
	}

	private func formatHour(_ hour: Int) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm"
		let calendar = Calendar.current
		let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
		return formatter.string(from: date)
	}
}

#Preview {
	let base = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
	let items = [
		TimelineItem(
			title: "New Event",
			startDate: base.addingTimeInterval(1800),
			endDate: base.addingTimeInterval(5400),
			color: .accentColor,
			location: "Main Office",
			isPrimary: true
		),
		TimelineItem(
			title: "Existing Meeting",
			startDate: base,
			endDate: base.addingTimeInterval(3600),
			color: .red,
			location: "Room 101",
			isPrimary: false
		),
	]

	return ZoomableDayTimelineView(items: items)
		.frame(height: 500)
		.padding()
}
