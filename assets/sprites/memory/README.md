# Memory Meadow sprites

**Every PNG in this folder is a programmer-art placeholder**, drawn by
`tools/make_memory_placeholders.gd`. Replace each with final art using the **same filename and
dimensions** and the scenes pick it up unchanged.

| File | Size | Notes |
|---|---|---|
| `bg_memory.png` | 1800×1000 | Meadow with a lighter clearing behind the cards; the 1280×720 play area is centred, like `bg_river.png` |
| `card_back.png` | 160×160 | The face-down side of every card |
| `card_front.png` | 160×160 | The face-up side; the animal is drawn on top |
| `animal_<name>.png` | 128×128 | One face per animal: fox, rabbit, bear, owl, frog, hedgehog, mouse, duck, pig, cat, deer, squirrel. Each needs a clearly different main colour and outline, so pairs are easy to tell apart at a glance |

Cards are scaled to fit the board, from 200 px (4 cards) down to about 155 px (20 cards).

The fox beside the board reuses the Forest Bridge character sheets (idle and celebrate). The retry
button reuses `forest_bridge/retry_icon.png`, though this world never shows it.
