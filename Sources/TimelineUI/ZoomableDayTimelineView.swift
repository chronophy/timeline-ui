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

/// Pure, testable logic for clearing a stale `editingItemID`.
///
/// `ZoomableDayTimelineView` keeps a stable identity as `WeekTimelineView` pages between days (so
/// scroll/zoom position persists), which means `editingItemID` isn't automatically reset when
/// `items` is swapped for a new day's events. A leftover id matching nothing in the new day's
/// `items` wouldn't show any edit UI (nothing matches it), but `scrollDisabled` is gated purely on
/// `editingItemID != nil`, so scroll would stay frozen with no visible cause and no way to
/// un-freeze it short of the id happening to be reused.
enum EditingItemReset {
	static func resolved(current: UUID?, items: [TimelineItem]) -> UUID? {
		guard let current, items.contains(where: { $0.id == current }) else { return nil }
		return current
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

	/// Called when the user moves or resizes an item by dragging, with the rescheduled item.
	/// Only items with `TimelineItem.isEditable == true` can be dragged; this is called
	/// once per gesture, on release, not continuously while dragging.
	public let onReschedule: ((TimelineItem) -> Void)?

	/// Called when the user creates a new event by long-pressing (iOS) or click-dragging (macOS)
	/// empty background, with the snapped, correctly-ordered start and end dates. Defaults to
	/// `nil`, which leaves empty background non-interactive.
	public let onCreate: ((_ start: Date, _ end: Date) -> Void)?

	/// Called when the user taps the delete affordance shown on an editable event block while
	/// it's in edit mode, with the item to delete. Only items with `TimelineItem.isEditable == true`
	/// show this affordance. Fires immediately, with no confirmation — hosts that want to confirm
	/// before removing data are responsible for that themselves. Deleting also exits edit mode, so
	/// `onEditEnd` fires immediately before this — hosts don't need a separate rule for "the user
	/// deleted it" vs. "the user finished editing it." Defaults to `nil`, which leaves event blocks
	/// without a delete affordance.
	public let onDelete: ((TimelineItem) -> Void)?

	/// Called once when the user enters edit mode for an item, with its state at that moment,
	/// before any edits happen this session. Lets a host prepare for a batch of upcoming edits
	/// (e.g. snapshot current state for a possible revert, show an "editing" indicator) without
	/// doing that work on every individual drag. Defaults to `nil`.
	public let onEditStart: ((TimelineItem) -> Void)?

	/// Called once when the user exits edit mode for an item — tapping elsewhere, tapping another
	/// event, or otherwise leaving edit mode — with the item reflecting its latest edits. Useful
	/// for one-shot wrap-up work that shouldn't run after every individual drag — e.g. a single
	/// "saved" indicator after a user drags the start handle, then the end handle, rather than one
	/// per handle. `onReschedule`/`onDelete` already cover persisting each edit as it happens; this
	/// (and `onEditStart`) are notifications only, and aren't guaranteed to fire if the view is torn
	/// down without an explicit exit (e.g. the host navigates away mid-edit). Defaults to `nil`.
	public let onEditEnd: ((TimelineItem) -> Void)?

	/// Creates a zoomable day timeline view that manages its own zoom level internally.
	///
	/// - Parameters:
	///   - items: The events to display. Pass an empty array to show just the hour grid.
	///     The view scrolls to the first event's time, or the current time if no events are provided.
	///   - onSelect: Called with the tapped item when the user taps an event block. Defaults to `nil`,
	///     which leaves event blocks non-interactive.
	///   - onReschedule: Called with the updated item when the user moves or resizes an editable
	///     event block by dragging. Defaults to `nil`, which leaves event blocks non-draggable.
	///   - onCreate: Called with the start and end dates when the user creates a new event on empty
	///     background. Defaults to `nil`, which leaves empty background non-interactive.
	///   - onDelete: Called with the item when the user taps an editable event block's delete
	///     affordance. Also exits edit mode, firing `onEditEnd` immediately before this. Defaults
	///     to `nil`, which leaves event blocks without a delete affordance.
	///   - onEditStart: Called once with the item's state when the user enters edit mode. Defaults
	///     to `nil`.
	///   - onEditEnd: Called once with the item's latest edits when the user exits edit mode.
	///     Defaults to `nil`.
	///   - initialHourHeight: The vertical scale (points per hour) to start at, before any pinching.
	///     Clamped to the same range the pinch gesture allows. Defaults to `60`. Exposed mainly so
	///     previews/tests/screenshots can pin a zoom level without simulating a gesture.
	///   - initialEditingItemID: The `id` of an item to start already in edit mode, matching
	///     `TimelineItem.id`. Defaults to `nil` (nothing starts in edit mode). Exposed mainly so
	///     previews/tests/screenshots can capture edit mode without simulating a gesture.
	public init(
		items: [TimelineItem],
		onSelect: ((TimelineItem) -> Void)? = nil,
		onReschedule: ((TimelineItem) -> Void)? = nil,
		onCreate: ((_ start: Date, _ end: Date) -> Void)? = nil,
		onDelete: ((TimelineItem) -> Void)? = nil,
		onEditStart: ((TimelineItem) -> Void)? = nil,
		onEditEnd: ((TimelineItem) -> Void)? = nil,
		initialHourHeight: CGFloat = 60,
		initialEditingItemID: UUID? = nil
	) {
		self.items = items
		self.onSelect = onSelect
		self.onReschedule = onReschedule
		self.onCreate = onCreate
		self.onDelete = onDelete
		self.onEditStart = onEditStart
		self.onEditEnd = onEditEnd
		self.externalHourHeight = nil
		_internalHourHeight = State(
			initialValue: ZoomAnchor.clampedHourHeight(
				base: initialHourHeight,
				gestureScale: 1,
				min: Self.minHourHeight,
				max: Self.maxHourHeight
			)
		)
		_editingItemID = State(initialValue: initialEditingItemID)
	}

	/// Creates a zoomable day timeline view whose zoom level is externally owned.
	///
	/// Use this when a host view needs the zoom level to survive this view being recreated —
	/// e.g. ``WeekTimelineView`` uses it so the zoom level stays the same when paging between days.
	///
	/// - Parameters:
	///   - items: The events to display. Pass an empty array to show just the hour grid.
	///     The view scrolls to the first event's time, or the current time if no events are provided.
	///   - hourHeight: The vertical scale (points per hour), owned by the caller. Pinching
	///     updates it live; the caller is responsible for persisting it across this view's lifetime.
	///   - onSelect: Called with the tapped item when the user taps an event block. Defaults to `nil`,
	///     which leaves event blocks non-interactive.
	///   - onReschedule: Called with the updated item when the user moves or resizes an editable
	///     event block by dragging. Defaults to `nil`, which leaves event blocks non-draggable.
	///   - onCreate: Called with the start and end dates when the user creates a new event on empty
	///     background. Defaults to `nil`, which leaves empty background non-interactive.
	///   - onDelete: Called with the item when the user taps an editable event block's delete
	///     affordance. Also exits edit mode, firing `onEditEnd` immediately before this. Defaults
	///     to `nil`, which leaves event blocks without a delete affordance.
	///   - onEditStart: Called once with the item's state when the user enters edit mode. Defaults
	///     to `nil`.
	///   - onEditEnd: Called once with the item's latest edits when the user exits edit mode.
	///     Defaults to `nil`.
	///   - initialEditingItemID: The `id` of an item to start already in edit mode, matching
	///     `TimelineItem.id`. Defaults to `nil` (nothing starts in edit mode). Exposed mainly so
	///     previews/tests/screenshots can capture edit mode without simulating a gesture.
	public init(
		items: [TimelineItem],
		hourHeight: Binding<CGFloat>,
		onSelect: ((TimelineItem) -> Void)? = nil,
		onReschedule: ((TimelineItem) -> Void)? = nil,
		onCreate: ((_ start: Date, _ end: Date) -> Void)? = nil,
		onDelete: ((TimelineItem) -> Void)? = nil,
		onEditStart: ((TimelineItem) -> Void)? = nil,
		onEditEnd: ((TimelineItem) -> Void)? = nil,
		initialEditingItemID: UUID? = nil
	) {
		self.items = items
		self.onSelect = onSelect
		self.onReschedule = onReschedule
		self.onCreate = onCreate
		self.onDelete = onDelete
		self.onEditStart = onEditStart
		self.onEditEnd = onEditEnd
		self.externalHourHeight = hourHeight
		_internalHourHeight = State(initialValue: hourHeight.wrappedValue)
		_editingItemID = State(initialValue: initialEditingItemID)
	}

	@State private var internalHourHeight: CGFloat
	private let externalHourHeight: Binding<CGFloat>?

	private var hourHeight: CGFloat {
		get { externalHourHeight?.wrappedValue ?? internalHourHeight }
		nonmutating set {
			if let externalHourHeight {
				externalHourHeight.wrappedValue = newValue
			} else {
				internalHourHeight = newValue
			}
		}
	}

	@State private var activeAnchorHour: CGFloat?
	@State private var scrollOffsetY: CGFloat = 0
	@State private var scrollPosition = ScrollPosition()
	@State private var hasScrolledToInitialPosition = false
	@State private var editingItemID: UUID?
	@GestureState private var pinchScale: CGFloat = 1
	#if os(macOS)
		@GestureState private var createDragState: (start: CGFloat, current: CGFloat)?
	#else
		/// Captured via `.onChanged` as soon as it's available, since `SequenceGesture`'s `.second`
		/// case can still report a `nil` drag value at `.onEnded` for a long-press released with
		/// essentially zero subsequent movement — a real risk for "long-press to create," unlike
		/// `TimelineEventBlock.entryGesture`'s use of this same shape, which only needs `.second(true, _)`
		/// to fire (no location required) and so never depended on the drag value being non-nil.
		@State private var createStartY: CGFloat?
	#endif

	static let minHourHeight: CGFloat = 24
	static let maxHourHeight: CGFloat = 200
	private static let defaultCreateDurationMinutes = 60
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

	private func snapMinutes(viewportHeight: CGFloat) -> Int {
		RescheduleMath.snapMinutes(visibleHours: viewportHeight / effectiveHourHeight)
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

				let scrollableContent =
					ScrollView(.vertical) {
						ZStack(alignment: .topLeading) {
							backgroundLayer(contentWidth: contentWidth, viewportHeight: viewportHeight)

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
									onSelect: onSelect,
									onReschedule: onReschedule,
									onDelete: onDelete,
									onEditStart: onEditStart,
									onEditEnd: onEditEnd,
									snapMinutes: snapMinutes(viewportHeight: viewportHeight),
									editingItemID: $editingItemID
								)
							}

							#if os(macOS)
								createPreview(contentWidth: contentWidth, viewportHeight: viewportHeight)
							#endif
						}
						.frame(height: effectiveHourHeight * 24)
					}
					.scrollPosition($scrollPosition)
					.onScrollGeometryChange(for: CGFloat.self) { geometry in
						geometry.contentOffset.y
					} action: { _, newValue in
						scrollOffsetY = newValue
					}
					// `.simultaneousGesture`, not `.highPriorityGesture`: high-priority gestures hold
					// off delivering touches to descendants for as long as they might still
					// succeed, and magnification can never conclusively rule out "this could still
					// become a pinch" until the touch lifts (a second finger could join at any
					// point) — so TimelineEventBlock's own drag-to-reschedule gestures (a
					// descendant, since it's rendered inside this ScrollView) never got to run
					// live, only resolving once the touch ended, regardless of the `including:`
					// mask. `.simultaneousGesture` recognizes magnification alongside whatever else
					// is happening instead of gating on it first.
					.simultaneousGesture(magnificationGesture(viewportHeight: viewportHeight))
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

