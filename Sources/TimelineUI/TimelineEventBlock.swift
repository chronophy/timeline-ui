import SwiftUI

/// Pure, testable math for converting a date into a vertical pixel offset on the hour grid.
enum EventPositionMath {
	/// The vertical offset of `date`, measured in hours-since-midnight of `referenceDate`'s
	/// calendar day, minus `rangeStart` (the first hour shown), scaled by `hourHeight`.
	///
	/// Anchoring to `calendar.startOfDay(for:)` rather than `referenceDate`'s own `.hour`
	/// component matters: the `.hour` component alone discards `referenceDate`'s minutes, and
	/// re-deriving the offset from a raw `timeIntervalSince(referenceDate)` delta then leaks
	/// those discarded minutes back in as a fixed error applied to every event on the timeline.
	static func yOffset(
		of date: Date,
		referenceDate: Date,
		rangeStart: Int,
		hourHeight: CGFloat,
		calendar: Calendar
	) -> CGFloat {
		let startOfDay = calendar.startOfDay(for: referenceDate)
		let hoursSinceStartOfDay = date.timeIntervalSince(startOfDay) / 3600.0
		let hoursFromRangeStart = hoursSinceStartOfDay - Double(rangeStart)
		return CGFloat(hoursFromRangeStart) * hourHeight
	}

	/// Exact inverse of `yOffset(of:referenceDate:rangeStart:hourHeight:calendar:)` — unsnapped,
	/// by design (snapping is a separate, later step, same layering used throughout this file:
	/// raw geometry math never snaps itself).
	static func date(
		atYOffset yOffset: CGFloat,
		referenceDate: Date,
		rangeStart: Int,
		hourHeight: CGFloat,
		calendar: Calendar
	) -> Date {
		let hoursFromRangeStart = Double(yOffset / hourHeight)
		let hoursSinceStartOfDay = hoursFromRangeStart + Double(rangeStart)
		let startOfDay = calendar.startOfDay(for: referenceDate)
		return startOfDay.addingTimeInterval(hoursSinceStartOfDay * 3600)
	}
}

/// Pure, testable math for drag-to-reschedule: adaptive snap granularity, and the
/// resulting start/end dates for a move or resize gesture given a vertical translation.
enum RescheduleMath {
	/// Snap granularity in minutes, adapted to how many hours are currently visible in the
	/// viewport. Thresholds are the arithmetic midpoints between the anchors 20+/12/8/4 hours
	/// visible ↔ 60/30/15/5 minute snap.
	static func snapMinutes(visibleHours: Double) -> Int {
		switch visibleHours {
		case 16...: return 60
		case 10..<16: return 30
		case 6..<10: return 15
		default: return 5
		}
	}

	static func snapped(_ date: Date, toNearestMinutes minutes: Int, calendar: Calendar) -> Date {
		guard minutes > 0 else { return date }
		let startOfDay = calendar.startOfDay(for: date)
		let minutesSinceStartOfDay = date.timeIntervalSince(startOfDay) / 60
		let roundedMinutes = (minutesSinceStartOfDay / Double(minutes)).rounded() * Double(minutes)
		return calendar.date(byAdding: .minute, value: Int(roundedMinutes), to: startOfDay) ?? date
	}

	/// Snaps only the resulting start; end is derived as `start + originalDuration` so a move
	/// never drifts an event's duration. Zero translation always returns the original dates
	/// unchanged, regardless of whether they happen to fall on a snap boundary.
	static func movedDates(
		originalStart: Date,
		originalEnd: Date,
		translationY: CGFloat,
		hourHeight: CGFloat,
		snapMinutes: Int,
		calendar: Calendar
	) -> (start: Date, end: Date) {
		guard translationY != 0 else { return (originalStart, originalEnd) }
		let minutesDelta = Double(translationY / hourHeight * 60)
		let rawStart = originalStart.addingTimeInterval(minutesDelta * 60)
		let snappedStart = snapped(rawStart, toNearestMinutes: snapMinutes, calendar: calendar)
		let duration = originalEnd.timeIntervalSince(originalStart)
		return (snappedStart, snappedStart.addingTimeInterval(duration))
	}

