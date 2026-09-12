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
    checked = 0
    minimum_button_margin = math.inf
    for scale, width, gutter in itertools.product((0.75, 1, 1.25, 1.5, 2), (180, 200, 240, 280, 320), (0, 8, 12, 16)):
        label = f"scale={scale}, column={width}, gutter={gutter}"
        variables = dict(sections["variables"])
        variables.update(scale=str(scale), columnwidth=str(width), gutter=str(gutter))

        def var(name: str) -> float:
            return number(f"#{name}#", variables)

        assert var("Columns") == 2, "Settings must use double-column geometry after include overrides."
        assert var("PanelHeight") == 644, "Settings' local height was lost to default precedence."
        window_w, window_h = var("WindowWidth"), var("WindowHeight")
        assert var("Gap") % 2 == 0, label
        assert window_w == 2 * var("Pitch"), label
        assert var("PanelWidth") == 2 * var("UnitWidth") + var("Gap"), label
        single = dict(variables, columns="1")
        assert 2 * number("#WindowWidth#", single) == window_w, label

        text_boxes = []
        for name, raw in sections.items():
            if raw.get("meter", "").lower() not in ("string", "image"):
                continue
            resolved = options(name, sections)
            assert resolved.get("stringalign", "left").lower() in ("left", "lefttop"), "Extend fixture for non-left anchors."
            x, y, w, h = (number(resolved.get(key, "0"), variables) for key in ("x", "y", "w", "h"))
            pad = [number(item, variables) for item in resolved.get("padding", "0,0,0,0").split(",")]
            assert len(pad) == 4
            w += pad[0] + pad[2]
            h += pad[1] + pad[3]
            assert x >= 0 and y >= 0 and w > 0 and h > 0, (name, label)
            assert x + w <= window_w + 1e-7 and y + h <= window_h + 1e-7, (name, label, "outside window")
            if raw.get("meter", "").lower() == "string":
                assert resolved.get("clipstring") == "1", (name, "text must respect fixed bounds")
                assert x >= var("ContentX"), (name, label)
                assert x + w <= var("ContentX") + var("ContentWidth") + 1e-7, (name, label, "outside content")
                # The popup deliberately covers the Scale controls; its dismiss
                # layer blocks those controls while it is visible.
                if resolved.get("hidden") != "1":
                    text_boxes.append((name, x, y, w, h))
                elif name == "meterthemedefault":
                    popup_x = var("ContentX") + 76 * scale
                    popup_y = var("Inset") + 78 * scale
                    assert x >= popup_x and y >= popup_y, (name, label, "outside popup")
                    assert x + w <= var("ContentX") + var("ContentWidth") + 1e-7, (name, label, "popup width")
                    assert y + h <= popup_y + 24 * scale + 1e-7, (name, label, "popup height")
                    assert resolved.get("group") == "ThemeMenu", "Option must dismiss with the menu"
                if "leftmouseupaction" in resolved:
                    assert resolved.get("tooltiptext"), (name, "button needs a tooltip")
                    minimum_button_margin = min(minimum_button_margin, var("ContentX") + var("ContentWidth") - x - w)
        for first, second in itertools.combinations(text_boxes, 2):
            overlap_w = min(first[1] + first[3], second[1] + second[3]) - max(first[1], second[1])
            overlap_h = min(first[2] + first[4], second[2] + second[4]) - max(first[2], second[2])
            assert overlap_w <= 1e-7 or overlap_h <= 1e-7, (first[0], second[0], label, "overlapping declared text boxes")
        checked += 1
    print(f"Settings geometry passed: {checked} preset combinations; minimum padded-button right margin {max(0, minimum_button_margin):g} computed pixels.")
    print("Scope: declared INI geometry, include layering, text rectangles, and button padding. Font rendering, Windows DPI, and Lua execution remain untested.")


if __name__ == "__main__":
    run()
