<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.3.1] - 2026-07-23

### Fixed

- Entering edit mode on macOS now requires a double-click instead of a single click, preventing accidental drags when clicking through several events

## [1.3.0] - 2026-07-23

### Added

- Custom `calendar`/timezone support for `ZoomableDayTimelineView` and `WeekTimelineView`

### Fixed

- Event positions no longer drift across DST transitions
- Rescheduled events no longer snap back if the host is slow to persist them
- Dragging an event no longer gets interrupted when another event enters edit mode
- Hour labels now align with their grid lines
- Timeline no longer freezes when paging days mid-edit
- Correct hour range when the day starts at a non-zero minute
- Read-only events no longer block taps or scrolling meant for the container
- Overlapping event columns no longer affected by unrelated events elsewhere in the day
- Pinch-to-zoom no longer gets stuck after a cancelled gesture

## [1.2.0] - 2026-07-22

### Added

- Tap-to-select on `DayTimelineView` event blocks
- A zoomable, scrollable full-day timeline (`ZoomableDayTimelineView`) with pinch-to-zoom
- A locale-aware week view (`WeekStripView`/`WeekTimelineView`) with swipe/chevron day navigation
- Editing capabilities for `ZoomableDayTimelineView`/`WeekTimelineView`: drag to move or resize events, create new events by long-press or click-drag, delete events from an in-timeline affordance, and edit-session lifecycle notifications (`onEditStart`/`onEditEnd`)

### Changed

- Event blocks now hit-test via `.position()` instead of `.offset()`, so tap targets align with rendered frames on macOS
- Raised the macOS deployment target to 15

### Fixed

- Event vertical offset math now anchors on start-of-day instead of leaking the reference date's minutes into every event's position

## [1.1.0] - 2025-12-30

### Added

- `ExpandableTimelineContainer`, a compact-to-full-day expand/collapse container with a matched geometry transition

## [1.0.0] - 2025-12-30

Initial release.

### Added

- `TimelineItem` view model and `DayTimelineView`/`CompactTimelineView` for displaying calendar events on an hour grid, with automatic column layout for overlapping events
- `HeightMode` for `CompactTimelineView` (`.flexible` / `.fixed(hours:)`)
- `AccessPromptView`/`.accessRestricted(_:)` for permission-gated content
- `TimelineUIEventKit` module for `EKEvent` ↔ `TimelineItem` conversion
- DocC documentation and a `RenderPreviews` CLI for generating preview screenshots

[1.3.1]: https://github.com/chronophy/timeline-ui/releases/tag/1.3.1
[1.3.0]: https://github.com/chronophy/timeline-ui/releases/tag/1.3.0
[1.2.0]: https://github.com/chronophy/timeline-ui/releases/tag/1.2.0
[1.1.0]: https://github.com/CleanCocoa/timeline-ui/releases/tag/1.1.0
[1.0.0]: https://github.com/CleanCocoa/timeline-ui/releases/tag/1.0.0
