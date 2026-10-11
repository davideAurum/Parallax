"""Offline GPU include/geometry checks; standard-library Python only.

Evaluates the real include tree and layout formulas, then checks the exact
meter set, shape ink bounds, pairwise meter-box overlap, top-to-bottom order
and panel containment across supported widths, scales, title sizes, bar and
rule thicknesses, gutters, saved heights and GraphHeight overrides.
--all-scales adds every 0.01 Scale step that Global Settings allows.

Geometry is evaluated as exact formula values. This does not emulate
Rainmeter's pixel conversion, execute Lua or validate font rendering (box
heights are fixed; glyph fit at large fonts is a native-capture question).
The packaging allowlist excludes this development-only .py file.
"""
import ast
import math
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EPS = 1e-6
sections = {}
loaded = set()


def expand(value, variables):
    for _ in range(30):
        updated = re.sub(r"#([^#]+)#", lambda m: variables.get(m[1], m[0]), value)
        if updated == value:
            return value
        value = updated
    raise AssertionError("Recursive variable expansion")


def load(path):
    path = path.resolve()
    assert path.is_relative_to(ROOT), path
    assert path not in loaded, f"Repeated include: {path}"
    loaded.add(path)
    local_sections, current = set(), None
    local_keys = set()
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            assert current not in local_sections, f"Duplicate section: {current}"
            local_sections.add(current)
            local_keys = set()
            sections.setdefault(current, {})
            continue
        assert current and "=" in line, line
        key, value = (part.strip() for part in line.split("=", 1))
        assert key not in local_keys, f"Duplicate option: {key}"
        local_keys.add(key)
        if key.startswith("@Include"):
            variables = dict(sections.get("Variables", {}), **{"@": str(ROOT / "@Resources") + "/"})
            load(Path(expand(value, variables).replace("\\", "/")))
        else:
            sections[current][key] = value


TOKEN = re.compile(r"#([^#]+)#")
FUNCTIONS = {"Round": lambda x: math.floor(x + 0.5), "Max": max, "Min": min, "Ceil": math.ceil}
# Compare covers Rainmeter's (a<b) 0/1 terms, e.g. the graph startup cover.
ALLOWED_NODES = (ast.Expression, ast.Constant, ast.BinOp, ast.UnaryOp, ast.Add,
                 ast.Sub, ast.Mult, ast.Div, ast.UAdd, ast.USub, ast.Call,
                 ast.Name, ast.Load, ast.Compare, ast.Lt, ast.Gt, ast.LtE, ast.GtE)
compiled = {}


def number(value, variables, resolved=None):
    """Evaluate a formula. Each template compiles once; #Variables# resolve
    recursively to numbers, cached in resolved for the caller's variable set."""
    if value not in compiled:
        names = list(dict.fromkeys(TOKEN.findall(value)))
        text = TOKEN.sub(lambda m: f"v{names.index(m[1])}", value)
        tree = ast.parse(text, mode="eval")
        for item in ast.walk(tree):
            assert isinstance(item, ALLOWED_NODES), f"Unsupported formula: {value}"
            if isinstance(item, ast.Name):
                assert item.id in FUNCTIONS or re.fullmatch(r"v\d+", item.id), item.id
            if isinstance(item, ast.Constant):
                assert isinstance(item.value, (int, float)), item.value
        compiled[value] = names, compile(tree, "<geometry>", "eval")
    names, code = compiled[value]
    resolved = {} if resolved is None else resolved
    scope = dict(FUNCTIONS)
    for index, name in enumerate(names):
        if name not in resolved:
            raw = variables[name]
            # Numeric substitution equals Rainmeter's text substitution only
            # for plain numbers and fully parenthesized formulas.
            assert re.fullmatch(r"-?\d+(\.\d+)?|\(.*\)", raw), (name, raw)
            resolved[name] = number(raw, variables, resolved)
        scope[f"v{index}"] = resolved[name]
    return float(eval(code, {"__builtins__": {}}, scope))


def split_args(text):
    """Split on top-level commas so Min(a,b)-style formulas stay whole."""
    parts, depth, current = [], 0, ""
    for char in text:
        depth += (char == "(") - (char == ")")
        if char == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += char
    assert depth == 0, text
    parts.append(current.strip())
    return parts


