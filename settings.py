TITLE = "Echoes of the Fractured Age"
SCREEN_WIDTH = 960
SCREEN_HEIGHT = 640
TILE_SIZE = 48
FPS = 60
PLAYER_SPEED = 3

# Tile types
FLOOR = 0
WALL = 1
WATER = 2

# 20 cols x 12 rows = 960 x 576px map, leaving 64px for HUD
MAP_DATA = [
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,1],
    [1,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]

MAP_HEIGHT = len(MAP_DATA) * TILE_SIZE   # 576
UI_HEIGHT = SCREEN_HEIGHT - MAP_HEIGHT   # 64

ERA_ORDER = ["verdant", "iron", "ashen"]

ERAS = {
    "verdant": {
        "name": "The Verdant Age",
        "subtitle": "Ancient. Nature-ruled.",
        "overlay": (10, 60, 10, 50),
        "bg":       (20, 40, 20),
        "floor":    (45, 95, 45),
        "wall":     (25, 55, 25),
        "water":    (30, 100, 160),
        "player":   (200, 170, 100),
        "npc":      (180, 140, 80),
        "ui_bg":    (15, 35, 15),
        "ui_text":  (180, 230, 140),
        "hud_era":  (100, 200, 80),
    },
    "iron": {
        "name": "The Iron Compact",
        "subtitle": "Industrial. Political intrigue.",
        "overlay": (60, 50, 30, 50),
        "bg":       (55, 48, 38),
        "floor":    (100, 88, 70),
        "wall":     (65, 55, 42),
        "water":    (55, 80, 120),
        "player":   (180, 155, 115),
        "npc":      (160, 130, 95),
        "ui_bg":    (45, 38, 28),
        "ui_text":  (230, 210, 170),
        "hud_era":  (220, 180, 100),
    },
    "ashen": {
        "name": "The Ashen Future",
        "subtitle": "Post-collapse. Corrupted.",
        "overlay": (40, 20, 60, 60),
        "bg":       (35, 30, 45),
        "floor":    (75, 65, 90),
        "wall":     (45, 38, 58),
        "water":    (40, 100, 130),
        "player":   (150, 130, 180),
        "npc":      (130, 110, 160),
        "ui_bg":    (28, 22, 38),
        "ui_text":  (200, 180, 230),
        "hud_era":  (160, 120, 220),
    },
}

# NPC Maren has different memories of you in each era
NPC_DIALOGUE = {
    "verdant": [
        "Tidewarden... you carry the scent of other ages on you.",
        "The forest knows. These trees remember before your kind fractured time.",
        "Be careful near the water. The spirits here are uneasy.",
        "[End of conversation]",
    ],
    "iron": [
        "You there — Tidewarden. The Compact doesn't take kindly to your sort.",
        "I used to believe in the fracture too. Then I watched it swallow my daughter whole.",
        "The Council chamber is east. Don't mention the old forest to them.",
        "[End of conversation]",
    ],
    "ashen": [
        "Still breathing. Didn't expect that.",
        "Most Tidewardens burned up in the Collapse.",
        "Whatever you're trying to fix... some things are broken for a reason.",
        "[End of conversation]",
    ],
}