	/// Clamped so the event never gets shorter than one snap increment (or its own original
	/// duration if that's shorter) — using the event's own duration as an alternate floor
	/// avoids a jump-on-touch for short events at coarse zoom. Zero translation always returns
	/// the original start unchanged.
	static func resizedStart(
		originalStart: Date,
		originalEnd: Date,
		translationY: CGFloat,
		hourHeight: CGFloat,
		snapMinutes: Int,
		calendar: Calendar
	) -> Date {
		guard translationY != 0 else { return originalStart }
		let minutesDelta = Double(translationY / hourHeight * 60)
		let rawStart = originalStart.addingTimeInterval(minutesDelta * 60)
		let snappedStart = snapped(rawStart, toNearestMinutes: snapMinutes, calendar: calendar)
		let minDuration = min(Double(snapMinutes) * 60, originalEnd.timeIntervalSince(originalStart))
		let latestAllowedStart = originalEnd.addingTimeInterval(-minDuration)
		return min(snappedStart, latestAllowedStart)
	}

	static func resizedEnd(
		originalStart: Date,
		originalEnd: Date,
		translationY: CGFloat,
		hourHeight: CGFloat,
		snapMinutes: Int,
		calendar: Calendar
	) -> Date {
		guard translationY != 0 else { return originalEnd }
		let minutesDelta = Double(translationY / hourHeight * 60)
		let rawEnd = originalEnd.addingTimeInterval(minutesDelta * 60)
		let snappedEnd = snapped(rawEnd, toNearestMinutes: snapMinutes, calendar: calendar)
		let minDuration = min(Double(snapMinutes) * 60, originalEnd.timeIntervalSince(originalStart))
		let earliestAllowedEnd = originalStart.addingTimeInterval(minDuration)
		return max(snappedEnd, earliestAllowedEnd)
	}

	/// Swaps a reversed pair (the user dragged upward) and clamps up to `minimumDuration` if the
	/// dragged range is too short — needed for macOS's click-drag-to-create, which can produce
	/// either.
	static func orderedRange(_ a: Date, _ b: Date, minimumDuration: TimeInterval) -> (start: Date, end: Date) {
		let start = min(a, b)
		let end = max(a, b)
		guard end.timeIntervalSince(start) < minimumDuration else { return (start, end) }
		return (start, start.addingTimeInterval(minimumDuration))
	}
}

/// Renders one event. Drag-to-reschedule is a small state machine, coordinated across sibling
/// blocks via the shared `editingItemID` binding (owned by the parent timeline view):
///
/// - At rest, a block is read-only: tap selects (`onSelect`), nothing else.
/// - On iOS, a long-press on an editable block's body enters edit mode. On macOS, a plain click
///   enters edit mode directly (in addition to selecting) — clicking and long-pressing are
///   already unambiguous on macOS, unlike touch, where a resting/scrolling finger looks the same
///   as the start of a long-press.
/// - While a block is the one named by `editingItemID`, its resize handles are visible and it
///   (along with its handles) accepts plain drags — no further long-press needed.
/// - Tapping/clicking anything else (another block, or empty background — see
///   `ZoomableDayTimelineView`) clears `editingItemID`, returning this block to read-only.
struct TimelineEventBlock: View {
	let item: TimelineItem
	let column: Int
	let totalColumns: Int
	let hourHeight: CGFloat
	let rangeStart: Int
	let baseDate: Date
	let labelWidth: CGFloat
	let contentWidth: CGFloat
	let onSelect: ((TimelineItem) -> Void)?
	let onReschedule: ((TimelineItem) -> Void)?
	/// Called when the user taps the delete affordance shown while this item is in edit mode.
	/// Deleting also exits edit mode, so `onEditEnd` fires immediately before this — hosts don't
	/// need a separate rule for "the user deleted it" vs. "the user finished editing it."
	let onDelete: ((TimelineItem) -> Void)?
	/// Called once when the user enters edit mode for this item — long-pressing (iOS) or clicking
	/// (macOS) it — with its state at that moment, before any edits happen this session. Lets a
	/// host prepare for a batch of upcoming edits (e.g. snapshot current state for a possible
	/// revert, show an "editing" indicator) without doing that work on every individual drag.
	let onEditStart: ((TimelineItem) -> Void)?
	/// Called once when the user exits edit mode for this item — tapping elsewhere, tapping
	/// another event, or otherwise clearing `editingItemID` — with the item reflecting its
	/// latest edits (via `committedItem`, not necessarily yet reconciled into `item` itself if the
	/// host hasn't returned an updated `items` array since the last `onReschedule`). Useful for
	/// one-shot wrap-up work that shouldn't run after *every* individual drag — e.g. a single
	/// "saved" indicator after a user drags the start handle, then the end handle, rather than one
	/// per handle. Neither this nor `onEditStart` is guaranteed to fire if this view is torn down
	/// without an explicit edit-mode exit (e.g. the host navigates away mid-edit) — `onReschedule`/
	/// `onDelete` already covered the data at that point, so nothing but these notifications is lost.
	let onEditEnd: ((TimelineItem) -> Void)?
	let snapMinutes: Int
	@Binding var editingItemID: UUID?