				// Always attached, driven by a plain `Bool` — not branched into an `if`/`else` that
				// only attaches `.scrollDisabled(true)` in the editing case. Those two branches are
				// different view *types* (`ScrollView` vs. `ModifiedContent<ScrollView, _>`), so
				// every time `editingItemID` toggled between nil/non-nil, SwiftUI tore down and
				// remounted the whole `ScrollView` as a "different" view — losing its live scroll
				// offset (a visible jump) and remounting already `scrollDisabled`, un-scrollable
				// until it toggled back. Driving the same modifier with a `Bool` keeps one stable
				// view identity across edit-mode transitions, so neither happens.
				scrollableContent.scrollDisabled(editingItemID != nil)
			}
			.padding(.vertical, 8)
			// `TimelineItem` isn't `Equatable`, so this observes item ids (all the reset logic
			// needs) rather than `items` itself.
			.onChange(of: items.map(\.id)) { _, _ in
				editingItemID = EditingItemReset.resolved(current: editingItemID, items: items)
			}
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

	/// The hour-grid background, carrying the deselect-tap and (if `onCreate` is supplied)
	/// create gesture. `.highPriorityGesture` on both platforms — unlike `TimelineEventBlock`'s
	/// gestures, which stay at normal priority on iOS specifically to avoid claiming a touch a
	/// two-finger pinch needs, this gesture's hit-testing region is the *entire* scrollable content
	/// (not a small, isolated event block), which needs high priority to reliably win against
	/// `ScrollView`'s own native single-finger pan. This doesn't reintroduce the pinch regression:
	/// pinch is a separate two-finger gesture recognized via `.simultaneousGesture` on the
	/// `ScrollView` ancestor, which runs regardless of what a single-finger descendant gesture does.
	private func backgroundLayer(contentWidth: CGFloat, viewportHeight: CGFloat) -> some View {
		hourLines(contentWidth: contentWidth)
			.contentShape(Rectangle())
			.highPriorityGesture(backgroundGesture(viewportHeight: viewportHeight))
	}

	/// Tap-vs-create disambiguation via `.exclusively(before:)` — the same combinator
	/// `TimelineEventBlock` uses for tap-vs-drag, for the same reason: two independent gesture
	/// modifiers competing for the same touch is what broke tap-to-select once already. The
	/// attachment itself (`backgroundLayer`, above) is always the same shape; only the *value*
	/// returned here varies with whether `onCreate` is supplied.
	private func backgroundGesture(viewportHeight: CGFloat) -> some Gesture {
		let deselect = TapGesture().onEnded { editingItemID = nil }
		guard onCreate != nil else {
			return AnyGesture(deselect.map { _ in () })
		}

		#if os(macOS)
			let create =
				DragGesture(minimumDistance: 5)
				.updating($createDragState) { value, state, _ in
					state = (value.startLocation.y, value.location.y)
				}
				.onEnded { value in
					commitCreate(startY: value.startLocation.y, endY: value.location.y, viewportHeight: viewportHeight)
				}
		#else
			let create =
				LongPressGesture(minimumDuration: 0.4, maximumDistance: 10)
				.sequenced(before: DragGesture(minimumDistance: 0))
				.onChanged { value in
					if case .second(true, let drag) = value, let drag {
						createStartY = drag.startLocation.y
					}
				}
				.onEnded { value in
					defer { createStartY = nil }
					guard case .second(true, let drag) = value else { return }
					guard let startY = drag?.startLocation.y ?? createStartY else { return }
					commitCreate(startY: startY, endY: nil, viewportHeight: viewportHeight)
				}
		#endif

		return AnyGesture(deselect.exclusively(before: create).map { _ in () })
	}

	/// Shared by `commitCreate` and (on macOS) the live preview: converts a Y position to a date
	/// and snaps it in one step, so the preview and the committed result never disagree.
	private func snappedDate(atY y: CGFloat, snapMinutesValue: Int, calendar: Calendar) -> Date {
		let raw = EventPositionMath.date(
			atYOffset: y,
			referenceDate: baseDate,
			rangeStart: 0,
			hourHeight: effectiveHourHeight,
			calendar: calendar
		)
		return RescheduleMath.snapped(raw, toNearestMinutes: snapMinutesValue, calendar: calendar)
	}

	/// `endY == nil` (iOS long-press) always derives a default-duration event; `60` is divisible
	/// by every value `snapMinutes(viewportHeight:)` can return, so the derived end is already
	/// grid-aligned with no extra snap step needed.
	private func commitCreate(startY: CGFloat, endY: CGFloat?, viewportHeight: CGFloat) {
		let calendar = Calendar.current
		let snapMinutesValue = snapMinutes(viewportHeight: viewportHeight)
		let start = snappedDate(atY: startY, snapMinutesValue: snapMinutesValue, calendar: calendar)

		guard let endY else {
			let end = start.addingTimeInterval(TimeInterval(Self.defaultCreateDurationMinutes * 60))
			onCreate?(start, end)
			return
		}

		let end = snappedDate(atY: endY, snapMinutesValue: snapMinutesValue, calendar: calendar)
		let ordered = RescheduleMath.orderedRange(start, end, minimumDuration: TimeInterval(snapMinutesValue * 60))
		onCreate?(ordered.start, ordered.end)
	}

	#if os(macOS)
		/// A lightweight, non-interactive preview of the in-progress click-drag-to-create, snapped
		/// live to match what `commitCreate` will actually produce on release. `.allowsHitTesting(false)`
		/// so it can never become a gesture-carrying view driven by its own output — the precondition
		/// behind the drag-to-reschedule oscillation bug — even though it's rendered directly from
		/// live `@GestureState`.
		@ViewBuilder
		private func createPreview(contentWidth: CGFloat, viewportHeight: CGFloat) -> some View {
			if let createDragState {
				let calendar = Calendar.current
				let snapMinutesValue = snapMinutes(viewportHeight: viewportHeight)
				let start = snappedDate(
					atY: createDragState.start,
					snapMinutesValue: snapMinutesValue,
					calendar: calendar
				)
				let current = snappedDate(
					atY: createDragState.current,
					snapMinutesValue: snapMinutesValue,
					calendar: calendar
				)
				let ordered = RescheduleMath.orderedRange(
					start,
					current,
					minimumDuration: TimeInterval(snapMinutesValue * 60)
				)
				let topY = EventPositionMath.yOffset(
					of: ordered.start,
					referenceDate: baseDate,
					rangeStart: 0,
					hourHeight: effectiveHourHeight,
					calendar: calendar
				)
				let bottomY = EventPositionMath.yOffset(
					of: ordered.end,
					referenceDate: baseDate,
					rangeStart: 0,
					hourHeight: effectiveHourHeight,
					calendar: calendar
				)

				RoundedRectangle(cornerRadius: 4)
					.fill(Color.accentColor.opacity(0.25))
					.overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 1.5))
					.frame(width: contentWidth - 16, height: max(bottomY - topY, 4))
					.position(x: labelWidth + 8 + (contentWidth - 16) / 2, y: (topY + bottomY) / 2)
					.allowsHitTesting(false)
			}
		}
	#endif

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

					Rectangle()
						.fill(.quaternary)
						.frame(height: 1)
						.frame(maxWidth: .infinity)
				}
				.frame(height: effectiveHourHeight, alignment: .top)
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
		TimelineItem(
			title: "All day event",
			startDate: Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!,
			endDate: Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!,
			color: .blue,
			location: "Conference Room A",
			isPrimary: false
		),
	]

	ZoomableDayTimelineView(items: items)
		.frame(height: 500)
		.padding()
}
