# Template editor basics — next release after 0.2.5

Date: 2026-11-16
Status: scoped for the next release by operator request; implementation and device validation pending.
Release: next version after released 0.2.5 (8), named 0.2.6 by the operator on 2026-11-21; no version bump or release date in this change.

## Decision and user task

A user editing starter content should be able to find and replace a repeated value without leaving NewFile, and type literal code without prose-oriented substitutions. Deliver native Find/Replace and explicitly configured plain-text editing in the existing template sheet. This is a bounded craft improvement to an existing feature, not a growth experiment.

Lowest-effort visible addition: native Find/Replace. Use the platform text system rather than writing search UI or introducing a code-editor package. Reliable literal input and undo are the foundation for that addition. Syntax highlighting was considered in the May 7 design and deferred; it remains deferred here because language grammars, themes and editing-state integration add more scope than this task needs.

## Evidence and limits

Inspected `App/TemplateEditorSheet.swift` at `bf62ce2`, after the 0.2.5 release:
- A SwiftUI `TextEditor` with a 12-point monospaced font occupies the sheet.
- The view declares no Find/Replace affordance or explicit text-substitution settings.
- Save Template copies the buffer as-is; Cancel discards it. Existing templates can be removed. JSON parsing and shell shebang hints do not prevent saving.
- The sheet already declares flexible dimensions, with a 560 × 420 minimum. A larger editor alone is not a new feature.

These are source observations. The absence of explicit configuration does not prove that build 8 corrupts quotes, lacks undo, or cannot expose native editing commands. Before implementation, walk the installed editor and record what already works. Preserve native behavior already present; do not claim a reproduced defect without that check.

## User-visible scope

1. **Find and replace within the current template.** A small secondary `Find…` button near the editor title opens the native find bar. Command-F does the same when the sheet is active. The native bar exposes Replace; next/previous match use native commands. Search and replacement never reach other file types. No custom toolbar or search engine.
2. **Literal plain text.** Straight quotes stay straight; double hyphens stay double hyphens. Disable automatic quote/dash substitution, automatic spelling correction and automatic text replacement for this editor. Paste imports text without rich-text attributes or attachments. No automatic indentation, reformatting, or whitespace trimming on save. Existing soft wrapping remains presentation-only.
3. **Standard editing.** Cut/copy/paste/select-all and Command-Z / Shift-Command-Z work. Find does not edit the document. Replacement participates in undo. Opening another template starts its own editing session; undo cannot reach another type's content.
4. **Focus and dismissal.** Opening the template sheet places the caret at the end without selecting existing content. This does not change the Settings window's no-field-focused behavior. Command-F focuses search. Escape closes an open find bar first; a subsequent Escape uses the existing Cancel behavior. Command-S saves and dismisses as today.
5. **Keep the current content contract.** Save commits the exact buffer; Cancel commits nothing; Remove Template clears only that type. Preserve the existing empty/whitespace-only behavior and nonblocking JSON/shell hints. The main Settings window remains a singleton.

The editor remains the main visual element; Save Template is the primary action. Find is secondary and replacement controls appear only when requested. Keep the existing sheet title, spacing and system colors. Keyboard and VoiceOver users must be able to reach and identify the editor, search, replacement and action controls. Verify light/dark appearances. Design follows the repository's native-app-design guidance: clear primary action and progressive disclosure.

## Smallest implementation

First check the installed app and supported SDK for existing native functionality. If the SwiftUI editor can meet the entire contract with supported public configuration, retain it. Otherwise replace only the editing surface with a small `NSViewRepresentable` hosting an `NSScrollView` and plain `NSTextView`; retain the SwiftUI sheet and its buffer/save semantics.

Use AppKit's `NSTextFinder`/find bar (`usesFindBar`) and native responder actions, with undo enabled. Route commands to the active editor; do not add app-global shortcuts that steal input from Settings or a different sheet. Explicitly configure substitution behavior per editor, never change system preferences. Keep selection, marked text/IME composition and undo history intact across SwiftUI updates: do not reset the text view's string on every update. No settings migration, new persisted preferences, third-party dependency or release artifact change is needed.

Apple references, checked 2026-11-16:
- [NSTextView](https://developer.apple.com/documentation/AppKit/NSTextView)
- [Native find bar](https://developer.apple.com/documentation/appkit/nstextview/usesfindbar)
- [Automatic quote substitution](https://developer.apple.com/documentation/appkit/nstextview/isautomaticquotesubstitutionenabled)
- [Undo support](https://developer.apple.com/documentation/appkit/nstextview/allowsundo)

Target remains macOS 13 and later. Verify public APIs against that deployment target. No reliance on private view introspection.

## Acceptance and shortest verification path

Record the baseline first, then test the changed sheet on a local candidate. Add focused regression coverage for buffer synchronization, Cancel isolation and undo only where the chosen implementation creates those failure modes; do not count source-string assertions as interaction tests.

- Load a multiline template with repeated `PROJECT_NAME`. Find via button and Command-F; move between matches; replace one and all; undo and redo. A missing query shows the native no-match state without changing content.
- Type ASCII quotes, apostrophes, `--`, indentation and a trailing newline. Paste formatted source text. Save, reopen, and create a file through the actual Finder extension: its UTF-8 content equals the intended plain-text buffer, including whitespace.
- Edit and replace, then Cancel: reopen to the original content. Save changes only the selected type. Remove Template retains its existing behavior.
- Open a second file type: no prior buffer or undo history leaks. Cursor and composed text do not jump or disappear while editing. Check a non-ASCII/IME input path.
- Verify sheet focus, Escape ordering and Command-S; opening Settings itself still selects no field. Find does not open another Settings window.
- Check an empty template, existing whitespace-only template, long line, and multiline template; no clipping or forced horizontal growth. Existing JSON and shell hints still allow saving.
- Verify keyboard navigation and accessibility labels, light/dark mode, deployment-target compatibility, and the supported current macOS version. State any older-OS runtime check not performed.

Done means the feature passes these interaction checks and the repository's applicable build/tests. Signing, update delivery and release publication use the existing release runbook separately. This spec does not authorize a release or alter the installed 0.2.5 app.

## Cut from this release scope

Syntax highlighting, line-number gutter, font/size controls, wrap toggle, auto-indent, completion, bracket matching, rich-text formatting, template variables, multiple named templates, import/export, external editor integration, previews and formatters. Revisit these only for a named editing task; they are not implied follow-on work.