	private enum DragMode: Equatable {
		case move
		case resizeStart
		case resizeEnd
	}

	@GestureState private var moveDragState: CGFloat?
	@GestureState private var resizeStartDragState: CGFloat?
	@GestureState private var resizeEndDragState: CGFloat?
	@State private var activeDrag: (mode: DragMode, originalStart: Date, originalEnd: Date)?
	@State private var pendingReschedule: (start: Date, end: Date)?
	/// Set right before a delete-triggered `editingItemID` clear, so the `.onChange` below doesn't
	/// *also* fire `onEditEnd` — `deleteButton()` already fires it explicitly and synchronously, in
	/// the correct order relative to `onDelete`. `.onChange` alone isn't enough for that ordering:
	/// SwiftUI defers it to the next update cycle, so relying on it here let `onDelete` (which runs
	/// immediately, in the same call stack as the `editingItemID` write) observably fire *before*
	/// `onEditEnd`.
	@State private var editEndFiredByDelete = false

	private var isRescheduleEnabled: Bool {
		item.isEditable && onReschedule != nil
	}

	private var isDeleteEnabled: Bool {
		item.isEditable && onDelete != nil
	}

	/// Broader than `isRescheduleEnabled` alone: a delete-only item (no `onReschedule`) still
	/// needs to enter edit mode to show its delete button, even though it can't be dragged.
	private var canEnterEditMode: Bool {
		isRescheduleEnabled || isDeleteEnabled
	}

	private var isEditing: Bool {
		canEnterEditMode && editingItemID == item.id
	}

	// MARK: - Committed (non-live) geometry — never fed by an in-progress drag, so a view's own
	// gesture never repositions itself from its own live output (the cause of the oscillation
	// this replaced). The live portion is applied separately, purely via `.offset()`.

	private var committedStartDate: Date { pendingReschedule?.start ?? item.startDate }
	private var committedEndDate: Date { pendingReschedule?.end ?? item.endDate }

	/// `item` folded with any not-yet-reconciled `pendingReschedule` — used for `onEditStart`/
	/// `onEditEnd` so both report a consistent, up-to-date snapshot regardless of whether the host
	/// has caught up via a new `items` array since the last `onReschedule`.
	private var committedItem: TimelineItem {
		item.rescheduled(startDate: committedStartDate, endDate: committedEndDate)
	}

	private var committedYOffset: CGFloat {
		EventPositionMath.yOffset(
			of: committedStartDate,
			referenceDate: baseDate,
			rangeStart: rangeStart,
			hourHeight: hourHeight,
			calendar: .current
		)
	}

	private var committedBlockHeight: CGFloat {
		let duration = committedEndDate.timeIntervalSince(committedStartDate)
		let hours = duration / 3600.0
		return max(CGFloat(hours) * hourHeight, 24)
	}

	private var blockWidth: CGFloat {
		let availableWidth = contentWidth - 16
		return availableWidth / CGFloat(totalColumns)
	}

	private var xOffset: CGFloat {
		labelWidth + 8 + (blockWidth * CGFloat(column))
	}

