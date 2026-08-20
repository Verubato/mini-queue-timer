# MiniQueueTimer reference

## What it does

Shows on-screen text with how long you have been waiting in your longest active
PvP or PvE queue, plus the estimated wait. Two lines of text: elapsed queue time on
top, estimated wait below. The text only appears while you are actually queued and
disappears otherwise. It is hidden entirely while inside an instance.

## Facts

| Item | Value |
| --- | --- |
| Version | 1.4.6 |
| Author | Verz |
| Interface versions (TOC) | 120100, 50504, 40402, 38002, 38000, 30405, 30300, 20506, 11509 |
| Saved variables | MiniQueueTimerDB |
| Slash commands | /mqt, /miniqueuetimer, /miniqt (all open the settings panel) |
| Options location | Game options -> AddOns -> MiniQueueTimer |
| Bundled libraries | LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, MiniFramework |
| Integrations | Fonts registered by other addons via LibSharedMedia appear in the Font dropdown |

## Features

### Queue tracking

- PvP: scans all battlefield queues whose status is "queued" or "confirm" and reads
  time waited and estimated wait from the battlefield API.
- PvE (only on clients that have the LFG API): checks whichever of these LFG
  categories exist on the client: Dungeon Finder (LFD), Raid Finder (LFR), RF,
  Scenario, and Battlefield, for modes "queued", "proposal", or "confirm".
- If queued for several things at once, the queue with the longest elapsed time is
  shown; on a tie the PvP queue wins.
- Times are formatted as minutes and seconds. If a value is unavailable (for
  example no estimate yet), that line shows "Unknown".
- The display refreshes every 0.25 seconds while a queue is active, and the refresh
  timer stops about 2 seconds after no queue data is found.

### Positioning

- Drag the text with the left mouse button to move it; the position is saved.
  Default position is bottom center of the screen, 200 px up.
- The frame only accepts the mouse while the timer text is visible, so to
  reposition it without being in a queue, turn on Preview first.
- There is no lock option.

## Settings

Single options panel with two sections plus two buttons.

### Font section

| Setting | Type | Default | Range / options | Notes |
| --- | --- | --- | --- | --- |
| Font | dropdown | Friz Quadrata | All LibSharedMedia fonts; falls back to 5 built-in fonts (Friz Quadrata, Arial Narrow, Morpheus, Skurri, Myriad Pro) | Applied to both text lines. |
| Outline | dropdown | Outline | Outline, Thick Outline, Monochrome, None | |
| Font Size | slider | 18 | 8-64 | |
| Font Color | color swatch | white (1, 1, 1, 1) | any color + alpha | Label reads "Font Color (click to change)". |

### Text section

| Setting | Type | Default | Notes |
| --- | --- | --- | --- |
| Queue Text | edit box | "Time in queue: %02d:%02d" | Format string; the two %02d placeholders receive minutes then seconds. Empty text is rejected (keeps the old value). |
| Estimated Text | edit box | "Estimated: %02d:%02d" | Same placeholder rules. |

### Buttons

- Preview ("Preview: Off" / "Preview: On"): toggles a fake timer so the text can be
  styled and dragged without queueing. The elapsed time counts up from when preview
  was enabled and the estimated line shows a fixed 5:00.
- Reset Defaults: resets all settings in MiniQueueTimerDB to defaults immediately
  (no confirmation prompt).

## Version-gated behavior

- PvE queue tracking depends on the LFG API and category constants existing on the
  client; on clients without them (for example Classic Era) only PvP queues are
  tracked.
- On Midnight (12.x) clients the settings panel cannot be opened during combat; the
  slash command prints "Can't do that during combat." instead.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| No timer shows while queued | You are inside an instance: the display is hidden by design in instances. Otherwise the queue API has not reported an elapsed time yet; it appears once the wait time is greater than zero. |
| Timer not visible and I want to move it | The frame is only draggable while text is showing. Enable the Preview button in the options, drag the text, then turn Preview off. |
| Estimated line says "Unknown" | The client has not provided an estimated wait for that queue. Normal for some queue types. |
| Only my PvP queue shows, not the dungeon queue | The longest elapsed queue wins; also on Classic-style clients without the LFG API, PvE queues are not tracked. |
| Timer vanished mid-queue | The timer hides when it stops receiving queue data (for example the queue popped or was left) and also on entering an instance. |
| My custom text broke the timer | The Queue Text and Estimated Text values are format strings; keep two %02d number placeholders (minutes, seconds) in them. |
| Changed fonts do not appear in the dropdown | Only fonts registered through LibSharedMedia (usually by another addon like SharedMedia) are listed; otherwise only the 5 built-in fonts show. |
