# Audio

Every file here is a generated placeholder, made by `tools/make_audio_placeholders.gd`. Replace any of
them with a real sound under the same name; nothing else needs to change. `AudioManager` plays them by
name: `"win"` is `win.wav`, `"forest/place"` is `forest/place.wav`.

| Name | Plays when |
|---|---|
| `win` | The player answers right |
| `lose` | The player answers wrong (keep it soft and friendly) |
| `complete` | The star screen appears after a difficulty's last level |
| `tap` | A button or card is tapped in the menu, level picker or star screen |
| `<world>/place` | A piece goes in: a plank, bag or fruit |
| `<world>/remove` | A piece comes back out, or a balloon pops |
| `<world>/ambience` | Loops quietly while in that world |
| `menu/ambience` | Loops quietly on the main menu |

Every registered world needs its own `ambience`, `place` and `remove`; a test fails if one is missing.
Background loops are set to repeat when played, so their files need no loop settings.
