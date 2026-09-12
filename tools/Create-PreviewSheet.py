"""Arrange unscaled native window captures into a review sheet; never invent UI or telemetry."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument("captures", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
columns = [("CPU", "RAM"), ("GPU", "Network"), ("IO", "Chronometer"), ("Media", "Visualizer")]
shots = {name: Image.open(args.captures / f"{name}.png").convert("RGB") for col in columns for name in col}
column_width = max(shot.width for shot in shots.values())
column_height = max(sum(shots[name].height for name in col) for col in columns)
sheet = Image.new("RGB", (column_width * 4 + 32, column_height + 90), (0, 0, 0))
draw = ImageDraw.Draw(sheet)
font_root = Path(__file__).resolve().parents[1] / "Skins/Parallax/@Resources/Fonts"
title_font = ImageFont.truetype(str(font_root / "IBMPlexSans-SemiBold.ttf"), 20)
caption_font = ImageFont.truetype(str(font_root / "IBMPlexSans-Regular.ttf"), 12)
draw.text((20, 10), "PARALLAX", font=title_font, fill=(220, 220, 220))
draw.text((20, 37), "ModernGadgets-inspired starting point / actual Rainmeter window captures", font=caption_font, fill=(175, 175, 175))
positions = []
for index, column in enumerate(columns):
    x, y = 16 + column_width * index, 62
    for name in column:
        shot = shots[name]
        sheet.paste(shot, (x, y))
        positions.append({"module": name, "source": str((args.captures / f"{name}.png").resolve()), "x": x, "y": y, "width": shot.width, "height": shot.height})
        y += shot.height
draw.text((20, sheet.height - 20), "Native capture snapshots; Media shows dependency setup. Values reflect the captured moment.", font=caption_font, fill=(145, 145, 145))
args.output.parent.mkdir(parents=True, exist_ok=True)
sheet.save(args.output)
args.output.with_suffix(".json").write_text(json.dumps({"description": "Unscaled screenshot contact sheet; pixels inside each source capture are unchanged.", "captures": positions}, indent=2), encoding="utf-8")
print(args.output.resolve())