def effective(name):
    options = sections[name]
    result = {}
    for style in options.get("MeterStyle", "").split("|"):
        if style:
            assert style in sections, style
            assert "Meter" not in sections[style], style
            result.update(effective(style))
    result.update(options)
    return result


def string_origin(x, y, w, h, alignment):
    """Convert Rainmeter StringAlign anchors to a top-left bounding box."""
    alignment = alignment.lower()
    if alignment.startswith("right"):
        x -= w
    elif alignment.startswith("center"):
        x -= w / 2
    if alignment in ("leftcenter", "rightcenter", "centercenter"):
        y -= h / 2
    elif alignment.endswith("bottom"):
        y -= h
    return x, y


def arc_points(start, end, radius, sweep, size):
    """End point plus the axis extremes a circular ArcTo passes through.

    Rainmeter SweepDirection 0 is clockwise on screen (y down) and 1 is
    counter-clockwise -- the reverse of SVG's sweep flag. Size 1 is the
    large arc. The centre is the one consistent with both flags.
    """
    (x0, y0), (x1, y1) = start, end
    dx, dy = x1 - x0, y1 - y0
    chord = math.hypot(dx, dy)
    assert 0 < chord <= 2 * radius + 1e-6, (start, end, radius)
    offset = math.sqrt(max(0.0, radius ** 2 - (chord / 2) ** 2))
    for side in (1, -1):
        cx = (x0 + x1) / 2 - side * dy / chord * offset
        cy = (y0 + y1) / 2 + side * dx / chord * offset
        a0, a1 = math.atan2(y0 - cy, x0 - cx), math.atan2(y1 - cy, x1 - cx)
        span = ((a1 - a0) if sweep == 0 else (a0 - a1)) % (2 * math.pi)
        if (span > math.pi) == bool(size) or math.isclose(span, math.pi):
            break
    else:
        raise AssertionError(("No arc centre", start, end, radius, sweep, size))
    points = [end]
    for k in range(4):
        angle = k * math.pi / 2
        travelled = ((angle - a0) if sweep == 0 else (a0 - angle)) % (2 * math.pi)
        if travelled < span:
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def primitive_bounds(options, key, n, token=None):
    """Ink bounds of one ShapeN primitive in meter coordinates, stroke included.

    Lines honour their caps (Rainmeter default Flat); other primitives pad
    half the stroke on every side. With token, every coordinate and stroke
    width must scale by that variable.
    """
    primitive, *modifiers = shape = options[key].split("|")
    kind, parameters = primitive.strip().split(" ", 1)
    expanded = []
    for modifier in (part.strip() for part in modifiers):
        if modifier.startswith("Extend "):
            for name in re.split(r"[,\s]+", modifier[len("Extend "):].strip()):
                expanded.extend(part.strip() for part in options[name].split("|"))
        else:
            expanded.append(modifier)

    def coordinates(text, count=None):
        values = split_args(text)
        scaled = values if count is None else values[:count]
        assert token is None or all(token in value for value in scaled), (key, text)
        return [n(value) for value in values]

    stroke, caps = 1.0, {"StrokeStartCap": "Flat", "StrokeEndCap": "Flat"}
    for modifier in expanded:
        option, _, value = modifier.partition(" ")
        if option == "StrokeWidth":
            stroke = n(value)
            assert stroke == 0 or token is None or token in value, (key, modifier)
        elif option in caps:
            caps[option] = value.strip()
    assert stroke >= 0, (key, shape)
    half = stroke / 2
    if kind == "Line":
        x1, y1, x2, y2 = coordinates(parameters)
        length = math.hypot(x2 - x1, y2 - y1)
        ux, uy = ((x2 - x1) / length, (y2 - y1) / length) if length else (1.0, 0.0)
        points = []
        for (px, py), cap, sign in (((x1, y1), caps["StrokeStartCap"], -1), ((x2, y2), caps["StrokeEndCap"], 1)):
            assert cap in ("Flat", "Round", "Square"), (key, cap)
            if cap == "Round":
                points += [(px - half, py - half), (px + half, py + half)]
            else:
                ex, ey = (sign * half * ux, sign * half * uy) if cap == "Square" else (0, 0)
                points += [(px - half * uy + ex, py + half * ux + ey), (px + half * uy + ex, py - half * ux + ey)]
        x, y = min(p[0] for p in points), min(p[1] for p in points)
        return x, y, max(p[0] for p in points) - x, max(p[1] for p in points) - y
    if kind == "Rectangle":
        x, y, w, h = coordinates(parameters)[:4]
    elif kind == "Ellipse":
        values = coordinates(parameters)
        cx, cy, rx = values[:3]
        ry = values[3] if len(values) > 3 else rx
        x, y, w, h = cx - rx, cy - ry, 2 * rx, 2 * ry
    else:
        assert kind == "Path", (key, kind)
        start, *segments = options[parameters.strip()].split("|")
        points = [tuple(coordinates(start))]
        assert len(points[0]) == 2, (key, start)
        for segment in segments:
            command, _, text = segment.strip().partition(" ")
            if command == "LineTo":
                point = tuple(coordinates(text))
                assert len(point) == 2, (key, segment)
                points.append(point)
            elif command == "ArcTo":
                fields = coordinates(text, 4)
                assert len(fields) == 7, (key, segment)
                px, py, rx, ry, angle, sweep, size = fields
                assert angle == 0 and math.isclose(rx, ry) and rx > 0, (key, segment)
                assert sweep in (0, 1) and size in (0, 1), (key, segment)
                points += arc_points(points[-1], (px, py), rx, sweep, size)
            else:
                assert command == "ClosePath", (key, command)
        x, y = min(p[0] for p in points), min(p[1] for p in points)
        w, h = max(p[0] for p in points) - x, max(p[1] for p in points) - y
    return x - half, y - half, w + stroke, h + stroke


