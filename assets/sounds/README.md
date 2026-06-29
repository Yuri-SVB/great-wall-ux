# Sounds

Short UI sound cues for the "sober, but game-like" interaction surface
(see `great-wall-docs/great-wall-ux/SCOPE.md`). Synthesised procedurally
(no third-party samples) as a futuristic-console homage:

| file          | cue     | when                                   |
|---------------|---------|----------------------------------------|
| `click.wav`   | click   | any pointer tap on the canvas          |
| `select.wav`  | select  | a point is committed                   |
| `confirm.wav` | confirm | a stage decode/encode completes        |
| `deny.wav`    | deny    | a rejected / invalid action            |

Played through the `SoundBoard` controller. Volume is a discrete level from
`0` to `kMaxVolumeLevel` (11 settings); **level `0` is silent and is exactly
what "muted" means** — there is no separate mute flag. The canvas exposes
`V` + Up/Down as a live volume hotkey (mirroring `L` + scroll for brightness),
and each step plays a cue at the new level as feedback. These are display-only
feedback and are never logged.
