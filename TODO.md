# TODO

Possible additions and polish for k5. Items are unordered; pick whatever looks fun.

## Wallpaper / backgrounds

- [ ] Use `awww` transition settings from the bar's own transition picker (grow/wave/etc.) instead of hard-coding `grow`.
- [ ] Expose a “default floor” image for the time before `awww-daemon` is ready, so the first frame is never black.
- [ ] Optional `swww` binary check could be removed once `awww` is assumed.

## Clipboard

- [x] Make “Clear All” guarantee the system clipboard is empty (wl-clipboard + cliphist).
- [ ] Show a toast confirming that the clipboard was cleared.
- [ ] Allow clearing only text or only images while keeping pins.
- [ ] Add a “copy without saving to history” mode for passwords.

## Capture and editing

- [ ] Add explicit Satty action in the capture UI (not just shortcut) with tool presets.
- [ ] Batch export selected clips with different formats/resolutions.
- [ ] Let the poster frame be chosen manually for videos/GIFs.

## OpenCode / agents

- [ ] Show OpenCode usage (tokens/cost) in the Agentes plugin using `opencode stats --json`.
- [ ] Add OpenCode to Agentes launcher keywords (already present in Terminal).
- [ ] Detect the OpenCode background service health in Diagnostics.

## UI / polish

- [ ] Empty-state illustrations for Panel media and other widgets (already partially done).
- [ ] Animated Wi-Fi strength steps in the panel tile.
- [ ] Translate remaining big-file comments and README fully to English (done now; ongoing).
- [ ] Rename more user-visible Spanish identifiers (flags stay as aliases for compat).

## Reliability

- [ ] Run `quickshell` syntax check in CI for all QML files.
- [ ] Add unit tests for `tools/portapapeles.py` and `tools/agentes.py`.
- [ ] Make optional hardware-specific deps (nvidia-utils) conditional in diagnostics. (Done now)
