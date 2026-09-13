"""Offline GPU include/geometry checks; standard-library Python only.

This does not emulate Rainmeter, execute Lua or validate font rendering.
The packaging allowlist excludes this development-only .py file.
"""
import ast
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
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


def number(value, variables):
    text = expand(value, variables)
    tree = ast.parse(text, mode="eval")
    allowed = (ast.Expression, ast.Constant, ast.BinOp, ast.UnaryOp, ast.Add,
               ast.Sub, ast.Mult, ast.Div, ast.UAdd, ast.USub, ast.Call,
               ast.Name, ast.Load)
    functions = {"Round": lambda x: math.floor(x + 0.5), "Max": max, "Min": min, "Ceil": math.ceil}
    for item in ast.walk(tree):
        assert isinstance(item, allowed), f"Unsupported formula: {text}"
        if isinstance(item, ast.Name):
            assert item.id in functions, item.id
        if isinstance(item, ast.Constant):
            assert isinstance(item.value, (int, float)), item.value
    return float(eval(compile(tree, "<geometry>", "eval"), {"__builtins__": {}}, functions))


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


def icon_bounds(options, n):
    """Check the actual GPU primitives and strokes, beyond the meter canvas."""
    def coordinates(text):
        parameters = text.split(",")
        assert all("#TitleIconScale#" in value for value in parameters), text
        return [n(value.strip()) for value in parameters]

    for key, shape in options.items():
        if not re.fullmatch(r"Shape\d*", key):
            continue
        primitive, *modifiers = shape.split("|")
        kind, parameters = primitive.strip().split(" ", 1)
        expanded_modifiers = []
        for modifier in modifiers:
            if modifier.strip().startswith("Extend "):
                for name in modifier.strip().split()[1:]:
                    expanded_modifiers.extend(options[name].split("|"))
            else:
                expanded_modifiers.append(modifier)
        stroke = 1.0
        for modifier in expanded_modifiers:
            if modifier.strip().startswith("StrokeWidth "):
                expression = modifier.strip().split(" ", 1)[1]
                stroke = n(expression)
                assert stroke == 0 or "#TitleIconScale#" in expression, (key, shape)
        if kind == "Path":
            start, *segments = options[parameters.strip()].split("|")
            points = [coordinates(start)]
            assert len(points[0]) == 2
            for segment in segments:
                command, text = segment.strip().split(" ", 1)
                if command == "LineTo":
                    point = coordinates(text)
                    assert len(point) == 2
                else:
                    assert command == "ArcTo", command
                    fields = text.split(",")
                    assert len(fields) == 7
                    px, py, rx, ry = coordinates(",".join(fields[:4]))
                    assert [n(field) for field in fields[4:]] == [0, 1, 0]
                    # The supplied SVG uses axis-aligned quarter-circle corners.
                    # Their endpoints enclose the complete small arc; reject
                    # other arc geometry instead of underestimating its bounds.
                    assert math.isclose(rx, ry) and rx > 0
                    assert math.isclose(abs(px - points[-1][0]), rx)
                    assert math.isclose(abs(py - points[-1][1]), ry)
                    point = [px, py]
                points.append(point)
            x, y = min(p[0] for p in points), min(p[1] for p in points)
            w, h = max(p[0] for p in points) - x, max(p[1] for p in points) - y
        elif kind == "Rectangle":
            values = coordinates(parameters)
            x, y, w, h = values[:4]
        elif kind == "Ellipse":
            values = coordinates(parameters)
            cx, cy, rx, ry = values
            x, y, w, h = cx - rx, cy - ry, 2 * rx, 2 * ry
        else:
            assert kind == "Line", (key, kind)
            values = coordinates(parameters)
            x1, y1, x2, y2 = values
            x, y, w, h = min(x1, x2), min(y1, y2), abs(x2 - x1), abs(y2 - y1)
        yield x - stroke / 2, y - stroke / 2, w + stroke, h + stroke


def bar_bounds(shape, n):
    """Bounds of scalar bars' horizontal lines, including their flat-cap stroke."""
    primitive, *modifiers = [part.strip() for part in shape.split("|")]
    assert primitive.startswith("Line "), primitive
    coordinates = [n(value) for value in primitive[5:].split(",")]
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