	private var handleHitSize: CGFloat {
		max(20, min(44, committedBlockHeight, blockWidth))
	}

	// MARK: - Live drag

	private func liveDraggedDates() -> (start: Date, end: Date)? {
		guard let activeDrag else { return nil }
		let translationY: CGFloat
		switch activeDrag.mode {
		case .move: translationY = moveDragState ?? 0
		case .resizeStart: translationY = resizeStartDragState ?? 0
		case .resizeEnd: translationY = resizeEndDragState ?? 0
		}
		return resolvedDates(
			mode: activeDrag.mode,
			originalStart: activeDrag.originalStart,
			originalEnd: activeDrag.originalEnd,
			translationY: translationY
		)
	}

	private var effectiveStartDate: Date { liveDraggedDates()?.start ?? committedStartDate }
	private var effectiveEndDate: Date { liveDraggedDates()?.end ?? committedEndDate }

	/// How far the top edge should visually shift right now — non-zero while moving or dragging
	/// the start handle, zero otherwise (including while dragging only the end handle).
	private var liveTopDeltaY: CGFloat {
		guard let activeDrag, let live = liveDraggedDates() else { return 0 }
		switch activeDrag.mode {
		case .move, .resizeStart: return pixelDelta(from: committedStartDate, to: live.start)
		case .resizeEnd: return 0
		}
	}

	/// How far the bottom edge should visually shift right now — the resize-end counterpart to
	/// `liveTopDeltaY`.
	private var liveBottomDeltaY: CGFloat {
		guard let activeDrag, let live = liveDraggedDates() else { return 0 }
		switch activeDrag.mode {
		case .move, .resizeEnd: return pixelDelta(from: committedEndDate, to: live.end)
		case .resizeStart: return 0
		}
	}

	private func pixelDelta(from: Date, to: Date) -> CGFloat {
		CGFloat(to.timeIntervalSince(from) / 3600) * hourHeight
	}

