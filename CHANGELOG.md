<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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

[1.1.0]: https://github.com/CleanCocoa/timeline-ui/releases/tag/1.1.0
[1.0.0]: https://github.com/CleanCocoa/timeline-ui/releases/tag/1.0.0