load(ROOT / "GPU" / "GPU.ini")
for include in ("Measures.inc", "ProcessMeasures.inc", "ProcessMeters.inc", "TemperatureMeasures.inc", "DriverMeters.inc"):
    assert (ROOT / "@Resources" / "Modules" / "GPU" / include).resolve() in loaded, include
assert set(sections["Rainmeter"]["Group"].split("|")) == {"Parallax", "ParallaxGPU"}
assert sections["Rainmeter"]["DynamicWindowSize"] == "0"
# Geometry validation accepts either preserved user choice; packaging owns the
# shipping baseline. Do not require rewriting a user's enabled sensor setting.
assert sections["Variables"]["GPUEnableSensors"] in ("0", "1")
for field in ("Temperature", "Power", "Clock"):
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
assert len(meters) == 47, "GPU requires overview, direct memory/activity, five process rows and sensor readings"
assert "MeterActivityDetail" not in meters
assert {name for name in meters if name.startswith("MeterGPUProcess")} == {
    f"MeterGPUProcess{part}{i}" for i in range(1, 6) for part in ("Name", "Value", "Bar")}
assert "MeterVRAMLabel" not in meters
assert not any(name.startswith(("MeterGPUBaseClock", "MeterGPUBoostClock", "MeterGPUClocks")) for name in meters)
assert not any(name.startswith(("MeterDirect3D", "MeterShader", "MeterRayTracing", "MeterDriver")) for name in meters)
assert {name for name in meters if name.startswith(("MeterGPUMemory", "MeterGPUVRAM", "MeterGPUShared", "MeterGPUUtilization", "MeterGPULoad", "MeterGPUControllerLoad", "MeterGPUVideoLoad", "MeterGPUBusLoad"))} == {
    "MeterGPUMemoryHeader", "MeterGPUVRAMUsage", "MeterGPUVRAMBar", "MeterGPUSharedMemory", "MeterGPUUtilizationHeader",
    *{f"MeterGPU{field}Load{part}" for field in ("", "Controller", "Video", "Bus") for part in ("Label", "Value")}}
for name in ("MeterGPUVRAMUsage", "MeterGPUVRAMBar", "MeterGPUSharedMemory", "MeterGPULoadValue",
             "MeterGPUControllerLoadValue", "MeterGPUVideoLoadValue", "MeterGPUBusLoadValue", "MeterTemperatureValue"):
    assert "GPUDriverReadout" in meters[name]["Group"].split("|"), name
rows = []
cases = [(column_width, scale, columns, title_size, bar_thickness, None) for column_width in (180, 200, 220, 240, 280, 320)
         for scale in (0.75, 1, 1.25, 1.5, 2) for columns in (1, 2) for title_size in (6, 10, 12)
         for bar_thickness in (1, 6, 12)]
# Old saved heights reserve the complete table; larger saved heights stay larger.
cases += [(column_width, scale, columns, 12, 12, saved_height)
          for column_width in (180, 220) for scale in (.75, 1, 2)
          for columns in (1, 2) for saved_height in (330, 633)]
