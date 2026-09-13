"""Check Settings geometry from real INI/includes without running Rainmeter.

Run with Python 3.10+. No third-party packages or source mutations.
This evaluates the suite's small formula subset and declared/padded rectangles;
it does not render fonts, reproduce all Rainmeter parsing, or test Windows DPI.
Padding semantics: https://docs.rainmeter.net/manual/meters/general-options/#Padding
"""
from __future__ import annotations

import ast
import itertools
import math
import operator
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2] / "Skins" / "Parallax"
ENTRYPOINT = ROOT / "Settings" / "Settings.ini"
VARIABLE = re.compile(r"#([^#]+)#")
NUMERIC_CONTROLS = {
    "MeterScale": "Scale", "MeterWidth": "ColumnWidth", "MeterGap": "Gutter",
    "MeterRounding": "CornerRadius", "MeterTitleSize": "TitleFontSize",
    "MeterHeaderSize": "HeaderFontSize", "MeterBodySize": "FontSize",
    "MeterBackgroundTransparency": "BackgroundTransparency",
    "MeterBorderSize": "BorderThickness", "MeterDividerSize": "DividerThickness",
    "MeterTableHeaderBorderSize": "TableHeaderBorderThickness", "MeterDataBarSize": "DataBarThickness",
}


def expand(text: str, variables: dict[str, str]) -> str:
    for _ in range(40):
        replaced = VARIABLE.sub(lambda m: variables.get(m[1].lower(), m[0]), text)
        if replaced == text:
            return text
        text = replaced
    raise AssertionError(f"Recursive variables: {text}")


def load_sections() -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    active: set[Path] = set()

    def load(path: Path) -> None:
        path = path.resolve()
        assert path.is_relative_to(ROOT.resolve()), f"External include: {path}"
        assert path not in active, f"Include cycle: {path}"
        active.add(path)
        current = ""
        physical_sections: set[str] = set()
        for line in path.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            if line.startswith("[") and line.endswith("]"):
                current = line[1:-1].lower()
                assert current not in physical_sections, f"Duplicate section in {path}: {current}"
                physical_sections.add(current)
                sections.setdefault(current, {})
                continue
            key, value = line.split("=", 1)
            key, value = key.strip().lower(), value.strip()
            if key.startswith("@include"):
                variables = dict(sections.get("variables", {}))
                variables["@"] = str(ROOT / "@Resources") + "/"
                target = expand(value, variables).replace("\\", "/").strip('"')
                included = Path(target)
                if not included.is_absolute():
                    included = path.parent / included
                load(included)
            else:
                sections[current][key] = value
        active.remove(path)

    load(ENTRYPOINT)
    return sections


def number(value: str, variables: dict[str, str]) -> float:
    expression = expand(value, variables)
    operations = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}

    def evaluate(node: ast.AST) -> float:
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -evaluate(node.operand)
        if isinstance(node, ast.BinOp) and type(node.op) in operations:
            return operations[type(node.op)](evaluate(node.left), evaluate(node.right))
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id.lower() == "round" and len(node.args) == 1:
            value = evaluate(node.args[0])
            assert value >= 0, "This fixture evaluates only positive geometry rounding."
            return float(math.floor(value + 0.5))
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id.lower() == "max" and len(node.args) == 2:
            return max(evaluate(node.args[0]), evaluate(node.args[1]))
        raise AssertionError(f"Unsupported geometry expression: {expression}")

    return evaluate(ast.parse(expression, mode="eval").body)


def options(name: str, sections: dict[str, dict[str, str]]) -> dict[str, str]:
    own = sections[name]
    result: dict[str, str] = {}
    for style in own.get("meterstyle", "").split("|"):
        if style:
            result.update(options(style.lower(), sections))
    result.update(own)
    return result


