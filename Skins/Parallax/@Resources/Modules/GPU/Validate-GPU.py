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


load(ROOT / "GPU" / "GPU.ini")
assert set(sections["Rainmeter"]["Group"].split("|")) == {"Parallax", "ParallaxGPU"}
assert sections["Rainmeter"]["DynamicWindowSize"] == "0"
assert sections["Variables"]["GPUEnableSensors"] == "0"
for field in ("Temperature", "Power", "Clock"):
    assert sections["Variables"][f"GPU{field}Index"] == "-1"
    assert sections["Variables"][f"GPU{field}Sensor"] == ""
    assert sections["Variables"][f"GPU{field}Label"] == ""
counter = sections["MeasureGPUActivity"]
assert {key: counter[key] for key in ("Alias", "Index", "PIDToName", "Rollup", "Percent", "RawValue")} == {
    "Alias": "GPU", "Index": "1", "PIDToName": "0", "Rollup": "0", "Percent": "0", "RawValue": "0"}
meters = {name: effective(name) for name, options in sections.items() if "Meter" in options}
assert all("Meter" in options for name, options in sections.items() if name.startswith("Meter"))
rows = []
cases = [(column_width, scale, columns) for column_width in (180, 200, 240, 280, 320)
         for scale in (0.75, 1, 1.25, 1.5, 2) for columns in (1, 2)]
for column_width, scale, columns in cases:
        variables = dict(sections["Variables"], ColumnWidth=str(column_width), Scale=str(scale), Columns=str(columns))
        n = lambda value: number(value, variables)
        width, height = n("#WindowWidth#"), n("#WindowHeight#")
        inset = n("#Inset#")
        assert width == columns * n("#Pitch#")
        assert n("#PanelWidth#") + 2 * inset == width
        assert n("#PanelHeightPx#") + 2 * inset == height
        for name, options in meters.items():
            x, y = n(options.get("X", "0")), n(options.get("Y", "0"))
            if options["Meter"] == "Shape":
                # Static native primitives; icon has explicit size and every
                # stroke remains inside that box. No simulated telemetry.
                if name == "MeterPanel":
                    w, h = n("#PanelWidth#"), n("#PanelHeightPx#")
                elif name in ("MeterIcon", "MeterOptions", "MeterAdapterPanel"):
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
            if options.get("StringAlign") == "Right":
                x -= w
            assert x >= 0 and y >= 0 and x + w <= width and y + h <= height, (name, column_width, scale, columns)
            if options["Meter"] == "String":
                assert options["ClipString"] == "1", name
                assert x >= inset and x + w <= width - inset, name
        # Label/value rows and header fields must not overlap at narrow widths.
        for field in ("Temperature", "Power", "Clock", "VRAM", "Direct3D", "Shader", "RayTracing", "Driver"):
            label, value = meters[f"Meter{field}Label"], meters[f"Meter{field}Value"]
            assert n(label["Y"]) == n(value["Y"])
            assert n(label["X"]) + n(label["W"]) <= n(value["X"]) - n(value["W"])
        title, value = meters["MeterTitle"], meters["MeterActivityValue"]
        assert n(title["X"]) + n(title["W"]) <= n(value["X"]) - n(value["W"])
        # The model and every capability row fit inside the bordered inset,
        # in reading order, without encroaching on live activity below it.
        panel = meters["MeterAdapterPanel"]
        last_bottom = n(panel["Y"])
        for name in ("AdapterName", "VRAMLabel", "Direct3DLabel", "ShaderLabel", "RayTracingLabel", "DriverLabel"):
            row = meters["Meter" + name]
            assert n(row["Y"]) >= last_bottom
            last_bottom = n(row["Y"]) + n(row["H"])
            assert last_bottom <= n(panel["Y"]) + n(panel["H"])
        assert n(panel["Y"]) + n(panel["H"]) <= n(meters["MeterActivityLabel"]["Y"])
        if column_width in (180, 200):
            rows.append(f"width={column_width} scale={scale:g} columns={columns}: {width:g} x {height:g}, meters inside bounds")

# Check the actual sensor-divider formula at default and slower/faster intervals.
for metrics, sensors in ((1000, 2000), (1500, 2000), (500, 2000), (3000, 2000)):
    variables = dict(sections["Variables"], MetricsInterval=str(metrics), SensorInterval=str(sensors))
    divider = number(sections["MeasureGPURegistryNames"]["UpdateDivider"], variables)
    assert divider * metrics >= sensors
    assert divider >= 1 and divider.is_integer()

print(f"PASS: {len(loaded)} includes/configs; {len(meters)} explicit meters; {len(cases)} geometry cases; 4 sensor cadences.")
print("\n".join(rows))
print("This offline check does not execute Lua or verify rendering, HWiNFO integration or performance.")
