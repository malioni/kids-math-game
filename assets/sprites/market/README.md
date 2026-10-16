# Market sprites

**Every PNG in this folder is a programmer-art placeholder**, drawn by
`tools/make_market_placeholders.gd`. Replace each with final art using the **same filename and
dimensions** and the scenes pick it up unchanged.

| File | Size | Notes |
|---|---|---|
| `bg_market.png` | 1800×1000 | Market stall; the 1280×720 play area is centred, like `bg_river.png` |
| `table.png` | 760×330 | Table top the bags are placed on (drawn as a `NinePatchRect`, 12 px margins) |
| `crate.png` | 150×110 | Crate each item's bags come from; one per ordered item |
| `bag.png` | 96×96 | Paper bag; leave the face blank (the bag size and item icon are drawn on top) |
| `bag_shadow.png` | 96×96 | Shown under a bag while it is dragged |
| `order_slip.png` | 200×230 | The customer's order; leave blank (amounts and icons are drawn on top) |
| `icon_tomato.png` | 64×64 | Tomato icon on bags and the order slip; also the thrown tomato |
| `icon_potato.png` | 64×64 | Potato icon |
| `icon_carrot.png` | 64×64 | Carrot icon |
| `customer_idle.png` | 640×220 | 4 frames of 160×220, looping |
| `customer_happy.png` | 640×220 | 4 frames, looping; plays on a correct order |
| `customer_throw.png` | 640×220 | 4 frames, plays once on a wrong order; the tomato leaves the hand after the last frame |
| `splat.png` | 200×200 | Tomato splat shown over the table after a throw |

The Go and retry buttons reuse `forest_bridge/go_icon.png` and `forest_bridge/retry_icon.png`.
