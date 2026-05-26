# Manual Testing Checklist (Tier 3)

Run this before publishing a draft release. Check each item and note the FingerText2 version and date.

**Version:** ___________  
**Date:** ___________  
**Architecture(s) tested:** [ ] 32-bit  [ ] 64-bit

---

## Visual / layout

- [ ] Snippet dock renders with correct button layout (New Snippet, Edit Selected, Save Current Snippet, Delete Selected, Import ftd File, Export Current List, Export All, Delete All, Switch To Snippet Editor, Close Editor)
- [ ] Filter text box is present and filters the list as you type
- [ ] Hotspot insert combo box and Insert button are visible in the lower section
- [ ] No overlapping or clipped controls

## About dialog

- [ ] About dialog opens from Plugins > FingerText2 > About
- [ ] Shows plugin name "FingerText2" followed by a version number
- [ ] Shows author name "Jimmy Pautz"
- [ ] Shows correct homepage URL
- [ ] Text is not garbled (no encoding artifacts)

## Snippet editor

- [ ] Double-clicking a snippet in the dock opens the editor view in a tab named "SnippetEditor.ftb"
- [ ] The editor view displays the snippet header (`<scope>trigger`) on the first line
- [ ] Annotation on the last line renders without visual artifacts

## Snippet expansion

- [ ] Type a valid trigger and press Tab — snippet expands correctly
- [ ] Hotspot placeholder text is selected on expansion
- [ ] Tab advances to the next hotspot; Shift+Tab goes back
- [ ] Terminal marker `$[0[]0]` positions the cursor correctly after all hotspots

## Import / export round-trip

- [ ] Export All produces a non-empty .ftd file
- [ ] Importing the exported .ftd file back reports the correct snippet count
- [ ] No crash or exception during import of a large snippet pack

## Migration (first install alongside old FingerText)

- [ ] With FingerText (original) installed and no FingerText2 config present, installing FingerText2 copies the existing snippets on first launch
- [ ] Old FingerText config folder is left untouched

---

Sign off: ___________
