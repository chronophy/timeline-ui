# ``TimelineUI``

A SwiftUI component library for displaying calendar timeline views.

@Metadata {
    @DisplayName("TimelineUI")
}

## Overview

TimelineUI provides SwiftUI views for displaying daily schedules. Events are positioned by time on an hour grid, and overlapping events are automatically arranged side-by-side.

![Compact timeline showing events](compact-conflicts-light.png)

Use ``DayTimelineView`` for full-day schedules that expand to fill available space,
``CompactTimelineView`` for a focused 2-3 hour window ideal for widgets, or
``ZoomableDayTimelineView`` for a scrollable, pinch-to-zoom full day — pair it with
``WeekStripView`` (or the combined ``WeekTimelineView``) for week navigation. Items marked
``TimelineItem/isEditable`` can be moved or resized by dragging in ``ZoomableDayTimelineView``.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:AccessControl>

### Displaying Timelines

- ``DayTimelineView``
- ``CompactTimelineView``
- ``ZoomableDayTimelineView``
- ``WeekStripView``
- ``WeekTimelineView``
- ``HeightMode``

### Event Data

- ``TimelineItem``

### Expandable Timeline

- ``ExpandableTimelineContainer``
- ``ExpandedTimelineContent``
- ``TimelineTransitionModifier``

### Access Control

- ``AccessPromptView``
- ``AccessRestrictedModifier``
