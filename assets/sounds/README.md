# Sounds

Short UI sound cues for the "sober, but game-like" interaction surface
(see `great-wall-docs/great-wall-ux/SCOPE.md`). Synthesised procedurally
(no third-party samples) as a futuristic-console homage.

## How it's organised

Each **theme** is a directory under `assets/sounds/` holding one wav per cue.
The active theme defaults to `sober/`; theme *selection* is a later step. To
**change a cue, just replace its wav** in the theme directory — the filename is
the contract; no code or pubspec change is needed (the directory is declared
wholesale in `pubspec.yaml`). To **add a theme**, copy `sober/` to a sibling
directory, swap the wavs, add a `SoundTheme` value and a pubspec line.

First cut: every cue is a copy of one of the four base primitives, so the cue
set sounds uniform today. They are meant to diverge — that's why each has its
own file. Played through the `SoundBoard` controller; volume is a discrete level
(`0` = silent = muted). Display-only feedback, never logged.

## Cues (`sober/`)

Base primitives:

| file          | cue       | meaning                                  |
|---------------|-----------|------------------------------------------|
| `click.wav`   | click     | generic tap / neutral UI press           |
| `select.wav`  | select    | generic affirmative selection            |
| `confirm.wav` | confirm   | generic success                          |
| `deny.wav`    | deny      | generic rejected / invalid action        |

Errors & negatives (copies of `deny`):

| file               | cue          | meaning                                 |
|--------------------|--------------|-----------------------------------------|
| `deny_blocked.wav` | denyBlocked  | blocked by a precondition (no prior pt) |
| `deny_pending.wav` | denyPending  | not yet — inter-stage hashing running   |
| `deny_miss.wav`    | denyMiss     | point in a contracted-away area         |
| `deny_input.wav`   | denyInput    | invalid text input (number / generic)   |
| `warn.wav`         | warn         | destructive confirmation (abort/reset)  |
| `undo.wav`         | undo         | remove / undo (tbd)                     |

Soft ticks, UI, directional (copies of `click`):

| file               | cue          | meaning                                 |
|--------------------|--------------|-----------------------------------------|
| `tick_soft.wav`    | tickSoft     | soft keystroke / corrected input        |
| `focus.wav`        | focus        | a field took focus                      |
| `slide.wav`        | slide        | pan / slide the canvas                  |
| `adjust_up.wav`    | adjustUp     | volume / zoom / brightness — more       |
| `adjust_down.wav`  | adjustDown   | volume / zoom / brightness — less       |
| `chrome_up.wav`    | chromeUp     | chrome maximized / restored             |
| `chrome_down.wav`  | chromeDown   | chrome minimized                        |
| `nav_mode.wav`     | navMode      | top-level mode nav (F1–F5)              |
| `mode_off.wav`     | modeOff      | a toggle turned off (fast render)       |

Navigation & selection (copies of `select`):

| file                | cue          | meaning                                |
|---------------------|--------------|----------------------------------------|
| `nav_stage.wav`     | navStage     | moved to a stage (0 or fractal)        |
| `nav_zoom.wav`      | navZoom      | canonical zoom onto a point            |
| `select_point.wav`  | selectPoint  | a point was selected                   |
| `change_point.wav`  | changePoint  | the selected point was changed         |
| `mode_on.wav`       | modeOn       | a toggle turned on (deep render)       |

Success & ready (copies of `confirm`):

| file                | cue          | meaning                                |
|---------------------|--------------|----------------------------------------|
| `stage_ready.wav`   | stageReady   | a new stage became ready (derived)     |
| `final_ready.wav`   | finalReady   | final stage / full recall complete     |
| `digest_ready.wav`  | digestReady  | new intermediary digest (tbd wiring)   |
| `export_ok.wav`     | exportOk     | a secret was exported to the clipboard |
