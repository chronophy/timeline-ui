import SwiftUI

/// Locale-aware date math for the week strip: which 7 days make up "the week",
/// in which order, and how to page between weeks.
enum WeekDateMath {
	static func weekStart(containing date: Date, calendar: Calendar) -> Date {
		calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
	}

	static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
		let start = weekStart(containing: date, calendar: calendar)
		return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
	}

	static func orderedWeekdaySymbols(calendar: Calendar) -> [String] {
		let symbols = calendar.veryShortWeekdaySymbols
		let firstIndex = calendar.firstWeekday - 1
		return Array(symbols[firstIndex...] + symbols[..<firstIndex])
	}

	static func shifted(_ date: Date, byWeeks weeks: Int, calendar: Calendar) -> Date {
		calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
	}
}

/// A locale-aware 7-day week strip, showing single-letter weekday headers and day
/// numbers with the selected day highlighted — similar to Apple Calendar's day-view header.
///
/// ```swift
/// @State private var selectedDate = Date()
///
/// WeekStripView(selectedDate: $selectedDate)
/// ```
///
/// The displayed week, weekday letters, and first day of the week all follow the
/// given `calendar`'s locale (defaulting to `Calendar.current`) — a Monday-first
/// locale shows `M T W T F S S`, a Sunday-first locale shows `S M T W T F S`.
///
/// Swipe left/right (or use the chevron buttons) to page to the next/previous week;
/// tap a day to select it. Both update `selectedDate`. Use ``WeekTimelineView`` to pair
/// this with a scrollable day timeline that follows the selection.
public struct WeekStripView: View {
	@Binding var selectedDate: Date
	let calendar: Calendar

	/// Creates a week strip view.
	/// - Parameters:
	///   - selectedDate: The currently selected day. Updated when the user taps a day,
	///     swipes, or uses the chevron buttons.
	///   - calendar: The calendar used to determine week boundaries, weekday order, and
	///     weekday symbols. Defaults to `Calendar.current`.
	public init(selectedDate: Binding<Date>, calendar: Calendar = .current) {
		self._selectedDate = selectedDate
		self.calendar = calendar
	}

	@State private var dragTranslation: CGFloat = 0
	@State private var swipeDirection: Int = 1

	private var weekDates: [Date] {
		WeekDateMath.weekDates(containing: selectedDate, calendar: calendar)
	}

	private var weekdaySymbols: [String] {
		WeekDateMath.orderedWeekdaySymbols(calendar: calendar)
	}

	public var body: some View {
		HStack(spacing: 4) {
			#if os(macOS)
				chevronButton(systemName: "chevron.left", weeks: -1)
			#endif

			weekRow
				.id(WeekDateMath.weekStart(containing: selectedDate, calendar: calendar))
				.transition(
					.asymmetric(
						insertion: .move(edge: swipeDirection > 0 ? .trailing : .leading).combined(with: .opacity),
						removal: .move(edge: swipeDirection > 0 ? .leading : .trailing).combined(with: .opacity)
					)
				)
				.clipped()

			#if os(macOS)
				chevronButton(systemName: "chevron.right", weeks: 1)
			#endif
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 4)
	}

	private var weekRow: some View {
		HStack(spacing: 0) {
			ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
				dayCell(date: date, weekdaySymbol: weekdaySymbols[index])
					.frame(maxWidth: .infinity)
			}
		}
		.offset(x: dragTranslation)
		.gesture(dragGesture)
	}

	private func dayCell(date: Date, weekdaySymbol: String) -> some View {
		let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
		let isToday = calendar.isDateInToday(date)
		let dayNumber = calendar.component(.day, from: date)

		return VStack(spacing: 4) {
			Text(weekdaySymbol)
				.font(.caption2)
				.foregroundStyle(.secondary)

			Text("\(dayNumber)")
				.font(.headline)
				.foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
				.frame(width: 32, height: 32)
				.background(isSelected ? Color.accentColor : Color.clear, in: Circle())
		}
		.contentShape(Rectangle())
		.onTapGesture {
			withAnimation(.spring(duration: 0.3)) {
				selectedDate = date
			}
		}
	}

	#if os(macOS)
		private func chevronButton(systemName: String, weeks: Int) -> some View {
			Button {
				changeWeek(by: weeks)
			} label: {
				Image(systemName: systemName)
					.font(.caption.bold())
					.foregroundStyle(.secondary)
					.frame(width: 24, height: 24)
			}
			.buttonStyle(.plain)
		}
	#endif

	private var dragGesture: some Gesture {
		DragGesture(minimumDistance: 10)
			.onChanged { value in
				dragTranslation = value.translation.width
			}
			.onEnded { value in
				let threshold: CGFloat = 40
				if value.translation.width < -threshold {
					changeWeek(by: 1)
				} else if value.translation.width > threshold {
					changeWeek(by: -1)
				} else {
					withAnimation(.spring(duration: 0.3)) {
						dragTranslation = 0
					}
				}
			}
	}

	private func changeWeek(by weeks: Int) {
		swipeDirection = weeks
		dragTranslation = 0
		withAnimation(.spring(duration: 0.3)) {
			selectedDate = WeekDateMath.shifted(selectedDate, byWeeks: weeks, calendar: calendar)
		}
	}
}

#Preview {
	struct PreviewWrapper: View {
		@State private var selectedDate = Date()

		var body: some View {
			WeekStripView(selectedDate: $selectedDate)
				.padding()
		}
	}

	return PreviewWrapper()
}
