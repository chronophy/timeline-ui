# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TimelineUI is a SwiftUI component library for displaying calendar timeline visualizations. It provides day view timelines with hour grids and event blocks, suitable for showing schedules and detecting conflicts.

## Build Commands

```bash
mise run build      # Build the Swift package
mise run tests      # Run package unit tests
mise run format     # Format Swift source files
mise run lint       # Check formatting without writing anything (what CI runs)
mise run previews   # Generate preview PNG images to ./previews/
mise run clean      # Clean build artifacts
```

## Architecture

- **Package.swift** - Swift Package at root containing the library
- **Sources/TimelineUI/** - Core library with timeline components
  - `TimelineItem.swift` - View model for timeline events
  - `DayTimelineView.swift` - Full day timeline with hour grid, sized to fit available height (no scrolling)
  - `ZoomableDayTimelineView.swift` - Full day timeline with pinch-to-zoom; always scrollable, fixed 24h range
  - `CompactTimelineView.swift` - Compact 2-3 hour preview
  - `TimelineEventBlock.swift` - Individual event block component
  - `TimelineEventLayout.swift` - Shared column-layout algorithm for overlapping events
  - `WeekStripView.swift` - Locale-aware 7-day week strip toolbar (swipe/chevron week navigation)
  - `WeekTimelineView.swift` - `WeekStripView` pinned above a `ZoomableDayTimelineView`
  - `ExpandableTimelineContainer.swift` - Compact-to-full-day expand/collapse container
  - `TimelineTransitionModifier.swift` - Matched geometry transition used by the expandable container
  - `AccessRestrictedModifier.swift` - Blur+overlay for restricted content
  - `AccessPromptView.swift` - Standard UI for requesting access
- **Sources/TimelineUIEventKit/** - Optional EventKit integration
  - `EKEvent+TimelineItem.swift` - Convert EKEvent to TimelineItem
- **Sources/RenderPreviews/** - macOS CLI to generate preview PNGs
- **Tests/TimelineUITests/** - Unit tests for the library

## Technical Constraints

- Target: iOS 26+, macOS 15+
- Swift 6.2 with modern concurrency
- SwiftUI only - no UIKit/AppKit dependencies in core library. This rules out reading exact
  gesture locations (e.g. pinch-center or two-finger trackpad-swipe position), since
  `MagnificationGesture`/`DragGesture` don't expose them in pure SwiftUI - only
  `UIPinchGestureRecognizer`/`NSMagnificationGestureRecognizer` do. Work around this with
  SwiftUI-only approximations (see `ZoomAnchor`) rather than dropping into UIKit/AppKit interop.
- TimelineUIEventKit links EventKit framework

## API Design

The library uses a simple `TimelineItem` struct as the view model:

```swift
TimelineItem(
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool = false,
    color: Color,
    location: String? = nil,
    isPrimary: Bool = false,  // Distinguishes "new" from "existing" events
    isEditable: Bool = false  // Allows drag-to-move/resize in ZoomableDayTimelineView
)
```

Views accept `[TimelineItem]` arrays and handle layout automatically.

### Access Control

For permission-restricted content (e.g., calendar access), use the blur+overlay modifier:

```swift
CompactTimelineView(items: items)
    .accessRestricted(!canReadEvents) {
        AccessPromptView.calendar(style: .compact) {
            await requestAccess()
        }
    }
```

### EventKit Integration

Import `TimelineUIEventKit` for EKEvent conversion:

```swift
import TimelineUIEventKit

let item = TimelineItem(ekEvent)
let items = ekEvents.asTimelineItems(primaryEventID: selectedEvent.eventIdentifier)
```

### Drag to Reschedule

Items with `isEditable: true` can be moved or resized by dragging in `ZoomableDayTimelineView`
(and `WeekTimelineView`, which is built on it). Supply `onReschedule` to receive the updated item
when a drag ends:

```swift
ZoomableDayTimelineView(
    items: items,
    onReschedule: { updated in
        // Persist updated.startDate / updated.endDate
    }
)
```

While an item is being dragged or resized it's in "edit mode": resize handles appear on the
block, and (if `onDelete` is supplied) a delete button does too. Edit mode is a small state
machine (long-press on iOS / double-click on macOS → edit mode → tap elsewhere → view mode), coordinated
across sibling `TimelineEventBlock`s via a shared `editingItemID: UUID?` binding owned by
`ZoomableDayTimelineView`. `initialEditingItemID` seeds it for previews/tests without simulating
a gesture (see `zoomable-day-editing` in `RenderPreviews/main.swift`).

### Create and Delete Events

Long-pressing (iOS) or click-dragging (macOS) empty background in `ZoomableDayTimelineView`
creates a new event — matching each platform's native calendar convention, with a live preview
on macOS. Tapping the delete button shown on an editable item in edit mode deletes it. Both
report back through plain closures; the library never constructs or removes a `TimelineItem`
itself:

```swift
ZoomableDayTimelineView(
    items: items,
    onDelete: { item in
        // Remove item from your data source
    },
    onCreate: { start, end in
        // Insert a new TimelineItem(startDate: start, endDate: end, ...) into your data source
    }
)
```

`onDelete` is gated on `isEditable` independently of `onReschedule` — an item can be delete-only
(no drag handles, just the delete button) by supplying `onDelete` without `onReschedule`. Deleting
also exits edit mode: `onEditEnd` (below) always fires immediately before `onDelete`, fired
explicitly in `TimelineEventBlock.deleteButton()` rather than left to the `editingItemID`
`onChange` handler, since that's deferred to the next SwiftUI update cycle and would otherwise
make `onDelete` observably fire before `onEditEnd`.

### Edit Lifecycle Notifications

`onEditStart`/`onEditEnd` fire once each, when an item enters and exits edit mode, as opposed to
`onReschedule` firing once per individual drag. Use them for work that should happen once per
editing session rather than once per drag:

```swift
ZoomableDayTimelineView(
    items: items,
    onEditStart: { item in
        // e.g. snapshot current state for a possible revert
    },
    onEditEnd: { item in
        // e.g. show a single "saved" indicator for the whole editing session
    }
)
```

Neither is guaranteed to fire if `TimelineEventBlock` is torn down without an explicit edit-mode
exit (e.g. the host navigates away mid-edit) — `onReschedule`/`onDelete` already covered the data
at that point, so nothing but these notifications is lost.

## Coding Conventions

- Use Swift Testing framework with raw identifiers for test names:
  ```swift
  @Test func `renders items with correct positions`() throws { ... }
  ```
- Do not add comments unless asked
- After modifying UI components, run `mise run previews` to regenerate preview images
- Extract pure, testable math into a small `enum` colocated in the same file as the view that
  uses it (e.g. `ZoomAnchor` in `ZoomableDayTimelineView.swift`, `WeekDateMath` in
  `WeekStripView.swift`, `EventPositionMath`/`RescheduleMath` in `TimelineEventBlock.swift`)
  instead of embedding it in view code - keeps gesture/layout math covered by Swift Testing
  without needing to render views
- Views take data already scoped/filtered by the host app (e.g. `items` for just the selected
  day) and expose interaction via stateless closures (`onSelect`) or `Binding`s (`selectedDate`)
  rather than fetching or filtering data themselves
- `Sources/RenderPreviews/main.swift`'s `renderView` attaches the `NSHostingView` to a real,
  hidden `NSWindow` and pumps the run loop briefly before capturing a bitmap - required for
  previewing views with `.onAppear`-driven state (e.g. initial scroll position). A bare
  `NSHostingView` never gets a chance to run that state update before the snapshot is taken