def bar_bounds(shape, n):
    """Bounds of scalar bars' horizontal lines, including their flat-cap stroke."""
    primitive, *modifiers = [part.strip() for part in shape.split("|")]
    assert primitive.startswith("Line "), primitive
    coordinates = [n(value) for value in split_args(primitive[5:])]
    assert len(coordinates) == 4
    x1, y1, x2, y2 = coordinates
    assert math.isclose(y1, y2)
    assert "StrokeStartCap Flat" in modifiers and "StrokeEndCap Flat" in modifiers
    stroke_options = [item[len("StrokeWidth "):] for item in modifiers if item.startswith("StrokeWidth ")]
    assert len(stroke_options) == 1
    stroke = n(stroke_options[0])
    assert stroke >= 0
    return min(x1, x2), y1 - stroke / 2, abs(x2 - x1), stroke


def validate_bar(name, bar, n, scale, thickness):
    """The full track and initial empty fill fit the shared-thickness canvas."""
    assert math.isclose(n(bar["X"]), n("#ContentX#")), name
    assert math.isclose(n(bar["W"]), n("#ContentWidth#")), name
    assert math.isclose(n(bar["H"]), n("#DataBarThicknessPx#")), name
    assert math.isclose(n(bar["H"]), max(1, math.floor(thickness * scale + .5))), name
    for key in ("Shape", "Shape2"):
        x, y, w, h = bar_bounds(bar[key], n)
        assert min(x, y, w, h) >= 0, (name, key)
        assert x + w <= n(bar["W"]) and y + h <= n(bar["H"]), (name, key)
        if key == "Shape":
            assert math.isclose(x, 0) and math.isclose(w, n(bar["W"])), name
            assert math.isclose(y, 0) and math.isclose(h, n(bar["H"])), name
        else:
            assert math.isclose(w, 0) and math.isclose(h, 0), name


def overlaps(a, b):
    return (a[0] < b[0] + b[2] - EPS and b[0] < a[0] + a[2] - EPS and
            a[1] < b[1] + b[3] - EPS and b[1] < a[1] + a[3] - EPS)