for column_width, scale, columns, title_size, bar_thickness, saved_height in cases:
        variables = dict(sections["Variables"], ColumnWidth=str(column_width), Scale=str(scale),
                         Columns=str(columns), TitleFontSize=str(title_size), DataBarThickness=str(bar_thickness))
        if saved_height is not None:
            variables["PanelHeight"] = str(saved_height)
        n = lambda value: number(value, variables)
        width, height = n("#WindowWidth#"), n("#WindowHeight#")
        inset = n("#Inset#")
        assert width == columns * n("#Pitch#")
        assert n("#PanelWidth#") + 2 * inset == width
        assert n("#PanelHeightPx#") + 2 * inset == height
        assert n("#PanelHeightPx#") == math.floor(max(560, n("#PanelHeight#")) * scale + .5)
        for name, options in meters.items():
            x, y = n(options.get("X", "0")), n(options.get("Y", "0"))
            if options["Meter"] == "Shape":
                # Static native primitives; icon has explicit size and every
                # stroke remains inside that box. No simulated telemetry.
                if name == "MeterPanel":
                    w, h = n("#PanelWidth#"), n("#PanelHeightPx#")
                elif name in ("MeterIcon", "MeterOptions", "MeterAdapterPanel", "MeterGPUVRAMBar") or re.fullmatch(r"MeterGPUProcessBar[1-5]", name):
                    w, h = n(options["W"]), n(options["H"])
                else:
                    assert name == "MeterRule"
                    w, h = n("#ContentWidth#"), n("#DividerThickness#*#Scale#")
                    y -= h / 2
            else:
                w, h = n(options["W"]), n(options["H"])
                padding = [n(p) for p in options.get("Padding", "0,0,0,0").split(",")]
                assert len(padding) == 4
                w += padding[0] + padding[2]
                h += padding[1] + padding[3]
            assert w >= 0 and h >= 0, name
            if options["Meter"] == "String":
                x, y = string_origin(x, y, w, h, options.get("StringAlign", "Left"))
            assert x >= 0 and y >= 0 and x + w <= width and y + h <= height, (name, column_width, scale, columns, title_size, bar_thickness, saved_height)
            if options["Meter"] == "String":
                assert options["ClipString"] == "1", name
                assert x >= inset and x + w <= width - inset, name
        # Label/value rows and header fields must not overlap at narrow widths.
        for field in ("Temperature", "Power", "Clock", "GPULoad", "GPUControllerLoad", "GPUVideoLoad", "GPUBusLoad"):
            label, value = meters[f"Meter{field}Label"], meters[f"Meter{field}Value"]
            assert label.get("StringAlign", "Left") == "Left" and value["StringAlign"] == "Right"
            assert n(label["Y"]) == n(value["Y"])
            assert n(label["H"]) == n(value["H"])
            assert n(label["X"]) + n(label["W"]) + 4 * scale <= n(value["X"]) - n(value["W"]), field
        title, value = meters["MeterTitle"], meters["MeterActivityValue"]
        assert n(title["X"]) + n(title["W"]) <= n(value["X"]) - n(value["W"])
        icon, gear = meters["MeterIcon"], meters["MeterOptions"]
        assert title["StringAlign"] == "LeftCenter"
        assert value["StringAlign"] == "RightCenter"
        row_center = n("#TitleRowCenterY#")
        for center in (n(title["Y"]), n(value["Y"]), n(icon["Y"]) + n(icon["H"]) / 2,
                       n(gear["Y"]) + n(gear["H"]) / 2):
            assert math.isclose(center, row_center), (column_width, scale, title_size, center)
        assert math.isclose(n(icon["W"]), 14 * scale * title_size / 10)
        assert math.isclose(n(icon["H"]), n(icon["W"]))
        assert math.isclose(n(title["X"]), n(icon["X"]) + n(icon["W"]) + n("#TitleIconGap#"))
        for x, y, w, h in icon_bounds(icon, n):
            assert min(x, y) >= 0 and x + w <= n(icon["W"]) and y + h <= n(icon["H"])
        # The name and combined memory/clock details use full inset width.
        # The fixed detail height permits wrapping without growing the window.
        panel = meters["MeterAdapterPanel"]
        for header in (title, value):
            assert n(header["Y"]) + n(header["H"]) / 2 <= n(panel["Y"])
        for header in (icon, gear):
            assert n(header["Y"]) + n(header["H"]) <= n(panel["Y"])
        last_bottom = n(panel["Y"])
        for name in ("AdapterName", "VRAMValue"):
            row = meters["Meter" + name]
            assert row.get("StringAlign", "Left") == "Left"
            assert math.isclose(n(row["X"]), n(panel["X"]) + 4 * scale)
            assert math.isclose(n(row["W"]), n(panel["W"]) - 8 * scale)
            assert n(row["Y"]) >= last_bottom
            last_bottom = n(row["Y"]) + n(row["H"])
            assert last_bottom <= n(panel["Y"]) + n(panel["H"])
        assert math.isclose(n(meters["MeterVRAMValue"]["H"]), 36 * scale)
        last_bottom = n(panel["Y"]) + n(panel["H"])
        # Memory amounts and their capacity bar precede independent activity
        # percentages; both blocks remain above temperature and the process table.
        for name in ("GPUMemoryHeader", "GPUVRAMUsage", "GPUVRAMBar", "GPUSharedMemory", "GPUUtilizationHeader",
                     "GPULoadLabel", "GPUControllerLoadLabel", "GPUVideoLoadLabel", "GPUBusLoadLabel",
                     "TemperatureLabel", "PowerLabel", "ClockLabel", "SensorStatus"):
            row = meters["Meter" + name]
            assert n(row["Y"]) >= last_bottom, name
            last_bottom = n(row["Y"]) + n(row["H"])
        for name in ("MeterGPUVRAMUsage", "MeterGPUSharedMemory"):
            row = meters[name]
            assert row.get("StringAlign", "Left") == "Left"
            assert math.isclose(n(row["X"]), n("#ContentX#"))
            assert math.isclose(n(row["W"]), n("#ContentWidth#"))
        validate_bar("MeterGPUVRAMBar", meters["MeterGPUVRAMBar"], n, scale, bar_thickness)
        divider_y = n(meters["MeterRule"]["Y"])
        divider_h = n("#DividerThickness#*#Scale#")
        assert last_bottom <= divider_y - divider_h / 2
        last_bottom = divider_y + divider_h / 2
        for name in ("ActivityLabel", "ActivityScope"):
            row = meters["Meter" + name]
            assert n(row["Y"]) >= last_bottom, name
            last_bottom = n(row["Y"]) + n(row["H"])
        # Every process label/value row has its own bounded bar below it.
        # Track strokes and the initial empty fills stay inside the declared
        # canvases. Runtime fill clamping is exercised by ProcessGraphSuite.lua.
        for i in range(1, 6):
            label, value, bar = (meters[f"MeterGPUProcess{part}{i}"] for part in ("Name", "Value", "Bar"))
            assert all(row["Group"] == "GPUProcessGraph" for row in (label, value, bar))
            assert label.get("StringAlign", "Left") == "Left" and value["StringAlign"] == "Right"
            assert math.isclose(n(label["Y"]), n(value["Y"]))
            assert n(label["Y"]) >= last_bottom
            assert n(label["X"]) + n(label["W"]) <= n(value["X"]) - n(value["W"])
            assert n(label["Y"]) + n(label["H"]) <= n(bar["Y"])
            assert n(value["Y"]) + n(value["H"]) <= n(bar["Y"])
            validate_bar(f"MeterGPUProcessBar{i}", bar, n, scale, bar_thickness)
            last_bottom = n(bar["Y"]) + n(bar["H"])
        assert last_bottom <= inset + n("#PanelHeightPx#")
        if column_width in (180, 220) and scale in (.75, 1, 2) and columns == 1 and title_size == 12:
            rows.append(f"width={column_width} scale={scale:g} title={title_size} bars={bar_thickness} saved_height={n('#PanelHeight#'):g}: {width:g} x {height:g}, memory/activity and process bars inside bounds")

# Check the actual sensor-divider formula at default and slower/faster intervals.
for metrics, sensors in ((1000, 2000), (1500, 2000), (500, 2000), (3000, 2000)):
    variables = dict(sections["Variables"], MetricsInterval=str(metrics), SensorInterval=str(sensors))
    for name in ["MeasureGPURegistryNames"] + [f"MeasureGPU{field}{suffix}" for field in ("Power", "Clock") for suffix in ("Sensor", "Label", "Value", "ValueRaw")]:
        assert sections[name]["Disabled"] == "1", name  # Canonical source enabling is tested in native Lua.
        divider = number(sections[name]["UpdateDivider"], variables)
        assert divider * metrics >= sensors, name
        assert divider >= 1 and divider.is_integer(), name

print(f"PASS: {len(loaded)} includes/configs; {len(meters)} explicit meters; {len(cases)} geometry cases; 4 sensor cadences.")
print("\n".join(rows))
print("This offline check does not execute Lua or verify rendering, HWiNFO integration or performance.")
