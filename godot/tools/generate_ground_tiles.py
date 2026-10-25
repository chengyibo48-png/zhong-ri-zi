"""Generate the compact seasonal ground atlas used by FarmWorld's TileMapLayer."""

from pathlib import Path
import random


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "art" / "ground_tiles.svg"
SEASONS = ["spring", "summer", "autumn", "winter"]

# Each material keeps a related hue across seasons, while tile detail placement
# is deterministic so a rebuilt atlas leaves maps and screenshots reproducible.
MATERIALS = [
    {"base": ["#929b87", "#89967f", "#969477", "#a5b2a3"], "light": "#c0c7b1", "shade": "#707c70"},  # mountain gravel
    {"base": ["#b7b09a", "#b4ae98", "#b4aa8d", "#c2c6ba"], "light": "#d2cbb1", "shade": "#918d7d"},  # town stone
    {"base": ["#b9c2a4", "#b2c0a2", "#b9b89d", "#bdc7b7"], "light": "#d6d5b7", "shade": "#96a58f"},  # river sand
    {"base": ["#73945e", "#648b55", "#8d9460", "#829a84"], "light": "#a3b779", "shade": "#4f704c"},  # bamboo foliage ground
    {"base": ["#83a765", "#749f58", "#a39c5b", "#9eafa0"], "light": "#b4c67d", "shade": "#5f824e"},  # farm grass
    {"base": ["#91ad6c", "#84a45e", "#9a9856", "#a8b7a6"], "light": "#bfca83", "shade": "#698550"},  # pasture
    {"base": ["#bba47a", "#b59a6d", "#b9a175", "#c5c1a9"], "light": "#d5be8e", "shade": "#927a59"},  # earth path
    {"base": ["#a6ad9c", "#a1a995", "#a9a58c", "#b8c0b3"], "light": "#c7cbb9", "shade": "#858c7e"},  # stone path
    {"base": ["#6b9d9a", "#5e999b", "#709493", "#879e9d"], "light": "#94c2b8", "shade": "#4d7f84"},  # water
    {"base": ["#957956", "#8f704e", "#9a7954", "#a79a7e"], "light": "#bc9a6b", "shade": "#70563f"},  # wood path
]


def rect(x: int, y: int, w: int, h: int, color: str) -> str:
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def render_tile(kind: int, season: int, variant: int) -> str:
    rng = random.Random(0x5EED + kind * 1009 + season * 131 + variant * 17)
    material = MATERIALS[kind]
    parts = [rect(0, 0, 32, 32, material["base"][season])]

    if kind == 8:  # water: broken glints and calm horizontal currents
        for _ in range(5 + variant):
            x = rng.randrange(1, 27)
            y = rng.randrange(2, 30)
            width = rng.randrange(3, 10)
            color = material["light"] if rng.random() < 0.58 else material["shade"]
            parts.append(rect(x, y, min(width, 31 - x), 1, color))
        if season == 3:
            for _ in range(3):
                x = rng.randrange(1, 24)
                y = rng.randrange(3, 29)
                parts.append(rect(x, y, rng.randrange(3, 8), 2, "#d7e3d9"))
    elif kind in (6, 7, 9):
        # Paths get small wear marks, with visible seams for masonry and planks.
        for _ in range(7):
            x = rng.randrange(1, 29)
            y = rng.randrange(1, 29)
            parts.append(rect(x, y, rng.randrange(1, 4), 1, material["light"] if rng.random() < 0.6 else material["shade"]))
        if kind == 7:
            parts.extend([rect(0, 15, 32, 1, material["shade"]), rect(14, 0, 1, 15, material["shade"]), rect(25, 16, 1, 16, material["shade"])])
        elif kind == 9:
            for y in (7, 16, 25):
                parts.append(rect(0, y, 32, 1, material["shade"]))
            parts.extend([rect(8, 0, 1, 7, material["shade"]), rect(22, 8, 1, 8, material["shade"]), rect(12, 17, 1, 8, material["shade"])])
    else:
        count = 5 if kind in (0, 1, 2) else 7
        for _ in range(count):
            x = rng.randrange(1, 30)
            y = rng.randrange(1, 30)
            width = rng.randrange(1, 4)
            parts.append(rect(x, y, width, rng.randrange(1, 3), material["light"] if rng.random() < 0.56 else material["shade"]))
        if season == 0 and kind in (3, 4, 5) and variant % 2 == 0:
            for _ in range(2):
                x = rng.randrange(3, 29)
                y = rng.randrange(3, 29)
                parts.extend([rect(x, y, 2, 1, "#e7dfbd"), rect(x + 1, y - 1, 1, 3, "#e7dfbd")])
        elif season == 2 and kind in (3, 4, 5):
            for _ in range(2 + variant % 2):
                x = rng.randrange(2, 29)
                y = rng.randrange(2, 29)
                parts.append(rect(x, y, 2, 2, "#c49b50" if rng.random() < 0.55 else "#ba7653"))
        elif season == 3:
            for _ in range(2 + variant % 2):
                x = rng.randrange(2, 29)
                y = rng.randrange(2, 29)
                parts.append(rect(x, y, rng.randrange(2, 5), 1, "#e2e9df"))

    return "\n    ".join(parts)


def main() -> None:
    tile_rows = len(SEASONS) * 4
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="{tile_rows * 32}" viewBox="0 0 320 {tile_rows * 32}" shape-rendering="crispEdges">'
    ]
    for season, _name in enumerate(SEASONS):
        for variant in range(4):
            row = season * 4 + variant
            for kind in range(len(MATERIALS)):
                lines.append(f'  <g transform="translate({kind * 32},{row * 32})">')
                lines.append("    " + render_tile(kind, season, variant))
                lines.append("  </g>")
    lines.append("</svg>")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(MATERIALS)} materials x {len(SEASONS)} seasons x 4 variants)")


if __name__ == "__main__":
    main()