ACTIVITY = ("", "Controller", "Video", "Bus")
SENSORS = ("Temperature", "Power", "Clock")
PROCESS_COLUMNS = ("Name", "Memory", "Value")
GRAPH = ("MeterGPUUtilizationGraph", "MeterGPUGraphUncollected", "MeterGPUGraphFrame")
EXPECTED_METERS = {
    # Overview: window bounds, panel, title row, adapter inset.
    "MeterBounds", "MeterPanel", "MeterIcon", "MeterTitle", "MeterActivityValue", "MeterOptions",
    "MeterAdapterPanel", "MeterAdapterName", "MeterVRAMValue",
    # DriverMeters.inc: headerless memory rows, then activity rows each with a bar.
    "MeterGPUVRAMUsage", "MeterGPUVRAMBar", "MeterGPUSharedMemory",
    *{f"MeterGPU{domain}Load{part}" for domain in ACTIVITY for part in ("Label", "Value", "Bar")},
    # Driver sensor readings, the divider and the process-section label.
    *{f"Meter{field}{part}" for field in SENSORS for part in ("Label", "Value")},
    "MeterRule", "MeterActivityLabel",
    # ProcessMeters.inc: PID-grouped Process / VRAM / GPU % table.
    "MeterGPUProcessHeading", "MeterGPUProcessMemoryHeader", "MeterGPUProcessUtilHeader", "MeterGPUProcessHeaderRule",
    *{f"MeterGPUProcess{part}{i}" for i in range(1, 6) for part in PROCESS_COLUMNS},
    # GraphMeters.inc: utilization history with startup cover and frame overlays.
    "MeterGPUGraphHeading", "MeterGPUGraphRule", *GRAPH,
}
# Intentional overlaps: inset text inside its backing, the activity value and
# hover gear swap visibility, and the graph's cover/frame overlay its Line.
ALLOWED_OVERLAPS = {
    frozenset(("MeterAdapterPanel", "MeterAdapterName")), frozenset(("MeterAdapterPanel", "MeterVRAMValue")),
    frozenset(("MeterActivityValue", "MeterOptions")),
    *{frozenset((a, b)) for a in GRAPH for b in GRAPH if a != b},
}
# Top-to-bottom bands; every band starts at or below the previous band's end.
BANDS = [
    ("MeterIcon", "MeterTitle", "MeterActivityValue", "MeterOptions"),
    ("MeterAdapterPanel",),
    ("MeterGPUVRAMUsage",), ("MeterGPUVRAMBar",), ("MeterGPUSharedMemory",),
    *[band for domain in ACTIVITY for band in (
        (f"MeterGPU{domain}LoadLabel", f"MeterGPU{domain}LoadValue"), (f"MeterGPU{domain}LoadBar",))],
    *[(f"Meter{field}Label", f"Meter{field}Value") for field in SENSORS],
    ("MeterRule",), ("MeterActivityLabel",),
    ("MeterGPUProcessHeading", "MeterGPUProcessMemoryHeader", "MeterGPUProcessUtilHeader"),
    ("MeterGPUProcessHeaderRule",),
    *[tuple(f"MeterGPUProcess{part}{i}" for part in PROCESS_COLUMNS) for i in range(1, 6)],
    ("MeterGPUGraphHeading",), ("MeterGPUGraphRule",), GRAPH,
]
CONTAINERS = {"MeterBounds", "MeterPanel"}
INSET_TEXT = {"MeterAdapterName", "MeterVRAMValue"}
assert {name for band in BANDS for name in band} | CONTAINERS | INSET_TEXT == EXPECTED_METERS
# Icons whose every coordinate and stroke must scale by the named variable.
ICON_TOKENS = {"MeterIcon": "#TitleIconScale#", "MeterOptions": "#Scale#",
               "MeterGPUProcessMemoryHeader": "#Scale#", "MeterGPUProcessUtilHeader": "#Scale#"}


