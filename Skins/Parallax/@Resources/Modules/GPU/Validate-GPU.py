"""Offline GPU include/geometry checks; standard-library Python only.

--all-scales adds every 0.01 Scale step that Global Settings allows, at bar
thickness 6 and 12 with 4 px rules, so rounded bar pixels are checked between
the grid scales as well as on them.

This does not emulate Rainmeter, execute Lua or validate font rendering.
The packaging allowlist excludes this development-only .py file.
"""
import ast
import atexit
import math
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sections = {}
loaded = set()
# --processes/--memory override the saved GPUShowProcesses/GPUShowProcessMemory
# when choosing the include variants, as a changed User\GPU.inc would. A plain
# run checks the shipped values, and the other variants in subprocesses.
OVERRIDES = {}
for flag, key in (("--processes", "GPUShowProcesses"), ("--memory", "GPUShowProcessMemory")):
    if flag in sys.argv[1:]:
        OVERRIDES[key] = sys.argv[sys.argv.index(flag) + 1]
# The other include variants, each in a fresh interpreter (module state). They
# start now and run alongside this one; their results are read at the end.
VARIANT_RUNS = []
if __name__ == "__main__" and not OVERRIDES:
    for processes, memory in (("1", "0"), ("0", "1"), ("0", "0")):
        VARIANT_RUNS.append(subprocess.Popen([sys.executable, __file__, "--processes", processes, "--memory", memory]
                                             + [arg for arg in sys.argv[1:] if arg == "--all-scales"],
                                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
    # A failing check here must not leave the variant runs behind.
    atexit.register(lambda: [run.kill() for run in VARIANT_RUNS if run.poll() is None])
# Layouts meet exactly at 4 px gutters and shared row edges; absorb float noise
# from products such as 50*0.76 + 4*0.76 versus 54*0.76 without hiding real overlap.
EPS = 1e-6


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
            variables = dict(sections.get("Variables", {}), **OVERRIDES, **{"@": str(ROOT / "@Resources") + "/"})
            load(Path(expand(value, variables).replace("\\", "/")))
        else:
            sections[current][key] = value


# Expanded formula text -> value. Parsing, checking and evaluating depend on the
# text alone, and the geometry cases expand to the same texts many times over.
FORMULAS = {}


def number(value, variables):
    text = expand(value, variables)
    # Rainmeter's single "=" comparison, as in "(#PanelHeight#=650)", becomes
    # Python's "=="; "<=", ">=" and an existing "==" are left untouched.
    text = re.sub(r"(?<![<>=!])=(?!=)", "==", text)
    if text in FORMULAS:
        return FORMULAS[text]
    tree = ast.parse(text, mode="eval")
    allowed = (ast.Expression, ast.Constant, ast.BinOp, ast.UnaryOp, ast.Add,
               ast.Sub, ast.Mult, ast.Div, ast.UAdd, ast.USub, ast.Call,
               ast.Name, ast.Load, ast.Compare, ast.Eq)
    functions = {"Round": lambda x: math.floor(x + 0.5), "Max": max, "Min": min, "Ceil": math.ceil}
    for item in ast.walk(tree):
        assert isinstance(item, allowed), f"Unsupported formula: {text}"
        if isinstance(item, ast.Name):
            assert item.id in functions, item.id
        if isinstance(item, ast.Constant):
            assert isinstance(item.value, (int, float)), item.value
        if isinstance(item, ast.Compare):
            assert len(item.ops) == 1, f"Chained comparison: {text}"
    # A comparison evaluates to True/False, which arithmetic treats as 1/0.
    FORMULAS[text] = float(eval(compile(tree, "<geometry>", "eval"), {"__builtins__": {}}, functions))
    return FORMULAS[text]


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


def arc_bounds(start, end, rx, ry, rotation, sweep, large):
    """Axis-aligned bounds of one circular ArcTo segment (rotation 0).

    Rainmeter's SweepDirection is the reverse of SVG's sweep flag (0 draws
    clockwise on screen, 1 counter-clockwise); the center then follows the SVG
    implementation notes (F.6.5) for the equivalent flag pair. Besides the two
    endpoints, the box includes every quarter-turn extreme the arc passes.
    """
    assert rotation == 0 and math.isclose(rx, ry) and rx > 0, (rx, ry, rotation)
    assert sweep in (0, 1) and large in (0, 1), (sweep, large)
    svg_sweep = 1 - sweep
    (x1, y1), (x2, y2) = start, end
    hx, hy = (x1 - x2) / 2, (y1 - y2) / 2
    half = math.hypot(hx, hy)
    assert 0 < half <= rx * (1 + 1e-9), "arc chord longer than its diameter"
    lift = math.sqrt(max(0.0, rx * rx - half * half)) / half
    sign = 1 if large != svg_sweep else -1
    cx = (x1 + x2) / 2 + sign * lift * hy
    cy = (y1 + y2) / 2 - sign * lift * hx
    theta1 = math.atan2(y1 - cy, x1 - cx)
    theta2 = math.atan2(y2 - cy, x2 - cx)
    delta = (theta2 - theta1) % (2 * math.pi)
    if not svg_sweep:
        delta -= 2 * math.pi
    xs, ys = [x1, x2], [y1, y2]
    for quarter in range(4):
        angle = quarter * math.pi / 2
        offset = (angle - theta1) % (2 * math.pi)
        if (delta > 0 and offset <= delta) or (delta < 0 and offset - 2 * math.pi >= delta):
            xs.append(cx + rx * math.cos(angle))
            ys.append(cy + ry * math.sin(angle))
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def icon_bounds(options, n, token="#TitleIconScale#"):
    """Check the actual GPU primitives and strokes, beyond the meter canvas.

    Every coordinate and stroke must carry the scaling token: the title icon
    follows #TitleIconScale#, the table header glyphs and the gear #Scale#.
    """
    def coordinates(text):
        parameters = text.split(",")
        assert all(token in value for value in parameters), text
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
                assert stroke == 0 or token in expression, (key, shape)
        if kind == "Path":
            start, *segments = options[parameters.strip()].split("|")
            points = [coordinates(start)]
            assert len(points[0]) == 2
            boxes = []
            for segment in segments:
                command, text = segment.strip().split(" ", 1)
                if command == "LineTo":
                    point = coordinates(text)
                    assert len(point) == 2
                elif command == "ArcTo":
                    fields = text.split(",")
                    assert len(fields) == 7, segment
                    px, py, rx, ry = coordinates(",".join(fields[:4]))
                    rotation, sweep, large = (n(field) for field in fields[4:])
                    boxes.append(arc_bounds(points[-1], (px, py), rx, ry, rotation, sweep, large))
                    point = [px, py]
                else:
                    assert command == "ClosePath", command
                    continue
                points.append(point)
            xs = [p[0] for p in points] + [b[0] for b in boxes] + [b[0] + b[2] for b in boxes]
            ys = [p[1] for p in points] + [b[1] for b in boxes] + [b[1] + b[3] for b in boxes]
            x, y = min(xs), min(ys)
            w, h = max(xs) - x, max(ys) - y
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


def line_bounds(shape, n):
    """Bounds of a horizontal divider or header-rule line with its stroke."""
    primitive, *modifiers = [part.strip() for part in shape.split("|")]
    assert primitive.startswith("Line "), primitive
    x1, y1, x2, y2 = (n(value) for value in primitive[5:].split(","))
    assert math.isclose(y1, y2), primitive
    stroke_options = [item[len("StrokeWidth "):] for item in modifiers if item.startswith("StrokeWidth ")]
    assert len(stroke_options) == 1, shape
    stroke = n(stroke_options[0])
    assert stroke >= 0
    return min(x1, x2), y1 - stroke / 2, abs(x2 - x1), stroke


def rectangle_bounds(shape, n):
    """Bounds of a Rectangle primitive including its stroke (default width 1)."""
    primitive, *modifiers = [part.strip() for part in shape.split("|")]
    assert primitive.startswith("Rectangle "), primitive
    values = [n(value) for value in primitive[len("Rectangle "):].split(",")]
    assert len(values) in (4, 5, 6), primitive
    x, y, w, h = values[:4]
    stroke_options = [item[len("StrokeWidth "):] for item in modifiers if item.startswith("StrokeWidth ")]
    assert len(stroke_options) <= 1, shape
    stroke = n(stroke_options[0]) if stroke_options else 1.0
    return x - stroke / 2, y - stroke / 2, w + stroke, h + stroke


def validate_bar_geometry(name, bar, n, scale, thickness, expected_x, expected_w):
    """A bar's full track and initial empty fill fit its declared canvas."""
    assert math.isclose(n(bar["X"]), expected_x), name
    assert math.isclose(n(bar["W"]), expected_w), name
    assert math.isclose(n(bar["H"]), n("#DataBarThicknessPx#")), name
    assert math.isclose(n(bar["H"]), max(1, math.floor(thickness * scale + .5))), name
    assert "Shape3" not in bar, name
    for key in ("Shape", "Shape2"):
        x, y, w, h = bar_bounds(bar[key], n)
        assert min(x, y, w, h) + EPS >= 0, (name, key)
        assert x + w <= EPS + n(bar["W"]) and y + h <= EPS + n(bar["H"]), (name, key)
        if key == "Shape":
            assert math.isclose(x, 0) and math.isclose(w, n(bar["W"])), name
            assert math.isclose(y, 0) and math.isclose(h, n(bar["H"])), name
        else:
            assert math.isclose(w, 0) and math.isclose(h, 0), name


def validate_bar(name, bar, n, scale, thickness):
    """Full-width bars span the content column at the shared thickness."""
    validate_bar_geometry(name, bar, n, scale, thickness, n("#ContentX#"), n("#ContentWidth#"))


RULE_METERS = ("MeterGPUEngineFooterRule", "MeterGPUProcessFooterRule")


def meter_box(name, options, n):
    """Top-left bounding box of one meter in window pixels."""
    x, y = n(options.get("X", "0")), n(options.get("Y", "0"))
    kind = options["Meter"]
    if kind == "Shape" and name == "MeterPanel":
        w, h = n("#PanelWidth#"), n("#PanelHeightPx#")
    elif kind == "Shape" and name in RULE_METERS:
        # StyleRule draws a zero-height line centered on Y; it declares no W/H.
        assert "StyleRule" in options["MeterStyle"].split("|"), name
        assert "W" not in options and "H" not in options, name
        lx, ly, w, h = line_bounds(options["Shape"], n)
        assert math.isclose(lx, 0) and math.isclose(w, n("#ContentWidth#")), name
        assert math.isclose(h, n("#DividerThickness#*#Scale#")), name
        x, y = x + lx, y + ly
    elif kind == "Shape" and name == "MeterGPUGraphUncollected":
        # The cover's width follows a measure; its largest extent is the graph.
        assert "W" not in options and "H" not in options, name
        w, h = n("#ContentWidth#"), n("#GraphHeight#*#Scale#")
    else:
        w, h = n(options["W"]), n(options["H"])
        if kind != "Shape":
            padding = [n(p) for p in options.get("Padding", "0,0,0,0").split(",")]
            assert len(padding) == 4
            w += padding[0] + padding[2]
            h += padding[1] + padding[3]
        if kind == "String":
            x, y = string_origin(x, y, w, h, options.get("StringAlign", "Left"))
    assert w + EPS >= 0 and h + EPS >= 0, name
    return x, y, w, h


GPU_DIR = ROOT / "@Resources" / "Modules" / "GPU"
load(ROOT / "GPU" / "GPU.ini")
for include in ("Measures.inc", "TemperatureMeasures.inc", "DriverMeters.inc", "GraphMeters.inc"):
    assert (GPU_DIR / include).resolve() in loaded, include
# The process table and its VRAM column are include variants chosen by the
# saved GPUShowProcesses / GPUShowProcessMemory text. Only a "1" variant raises
# its layout flag, so the geometry follows what actually loaded.
SHOW_PROCESSES = OVERRIDES.get("GPUShowProcesses", sections["Variables"]["GPUShowProcesses"])
SHOW_MEMORY = OVERRIDES.get("GPUShowProcessMemory", sections["Variables"]["GPUShowProcessMemory"])
TABLE = SHOW_PROCESSES == "1"
MEMORY = TABLE and SHOW_MEMORY == "1"
assert sections["Variables"]["GPUProcessTable"] == ("1" if TABLE else "0")
assert sections["Variables"]["GPUProcessMemoryColumn"] == ("1" if MEMORY else "0")
VARIANT_FILES = {
    "ProcessMeasures1.inc": TABLE, "ProcessMeters1.inc": TABLE,
    "ProcessMeasures0.inc": SHOW_PROCESSES == "0", "ProcessMeters0.inc": SHOW_PROCESSES == "0",
    "ProcessMemoryMeasures1.inc": MEMORY, "ProcessMemoryMeters1.inc": MEMORY,
    "ProcessMemoryMeasures0.inc": TABLE and SHOW_MEMORY == "0", "ProcessMemoryMeters0.inc": TABLE and SHOW_MEMORY == "0",
}
for include, expected in VARIANT_FILES.items():
    assert ((GPU_DIR / include).resolve() in loaded) == expected, (include, SHOW_PROCESSES, SHOW_MEMORY)
assert not (GPU_DIR / "ProcessMeasures.inc").exists() and not (GPU_DIR / "ProcessMeters.inc").exists()
# Both stubs are comment-only: no section, so no measure, meter or variable.
for stub in ("ProcessMeasures0.inc", "ProcessMeters0.inc", "ProcessMemoryMeasures0.inc", "ProcessMemoryMeters0.inc"):
    lines = [line.strip() for line in (GPU_DIR / stub).read_text(encoding="utf-8-sig").splitlines()]
    assert lines and all(not line or line.startswith(";") for line in lines), stub
# UsageMonitor reads a whole counter category, process-wide, while any loaded
# measure names it, even a Disabled one; only leaving the measure out stops it.
usage_monitor = {name: opts for name, opts in sections.items() if opts.get("Plugin") == "UsageMonitor"}
expected_monitor = ({"MeasureGPUActivity", *(f"MeasureGPUProcess{i}" for i in range(2, 6))} if TABLE else set()) | (
    {f"MeasureGPUProcessMemory{i}" for i in range(1, 6)} if MEMORY else set())
assert set(usage_monitor) == expected_monitor, sorted(usage_monitor)
# B2 step 3 (ENGINE-05 / XMOD-07): DynamicVariables on a UsageMonitor measure
# re-reads its options, and so calls the plugin's Reload (re-registering its
# category), on every update, disabled or not. ProcessGraph.lua's !SetOption
# Name already forces the one re-read a rebinding needs, so none may have it,
# and no controller may turn it on at runtime.
assert not [name for name in usage_monitor if "DynamicVariables" in sections[name]], "UsageMonitor with DynamicVariables"
assert "DynamicVariables" not in (GPU_DIR / "ProcessGraph.lua").read_text(encoding="utf-8")
for name in usage_monitor:
    assert (GPU_DIR / ("ProcessMemoryMeasures1.inc" if "Memory" in name else "ProcessMeasures1.inc")).read_text(
        encoding="utf-8-sig").count(f"[{name}]") == 1, name
assert "Plugin=UsageMonitor" not in (GPU_DIR / "Measures.inc").read_text(encoding="utf-8-sig")
assert ("MeasureGPUProcessController" in sections) == TABLE
assert set(sections["Rainmeter"]["Group"].split("|")) == {"Parallax", "ParallaxGPU"}
assert sections["Rainmeter"]["DynamicWindowSize"] == "0"
# #ParallaxIdleJoinAction# is empty unless Global Settings Idle pause is on.
assert sections["Rainmeter"]["OnRefreshAction"] == '[!CommandMeasure MeasureGPUInfo "Run"]#ParallaxIdleJoinAction#'
assert sections["Rainmeter"]["OnCloseAction"] == '[!CommandMeasure MeasureGPUTemperatureController "Stop()"]'
# The gear replaces the title-row headline on hover, as in CPU Meter.
assert "[!HideMeter MeterActivityValue][!ShowMeter MeterOptions]" in sections["Rainmeter"]["MouseOverAction"]
assert "[!HideMeter MeterOptions][!ShowMeter MeterActivityValue]" in sections["Rainmeter"]["MouseLeaveAction"]
# Geometry validation accepts either preserved user choice; packaging owns the
# shipping baseline. Do not require rewriting a user's enabled sensor setting.
assert sections["Variables"]["GPUEnableSensors"] in ("0", "1")
assert sections["Variables"]["PanelHeight"] == "462", "User\\GPU.inc ships the natural (Fit) height"
for field in ("Temperature", "Power", "Clock"):
    assert sections["Variables"][f"GPU{field}Index"] == "-1"
    assert sections["Variables"][f"GPU{field}Sensor"] == ""
    assert sections["Variables"][f"GPU{field}Label"] == ""
for name, timeout in (("MeasureGPUTemperatureLauncher", "15000"),):
    options = sections[name]
    assert options["Measure"] == "Plugin" and options["Plugin"] == "RunCommand", name
    assert options["Timeout"] == timeout and options["State"] == "Hide", name
    assert "FinishAction" not in options and options["Parameter"] == "", name
# RunCommand polls a running child with a 1 ms wait on a plugin thread until
# it exits, so the resident host runs detached and no GPU command is unbounded.
# The launcher mints the session itself, so no compiling bootstrap remains.
assert "MeasureGPUTemperatureDriver" not in sections and "MeasureGPUTemperatureBootstrap" not in sections
temperature_raw = (GPU_DIR / "Temperature.lua").read_bytes()
temperature_text = temperature_raw.decode("utf-16") if temperature_raw.startswith(b"\xff\xfe") else temperature_raw.decode("utf-8")
assert "[guid]::NewGuid().ToString('N')" in temperature_text and "'CreateNew','Write','Read'" in temperature_text
assert "CreateSession" not in temperature_text and temperature_text.count("Add-Type") == 1
assert "Add-Type -TypeDefinition ([IO.File]::ReadAllText('@S@'))" in temperature_text
assert "-WorkingDirectory $t -WindowStyle Hidden -PassThru" in temperature_text
# Idle stand-down never kills a launch in progress: a Kill before RunCommand
# has created the process is refused (Error 102), and one after the
# launcher's Start-Process misses the detached host. Drain stops the host the
# launch reports, from one fixed delayed call, and starts nothing.
stand_down = re.search(r"\nfunction StandDown\(\)(.*?)\nend", temperature_text, re.S)
drain = re.search(r"\nfunction Drain\(\)(.*?)\nend", temperature_text, re.S)
assert stand_down and "Kill" not in stand_down.group(1) and "stopHelpers" not in stand_down.group(1), "idle stand-down must not kill a launch in progress"
assert drain and not re.search(r"launch\(|begin\(|'Run'", drain.group(1)), "the drain must never start a process"
assert """local drainCheck = '[!Delay 1000][!CommandMeasure MeasureGPUTemperatureController "Drain()"]'""" in temperature_text
assert "CreateSession" not in (GPU_DIR / "DriverTemperature.cs.txt").read_text(encoding="utf-8")
assert not any(opts.get("Plugin") == "RunCommand" and opts.get("Timeout", "-1") == "-1" for opts in sections.values())
assert not any(name.startswith("MeasureGPUTemperature") and opts.get("Measure") == "Registry" for name, opts in sections.items())
assert sections["MeasureGPUTemperatureController"]["Measure"] == "Script"
assert sections["MeasureGPUTemperatureController"]["ScriptFile"] == "#@#Modules\\GPU\\Temperature.lua"
# A frozen HWiNFO override export is withheld as "Not updating"; the behaviour is in TemperatureSuite.lua.
assert "local exportStaleSeconds, exportProbes = 60, 8" in temperature_text
assert "if reading and frozen then value = 'Not updating' end" in temperature_text
assert "SKIN:Bang('!EnableMeasure', 'MeasureGPUExportProbe' .. index)" in temperature_text
assert sections["MeasureGPUView"]["Measure"] == "Script"
assert sections["MeasureGPUView"]["ScriptFile"] == "#@#Modules\\GPU\\GPU.lua"
if TABLE:
    assert sections["MeasureGPUProcessController"]["Measure"] == "Script"
    assert sections["MeasureGPUProcessController"]["ScriptFile"] == "#@#Modules\\GPU\\ProcessGraph.lua"
info = sections["MeasureGPUInfo"]
assert info["Plugin"] == "RunCommand" and info["State"] == "Hide" and info["Timeout"] == "12000"
assert info["FinishAction"] == "[!UpdateMeasure MeasureGPUInfo][!UpdateMeasure MeasureGPUView]"
for index in range(1, 6) if TABLE else ():
    rank = sections["MeasureGPUActivity" if index == 1 else f"MeasureGPUProcess{index}"]
    assert {key: rank[key] for key in ("Plugin", "Alias", "Index", "PIDToName", "Rollup", "Percent", "RawValue")} == {
        "Plugin": "UsageMonitor", "Alias": "GPU", "Index": str(index), "PIDToName": "0", "Rollup": "0", "Percent": "0", "RawValue": "0"}, index
for index in range(1, 6) if MEMORY else ():
    memory = sections[f"MeasureGPUProcessMemory{index}"]
    assert memory["Plugin"] == "UsageMonitor" and "Alias" not in memory, index
    assert memory["Category"] == "GPU Process Memory" and memory["Counter"] == "Local Usage", index
    assert memory["Index"] == "0" and memory["RawValue"] == "1" and memory["Disabled"] == "1", index
    assert memory["Name"] == "__ParallaxNoGPUProcess__", index
    assert memory["PIDToName"] == "0", index
# The History trace is the controller's busy percentage, wrapped in an explicit
# 0-100 range directly after the controller in TemperatureMeasures.inc.
# Measures.inc no longer owns it. Since 2026-10-22 Temperature.lua pushes one
# point per new driver sample: it sets this Formula to a literal and forces the
# Calc, the sample counter and the Line meter, all three UpdateDivider=-1 so the
# 1 s skin cycle never plots a 2 s sample twice.
measures_text = (GPU_DIR / "Measures.inc").read_text(encoding="utf-8-sig")
temperature_text = (GPU_DIR / "TemperatureMeasures.inc").read_text(encoding="utf-8-sig")
assert "[MeasureGPUUtilizationHistory]" not in measures_text
assert temperature_text.index("[MeasureGPUUtilizationHistory]") > temperature_text.index("[MeasureGPUTemperatureController]")
assert sections["MeasureGPUUtilizationHistory"] == {
    "Measure": "Calc", "Formula": "0", "MinValue": "0", "MaxValue": "100", "UpdateDivider": "-1"}
samples = sections["MeasureGPUGraphSamples"]
assert samples["Measure"] == "Calc" and samples["UpdateDivider"] == "-1"
assert samples["Formula"] == "Min(MeasureGPUGraphSamples+1,#ContentWidth#)"
# A full graph retires the startup cover: hidden, and no further re-reads.
assert samples["IfCondition"] == "MeasureGPUGraphSamples>=#ContentWidth#"
assert samples["IfTrueAction"] == ("[!SetOption MeterGPUGraphUncollected DynamicVariables 0]"
                                   "[!SetOption MeterGPUGraphUncollected UpdateDivider -1][!HideMeter MeterGPUGraphUncollected]")

meters = {name: effective(name) for name, options in sections.items() if "Meter" in options}
assert all("Meter" in options for name, options in sections.items() if name.startswith("Meter"))
# 2026-10-11: tooltips were removed suite-wide; none may return unplanned.
assert not [(name, key) for name, options in sections.items() for key in options if key.lower().startswith("tooltip")]
SCALAR_FIELDS = ("Temperature", "Power", "Clock")
ENGINE_FIELDS = ("GPULoad", "GPUControllerLoad", "GPUVideoLoad", "GPUBusLoad")
ENGINE_LABELS = dict(zip(ENGINE_FIELDS, ("Core", "Memory", "Video", "Bus")))
PROCESS_PARTS = ("Name", "Memory", "Value")
EXPECTED_METERS = {
    "MeterBounds", "MeterPanel", "MeterIcon", "MeterTitle", "MeterActivityValue", "MeterOptions",
    "MeterAdapterPanel", "MeterAdapterName", "MeterAdapterDetails",
    *(f"Meter{field}{part}" for field in SCALAR_FIELDS for part in ("Label", "Value")),
    "MeterGPUEngineHeader", "MeterGPUEngineUsageHeader", "MeterGPUEngineHeaderRule",
    *(f"Meter{field}{part}" for field in ENGINE_FIELDS for part in ("Label", "Bar", "Value")),
    "MeterGPUEngineFooterRule",
    "MeterGPUVRAMLabel", "MeterGPUVRAMValue", "MeterGPUVRAMBar", "MeterGPUSharedLabel", "MeterGPUSharedValue",
    "MeterGPUProcessHeading", "MeterGPUProcessMemoryHeader", "MeterGPUProcessUtilHeader", "MeterGPUProcessHeaderRule",
    *(f"MeterGPUProcess{part}{i}" for i in range(1, 6) for part in PROCESS_PARTS),
    "MeterGPUProcessFooterRule",
    "MeterGPUHistoryLabel", "MeterGPUHistoryRange", "MeterGPUUtilizationGraph", "MeterGPUGraphUncollected", "MeterGPUGraphFrame",
}
assert len(EXPECTED_METERS) == 61
MEMORY_METERS = {"MeterGPUProcessMemoryHeader", *(f"MeterGPUProcessMemory{i}" for i in range(1, 6))}
TABLE_METERS = {name for name in EXPECTED_METERS if name.startswith("MeterGPUProcess")}
assert len(MEMORY_METERS) == 6 and len(TABLE_METERS) == 20 and MEMORY_METERS < TABLE_METERS
if not TABLE:
    EXPECTED_METERS -= TABLE_METERS
elif not MEMORY:
    EXPECTED_METERS -= MEMORY_METERS
assert set(meters) == EXPECTED_METERS, sorted(set(meters) ^ EXPECTED_METERS)
assert len(meters) == (61 if MEMORY else 55 if TABLE else 41), "title row, adapter inset, three scalar rows, Engine table, VRAM/Shared, process table and History"
REMOVED_METERS = {"MeterVRAMValue", "MeterActivityLabel", "MeterActivityScope", "MeterRule", "MeterSensorStatus",
                  "MeterGPUVRAMUsage", "MeterGPUSharedMemory", "MeterGPUMemoryHeader", "MeterGPUUtilizationHeader",
                  "MeterGPUGraphHeading", "MeterGPUGraphRule", *(f"MeterGPUProcessBar{i}" for i in range(1, 6))}
assert REMOVED_METERS.isdisjoint(meters)
styles = ("GPUStyleEngineLabel", "GPUStyleEngineValue", "GPUStyleEngineBar") + (
    ("GPUStyleProcessName", "GPUStyleProcessValue") if TABLE else ()) + (("GPUStyleProcessMemory",) if MEMORY else ())
for style in styles:
    assert style in sections and "Meter" not in sections[style], style
# GPU.lua writes the adapter inset (GPUReadout); Temperature.lua writes every
# driver-fed headline, scalar, memory and engine meter (GPUDriverReadout).
for name in ("MeterActivityValue", "MeterAdapterName", "MeterAdapterDetails", "MeterTemperatureValue"):
    # Rainmeter trims each group name (the idle stand-down adds " | ParallaxIdleFreeze").
    assert "GPUReadout" in {group.strip() for group in meters[name]["Group"].split("|")}, name
for name in ("MeterActivityValue", "MeterTemperatureValue", "MeterPowerValue", "MeterClockValue",
             "MeterGPUVRAMValue", "MeterGPUVRAMBar", "MeterGPUSharedValue",
             *(f"Meter{field}{part}" for field in ENGINE_FIELDS for part in ("Value", "Bar"))):
    assert "GPUDriverReadout" in {group.strip() for group in meters[name]["Group"].split("|")}, name
for i in range(1, 6) if TABLE else ():
    for part in PROCESS_PARTS if MEMORY else ("Name", "Value"):
        cell = meters[f"MeterGPUProcess{part}{i}"]
        assert cell["Group"] == f"GPUProcessGraph|GPUProcessRow{i}|ParallaxIdleFreeze", (part, i)
        assert cell["Text"] == "--" and cell["H"] == "(16*#Scale#)", (part, i)
assert meters["MeterTitle"]["Text"] == "GPU Meter"
assert meters["MeterActivityValue"]["Text"] == "--" and meters["MeterActivityValue"]["FontColor"] == "#GPUColor#"
assert meters["MeterAdapterDetails"]["FontColor"] == "#AccentColor#"
for field, text in zip(SCALAR_FIELDS, ("Temp:", "Power:", "Clock:")):
    label, value = meters[f"Meter{field}Label"], meters[f"Meter{field}Value"]
    assert label["Text"] == text, field
    assert "StyleValue" in value["MeterStyle"].split("|"), field
    assert value["FontColor"] == "#AccentColor2#" and value["FontSize"] == "(#FontSize#*#Scale#)", field
for field in ENGINE_FIELDS:
    assert meters[f"Meter{field}Label"]["Text"] == ENGINE_LABELS[field], field
    assert meters[f"Meter{field}Value"]["Text"] == "--", field
    assert "GPUStyleEngineBar" in meters[f"Meter{field}Bar"]["MeterStyle"].split("|"), field
for name in ("MeterGPUEngineHeader", "MeterGPUProcessHeading") if TABLE else ("MeterGPUEngineHeader",):
    assert meters[name]["FontSize"] == "(#HeaderFontSize#*#Scale#)" and meters[name]["FontColor"] == "#HeaderTextColor#", name
assert meters["MeterGPUEngineHeader"]["Text"] == "Engine"
assert not TABLE or meters["MeterGPUProcessHeading"]["Text"] == "Process"
assert meters["MeterGPUVRAMLabel"]["Text"] == "VRAM:" and meters["MeterGPUSharedLabel"]["Text"] == "Shared:"
assert meters["MeterGPUHistoryLabel"]["Text"] == "History" and meters["MeterGPUHistoryRange"]["Text"] == "0 - 100%"
graph = meters["MeterGPUUtilizationGraph"]
assert graph["Meter"] == "Line" and graph["MeasureName"] == "MeasureGPUUtilizationHistory"
assert graph["AutoScale"] == "0" and graph["LineCount"] == "1" and graph["GraphStart"] == "Right"
assert graph["LineColor"] == "#GPUColor#" and graph["UpdateDivider"] == "-1"
# Load-time options only: no per-update re-parse of the geometry chains.
assert "DynamicVariables" not in graph, "the History Line meter must not re-read its options"
uncollected = meters["MeterGPUGraphUncollected"]
assert "[MeasureGPUGraphSamples]" in uncollected["Shape"], "the startup cover must follow the sample count"
assert uncollected["DynamicVariables"] == "1" and uncollected["UpdateDivider"] == "1"
assert "StyleGraph" in meters["MeterGPUGraphFrame"]["MeterStyle"].split("|")
assert meters["MeterOptions"]["Hidden"] == "1"
for name in ("MeterIcon", "MeterOptions", "MeterAdapterPanel", "MeterGPUEngineUsageHeader",
             "MeterGPUProcessMemoryHeader", "MeterGPUProcessUtilHeader", "MeterGPUGraphFrame", "MeterGPUGraphUncollected"):
    if name in meters:
        assert meters[name]["Meter"] == "Shape", name
# Lua names only current meters: every quoted Meter... literal, or the prefix a
# script concatenates a field or slot onto, must start a meter that exists.
for script in ("GPU.lua", "Temperature.lua", "ProcessGraph.lua"):
    raw = (GPU_DIR / script).read_bytes()
    script_text = raw.decode("utf-16") if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else raw.decode("utf-8")
    for literal in set(re.findall(r"['\"](Meter[A-Za-z0-9]*)['\"]", script_text)):
        # ProcessGraph.lua only runs with its table, and writes VRAM cells only
        # while GPUProcessMemoryColumn is 1; every other script always.
        optional = script == "ProcessGraph.lua" and (not TABLE or (not MEMORY and literal.startswith("MeterGPUProcessMemory")))
        assert any(name.startswith(literal) for name in meters) or optional, (script, literal)
    assert not re.search(r"GetMeasure\(\s*['\"]MeasureGPUActivity['\"]", script_text), script
    assert "tooltip" not in script_text.lower(), script
    if script == "Temperature.lua":
        assert "'GPUEngineBarWidth'" in script_text and "'ContentWidth'" in script_text and "'DataBarThicknessPx'" in script_text
        # The controller forces every History point; nothing else updates them.
        for forced in ("'MeasureGPUUtilizationHistory'", "'MeasureGPUGraphSamples'", "'MeterGPUUtilizationGraph'"):
            assert forced in script_text, forced
        for name in ("MeterActivityValue", "MeterGPUVRAMValue", "MeterGPUVRAMBar", "MeterGPUSharedValue",
                     *(f"Meter{field}{part}" for field in ENGINE_FIELDS for part in ("Value", "Bar"))):
            assert f"'{name}'" in script_text, name
    elif script == "ProcessGraph.lua":
        assert "'GPUProcessRow'" in script_text and "'MeasureGPUInfo'" not in script_text
        assert "!ShowMeterGroup" in script_text and "!HideMeterGroup" in script_text
    else:
        assert "'MeterAdapterName'" in script_text and "'MeterAdapterDetails'" in script_text
for key in ("GPUBarExtra", "GPUNaturalHeight", "PanelHeightPx", "GPUEngineLabelWidth", "GPUEngineValueWidth",
            "GPUEngineBarX", "GPUEngineBarWidth", "GPUProcessValueWidth", "GPUProcessMemoryWidth",
            "GPUProcessNameWidth", "GPUProcessBlock", "GPUProcessTable", "GPUProcessMemoryColumn",
            "GPUShowProcesses", "GPUShowProcessMemory"):
    assert key in sections["Variables"], key


def check_process_table(case, n, box, meters, scale, extra, content_x, content_w, content_right, inset):
    """The process table's geometry, with or without its VRAM column."""
    top = lambda name: box[name][1]
    bottom = lambda name: box[name][1] + box[name][3]
    left = lambda name: box[name][0]
    right = lambda name: box[name][0] + box[name][2]
    assert bottom("MeterGPUSharedLabel") <= EPS + top("MeterGPUProcessHeading"), case
    heading = meters["MeterGPUProcessHeading"]
    memory_w, process_value_w = n("#GPUProcessMemoryWidth#"), n("#GPUProcessValueWidth#")
    process_value_center = content_right - process_value_w / 2
    memory_center = content_right - process_value_w - 4 * scale - memory_w / 2
    assert math.isclose(box["MeterGPUProcessHeading"][3], 16 * scale)
    assert math.isclose(top("MeterGPUProcessHeading"), inset + (276 + extra) * scale), case
    assert math.isclose(left("MeterGPUProcessHeading"), content_x)
    assert right("MeterGPUProcessHeading") <= EPS + left("MeterGPUProcessMemoryHeader" if MEMORY else "MeterGPUProcessUtilHeader"), case
    glyphs = (("MeterGPUProcessMemoryHeader", memory_center),) if MEMORY else ()
    for name, center in glyphs + (("MeterGPUProcessUtilHeader", process_value_center),):
        glyph = meters[name]
        assert math.isclose(n(glyph["W"]), 14 * scale) and math.isclose(n(glyph["H"]), 14 * scale), name
        assert math.isclose(left(name) + n(glyph["W"]) / 2, center), (name, case)
        assert top(name) + EPS >= top("MeterGPUProcessHeading") and bottom(name) <= EPS + top("MeterGPUProcessHeaderRule"), (name, case)
        for x, y, w, h in icon_bounds(glyph, n, "#Scale#"):
            assert min(x, y) + EPS >= 0 and x + w <= EPS + n(glyph["W"]) and y + h <= EPS + n(glyph["H"]), (name, case)
    assert not MEMORY or right("MeterGPUProcessMemoryHeader") <= EPS + left("MeterGPUProcessUtilHeader"), case
    assert bottom("MeterGPUProcessHeading") <= EPS + top("MeterGPUProcessHeaderRule"), case
    previous_bottom = bottom("MeterGPUProcessHeaderRule")
    for i in range(1, 6):
        name, memory, value = (f"MeterGPUProcess{part}{i}" for part in PROCESS_PARTS)
        cells = (name, memory, value) if MEMORY else (name, value)
        assert meters[name].get("StringAlign", "Left") == "Left", name
        assert all(meters[cell]["StringAlign"] == "Center" for cell in cells[1:]), i
        assert all(math.isclose(top(name), top(cell)) for cell in cells), i
        assert all(math.isclose(box[cell][3], 16 * scale) for cell in cells), i
        assert top(name) + EPS >= previous_bottom, (i, case)
        assert math.isclose(top(name), top("MeterGPUProcessName1") + 16 * scale * (i - 1)), (i, case)
        assert math.isclose(top(name), inset + (296 + 16 * (i - 1) + extra) * scale), (i, case)
        assert math.isclose(left(name), content_x), i
        assert math.isclose(box[value][2], process_value_w) and math.isclose(left(value) + process_value_w / 2, process_value_center), i
        assert math.isclose(right(value), content_right), i
        if MEMORY:
            assert math.isclose(box[memory][2], memory_w) and math.isclose(left(memory) + memory_w / 2, memory_center), i
            assert right(name) + 4 * scale <= EPS + left(memory), (i, case)
            assert right(memory) + 4 * scale <= EPS + left(value), (i, case)
        else:
            assert math.isclose(right(name) + 4 * scale, left(value)), (i, case)
        previous_bottom = bottom(name)
    assert previous_bottom <= EPS + top("MeterGPUProcessFooterRule"), case
    assert math.isclose(left("MeterGPUProcessFooterRule"), content_x) and math.isclose(box["MeterGPUProcessFooterRule"][2], content_w)
    assert math.isclose(n(meters["MeterGPUProcessFooterRule"]["Y"]), inset + (378 + extra) * scale), case


def check_case(column_width, scale, columns, title_size, bar_thickness, saved_height, overrides=None):
    """Validate one width/scale/columns/title/thickness/saved-height combination."""
    variables = dict(sections["Variables"], ColumnWidth=str(column_width), Scale=str(scale),
                     Columns=str(columns), TitleFontSize=str(title_size), DataBarThickness=str(bar_thickness))
    if saved_height is not None:
        variables["PanelHeight"] = str(saved_height)
    if overrides:
        variables.update(overrides)
    cache = {}

    def n(value):
        if value not in cache:
            cache[value] = number(value, variables)
        return cache[value]

    case = (column_width, scale, columns, title_size, bar_thickness, saved_height)
    box = {name: meter_box(name, options, n) for name, options in meters.items()}
    width, height = n("#WindowWidth#"), n("#WindowHeight#")
    inset = n("#Inset#")
    content_x, content_w = n("#ContentX#"), n("#ContentWidth#")
    content_right = content_x + content_w
    panel_h = n("#PanelHeightPx#")
    panel_bottom = inset + panel_h
    extra = max(0, bar_thickness - 6)
    saved = n("#PanelHeight#")
    block = 110 if TABLE else 0
    natural = 304 + block + n("#GraphHeight#") + extra
    thickness_px = max(1, math.floor(bar_thickness * scale + .5))
    # Derived variables: the old 650 Fit value counts as Fit; smaller saved
    # heights yield to the natural height and larger ones are honored.
    assert width == columns * n("#Pitch#")
    assert n("#PanelWidth#") + 2 * inset == width
    assert panel_h + 2 * inset == height
    assert n("#GPUBarExtra#") == extra, case
    assert n("#GPUNaturalHeight#") == natural, case
    # 462 (the Fit with the table) also counts as Fit without it, so hiding the
    # table shortens a fitted panel; with the table it is unchanged.
    fit = saved == 650 or (saved == 462 and not TABLE)
    assert n("#GPUProcessBlock#") == block, case
    assert panel_h == math.floor(max(0 if fit else saved, natural) * scale + .5), case
    assert n("#DataBarThicknessPx#") == thickness_px, case
    assert math.isclose(n("#GPUEngineLabelWidth#"), 52 * scale)
    assert math.isclose(n("#GPUEngineValueWidth#"), 42 * scale)
    assert math.isclose(n("#GPUEngineBarX#"), content_x + 56 * scale)
    assert math.isclose(n("#GPUEngineBarWidth#"), content_w - 102 * scale)
    assert math.isclose(n("#GPUProcessValueWidth#"), 46 * scale)
    assert math.isclose(n("#GPUProcessMemoryWidth#"), 58 * scale)
    name_w = content_w - 46 * scale - 4 * scale - ((58 + 4) * scale if MEMORY else 0)
    assert math.isclose(n("#GPUProcessNameWidth#"), name_w), case
    assert n("#GPUEngineBarWidth#") > 0 and name_w > 0, case
    # A frozen HWiNFO override reads "Not updating": 79.18 px in bundled IBM Plex Sans
    # Medium at the 10 pt body maximum (Pillow advance, pt*96/72), within the value cell.
    for name in ("MeterPowerValue", "MeterClockValue"):
        assert box[name][2] >= 79.18 * scale, (case, name)  # (x, y, w, h)
        assert box[name][0] + box[name][2] <= content_right + EPS, (case, name)
    # Every meter stays inside the window; every string stays inside the
    # painted panel and clips rather than growing the window.
    for name, (x, y, w, h) in box.items():
        assert x + EPS >= 0 and y + EPS >= 0 and x + w <= EPS + width and y + h <= EPS + height, (name, case)
        if meters[name]["Meter"] == "String":
            assert meters[name]["ClipString"] == "1", name
            assert x + EPS >= inset and x + w <= EPS + width - inset, (name, case)
            assert y + EPS >= inset and y + h <= EPS + panel_bottom, (name, case)
    top = lambda name: box[name][1]
    bottom = lambda name: box[name][1] + box[name][3]
    left = lambda name: box[name][0]
    right = lambda name: box[name][0] + box[name][2]
    # Title row: icon, title, hover gear and the busy-time headline share the
    # suite's title-row center; the title ends before the headline column.
    title, headline, icon, gear = (meters[name] for name in ("MeterTitle", "MeterActivityValue", "MeterIcon", "MeterOptions"))
    assert title["StringAlign"] == "LeftCenter" and headline["StringAlign"] == "RightCenter"
    assert right("MeterTitle") <= EPS + left("MeterActivityValue"), case
    assert math.isclose(right("MeterActivityValue"), content_right) and math.isclose(n(headline["W"]), 60 * scale)
    row_center = n("#TitleRowCenterY#")
    for center in (n(title["Y"]), n(headline["Y"]), n(icon["Y"]) + n(icon["H"]) / 2, n(gear["Y"]) + n(gear["H"]) / 2):
        assert math.isclose(center, row_center), (case, center)
    assert math.isclose(n(icon["W"]), 14 * scale * title_size / 10)
    assert math.isclose(n(icon["H"]), n(icon["W"]))
    assert math.isclose(n(icon["X"]), content_x)
    assert math.isclose(n(title["X"]), n(icon["X"]) + n(icon["W"]) + n("#TitleIconGap#"))
    assert math.isclose(right("MeterOptions"), content_right) and math.isclose(n(gear["W"]), 18 * scale)
    for x, y, w, h in icon_bounds(icon, n):
        assert min(x, y) + EPS >= 0 and x + w <= EPS + n(icon["W"]) and y + h <= EPS + n(icon["H"]), ("MeterIcon", case)
    for x, y, w, h in icon_bounds(gear, n, "#Scale#"):
        assert min(x, y) + EPS >= 0 and x + w <= EPS + n(gear["W"]) and y + h <= EPS + n(gear["H"]), ("MeterOptions", case)
    # Adapter inset: the shaded panel holds the name above the accent details,
    # both inside its 4 px side padding, and starts below the title row.
    panel = meters["MeterAdapterPanel"]
    for name in ("MeterTitle", "MeterActivityValue", "MeterIcon", "MeterOptions"):
        assert bottom(name) <= EPS + top("MeterAdapterPanel"), (name, case)
    assert math.isclose(left("MeterAdapterPanel"), content_x) and math.isclose(n(panel["W"]), content_w)
    assert math.isclose(n(panel["H"]), 34 * scale)
    px, py, pw, ph = rectangle_bounds(panel["Shape"], n)
    assert math.isclose(px, 0) and math.isclose(py, 0) and math.isclose(pw, n(panel["W"])) and math.isclose(ph, n(panel["H"])), case
    for name in ("MeterAdapterName", "MeterAdapterDetails"):
        row = meters[name]
        assert row.get("StringAlign", "Left") == "Left"
        assert math.isclose(left(name), content_x + 4 * scale) and math.isclose(n(row["W"]), content_w - 8 * scale), name
        assert math.isclose(n(row["H"]), 16 * scale), name
        assert top(name) + EPS >= top("MeterAdapterPanel") and bottom(name) <= EPS + bottom("MeterAdapterPanel"), (name, case)
    assert bottom("MeterAdapterName") <= EPS + top("MeterAdapterDetails"), case
    # Temp/Power/Clock: 16 px rows under the inset, label left and the accent
    # value flush right on the same edge as the VRAM and Shared readings.
    assert top("MeterTemperatureLabel") + EPS >= bottom("MeterAdapterPanel"), case
    for index, field in enumerate(SCALAR_FIELDS):
        label, value = f"Meter{field}Label", f"Meter{field}Value"
        assert meters[label].get("StringAlign", "Left") == "Left" and meters[value]["StringAlign"] == "Right", field
        assert math.isclose(top(label), top(value)) and math.isclose(box[label][3], box[value][3]), field
        assert math.isclose(box[label][3], 16 * scale), field
        assert math.isclose(top(label), top("MeterTemperatureLabel") + 16 * scale * index), (field, case)
        assert math.isclose(left(label), content_x), field
        assert right(label) + 4 * scale <= EPS + left(value), (field, case)
        assert math.isclose(right(value), content_right), (field, case)
    assert bottom("MeterClockLabel") <= EPS + top("MeterGPUEngineHeader"), case
    # Engine table: header text, gauge glyph over the percentage column, the
    # header rule, four 16 px label/bar/value rows and a closing divider.
    header, header_icon, header_rule = (meters[name] for name in ("MeterGPUEngineHeader", "MeterGPUEngineUsageHeader", "MeterGPUEngineHeaderRule"))
    value_w = n("#GPUEngineValueWidth#")
    value_center = content_right - value_w / 2
    assert math.isclose(box["MeterGPUEngineHeader"][3], 16 * scale)
    assert right("MeterGPUEngineHeader") <= EPS + left("MeterGPUEngineUsageHeader"), case
    assert math.isclose(n(header_icon["W"]), 14 * scale) and math.isclose(n(header_icon["H"]), 14 * scale)
    assert math.isclose(left("MeterGPUEngineUsageHeader") + n(header_icon["W"]) / 2, value_center), case
    assert top("MeterGPUEngineUsageHeader") + EPS >= top("MeterGPUEngineHeader"), case
    assert bottom("MeterGPUEngineUsageHeader") <= EPS + top("MeterGPUEngineHeaderRule"), case
    for x, y, w, h in icon_bounds(header_icon, n, "#Scale#"):
        assert min(x, y) + EPS >= 0 and x + w <= EPS + n(header_icon["W"]) and y + h <= EPS + n(header_icon["H"]), ("MeterGPUEngineUsageHeader", case)
    assert bottom("MeterGPUEngineHeader") <= EPS + top("MeterGPUEngineHeaderRule"), case
    for name in ("MeterGPUEngineHeaderRule", "MeterGPUProcessHeaderRule") if TABLE else ("MeterGPUEngineHeaderRule",):
        rule = meters[name]
        assert math.isclose(left(name), content_x) and math.isclose(n(rule["W"]), content_w), name
        assert math.isclose(n(rule["H"]), n("#TableHeaderBorderThickness#*#Scale#")), name
        lx, ly, lw, lh = line_bounds(rule["Shape"], n)
        assert math.isclose(lx, 0) and math.isclose(ly, 0) and math.isclose(lw, n(rule["W"])) and math.isclose(lh, n(rule["H"])), name
    bar_x, bar_w = n("#GPUEngineBarX#"), n("#GPUEngineBarWidth#")
    previous_bottom = bottom("MeterGPUEngineHeaderRule")
    for index, field in enumerate(ENGINE_FIELDS):
        label, bar, value = (f"Meter{field}{part}" for part in ("Label", "Bar", "Value"))
        assert meters[label].get("StringAlign", "Left") == "Left" and meters[value]["StringAlign"] == "Center", field
        assert math.isclose(top(label), top(value)) and math.isclose(box[label][3], 16 * scale) and math.isclose(box[value][3], 16 * scale), field
        assert top(label) + EPS >= previous_bottom, (field, case)
        assert math.isclose(top(label), top("MeterGPULoadLabel") + 16 * scale * index), (field, case)
        assert math.isclose(left(label), content_x) and math.isclose(box[label][2], n("#GPUEngineLabelWidth#")), field
        assert math.isclose(box[value][2], value_w) and math.isclose(left(value) + value_w / 2, value_center), field
        assert math.isclose(right(value), content_right), field
        validate_bar_geometry(bar, meters[bar], n, scale, bar_thickness, bar_x, bar_w)
        assert right(label) <= EPS + left(bar), (field, case)
        assert right(bar) + 4 * scale <= EPS + left(value), (field, case)
        # The bar is centered in its row and never touches the neighbors.
        assert math.isclose(top(bar) + box[bar][3] / 2, top(label) + 8 * scale), (field, case)
        assert top(bar) + EPS >= top(label) and bottom(bar) <= EPS + bottom(label), (field, case)
        previous_bottom = bottom(label)
    assert previous_bottom <= EPS + top("MeterGPUEngineFooterRule"), case
    assert math.isclose(left("MeterGPUEngineFooterRule"), content_x) and math.isclose(box["MeterGPUEngineFooterRule"][2], content_w)
    # Memory rows: VRAM label/value, a full-width bar below that row and
    # above the Shared row at every bar thickness, Shared label/value.
    assert bottom("MeterGPUEngineFooterRule") <= EPS + top("MeterGPUVRAMLabel"), case
    for label, value in (("MeterGPUVRAMLabel", "MeterGPUVRAMValue"), ("MeterGPUSharedLabel", "MeterGPUSharedValue")):
        assert meters[label].get("StringAlign", "Left") == "Left" and meters[value]["StringAlign"] == "Right", label
        assert math.isclose(top(label), top(value)) and math.isclose(box[label][3], box[value][3]), label
        assert math.isclose(box[label][3], 18 * scale), label
        assert math.isclose(left(label), content_x), label
        assert right(label) + 4 * scale <= EPS + left(value), (label, case)
        assert math.isclose(right(value), content_right), (value, case)
    for field in SCALAR_FIELDS:
        assert math.isclose(right(f"Meter{field}Value"), right("MeterGPUVRAMValue")), field
    validate_bar("MeterGPUVRAMBar", meters["MeterGPUVRAMBar"], n, scale, bar_thickness)
    assert math.isclose(top("MeterGPUVRAMBar"), inset + (218 + max(20, 23 - bar_thickness / 2)) * scale), case
    assert top("MeterGPUVRAMBar") + EPS >= bottom("MeterGPUVRAMLabel"), case
    assert bottom("MeterGPUVRAMBar") <= EPS + top("MeterGPUSharedLabel"), case
    assert math.isclose(top("MeterGPUSharedLabel"), inset + (250 + extra) * scale), case
    # Process table: heading with both column glyphs, header rule, five
    # 16 px rows of name / VRAM / GPU % and a closing divider; the three
    # columns never overlap and the glyphs center on their columns. Without
    # the VRAM column the name column runs up to the GPU % column's gutter.
    if TABLE:
        check_process_table(case, n, box, meters, scale, extra, content_x, content_w, content_right, inset)
    # History: header and fixed range on one row, the graph at least 20 px
    # below them with its startup cover and frame on the same canvas, and
    # 8 px of panel left under the graph at the natural height. Without the
    # process table the block takes the table's place below the Shared row.
    if TABLE:
        assert bottom("MeterGPUProcessFooterRule") <= EPS + top("MeterGPUHistoryLabel"), case
    else:
        assert bottom("MeterGPUSharedLabel") + 8 * scale <= EPS + top("MeterGPUHistoryLabel"), case
    label, span = meters["MeterGPUHistoryLabel"], meters["MeterGPUHistoryRange"]
    assert label.get("StringAlign", "Left") == "Left" and span["StringAlign"] == "Right"
    assert math.isclose(top("MeterGPUHistoryLabel"), top("MeterGPUHistoryRange")), case
    assert math.isclose(box["MeterGPUHistoryLabel"][3], 18 * scale) and math.isclose(box["MeterGPUHistoryRange"][3], 18 * scale)
    assert math.isclose(left("MeterGPUHistoryLabel"), content_x) and math.isclose(right("MeterGPUHistoryRange"), content_right)
    assert right("MeterGPUHistoryLabel") <= EPS + left("MeterGPUHistoryRange"), case
    assert top("MeterGPUUtilizationGraph") - top("MeterGPUHistoryLabel") + EPS >= 20 * scale, case
    assert top("MeterGPUUtilizationGraph") + EPS >= bottom("MeterGPUHistoryLabel"), case
    assert math.isclose(left("MeterGPUUtilizationGraph"), content_x) and math.isclose(box["MeterGPUUtilizationGraph"][2], content_w)
    assert math.isclose(box["MeterGPUUtilizationGraph"][3], n("#GraphHeight#*#Scale#"))
    assert math.isclose(top("MeterGPUHistoryLabel"), inset + (276 + block + extra) * scale), case
    assert math.isclose(top("MeterGPUUtilizationGraph"), inset + (296 + block + extra) * scale), case
    for name in ("MeterGPUGraphUncollected", "MeterGPUGraphFrame"):
        assert all(math.isclose(a, b) for a, b in zip(box[name], box["MeterGPUUtilizationGraph"])), (name, case)
    fx, fy, fw, fh = rectangle_bounds(meters["MeterGPUGraphFrame"]["Shape"], n)
    assert math.isclose(fx, 0) and math.isclose(fy, 0) and math.isclose(fw, content_w) and math.isclose(fh, n("#GraphHeight#*#Scale#")), case
    # PanelHeightPx = Round(natural*Scale) can land up to half a pixel either
    # side of the exact 8 px margin at non-grid scales (0.76: 351 versus
    # 351.12); the graph itself must still end inside the panel.
    assert bottom("MeterGPUUtilizationGraph") <= EPS + panel_bottom, case
    assert bottom("MeterGPUUtilizationGraph") + 8 * scale <= EPS + panel_bottom + 0.5, case
    # Whole-column order: every block starts at or below the previous one.
    order = ("MeterAdapterPanel", "MeterTemperatureLabel", "MeterPowerLabel", "MeterClockLabel",
             "MeterGPUEngineHeader", "MeterGPUEngineHeaderRule", *(f"Meter{field}Label" for field in ENGINE_FIELDS),
             "MeterGPUEngineFooterRule", "MeterGPUVRAMLabel", "MeterGPUVRAMBar", "MeterGPUSharedLabel",
             *(("MeterGPUProcessHeading", "MeterGPUProcessHeaderRule", *(f"MeterGPUProcessName{i}" for i in range(1, 6)),
                "MeterGPUProcessFooterRule") if TABLE else ()),
             "MeterGPUHistoryLabel", "MeterGPUUtilizationGraph")
    for before, after in zip(order, order[1:]):
        assert bottom(before) <= EPS + top(after) + 1e-9, (before, after, case)
    return f"width={column_width} scale={scale:g} title={title_size} bars={bar_thickness} saved_height={saved:g}: {width:g} x {height:g}, Engine table, memory rows, process columns and History inside bounds"


rows = []
cases = [(column_width, scale, columns, title_size, bar_thickness, None) for column_width in (180, 200, 220, 240, 280, 320)
         for scale in (0.75, 1, 1.25, 1.5, 2) for columns in (1, 2) for title_size in (6, 10, 12)
         for bar_thickness in (1, 6, 12)]
# Saved heights: below natural (natural wins), the legacy 650 Fit value
# (natural) and a larger custom minimum (honored).
cases += [(column_width, scale, columns, 12, bar_thickness, saved_height)
          for column_width in (180, 220) for scale in (.75, 1, 2)
          for columns in (1, 2) for bar_thickness in (6, 12) for saved_height in (330, 462, 650, 750)]
for column_width, scale, columns, title_size, bar_thickness, saved_height in cases:
    summary = check_case(column_width, scale, columns, title_size, bar_thickness, saved_height)
    if column_width in (180, 220) and scale in (.75, 1, 2) and columns == 1 and title_size == 12 and bar_thickness in (6, 12):
        rows.append(summary)
if "--all-scales" in sys.argv[1:]:
    # Every Global Settings Scale step (0.01) at bars 6 and 12 with 4 px rules:
    # DataBarThicknessPx rounds to whole pixels, so a bar can be up to half a
    # pixel taller than thickness*Scale between the grid scales above. Engine
    # bars are centered in 16 px rows and the VRAM bar keeps 6 px before the
    # Shared row, so every step must still keep each bar inside its own row.
    sweep = [(column_width, step / 100, 1, 12, bar_thickness, None)
             for column_width in (180, 320) for step in range(75, 201) for bar_thickness in (6, 12)]
    for column_width, scale, columns, title_size, bar_thickness, saved_height in sweep:
        check_case(column_width, scale, columns, title_size, bar_thickness, saved_height,
                   {"DividerThickness": "4", "TableHeaderBorderThickness": "4"})
    cases += sweep
    rows.append(f"--all-scales: {len(sweep)} additional 0.01-step cases from 0.75 to 2.00 at bars 6/12 with 4 px rules")

# Check the actual sensor-divider formula at default and slower/faster intervals.
for metrics, sensors in ((1000, 2000), (1500, 2000), (500, 2000), (3000, 2000)):
    variables = dict(sections["Variables"], MetricsInterval=str(metrics), SensorInterval=str(sensors))
    # Freshness probes for an HWiNFO override read the first eight exported raw values.
    probes = [f"MeasureGPUExportProbe{index}" for index in range(8)]
    for index, name in enumerate(probes):
        assert sections[name]["Measure"] == "Registry" and sections[name]["RegValue"] == f"ValueRaw{index}", name
        assert sections[name]["RegHKey"] == "#GPURegHKey#" and sections[name]["RegKey"] == "#GPURegKey#", name
    assert "MeasureGPUExportProbe8" not in sections
    for name in ["MeasureGPURegistryNames"] + [f"MeasureGPU{field}{suffix}" for field in ("Power", "Clock") for suffix in ("Sensor", "Label", "Value", "ValueRaw")] + probes:
        assert sections[name]["Disabled"] == "1", name  # Canonical source enabling is tested in native Lua.
        divider = number(sections[name]["UpdateDivider"], variables)
        assert divider * metrics + EPS >= sensors, name
        assert divider + EPS >= 1 and divider.is_integer(), name

variant = f"GPUShowProcesses={SHOW_PROCESSES} GPUShowProcessMemory={SHOW_MEMORY}"
print(f"PASS ({variant}): {len(loaded)} includes/configs; {len(meters)} explicit meters; {len(usage_monitor)} UsageMonitor measures; {len(cases)} geometry cases; 4 sensor cadences.")
print("\n".join(rows))
for run in VARIANT_RUNS:
    stdout, stderr = run.communicate()
    assert run.returncode == 0, stdout + stderr
    print(stdout.splitlines()[0])
print("This offline check does not execute Lua or verify rendering, HWiNFO integration or performance.")
