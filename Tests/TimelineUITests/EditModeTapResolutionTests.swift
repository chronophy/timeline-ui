import Foundation
import Testing

@testable import TimelineUI

@Test func `afterTap keeps editingItemID when the tapped block is already the one editing`() throws {
	let id = UUID()

	let resolved = EditModeTapResolution.afterTap(current: id, tappedID: id)

	#expect(resolved == id)
}

@Test func `afterTap clears editingItemID when a different block was editing`() throws {
	let editing = UUID()
	let tapped = UUID()

	let resolved = EditModeTapResolution.afterTap(current: editing, tappedID: tapped)

	#expect(resolved == nil)
}

@Test func `afterTap leaves nil unchanged when nothing was editing`() throws {
	let resolved = EditModeTapResolution.afterTap(current: nil, tappedID: UUID())

	#expect(resolved == nil)
}

// `afterEditEntryGesture` backs both macOS's double-click (`handleDoubleTap`) and iOS's
// long-press (`entryGesture`) — same decision either way, since both gestures mean the same
// thing once recognized: "enter edit mode for this block." The cases below are exercised once,
// not once per platform, because the function has no platform in its signature to vary on.

@Test func `afterEditEntryGesture enters edit mode for the tapped block when editing is allowed`() throws {
	let tapped = UUID()

	let resolved = EditModeTapResolution.afterEditEntryGesture(current: nil, tappedID: tapped, canEnterEditMode: true)

	#expect(resolved == tapped)
}

@Test func `afterEditEntryGesture moves edit mode from one block to another when editing is allowed`() throws {
	let previouslyEditing = UUID()
	let tapped = UUID()

	let resolved = EditModeTapResolution.afterEditEntryGesture(
		current: previouslyEditing,
		tappedID: tapped,
		canEnterEditMode: true
	)

	#expect(resolved == tapped)
}

@Test func `afterEditEntryGesture leaves editingItemID untouched when the tapped block isn't editable`() throws {
	let previouslyEditing = UUID()
	let tapped = UUID()

	let resolved = EditModeTapResolution.afterEditEntryGesture(
		current: previouslyEditing,
		tappedID: tapped,
		canEnterEditMode: false
	)

	#expect(resolved == previouslyEditing)
}

@Test func `afterEditEntryGesture leaves nil untouched when the tapped block isn't editable`() throws {
	let resolved = EditModeTapResolution.afterEditEntryGesture(current: nil, tappedID: UUID(), canEnterEditMode: false)

	#expect(resolved == nil)
}
