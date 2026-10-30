# Picnic sprites

**Every PNG in this folder is a programmer-art placeholder**, drawn by
`tools/make_picnic_placeholders.gd`. Replace each with final art using the **same filename and
dimensions** and the scenes pick it up unchanged.

| File | Size | Notes |
|---|---|---|
| `bg_picnic.png` | 1800×1000 | Meadow and blanket; the 1280×720 play area is centred, like `bg_river.png` |
| `tray.png` | 640×260 | The fox's plate the child fills (drawn as a `NinePatchRect`, 16 px margins) |
| `guest_plate.png` | 170×100 | Each friend's plate; dealt fruit is drawn on top |
| `basket.png` | 120×80 | Basket each fruit comes from; one per fruit, its total is drawn beside it |
| `icon_strawberry.png` | 64×64 | Strawberry; the pieces the child places and the small fruit on friends' plates |
| `icon_apple.png` | 64×64 | Apple (green, so it reads differently from the strawberry) |
| `icon_banana.png` | 64×64 | Banana |

The fox and its friends reuse the Forest Bridge character sheets (idle, celebrate, and the sad
sheet `forest_bridge/character_sad.png`). The friends are tinted copies of the fox; final art
should give them their own animals.

The Go and retry buttons reuse `forest_bridge/go_icon.png` and `forest_bridge/retry_icon.png`.
