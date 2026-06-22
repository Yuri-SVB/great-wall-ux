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

Played through the `SoundBoard` controller; muting is a simple flag.
These are display-only feedback and are never logged.
