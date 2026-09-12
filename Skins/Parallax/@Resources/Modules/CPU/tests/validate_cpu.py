"""Read-only CPU source/geometry checks; optional native Win32 counter probe.

Run with Python 3: python validate_cpu.py [--probe-native]
This does not load Rainmeter, execute Lua, or alter the user's configuration.
"""
import argparse
import ast
import ctypes as C
import math
import os
from pathlib import Path
import re
import time
from itertools import product

ROOT = Path(__file__).resolve().parents[4]
ENTRY = ROOT / "CPU/CPU.ini"
sections, variables, visited = {}, {"@": str(ROOT / "@Resources") + "/"}, []


def expand(text):
    for _ in range(30):
        updated = re.sub(r"#([^#]+)#", lambda m: variables[m[1]], text)
        if updated == text:
            return text
        text = updated
    raise AssertionError("Cyclic variable expansion")


def read_ini(path):
    assert path not in visited, f"Repeated include: {path}"
    visited.append(path)
    section = None
    seen = set()
    keys = set()
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            assert section not in seen, f"Duplicate section {section} in {path}"
            seen.add(section)
            sections.setdefault(section, {})
            keys = set()
        else:
            key, value = line.split("=", 1)
            assert section is not None and key not in keys, (path, section, key)
            keys.add(key)
            if key.lower().startswith("@include"):
                read_ini(Path(expand(value).replace("\\", "/")))
            else:
                sections[section][key] = value
                if section == "Variables":
                    variables[key] = value


def number(text):
    expr = ast.parse(expand(text), mode="eval")
    permitted = (ast.Expression, ast.BinOp, ast.UnaryOp, ast.Constant, ast.Add,
                 ast.Sub, ast.Mult, ast.Div, ast.USub, ast.UAdd, ast.Call,
                 ast.Name, ast.Load)
    for node in ast.walk(expr):
        assert isinstance(node, permitted), ast.dump(node)
        if isinstance(node, ast.Name):
            assert node.id == "Round"
    return eval(compile(expr, "<rainmeter-formula>", "eval"),
                {"__builtins__": {}, "Round": lambda x: math.floor(x + 0.5)})


def effective(name):
    local = sections[name]
    result = {}
    for style in local.get("MeterStyle", "").split("|"):
        if style.strip():
            result.update(effective(style.strip()))
    return result | local