def check_static():
    load(ROOT / "GPU" / "GPU.ini")
    for include in ("Measures.inc", "ProcessMeasures.inc", "ProcessMeters.inc", "TemperatureMeasures.inc",
                    "DriverMeters.inc", "GraphMeters.inc"):
        assert (ROOT / "@Resources" / "Modules" / "GPU" / include).resolve() in loaded, include
    assert set(sections["Rainmeter"]["Group"].split("|")) == {"Parallax", "ParallaxGPU"}
    assert sections["Rainmeter"]["DynamicWindowSize"] == "0"
    # Geometry validation accepts either preserved user choice; packaging owns the
    # shipping baseline. Do not require rewriting a user's enabled sensor setting.
    assert sections["Variables"]["GPUEnableSensors"] in ("0", "1")
    for field in SENSORS:
        assert sections["Variables"][f"GPU{field}Index"] == "-1"
        assert sections["Variables"][f"GPU{field}Sensor"] == ""
        assert sections["Variables"][f"GPU{field}Label"] == ""
    for name, timeout in (("MeasureGPUTemperatureBootstrap", "12000"), ("MeasureGPUTemperatureDriver", "-1")):
        options = sections[name]
        assert options["Measure"] == "Plugin" and options["Plugin"] == "RunCommand", name
        assert options["Timeout"] == timeout and options["State"] == "Hide", name
        assert "FinishAction" not in options and options["Parameter"] == "", name
    assert not any(name.startswith("MeasureGPUTemperature") and opts.get("Measure") == "Registry" for name, opts in sections.items())
    assert sections["MeasureGPUTemperatureController"]["Measure"] == "Script"
    assert sections["MeasureGPUTemperatureController"]["ScriptFile"] == "#@#Modules\\GPU\\Temperature.lua"
    counter = sections["MeasureGPUActivity"]
    assert {key: counter[key] for key in ("Alias", "Index", "PIDToName", "Rollup", "Percent", "RawValue")} == {
        "Alias": "GPU", "Index": "1", "PIDToName": "0", "Rollup": "0", "Percent": "0", "RawValue": "0"}

    meters = {name: effective(name) for name, options in sections.items() if "Meter" in options}
    assert all("Meter" in options for name, options in sections.items() if name.startswith("Meter"))
    assert set(meters) == EXPECTED_METERS, (
        f"missing {sorted(EXPECTED_METERS - set(meters))}, unexpected {sorted(set(meters) - EXPECTED_METERS)}")
    # Temperature.lua writes every driver readout, including all five bars.
    for name in ("MeterGPUVRAMUsage", "MeterGPUVRAMBar", "MeterGPUSharedMemory",
                 *(f"MeterGPU{domain}Load{part}" for domain in ACTIVITY for part in ("Value", "Bar")),
                 *(f"Meter{field}Value" for field in SENSORS)):
        assert "GPUDriverReadout" in meters[name]["Group"].split("|"), name
    # ProcessGraph.lua shows/hides whole rows by GPUProcessRow1-5.
    for i in range(1, 6):
        for part in PROCESS_COLUMNS:
            assert meters[f"MeterGPUProcess{part}{i}"]["Group"] == f"GPUProcessGraph|GPUProcessRow{i}", (part, i)
    graph = meters["MeterGPUUtilizationGraph"]
    assert graph["Meter"] == "Line" and graph["LineCount"] == "1" and graph["AutoScale"] == "0"
    assert graph["MeasureName"] in sections and "MeasureGPUGraphSamples" in sections
    assert "[MeasureGPUGraphSamples]" in meters["MeterGPUGraphUncollected"]["Shape"]
    assert meters["MeterGPUGraphUncollected"]["DynamicVariables"] == "1"
    for name, options in meters.items():
        if options["Meter"] == "String":
            assert options["ClipString"] == "1", name
    return meters


