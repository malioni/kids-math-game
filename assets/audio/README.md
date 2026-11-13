# Audio

Every file here is a generated placeholder, made by `tools/make_audio_placeholders.gd`. Replace any of
them with a real sound under the same name; nothing else needs to change. `AudioManager` plays them by
name: `"win"` is `win.wav`, `"forest/place"` is `forest/place.wav`.

| Name | Plays when |
|---|---|
| `win` | The player answers right |
| `lose` | The player answers wrong: three notes stepping down (keep it soft and friendly) |
| `complete` | The star screen appears after a difficulty's last level |
| `tap` | A button or card is tapped in the menu, level picker or star screen |
| `<world>/place` | A piece goes in: a plank, bag or fruit, or a memory card turns over |
| `<world>/remove` | A piece comes back out, a balloon pops, or two memory cards that don't match turn back |
| `<world>/ambience` | Loops quietly while in that world; the market's is a quick, bouncy 16 s tune |
| `menu/ambience` | Loops quietly on the main menu: a 16 s music-box tune |
| `market/splat` | The thrown tomato hits the table, after `lose` |
| `memory/match` | A memory pair is found (not the last one, which plays `win`) |

Every registered world needs its own `ambience`, `place` and `remove`; a test fails if one is missing.
Background loops are set to repeat when played, so their files need no loop settings.