	private var liveDragTimeLabel: String? {
		guard let activeDrag else { return nil }
		switch activeDrag.mode {
		case .move:
			return "\(formattedTime(effectiveStartDate)) – \(formattedTime(effectiveEndDate))"
		case .resizeStart:
			return formattedTime(effectiveStartDate)
		case .resizeEnd:
			return formattedTime(effectiveEndDate)
		}
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			eventCard

			if isEditing && isRescheduleEnabled {
				handleView(mode: .resizeStart)
				handleView(mode: .resizeEnd)
			}

			if isEditing && isDeleteEnabled {
				deleteButton()
			}

			if let liveDragTimeLabel {
				Text(liveDragTimeLabel)
					.font(.caption2.bold())
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(.regularMaterial, in: Capsule())
					.position(x: xOffset + (blockWidth - 2) / 2, y: max(10, committedYOffset - 12))
					.offset(y: (liveTopDeltaY + liveBottomDeltaY) / 2)
			}
		}
		.onChange(of: moveDragState) { clearActiveDragIfGestureEnded() }
		.onChange(of: resizeStartDragState) { clearActiveDragIfGestureEnded() }
		.onChange(of: resizeEndDragState) { clearActiveDragIfGestureEnded() }
		.onChange(of: item.startDate) { pendingReschedule = nil }
		.onChange(of: item.endDate) { pendingReschedule = nil }
		.onChange(of: editingItemID) { oldValue, newValue in
			if newValue != item.id { activeDrag = nil }
			if newValue == item.id && oldValue != item.id {
				onEditStart?(committedItem)
			}
			if oldValue == item.id && newValue != item.id {
				if editEndFiredByDelete {
					editEndFiredByDelete = false
				} else {
					onEditEnd?(committedItem)
				}
			}
		}
	}

	/// Split into two layers: a purely cosmetic visible card (free to move live with the drag,
	/// carries no gesture) and a separate, fixed hit-testing zone (carries the gesture, never
	/// moves). Earlier versions applied both the gesture *and* the live-drag `.offset()` to the
	/// same view — turns out `.offset()` isn't the layout-neutral, gesture-coordinate-safe
	/// transform it's usually treated as: feeding a gesture's own output back into that same
	/// view's offset let the two influence each other, converging on exactly half the true
	/// pointer movement and producing visible oscillation as the loop hunted for that
	/// equilibrium. A gesture-carrying view that never moves can't see its own output at all.
	private var eventCard: some View {
		let renderedHeight = max(committedBlockHeight + (liveBottomDeltaY - liveTopDeltaY), 24)
		let centerX = xOffset + (blockWidth - 2) / 2
		let committedCenterY = committedYOffset + committedBlockHeight / 2

		let visible =
			cardContent(height: renderedHeight)
			.allowsHitTesting(false)
			.position(x: centerX, y: committedCenterY)
			.offset(y: (liveTopDeltaY + liveBottomDeltaY) / 2)

		let gestureZone =
			Color.clear
			.frame(width: blockWidth - 2, height: committedBlockHeight)
			.contentShape(Rectangle())
			.position(x: centerX, y: committedCenterY)

		return ZStack {
			visible
			// `.highPriorityGesture` isn't needed on iOS: a long-press's own timing already
			// doesn't compete with scrolling/pinching, and once actually dragging,
			// `.scrollDisabled(editingItemID != nil)` (see `ZoomableDayTimelineView`) already
			// locks scroll out — whereas attaching it universally risked claiming one of the two
			// touches a pinch-to-zoom gesture needs, breaking pinch on touch devices.
			#if os(macOS)
				gestureZone.highPriorityGesture(cardGesture())
			#else
				gestureZone.gesture(cardGesture())
			#endif
		}
	}

	/// Tap-vs-drag disambiguation via `.exclusively(before:)`, the purpose-built combinator for
	/// "try the simple gesture first, fall back to the complex one" — rather than two independent
	/// modifiers (`.onTapGesture` + `.highPriorityGesture`) competing for the same touch, which is
	/// what caused tap-to-select to stop firing reliably. The gesture attachment itself is always
	/// the same shape regardless of `isRescheduleEnabled`/`isEditing`; only the *value* passed to
	/// `.exclusively(before:)`'s second branch varies, and `beginDragIfNeeded`/`entryGesture`'s own
	/// internal `isRescheduleEnabled` guards make the drag portion inert for non-editable items.
	private func cardGesture() -> some Gesture {
		let secondary: AnyGesture<Void>
		if isEditing {
			secondary = AnyGesture(dragGesture(mode: .move, gestureState: $moveDragState).map { _ in () })
		} else {
			secondary = AnyGesture(entryGesture(mode: .move, gestureState: $moveDragState).map { _ in () })
		}
		return TapGesture()
			.onEnded { handleTap() }
			.exclusively(before: secondary)
	}

	private func cardContent(height: CGFloat) -> some View {
		ZStack(alignment: .topLeading) {
			HStack(spacing: 0) {
				Rectangle()
					.fill(item.color)
					.frame(width: 4)
				Spacer(minLength: 0)
			}
			VStack(alignment: .leading, spacing: 0) {
				Text(item.title)
					.font(.caption2.bold())
					.lineLimit(1)
				if let location = item.location, height > 30 {
					Text(location)
						.font(.caption2)
						.lineLimit(1)
						.foregroundStyle(.secondary)
				}
			}
			.padding(.leading, 8)
			.padding(.top, 4)
		}
		.frame(width: blockWidth - 2, height: height)
		.background(item.isPrimary ? item.color.opacity(0.15) : item.color.opacity(0.2))
		.clipShape(RoundedRectangle(cornerRadius: 4))
		.shadow(color: .black.opacity(isEditing ? 0.25 : 0), radius: isEditing ? 6 : 0, y: isEditing ? 3 : 0)
		.scaleEffect(isEditing ? 1.03 : 1)
	}

	/// Same gesture-zone/visible-layer split as `eventCard`, for the same reason.
	private func handleView(mode: DragMode) -> some View {
		let gestureState = mode == .resizeStart ? $resizeStartDragState : $resizeEndDragState
		let liveDelta = mode == .resizeStart ? liveTopDeltaY : liveBottomDeltaY
		let position: CGPoint =
			mode == .resizeStart
			? CGPoint(x: xOffset + (blockWidth - 2), y: committedYOffset)
			: CGPoint(x: xOffset, y: committedYOffset + committedBlockHeight)

		let visible =
			Circle()
			.fill(.white)
			.overlay(Circle().stroke(item.color, lineWidth: 2))
			.frame(width: 10, height: 10)
			.allowsHitTesting(false)
			.position(position)
			.offset(y: liveDelta)

		let gestureZone =
			Color.clear
			.frame(width: handleHitSize, height: handleHitSize)
			.contentShape(Circle())
			.position(position)

		return ZStack {
			visible
			#if os(macOS)
				gestureZone.highPriorityGesture(dragGesture(mode: mode, gestureState: gestureState))
			#else
				gestureZone.gesture(dragGesture(mode: mode, gestureState: gestureState))
			#endif
		}
	}

	/// Rendered at the top-leading corner — the one corner not already used by the resize handles
	/// (top-trailing = resize-start, bottom-leading = resize-end). Tracks `liveTopDeltaY` the same
	/// way the resize-start handle does, so it follows the card's top edge while moving/resizing
	/// instead of staying pinned to the committed (pre-drag) position until release. A discrete tap
	/// has no live-offset feedback loop, so the oscillation bug this file works hard to avoid
	/// elsewhere can't recur here; the gesture-zone/visible-layer split below is purely for
	/// touch-target ergonomics, matching `handleView`. Unlike the card/handles, this always uses
	/// `.highPriorityGesture` on both platforms — there's no drag of its own to conflict with
	/// scrolling, so nothing is gained by the lower-priority attachment `eventCard` uses on iOS, and
	/// without high priority `eventCard`'s own full-card gesture zone (which overlaps this corner)
	/// wins the tap instead, silently swallowing it.
	///
	/// Deleting always exits edit mode: this clears `editingItemID` (rather than leaving it to
	/// whatever the host does with `items` after `onDelete`, which would otherwise leak edit mode —
	/// and `ZoomableDayTimelineView`'s `scrollDisabled` with it — until something else happened to
	/// clear it) and fires `onEditEnd` explicitly, synchronously, and in order before `onDelete`.
	/// It can't just rely on the `onChange` below for that ordering: SwiftUI defers `.onChange` to
	/// the next update cycle, so `onDelete` — which runs immediately, same call stack as the
	/// `editingItemID` write — would observably fire *before* `onEditEnd`. `editEndFiredByDelete`
	/// suppresses the later `onChange`-driven fire so this doesn't end up calling `onEditEnd` twice.
	private func deleteButton() -> some View {
		let position = CGPoint(x: xOffset, y: committedYOffset)

		let visible =
			Image(systemName: "trash.circle.fill")
			.symbolRenderingMode(.palette)
			.foregroundStyle(.white, .red)
			.font(.system(size: 16))
			.position(position)
			.offset(y: liveTopDeltaY)
			.allowsHitTesting(false)

		let gestureZone =
			Color.clear
			.frame(width: handleHitSize, height: handleHitSize)
			.contentShape(Circle())
			.position(position)

		return ZStack {
			visible
			gestureZone.highPriorityGesture(
				TapGesture().onEnded {
					let deletedItem = committedItem
					editEndFiredByDelete = true
					editingItemID = nil
					onEditEnd?(deletedItem)
					onDelete?(deletedItem)
				}
			)
		}
	}

	private func handleTap() {
		onSelect?(item)
		guard canEnterEditMode else {
			editingItemID = nil
			return
		}
		#if os(macOS)
			editingItemID = item.id
		#else
			if editingItemID != item.id {
				editingItemID = nil
			}
		#endif
	}

	/// A plain drag, no long-press — used once a block is already in edit mode, for both the
	/// body (move) and either handle (resize).
	private func dragGesture(mode: DragMode, gestureState: GestureState<CGFloat?>) -> some Gesture {
		DragGesture(minimumDistance: 5)
			.updating(gestureState) { value, state, _ in
				state = value.translation.height
			}
			.onChanged { _ in
				beginDragIfNeeded(mode: mode)
			}
			.onEnded { value in
				commitDrag(mode: mode, translationY: value.translation.height)
			}
	}

	/// The gesture that enters edit mode from a resting (not-yet-editing) block, on the body
	/// only (handles don't exist yet at this point). A plain click has a pixel or two of
	/// incidental jitter, so `minimumDistance: 0` would misfire on ordinary clicks meant for
	/// `onTapGesture`; a small non-zero threshold lets clicks fall through to the tap gesture
	/// while a deliberate click-and-drag engages a move immediately, with no hold delay.
	private func entryGesture(mode: DragMode, gestureState: GestureState<CGFloat?>) -> some Gesture {
		#if os(macOS)
			DragGesture(minimumDistance: 5)
				.updating(gestureState) { value, state, _ in
					state = value.translation.height
				}
				.onChanged { _ in
					guard canEnterEditMode else { return }
					editingItemID = item.id
					beginDragIfNeeded(mode: mode)
				}
				.onEnded { value in
					commitDrag(mode: mode, translationY: value.translation.height)
				}
		#else
			LongPressGesture(minimumDuration: 0.4, maximumDistance: 10)
				.sequenced(before: DragGesture(minimumDistance: 0))
				.updating(gestureState) { value, state, _ in
					if case .second(true, let drag) = value {
						state = drag?.translation.height
					}
				}
				.onChanged { value in
					guard canEnterEditMode else { return }
					if case .second(true, _) = value {
						editingItemID = item.id
						beginDragIfNeeded(mode: mode)
					}
				}
				.onEnded { value in
					if case .second(true, let drag) = value, let drag {
						commitDrag(mode: mode, translationY: drag.translation.height)
					} else {
						activeDrag = nil
					}
				}
		#endif
	}

	private func beginDragIfNeeded(mode: DragMode) {
		guard isRescheduleEnabled, activeDrag == nil else { return }
		activeDrag = (mode, effectiveStartDate, effectiveEndDate)
	}

	private func commitDrag(mode: DragMode, translationY: CGFloat) {
		guard isRescheduleEnabled, let activeDrag, activeDrag.mode == mode else {
			self.activeDrag = nil
			return
		}
		let dates = resolvedDates(
			mode: mode,
			originalStart: activeDrag.originalStart,
			originalEnd: activeDrag.originalEnd,
			translationY: translationY
		)
		self.activeDrag = nil
		guard dates.start != activeDrag.originalStart || dates.end != activeDrag.originalEnd else { return }
		pendingReschedule = dates
		onReschedule?(item.rescheduled(startDate: dates.start, endDate: dates.end))
	}

	private func resolvedDates(mode: DragMode, originalStart: Date, originalEnd: Date, translationY: CGFloat) -> (
		start: Date, end: Date
	) {
		switch mode {
		case .move:
			return RescheduleMath.movedDates(
				originalStart: originalStart,
				originalEnd: originalEnd,
				translationY: translationY,
				hourHeight: hourHeight,
				snapMinutes: snapMinutes,
				calendar: .current
			)
		case .resizeStart:
			let newStart = RescheduleMath.resizedStart(
				originalStart: originalStart,
				originalEnd: originalEnd,
				translationY: translationY,
				hourHeight: hourHeight,
				snapMinutes: snapMinutes,
				calendar: .current
			)
			return (newStart, originalEnd)
		case .resizeEnd:
			let newEnd = RescheduleMath.resizedEnd(
				originalStart: originalStart,
				originalEnd: originalEnd,
				translationY: translationY,
				hourHeight: hourHeight,
				snapMinutes: snapMinutes,
				calendar: .current
			)
			return (originalStart, newEnd)
		}
	}

	/// `@GestureState` auto-resets to `nil` on any gesture termination, including system
	/// cancellation (call interruption, app backgrounding) where `.onEnded` never fires — this is
	/// the safety net that guarantees `activeDrag` doesn't get stuck non-nil in that case.
	private func clearActiveDragIfGestureEnded() {
		let anyLive = moveDragState != nil || resizeStartDragState != nil || resizeEndDragState != nil
		if !anyLive {
			activeDrag = nil
		}
	}

	private func formattedTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm"
		return formatter.string(from: date)
	}
}