def check_case(meters, overrides):
    """All geometry checks for one variable set; returns a summary dict."""
    variables = dict(sections["Variables"], **{key: str(value) for key, value in overrides.items()})
    resolved = {}
    n = lambda value: number(value, variables, resolved)
    scale = n("#Scale#")
    width, height = n("#WindowWidth#"), n("#WindowHeight#")
    inset, padding = n("#Inset#"), n("#Padding#")
    content_x, content_w = n("#ContentX#"), n("#ContentWidth#")
    panel_w, panel_h = n("#PanelWidth#"), n("#PanelHeightPx#")
    graph_h = n("#GraphHeight#*#Scale#")
    assert width == n("#Columns#") * n("#Pitch#")
    assert panel_w + 2 * inset == width and panel_h + 2 * inset == height
    # The 650 minimum and larger saved heights are both honoured.
    assert panel_h >= math.floor(max(650, n("#PanelHeight#")) * scale + .5)

    boxes = {}
    for name, options in meters.items():
        x, y = n(options.get("X", "0")), n(options.get("Y", "0"))
        if name == "MeterPanel":
            w, h = panel_w, panel_h
        elif name == "MeterRule":
            # Centred stroke on a line at Y.
            w, h = content_w, n("#DividerThickness#*#Scale#")
            y -= h / 2
        elif name == "MeterGPUGraphUncollected":
            # No W/H: sized by its shape, which is widest before any sample.
            w, h = content_w, graph_h
        else:
            w, h = n(options["W"]), n(options["H"])
            if options["Meter"] == "String":
                pads = [n(p) for p in split_args(options.get("Padding", "0,0,0,0"))]
                assert len(pads) == 4
                w, h = w + pads[0] + pads[2], h + pads[1] + pads[3]
                x, y = string_origin(x, y, w, h, options.get("StringAlign", "Left"))
        assert w >= 0 and h >= 0, name
        boxes[name] = (x, y, w, h)

    # Containment: window, panel, then content columns and the panel's padded bottom.
    for name, (x, y, w, h) in boxes.items():
        assert x >= -EPS and y >= -EPS and x + w <= width + EPS and y + h <= height + EPS, name
        if name in CONTAINERS:
            continue
        assert x >= content_x - EPS and x + w <= content_x + content_w + EPS, name
        assert y >= inset - EPS and y + h <= inset + panel_h - padding + EPS, name

    # Shape ink stays inside each declared canvas.
    for name, options in meters.items():
        if options["Meter"] != "Shape" or name in ("MeterRule", "MeterGPUGraphUncollected"):
            continue
        w, h = boxes[name][2:]
        for key in (k for k in options if re.fullmatch(r"Shape\d*", k)):
            x, y, sw, sh = primitive_bounds(options, key, n, ICON_TOKENS.get(name))
            assert x >= -EPS and y >= -EPS and x + sw <= w + EPS and y + sh <= h + EPS, (name, key, (x, y, sw, sh), (w, h))

    # No two meter boxes overlap unless the overlap is a declared layering.
    names = sorted(set(boxes) - CONTAINERS)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if frozenset((a, b)) not in ALLOWED_OVERLAPS:
                assert not overlaps(boxes[a], boxes[b]), (a, boxes[a], b, boxes[b])

    # Top-to-bottom order of every band.
    last = inset
    for band in BANDS:
        top = min(boxes[name][1] for name in band)
        assert top >= last - EPS, (band, top, last)
        last = max(boxes[name][1] + boxes[name][3] for name in band)

    # Title row: shared centre, icon size/gap, activity space reserved beside the title.
    title, value = meters["MeterTitle"], meters["MeterActivityValue"]
    icon, gear = meters["MeterIcon"], meters["MeterOptions"]
    assert title["StringAlign"] == "LeftCenter" and value["StringAlign"] == "RightCenter"
    row_center = n("#TitleRowCenterY#")
    for center in (n(title["Y"]), n(value["Y"]), n(icon["Y"]) + n(icon["H"]) / 2, n(gear["Y"]) + n(gear["H"]) / 2):
        assert math.isclose(center, row_center), (overrides, center)
    assert math.isclose(n(icon["W"]), 14 * scale * n("#TitleFontSize#") / 10)
    assert math.isclose(n(icon["H"]), n(icon["W"]))
    assert math.isclose(n(title["X"]), n(icon["X"]) + n(icon["W"]) + n("#TitleIconGap#"))
    assert n(title["X"]) + n(title["W"]) <= n(value["X"]) - n(value["W"])

    # Adapter name and combined memory/clock details use the inset's full width.
    panel = boxes["MeterAdapterPanel"]
    last = panel[1]
    for name in ("MeterAdapterName", "MeterVRAMValue"):
        row = meters[name]
        assert row.get("StringAlign", "Left") == "Left"
        assert math.isclose(n(row["X"]), panel[0] + 4 * scale)
        assert math.isclose(n(row["W"]), panel[2] - 8 * scale)
        assert boxes[name][1] >= last - EPS
        last = boxes[name][1] + boxes[name][3]
        assert last <= panel[1] + panel[3] + EPS
    assert math.isclose(n(meters["MeterVRAMValue"]["H"]), 36 * scale)

    # Memory rows span the content width; every bar uses the shared thickness.
    for name in ("MeterGPUVRAMUsage", "MeterGPUSharedMemory"):
        assert meters[name].get("StringAlign", "Left") == "Left"
        assert math.isclose(boxes[name][0], content_x) and math.isclose(boxes[name][2], content_w)
    thickness = n("#DataBarThickness#")
    for name in ("MeterGPUVRAMBar", *(f"MeterGPU{domain}LoadBar" for domain in ACTIVITY)):
        validate_bar(name, meters[name], n, scale, thickness)

    # Label/value rows share a line and keep a 4 px gutter.
    for field in (*SENSORS, *(f"GPU{domain}Load" for domain in ACTIVITY)):
        label, value = meters[f"Meter{field}Label"], meters[f"Meter{field}Value"]
        assert label.get("StringAlign", "Left") == "Left" and value["StringAlign"] == "Right"
        assert n(label["Y"]) == n(value["Y"]) and n(label["H"]) == n(value["H"])
        assert n(label["X"]) + n(label["W"]) + 4 * scale <= n(value["X"]) - n(value["W"]) + EPS, field

    # Process table: Name | VRAM | GPU % columns with 4 px gutters, icon
    # headers centred on their columns, five rows on a fixed 24 px pitch.
    memory_w, value_w = n("#GPUProcessMemoryWidth#"), n("#GPUProcessValueWidth#")
    first_y = n(meters["MeterGPUProcessName1"]["Y"])
    for i in range(1, 6):
        name, memory, value = (boxes[f"MeterGPUProcess{part}{i}"] for part in PROCESS_COLUMNS)
        options = [meters[f"MeterGPUProcess{part}{i}"] for part in PROCESS_COLUMNS]
        assert [o.get("StringAlign", "Left") for o in options] == ["Left", "Center", "Center"], i
        assert name[1] == memory[1] == value[1] and name[3] == memory[3] == value[3], i
        assert math.isclose(name[1], first_y + 24 * scale * (i - 1)) and name[3] <= 24 * scale + EPS, i
        assert math.isclose(memory[2], memory_w) and math.isclose(value[2], value_w), i
        assert math.isclose(name[0], content_x) and math.isclose(value[0] + value[2], content_x + content_w), i
        assert name[2] > 0, (i, name)
        assert math.isclose(memory[0] - (name[0] + name[2]), 4 * scale), i
        assert math.isclose(value[0] - (memory[0] + memory[2]), 4 * scale), i
    heading = boxes["MeterGPUProcessHeading"]
    assert math.isclose(heading[0], content_x) and math.isclose(heading[2], boxes["MeterGPUProcessName1"][2])
    for header, column, column_w in (("MeterGPUProcessMemoryHeader", "MeterGPUProcessMemory1", memory_w),
                                     ("MeterGPUProcessUtilHeader", "MeterGPUProcessValue1", value_w)):
        box, col = boxes[header], boxes[column]
        assert math.isclose(box[0] + box[2] / 2, col[0] + col[2] / 2), header
        assert math.isclose(box[2], 14 * scale) and math.isclose(box[3], 14 * scale) and box[2] <= column_w, header

    # Graph: overlays coincide with the Line meter; the startup cover never
    # leaves the graph, covers it fully at 0 samples and vanishes once full.
    graph = boxes["MeterGPUUtilizationGraph"]
    assert math.isclose(graph[0], content_x) and math.isclose(graph[2], content_w) and math.isclose(graph[3], graph_h)
    for name in ("MeterGPUGraphUncollected", "MeterGPUGraphFrame"):
        assert boxes[name][:2] == graph[:2], name
    assert boxes["MeterGPUGraphFrame"] == graph
    cover = meters["MeterGPUGraphUncollected"]
    cover = dict(cover, Shape=cover["Shape"].replace("[MeasureGPUGraphSamples]", "#GraphSamples#"))
    for samples in (0, 1, content_w / 2, content_w - 1, content_w, content_w + 10):
        sampled_variables, sampled_resolved = dict(variables, GraphSamples=f"({samples})"), dict(resolved)
        sampled = lambda value: number(value, sampled_variables, sampled_resolved)
        x, y, w, h = primitive_bounds(cover, "Shape", sampled)
        assert x == 0 and y == 0 and 0 <= w <= content_w + EPS and math.isclose(h, graph_h), samples
        assert (samples > 0 or math.isclose(w, content_w)) and (samples < content_w or w == 0), (samples, w)

    return {"window": (width, height), "name_w": boxes["MeterGPUProcessName1"][2],
            "graph_margin": inset + panel_h - (graph[1] + graph[3])}


