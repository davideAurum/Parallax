"""Check actual IO meter geometry against the supported appearance matrix.

No Rainmeter process is launched. This checks declared geometry, not glyph ink,
Windows DPI behavior, telemetry, or screenshot quality. Packaging excludes tests.
"""
from pathlib import Path
import configparser
import math
import re


ROOT = Path(__file__).resolve().parents[4]
COMMON = (
    "@Resources/Defaults.inc",
    "@Resources/User/Settings.inc",
    "@Resources/User/IO.inc",
    "@Resources/Geometry.inc",
    "@Resources/Styles.inc",
)
PROFILES = {
    "monitor": (COMMON + ("@Resources/Modules/IO/Native.inc", "@Resources/Modules/IO/View.inc"), (1, 2)),
    "settings": (COMMON + ("IO/Settings/Settings.ini", "@Resources/Modules/IO/SettingsMeters.inc"), (2,)),
}


def formula(expression, variables):
    value = str(expression)
    for _ in range(30):
        expanded = re.sub(r"#([^#]+)#", lambda m: str(variables[m[1]]), value)
        if expanded == value:
            break
        value = expanded
    # Only local, trusted INI numeric formulas are evaluated, without builtins.
    return eval(value, {"__builtins__": {}}, {
        "Round": lambda n: math.floor(n + .5), "Max": max,
        "Min": min, "Ceil": math.ceil,
    })


def check_profile(includes, column_counts, fonts):
    sections = {}
    for relative in includes:
        parser = configparser.ConfigParser(interpolation=None, comment_prefixes=(";",))
        parser.optionxform = str
        parser.read(ROOT / relative, encoding="utf-8-sig")
        for name in parser.sections():
            sections.setdefault(name, {}).update(dict(parser[name]))
    defaults = sections["Variables"]
    checks = 0
    for width in (180, 200, 240, 280, 320):
        for scale in (.75, 1, 1.25, 1.5, 2):
            for columns in column_counts:
                variables = dict(defaults, ColumnWidth=width, Scale=scale, Columns=columns)
                variables.update(fonts)
                window_width = formula(variables["WindowWidth"], variables)
                window_height = formula(variables["WindowHeight"], variables)
                for name, section in sections.items():
                    if "Meter" not in section:
                        continue
                    options = {}
                    for style in section.get("MeterStyle", "").split("|"):
                        options.update(sections.get(style, {}))
                    options.update(section)
                    x, y, w, h = [formula(options.get(key, 0), variables) for key in "XYWH"]
                    if options.get("MeterStyle") == "StylePanel":
                        w = formula(variables["PanelWidth"], variables)
                        h = formula(variables["PanelHeightPx"], variables)
                    if options.get("StringAlign", "").startswith("Right"):
                        x -= w
                    elif options.get("StringAlign", "").startswith("Center"):
                        x -= w / 2
                    assert w > 0 and h > 0, (name, "nonpositive dimensions")
                    assert x >= 0 and y >= 0 and x+w <= window_width+.01 and y+h <= window_height+.01, (
                        name, width, scale, columns, x, y, w, h, window_width, window_height)
                    checks += 1
                assert formula(variables["PanelWidth"], variables) == (
                    columns * formula(variables["Pitch"], variables)
                    - formula(variables["Gap"], variables))
    return checks


def main():
    for typography, fonts in {
        "default": dict(TitleFontSize=10, HeaderFontSize=8, FontSize=9),
        "maximum": dict(TitleFontSize=12, HeaderFontSize=10, FontSize=10),
    }.items():
        for name, (includes, column_counts) in PROFILES.items():
            checks = check_profile(includes, column_counts, fonts)
            print(f"PASS: {checks} IO {name} meter bounds, {typography} typography; five widths, five scales, Columns={column_counts}.")


if __name__ == "__main__":
    main()