def validate():
    read_ini(ENTRY)
    expected = ["Defaults.inc", "Settings.inc", "CPU.inc", "Geometry.inc", "Styles.inc"]
    assert [p.name for p in visited[1:6]] == expected
    assert 'Parallax' in sections["Rainmeter"]["Group"].split('|')
    assert 'ParallaxCPU' in sections["Rainmeter"]["Group"].split('|')
    assert sections["Rainmeter"]["Update"] == "#MetricsInterval#"
    assert number(variables["MetricsInterval"]) == 1000
    assert all("Meter" not in values for name, values in sections.items() if "Style" in name)
    for name, values in sections.items():
        if name.startswith("Meter"):
            assert "Meter" in values, name
        for key, value in values.items():
            if key == "MeterStyle" or key.startswith("MeasureName"):
                assert all(ref.strip() in sections for ref in value.split("|")), (name, key)
    measures = [name for name, values in sections.items() if "Measure" in values]
    assert len(measures) == 93
    assert measures[-1] == "MeasureCPUController", "Script must follow telemetry"
    for index in range(1, 65):
        measure = sections[f"MeasureCPU{index}"]
        assert measure["Measure"] == "CPU"
        assert measure["Processor"] == "0" and measure["Disabled"] == "1"
        assert measure["MinValue"] == "0" and measure["MaxValue"] == "100"
        assert sections[f"MeterCoreBar{index}"]["MeasureName"] == f"MeasureCPU{index}"
        assert effective(f"MeterCoreBar{index}")["Hidden"] == "1"
    dimensions = []
    assert number(variables['ColumnWidth']) == 200
    assert number(variables['PanelPadding']) == 6
    assert number(variables['PanelHeight']) == 80
    assert number(variables['CPUAutoRows']) == 1
    for column_width in (180, 200, 240, 280, 320):
        for scale, columns in product((0.75, 1, 1.25, 1.5, 2), (1, 2)):
            variables.update(Scale=str(scale), Columns=str(columns), ColumnWidth=str(column_width))
            width, height = number("#WindowWidth#"), number("#WindowHeight#")
            assert width == columns * number("#Pitch#")
            assert number("#PanelWidth#") + number("#Gap#") == width
            assert number("#Inset#") * 2 == number("#Gap#")
            # Runtime table Y positions vary, but its source column widths do not.
            label, bar = effective('MeterCoreLabel1'), effective('MeterCoreBar1')
            assert number(label['X']) + number(label['W']) <= number(bar['X'])
            assert number(bar['W']) > 0
            assert number(bar['X']) + number(bar['W']) <= number('#ContentX#') + number('#CPUCoreColumnWidth#')
            assert number('#CPUCoreColumnWidth#') + 116 * scale == number('#ContentWidth#')
            rectangles = {}
            for name, values in sections.items():
                if "Meter" not in values:
                    continue
                meter = effective(name)
                if meter.get('Hidden', '0') == '1':
                    continue
                # Shapes without explicit W/H are verified from their geometry below.
                if "W" not in meter or "H" not in meter:
                    continue
                x, y = number(meter.get("X", "0")), number(meter.get("Y", "0"))
                w, h = number(meter["W"]), number(meter["H"])
                padding = [number(part) for part in meter.get('Padding', '0,0,0,0').split(',')]
                w += padding[0] + padding[2]
                h += padding[1] + padding[3]
                if meter.get("StringAlign", "").startswith("Right"):
                    x -= w
                elif meter.get("StringAlign", "").startswith("Center"):
                    x -= w / 2
                assert w > 0 and h > 0, name
                assert x >= 0 and y >= 0 and x+w <= width+0.01 and y+h <= height+0.01, (scale, columns, name)
                rectangles[name] = (x, y, x+w, y+h)
            def disjoint(first, second):
                if first not in rectangles or second not in rectangles:
                    return  # Deferred sections are laid out and checked natively.
                a, b = rectangles[first], rectangles[second]
                assert a[2] <= b[0]+0.01 or b[2] <= a[0]+0.01 or a[3] <= b[1]+0.01 or b[3] <= a[1]+0.01, (column_width, scale, columns, first, second)
            for first, second in [('MeterIcon', 'MeterTitle'), ('MeterTitle', 'MeterTotal'),
                                  ('MeterTitle', 'MeterProcessorPanel'),
                                  ('MeterProcessorName', 'MeterProcessorDetails'),
                                  ('MeterPrevious', 'MeterPage'),
                                  ('MeterPage', 'MeterNext'), ('MeterHistoryLabel', 'MeterHistoryTrack'),
                                  ('MeterHistoryTrack', 'MeterSensors')]:
                disjoint(first, second)
            for index in range(1, 65):
                disjoint(f'MeterCoreLabel{index}', f'MeterCoreValue{index}')
                disjoint(f'MeterCoreValue{index}', f'MeterCoreBar{index}')
                # Slots overlap safely while hidden. Lua places active slots and
                # expands the panel; the isolated native probe checks that layout.
            disjoint('MeterCoreBar8', 'MeterPrevious')
            # Graph frame/grid and bounded icon remain inside their explicit rectangles.
            for name in ('MeterHistoryTrack', 'MeterIcon', 'MeterProcessorPanel'):
                meter = effective(name)
                local_w, local_h = number(meter['W']), number(meter['H'])
                for key, shape in meter.items():
                    if not re.fullmatch(r'Shape\d*', key):
                        continue
                    geometry, *modifiers = shape.split('|')
                    kind, arguments = geometry.strip().split(' ', 1)
                    values = [number(value) for value in arguments.split(',')]
                    stroke = next((number(mod.strip()[12:]) for mod in modifiers if mod.strip().startswith('StrokeWidth ')), 1)
                    if kind == 'Rectangle':
                        x, y, w, h = values[:4]
                        assert x-stroke/2 >= -0.01 and y-stroke/2 >= -0.01
                        assert x+w+stroke/2 <= local_w+0.01 and y+h+stroke/2 <= local_h+0.01
                    elif kind == 'Line':
                        x, y, x2, y2 = values
                        assert 0 <= min(x, x2) <= max(x, x2) <= local_w
                        assert stroke/2 <= min(y, y2) <= max(y, y2) <= local_h-stroke/2
            # All shape surfaces/paths lie within content or panel extents.
            assert number("#Inset#") + number("#PanelHeightPx#") < height
            assert number("#ContentX#") + number("#ContentWidth#") < width
            dimensions.append((column_width, scale, columns, width, height))
    script = (ROOT / "@Resources/Modules/CPU/CPU.lua").read_text()
    assert not any(token in script for token in ("os.execute", "io.popen", "io.open"))
    print(f"PASS: {len(visited)} files, {len(measures)} measures, include/reference/startup checks.")
    print(f'PASS startup geometry: {len(dimensions)} combinations, widths180/200/240/280/320, Columns1/2, scales0.75/1/1.25/1.5/2; header bounds, graph/frame/grid and chip extents. Deferred section positions require native checks.')
    print('Startup200/1x: ' + '; '.join(f'{cols}col={w:g}x{h:g}' for cw,s,cols,w,h in dimensions if cw==200 and s==1))
    print("Lua execution and Rainmeter rendering are NOT covered by these checks.")