def geometry_cases(all_scales=False):
    grid = [dict(ColumnWidth=w, Scale=s, Columns=c, TitleFontSize=t, DataBarThickness=b)
            for w in (180, 200, 220, 240, 280, 320) for s in (0.75, 1, 1.25, 1.5, 2)
            for c in (1, 2) for t in (6, 10, 12) for b in (1, 6, 12)]
    # Old saved heights reserve the complete layout; larger saved heights stay larger.
    saved = [dict(ColumnWidth=w, Scale=s, Columns=c, TitleFontSize=12, DataBarThickness=12, PanelHeight=h)
             for w in (180, 220) for s in (.75, 1, 2) for c in (1, 2) for h in (330, 750)]
    # Advanced GraphHeight overrides grow the panel instead of clipping the graph.
    graphs = [dict(ColumnWidth=w, Scale=s, TitleFontSize=12, DataBarThickness=12, GraphHeight=g, PanelHeight=h)
              for w in (180, 320) for s in (.75, 1, 2) for g in (24, 96, 200) for h in (650, 750)]
    # Global Settings frame extremes: Gutter 0-16; border, divider and table rules 0-4.
    frames = [dict(ColumnWidth=w, Scale=s, Columns=c, TitleFontSize=12, DataBarThickness=12, Gutter=g,
                   BorderThickness=t, DividerThickness=t, TableHeaderBorderThickness=t)
              for w in (180, 320) for s in (.75, 1, 2) for c in (1, 2) for g, t in ((0, 0), (16, 4))]
    cases = grid + saved + graphs + frames
    if all_scales:
        # Every Global Settings Scale step (0.01), where rounded bar and
        # padding pixels can differ from the grid scales above.
        cases += [dict(ColumnWidth=w, Scale=step / 100, TitleFontSize=12, DataBarThickness=b,
                       DividerThickness=4, TableHeaderBorderThickness=4)
                  for w in (180, 320) for step in range(75, 201) for b in (6, 12)]
    return cases