def run() -> None:
    sections = load_sections()
    arrow_names = set()
    for base, key in NUMERIC_CONTROLS.items():
        value = options((base + "Input").lower(), sections)
        assert value["leftmouseupaction"] == f'[!CommandMeasure MeasureSettings "BeginEdit(\'{key}\')"]', (key, "Value must retain the shared numeric editor")
        frame = options((base + "Frame").lower(), sections)
        assert frame.get("meter", "").lower() == "shape", (base, "Editable value requires its outlined frame")
        assert frame.get("leftmouseupaction") == value["leftmouseupaction"] and frame.get("tooltiptext"), (base, "Frame must open the same numeric editor")
        for suffix, direction in (("Decrease", -1), ("Increase", 1)):
            name = (base + suffix).lower()
            arrow_names.add(name)
            arrow = options(name, sections)
            expected = f'[!CommandMeasure MeasureSettings "Adjust(\'{key}\',{direction})"]'
            assert arrow.get("leftmouseupaction", "").replace(" ", "") == expected.replace(" ", ""), (name, "Arrow must target only its numeric setting and direction")
            assert arrow.get("tooltiptext"), (name, "Arrow requires a descriptive tooltip")
            assert arrow.get("hidden", "0") != "1", (name, "Numeric arrow unexpectedly hidden")
            assert arrow.get("fontcolor") == "#AccentColor#", (name, "Numeric arrows must use Accent 1")
    theme_arrows = {"meterthemedecrease", "meterthemeincrease"}
    for name in theme_arrows:
        arrow = options(name, sections)
        assert not any(key.endswith("action") and value for key, value in arrow.items()), (name, "Single-theme arrows must not dispatch actions")
        assert arrow.get("mouseactioncursor") == "0" and arrow.get("fontcolor") == "175,175,175", (name, "Single-theme arrows must appear disabled")
        assert arrow.get("tooltiptext") and arrow.get("hidden", "0") != "1", (name, "Disabled theme arrows must remain visible and explained")
    for name in ("meterthemeselect", "meterthemearrow"):
        assert options(name, sections).get("leftmouseupaction") == '[!CommandMeasure MeasureSettings "ToggleThemeMenu()"]', (name, "Theme center must retain its dropdown")
    arrow_names.update(theme_arrows)
    for name, direction in (("meterrefreshdecrease", -1), ("meterrefreshincrease", 1), ("meterrefreshvalue", 1), ("meterrefreshframe", 1)):
        assert options(name, sections).get("leftmouseupaction") == f'[!CommandMeasure MeasureSettings "CycleProfile({direction})"]', (name, "Refresh must use the validated cycling action")
    for heading, rule, title in (("meterappearancesection", "meterappearancerule", "Appearance"), ("meterperformancesection", "meterperformancerule", "Performance")):
        assert sections[heading]["text"] == title, f"Missing settings section: {title}"
        assert sections[rule]["meterstyle"] == "StyleRule", f"{title} must use section divider styling."
    assert {name for name, raw in sections.items() if raw.get("meterstyle") == "StyleTableHeaderRule"} == {"metersurfaceheaderrule", "metertextheaderrule"}, "Table-header styling belongs only to the panel and text tables."
    # Native Bar meters truncate fractional heights. Shared geometry must provide
    # a visible integer pixel count, including values exactly at half a pixel.
    for scale, thickness, expected in ((0.75, 1, 1), (0.75, 2, 2), (1, 1.5, 2), (1, 2.5, 3), (1.25, 2, 3), (1.5, 1, 2)):
        scaled = dict(sections["variables"], scale=str(scale), databarthickness=str(thickness))
        assert number("#DataBarThicknessPx#", scaled) == expected, (scale, thickness, "data bar pixel rounding boundary")
    checked = 0
    minimum_button_margin = math.inf
    for scale, width, gutter in itertools.product((0.75, 1, 1.25, 1.5, 2), (180, 200, 220, 240, 280, 320), (0, 8, 12, 16)):
        label = f"scale={scale}, column={width}, gutter={gutter}"
        variables = dict(sections["variables"])
        variables.update(scale=str(scale), columnwidth=str(width), gutter=str(gutter))

        def var(name: str) -> float:
            return number(f"#{name}#", variables)

        assert var("Columns") == 2, "Settings must use double-column geometry after include overrides."
        assert var("PanelHeight") == 758, "Settings' local height was lost to default precedence."
        for thickness in (1, 1.25, 1.5, 2, 2.5, 6, 8.75, 12):
            scaled = dict(variables, databarthickness=str(thickness))
            expected = max(1, math.floor(thickness * scale + 0.5))
            assert number("#DataBarThicknessPx#", scaled) == expected, (label, thickness, "data bar scale must round to at least one physical pixel")
        window_w, window_h = var("WindowWidth"), var("WindowHeight")
        assert var("Gap") % 2 == 0, label
        assert window_w == 2 * var("Pitch"), label
        assert var("PanelWidth") == 2 * var("UnitWidth") + var("Gap"), label
        single = dict(variables, columns="1")
        assert 2 * number("#WindowWidth#", single) == window_w, label

        text_boxes = []
        control_boxes = {}
        for name, raw in sections.items():
            if raw.get("meter", "").lower() not in ("string", "image") and name not in arrow_names:
                continue
            resolved = options(name, sections)
            alignment = resolved.get("stringalign", "left").lower()
            assert alignment in ("left", "lefttop", "leftcenter", "center", "centertop", "centercenter"), "Extend fixture for other anchors."
            x, y, w, h = (number(resolved.get(key, "0"), variables) for key in ("x", "y", "w", "h"))
            pad = [number(item, variables) for item in resolved.get("padding", "0,0,0,0").split(",")]
            assert len(pad) == 4
            w += pad[0] + pad[2]
            h += pad[1] + pad[3]
            if alignment.startswith("center"):
                x -= w / 2
            if alignment in ("leftcenter", "centercenter"):
                y -= h / 2
            assert x >= 0 and y >= 0 and w > 0 and h > 0, (name, label)
            assert x + w <= window_w + 1e-7 and y + h <= window_h + 1e-7, (name, label, "outside window")
            if raw.get("meter", "").lower() == "string" or name in arrow_names:
                if raw.get("meter", "").lower() == "string":
                    assert resolved.get("clipstring") == "1", (name, "text must respect fixed bounds")
                assert x >= var("ContentX"), (name, label)
                assert x + w <= var("ContentX") + var("ContentWidth") + 1e-7, (name, label, "outside content")
                # The popup deliberately covers the Scale controls; its dismiss
                # layer blocks those controls while it is visible.
                if resolved.get("hidden") != "1":
                    text_boxes.append((name, x, y, w, h))
                    control_boxes[name] = (x, y, w, h)
                elif name == "meterthemedefault":
                    popup_x = var("ContentX") + 76 * scale
                    popup_y = number(options("meterthemepopup", sections)["y"], variables)
                    assert x >= popup_x and y >= popup_y, (name, label, "outside popup")
                    assert x + w <= var("ContentX") + var("ContentWidth") + 1e-7, (name, label, "popup width")
                    assert y + h <= popup_y + 24 * scale + 1e-7, (name, label, "popup height")
                    assert resolved.get("group") == "ThemeMenu", "Option must dismiss with the menu"
                if "leftmouseupaction" in resolved:
                    assert resolved.get("tooltiptext"), (name, "button needs a tooltip")
                    minimum_button_margin = min(minimum_button_margin, var("ContentX") + var("ContentWidth") - x - w)
        for base in (*NUMERIC_CONTROLS, "MeterRefresh"):
            left, value, right = (control_boxes[(base + suffix).lower()] for suffix in ("Decrease", "Value" if base == "MeterRefresh" else "Input", "Increase"))
            resolved_frame = options((base + "Frame").lower(), sections)
            frame = tuple(number(resolved_frame.get(key, "0"), variables) for key in ("x", "y", "w", "h"))
            assert frame[0] >= var("ContentX") and frame[1] >= 0 and min(frame[2:]) > 0, (base, label, "Invalid frame bounds")
            assert frame[0] + frame[2] <= var("ContentX") + var("ContentWidth") + 1e-7 and frame[1] + frame[3] <= window_h + 1e-7, (base, label, "Frame outside content/window")
            assert value[0] >= frame[0] - 1e-7 and value[1] >= frame[1] - 1e-7, (base, label, "Editable value starts outside frame")
            assert value[0] + value[2] <= frame[0] + frame[2] + 1e-7 and value[1] + value[3] <= frame[1] + frame[3] + 1e-7, (base, label, "Editable value extends outside frame")
            shape_parts = resolved_frame["shape"].split("|")
            assert shape_parts[0].strip().lower().startswith("rectangle "), (base, "Extend fixture for other frame shapes")
            shape = [number(part, variables) for part in shape_parts[0].strip()[len("Rectangle "):].split(",")]
            assert len(shape) == 5, (base, "Extend fixture for other frame shapes")
            stroke = [part.strip()[len("StrokeWidth "):] for part in shape_parts[1:] if part.strip().lower().startswith("strokewidth ")]
            assert len(stroke) == 1, (base, "Frame must declare its stroke width")
            half_stroke = number(stroke[0], variables) / 2
            assert abs(shape[0] - half_stroke) < 1e-7 and abs(shape[1] - half_stroke) < 1e-7, (base, label, "Frame stroke escapes its top/left bounds")
            assert abs(shape[0] + shape[2] + half_stroke - frame[2]) < 1e-7 and abs(shape[1] + shape[3] + half_stroke - frame[3]) < 1e-7, (base, label, "Frame stroke differs from its declared bounds")
            assert left[0] + left[2] <= frame[0] + 1e-7, (base, label, "Decrease arrow overlaps editable frame")
            assert frame[0] + frame[2] <= right[0] + 1e-7, (base, label, "Increase arrow overlaps editable frame")
            centers = [rectangle[1] + rectangle[3] / 2 for rectangle in (left, value, right, frame)]
            assert max(centers) - min(centers) < 1e-7, (base, label, "Arrow/value centers differ")
            # This is a usable declared hit target, not a claim about rendered
            # glyph width or the host's Windows DPI scaling.
            assert left[2] >= 12 * scale and right[2] >= 12 * scale, (base, label, "Arrow hit target is too narrow")
            assert value[2] >= 40 * scale, (base, label, "Editable value lost its useful width")
        theme_left, theme_value, theme_right = (control_boxes[name] for name in ("meterthemedecrease", "meterthemeselect", "meterthemeincrease"))
        assert theme_left[0] + theme_left[2] <= theme_value[0] + 1e-7 and theme_value[0] + theme_value[2] <= theme_right[0] + 1e-7, (label, "Theme arrows overlap the padded dropdown")
        theme_centers = [rectangle[1] + rectangle[3] / 2 for rectangle in (theme_left, theme_value, theme_right)]
        assert max(theme_centers) - min(theme_centers) < 1e-7, (label, "Theme arrow/dropdown centers differ")
        for first, second in itertools.combinations(text_boxes, 2):
            overlap_w = min(first[1] + first[3], second[1] + second[3]) - max(first[1], second[1])
            overlap_h = min(first[2] + first[4], second[2] + second[4]) - max(first[2], second[2])
            assert overlap_w <= 1e-7 or overlap_h <= 1e-7, (first[0], second[0], label, "overlapping declared text boxes")
        rectangles = {name: (y, y + height) for name, _, y, _, height in text_boxes}
        appearance_rule_y = number(options("meterappearancerule", sections)["y"], variables)
        performance_rule_y = number(options("meterperformancerule", sections)["y"], variables)
        # Use the maximum supported divider width to catch collisions even when
        # the user's current divider is thin or hidden.
        divider_half_width = 2 * scale
        assert rectangles["metergeometry"][1] < rectangles["meterappearancesection"][0], (label, "Appearance overlaps the layout summary")
        assert rectangles["meterappearancesection"][1] < appearance_rule_y - divider_half_width, (label, "Appearance heading touches its divider")
        assert rectangles["meterperformancesection"][1] < performance_rule_y - divider_half_width, (label, "Performance heading touches its divider")
        appearance_fields = (
            "meterthemeselect", "meterscaleinput", "meterwidthinput", "metergapinput", "meterroundinginput",
            "meteraccentvalue", "meteraccent2value", "metersurfacesection", "meterbackgroundcolorvalue",
            "meterbackgroundtransparencyinput", "meterbordercolorvalue", "meterbordersizeinput",
            "meterdividercolorvalue", "meterdividersizeinput", "metertableheaderbordercolorvalue",
            "metertableheaderbordersizeinput", "meterdatabarsizeinput", "metertextsection",
            "metertitlesizeinput", "metertitlecolorvalue", "meterheadersizeinput", "meterheadercolorvalue",
            "meterbodysizeinput", "meterbodycolorvalue",
        ) + tuple(sorted(arrow_names))
        for name in appearance_fields:
            top, bottom = rectangles[name]
            assert top > appearance_rule_y + divider_half_width and bottom < rectangles["meterperformancesection"][0], (name, label, "Appearance control escaped its section")
        footer_rule_y = number(options("meterrule", sections)["y"], variables)
        for name in ("meterrefreshlabel", "meterrefreshdecrease", "meterrefreshvalue", "meterrefreshincrease", "metercadence"):
            top, bottom = rectangles[name]
            assert top > performance_rule_y + divider_half_width and bottom < footer_rule_y - divider_half_width, (name, label, "Performance control escaped its section")
        checked += 1
    print(f"Settings geometry passed: {checked} preset combinations; minimum padded-button right margin {max(0, minimum_button_margin):g} computed pixels.")
    print("Scope: declared INI geometry, include layering, text rectangles, and button padding. Font rendering, Windows DPI, and Lua execution remain untested.")


if __name__ == "__main__":
    run()