def probe_native():
    assert os.name == "nt", "Native probe requires Windows"
    from ctypes import wintypes as W
    class SystemInfo(C.Structure):
        _fields_ = [("architecture", W.WORD), ("reserved", W.WORD),
                    ("pageSize", W.DWORD), ("minimum", C.c_void_p),
                    ("maximum", C.c_void_p), ("mask", C.c_size_t),
                    ("count", W.DWORD), ("type", W.DWORD),
                    ("granularity", W.DWORD), ("level", W.WORD), ("revision", W.WORD)]
    class Perf(C.Structure):
        _fields_ = [("idle", C.c_longlong), ("kernel", C.c_longlong),
                    ("user", C.c_longlong), ("reserved", C.c_longlong * 2),
                    ("reserved2", W.ULONG)]
    kernel, native = C.WinDLL("kernel32", use_last_error=True), C.WinDLL("ntdll")
    kernel.GetActiveProcessorGroupCount.restype = W.WORD
    info = SystemInfo()
    kernel.GetSystemInfo(C.byref(info))
    assert 1 <= info.count <= 64 and int(os.environ["NUMBER_OF_PROCESSORS"]) == info.count
    assert kernel.GetActiveProcessorGroupCount() == 1, "Multi-group scope requires separate validation"
    query = native.NtQuerySystemInformation
    query.argtypes = [C.c_int, C.c_void_p, W.ULONG, C.POINTER(W.ULONG)]
    query.restype = C.c_long
    def sample():
        buffer = (Perf * info.count)()
        size = W.ULONG()
        status = query(8, buffer, C.sizeof(buffer), C.byref(size))
        assert status == 0 and size.value == C.sizeof(buffer)
        cores = [(item.idle, item.kernel + item.user) for item in buffer]
        idle, ktime, utime = W.FILETIME(), W.FILETIME(), W.FILETIME()
        assert kernel.GetSystemTimes(C.byref(idle), C.byref(ktime), C.byref(utime))
        ticks = lambda value: value.dwLowDateTime + (value.dwHighDateTime << 32)
        return cores + [(ticks(idle), ticks(ktime) + ticks(utime))]
    before = sample()
    time.sleep(1.1)
    after = sample()
    for old, new in zip(before, after):
        idle_delta, total_delta = new[0]-old[0], new[1]-old[1]
        assert total_delta > 0 and 0 <= idle_delta <= total_delta
    print("PASS native probe: count metadata agrees with Win32; one group; valid total/per-LP interval deltas.")
    print("This probes Windows APIs, not the unloaded Rainmeter skin; no measurements are saved.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe-native", action="store_true")
    args = parser.parse_args()
    validate()
    if args.probe_native:
        probe_native()