def check_cadence():
    # Check the actual sensor-divider formula at default and slower/faster intervals.
    for metrics, sensors in ((1000, 2000), (1500, 2000), (500, 2000), (3000, 2000)):
        variables = dict(sections["Variables"], MetricsInterval=str(metrics), SensorInterval=str(sensors))
        for name in ["MeasureGPURegistryNames"] + [f"MeasureGPU{field}{suffix}" for field in ("Power", "Clock") for suffix in ("Sensor", "Label", "Value", "ValueRaw")]:
            assert sections[name]["Disabled"] == "1", name  # Canonical source enabling is tested in native Lua.
            divider = number(sections[name]["UpdateDivider"], variables)
            assert divider * metrics >= sensors, name
            assert divider >= 1 and divider.is_integer(), name


def main():
    meters = check_static()
    cases = geometry_cases(all_scales="--all-scales" in sys.argv[1:])
    rows = []
    for overrides in cases:
        summary = check_case(meters, overrides)
        if (overrides.get("Columns", 1) == 1 and overrides["TitleFontSize"] == 12 and overrides["DataBarThickness"] == 12
                and overrides["ColumnWidth"] in (180, 220) and overrides["Scale"] in (.75, 1, 2) and len(overrides) == 5):
            rows.append(f"width={overrides['ColumnWidth']} scale={overrides['Scale']:g} title=12 bars=12: "
                        f"{summary['window'][0]:g} x {summary['window'][1]:g}, process name column {summary['name_w']:g} px, "
                        f"{summary['graph_margin']:g} px below graph")
    check_cadence()
    print(f"PASS: {len(loaded)} includes/configs; {len(meters)} explicit meters; {len(cases)} geometry cases; 4 sensor cadences.")
    print("\n".join(rows))
    print("Exact formula geometry only: does not model Rainmeter pixel conversion, execute Lua or verify rendering, HWiNFO integration or performance.")


if __name__ == "__main__":
    main()
