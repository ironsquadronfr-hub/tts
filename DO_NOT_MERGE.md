# Do not merge this branch as it is

Everything this branch was made for (the V2 tokens and the smoke volume) is
already in the `loader` branch and in halestom's beta (`Wet_Mud_Guerillas`).

What it still carries is an old copy of the overlay toggle code,
`mod/src/includes/IsqOverlays.ttslua` (`macRefreshModeUI`). Each time it
rebuilds the UI (on load and on every click of the overlay button), the
Welcome changelog text doubles its indentation: 22 → 44 → 88 … spaces per line.
After 16 clicks the UI weighs 17 MB, which lags and then freezes the table
(measured 15/11/2026).

Merging this branch would bring the bug back. If it is ever picked up again,
trim the text lines before `UI.setXmlTable`, as `trimXmlTextIndent` does in
`ExtendedOverlays.ttslua` on `loader` (commit c2f1b01) and in
halestom15/tts PR #55.
