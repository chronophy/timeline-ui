# Getting Started with TimelineUI

Display calendar events in your iOS app with an hour-based timeline.

## Overview

TimelineUI makes it easy to show daily schedules. Create ``TimelineItem`` instances for your events, then display them with ``DayTimelineView`` or ``CompactTimelineView``.

## Create Timeline Items

Each event needs a title, start/end dates, and a color:

```swift
let events = [
    TimelineItem(
        title: "Team Meeting",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        color: .blue,
        location: "Conference Room A"
    ),
    TimelineItem(
        title: "Lunch",
        startDate: Date().addingTimeInterval(7200),
        endDate: Date().addingTimeInterval(10800),
        color: .green
    )
]
```

## Display a Day Timeline

Use ``DayTimelineView`` for a full-day view that expands to fill available space:

```swift
struct ScheduleView: View {
    var body: some View {
        DayTimelineView(items: events)
    }
}
```

![Day timeline with events](day-conflicts-light.png)

## Display a Compact Timeline

Use ``CompactTimelineView`` for widgets or previews:

```swift
CompactTimelineView(items: events, heightMode: .fixed(hours: 2))
```

![Compact timeline](compact-conflicts-light.png)

## Handle Many Events

The timeline automatically arranges overlapping events in columns:

![Many overlapping events](compact-many-light.png)

## Zoom and Scroll a Full Day

Use ``ZoomableDayTimelineView`` when you want the full 24-hour day in a scroll view, with
pinch-to-zoom on the hour grid:

```swift
ZoomableDayTimelineView(items: events)
    .frame(height: 500)
```

## Add Week Navigation

Pair ``WeekStripView`` with a day timeline, or use ``WeekTimelineView`` to get both together.
`WeekTimelineView` pins a locale-aware week strip above a ``ZoomableDayTimelineView`` and keeps
the selected day in sync between them:

```swift
@State private var selectedDate = Date()

WeekTimelineView(items: eventsForSelectedDay, selectedDate: $selectedDate)
```

Supply `items` already filtered to `selectedDate`, and update them whenever the binding changes.

## Drag to Reschedule

Mark an item ``TimelineItem/isEditable`` to let the user move or resize it by dragging in
``ZoomableDayTimelineView`` (or ``WeekTimelineView``). Supply `onReschedule` to receive the
updated item when a drag ends:

```swift
ZoomableDayTimelineView(
    items: events,
    onReschedule: { updated in
        // Persist updated.startDate / updated.endDate
    }
)
```
