import SwiftUI

/// A ``WeekStripView`` pinned above a scrollable ``ZoomableDayTimelineView``, coordinating
/// the selected day between them.
///
/// ```swift
/// @State private var selectedDate = Date()
///
/// WeekTimelineView(items: eventsForSelectedDay, selectedDate: $selectedDate)
/// ```
///
/// `items` should already be filtered to `selectedDate` — the same convention
/// ``ZoomableDayTimelineView`` uses. Observe `selectedDate` (tapping a day, swiping, or
/// using the chevron buttons updates it) and supply new `items` for the newly selected day.
///
/// > Note: The timeline's scroll position and zoom level are preserved across day changes,
/// > matching how Apple Calendar keeps your scroll position stable as you page through days.
/// > This relies on `WeekTimelineView` itself keeping a stable identity in your view hierarchy.
/// > If it sits behind a loading-state switch that gets rebuilt while the new day's data loads,
/// > that state resets along with everything else — use
/// > ``init(items:selectedDate:hourHeight:onSelect:calendar:)`` to own the zoom level yourself
/// > in a place that survives the rebuild.
public struct WeekTimelineView: View {
	/// The events to display for the currently selected day.
	public let items: [TimelineItem]

	@Binding var selectedDate: Date

	/// Called when the user taps an event block, with the tapped item.
	public let onSelect: ((TimelineItem) -> Void)?

	/// Called when the user moves or resizes an item by dragging, with the rescheduled item.
	/// Only items with `TimelineItem.isEditable == true` can be dragged.
	public let onReschedule: ((TimelineItem) -> Void)?

	let calendar: Calendar

	@State private var internalHourHeight: CGFloat
	private let externalHourHeight: Binding<CGFloat>?

	/// The zoom level (points per hour). Backed by `externalHourHeight` when the caller supplies
	/// one (see the `hourHeight:` init below), otherwise by `internalHourHeight`.
	private var hourHeight: Binding<CGFloat> {
		externalHourHeight ?? Binding(get: { internalHourHeight }, set: { internalHourHeight = $0 })
	}

	/// Creates a week timeline view that manages its own zoom level internally.
	///
	/// - Parameters:
	///   - items: The events to display, already filtered to `selectedDate`.
	///   - selectedDate: The currently selected day. Updated when the user taps a day,
	///     swipes, or uses the chevron buttons in the week strip.
	///   - onSelect: Called with the tapped item when the user taps an event block. Defaults
	///     to `nil`, which leaves event blocks non-interactive.
	///   - onReschedule: Called with the updated item when the user moves or resizes an editable
	///     event block by dragging. Defaults to `nil`, which leaves event blocks non-draggable.
	///   - initialHourHeight: The vertical scale (points per hour) the timeline starts at,
	///     before any pinching. Defaults to `60`.
	///   - calendar: The calendar used by the week strip to determine week boundaries,
	///     weekday order, and weekday symbols. Defaults to `Calendar.current`.
	public init(
		items: [TimelineItem],
		selectedDate: Binding<Date>,
		onSelect: ((TimelineItem) -> Void)? = nil,
		onReschedule: ((TimelineItem) -> Void)? = nil,
		initialHourHeight: CGFloat = 60,
		calendar: Calendar = .current
	) {
		self.items = items
		self._selectedDate = selectedDate
		self.onSelect = onSelect
		self.onReschedule = onReschedule
		self.calendar = calendar
		self.externalHourHeight = nil
		_internalHourHeight = State(
			initialValue: ZoomAnchor.clampedHourHeight(
				base: initialHourHeight,
				gestureScale: 1,
				min: ZoomableDayTimelineView.minHourHeight,
				max: ZoomableDayTimelineView.maxHourHeight
			)
		)
	}

	/// Creates a week timeline view whose zoom level is externally owned.
	///
	/// Use this if `WeekTimelineView` itself can be recreated by your app (e.g. it sits behind
	/// a loading-state switch that gets rebuilt when the selected day's data reloads) — own a
	/// `@State private var hourHeight: CGFloat = 60` in a stable ancestor view that survives
	/// that rebuild, and pass it here, the same way you already own `selectedDate`.
	///
	/// - Parameters:
	///   - items: The events to display, already filtered to `selectedDate`.
	///   - selectedDate: The currently selected day. Updated when the user taps a day,
	///     swipes, or uses the chevron buttons in the week strip.
	///   - hourHeight: The vertical scale (points per hour), owned by the caller. Pinching
	///     updates it live; the caller is responsible for persisting it.
	///   - onSelect: Called with the tapped item when the user taps an event block. Defaults
	///     to `nil`, which leaves event blocks non-interactive.
	///   - onReschedule: Called with the updated item when the user moves or resizes an editable
	///     event block by dragging. Defaults to `nil`, which leaves event blocks non-draggable.
	///   - calendar: The calendar used by the week strip to determine week boundaries,
	///     weekday order, and weekday symbols. Defaults to `Calendar.current`.
	public init(
		items: [TimelineItem],
		selectedDate: Binding<Date>,
		hourHeight: Binding<CGFloat>,
		onSelect: ((TimelineItem) -> Void)? = nil,
		onReschedule: ((TimelineItem) -> Void)? = nil,
		calendar: Calendar = .current
	) {
		self.items = items
		self._selectedDate = selectedDate
		self.onSelect = onSelect
		self.onReschedule = onReschedule
		self.calendar = calendar
		self.externalHourHeight = hourHeight
		_internalHourHeight = State(initialValue: hourHeight.wrappedValue)
	}

	public var body: some View {
		VStack(spacing: 0) {
			WeekStripView(selectedDate: $selectedDate, calendar: calendar)

			Divider()

			ZoomableDayTimelineView(
				items: items,
				hourHeight: hourHeight,
				onSelect: onSelect,
				onReschedule: onReschedule
			)
		}
	}
}

#Preview {
	struct PreviewWrapper: View {
		@State private var selectedDate = Date()

		private var items: [TimelineItem] {
			let base = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate)!
			return [
				TimelineItem(
					title: "Team Meeting",
					startDate: base,
					endDate: base.addingTimeInterval(3600),
					color: .blue,
					location: "Conference Room A",
					isPrimary: true
				)
			]
		}

		var body: some View {
			WeekTimelineView(items: items, selectedDate: $selectedDate)
				.frame(height: 500)
		}
	}

	return PreviewWrapper()
}
