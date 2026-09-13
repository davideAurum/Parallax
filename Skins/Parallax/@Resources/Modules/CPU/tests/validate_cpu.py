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
import struct
import time
from itertools import product

ROOT = Path(__file__).resolve().parents[4]
ENTRY = ROOT / "CPU/CPU.ini"
CPU_ICON_DIR = ROOT / "@Resources/Modules/CPU/Icons"
sections, variables, visited = {}, {"@": str(ROOT / "@Resources") + "/"}, []

LUCIDE_ICON_PATHS = {
    "cpu": "M12 20v2",
    "zap": "M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z",
    "flame": "M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4",
    "gauge": "M3.34 19a10 10 0 1 1 17.32 0",
}

LUCIDE_CPU_PATHS = (
    "M12 20v2", "M12 2v2", "M17 20v2", "M17 2v2",
    "M2 12h2", "M2 17h2", "M2 7h2", "M20 12h2",
    "M20 17h2", "M20 7h2", "M7 20v2", "M7 2v2",
)


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
            assert node.id in {"Max", "Round"}
    return eval(compile(expr, "<rainmeter-formula>", "eval"),
                {"__builtins__": {}, "Max": max,
                 "Round": lambda x: math.floor(x + 0.5)})


def effective(name):
    local = sections[name]
    result = {}
    for style in local.get("MeterStyle", "").split("|"):
        if style.strip():
            result.update(effective(style.strip()))
    return result | local


def validate_settings_shared_width():
    # CPU Settings shares CPU preferences but keeps the shared two-column width.
    saved_sections, saved_variables, saved_visited = sections.copy(), variables.copy(), visited.copy()
    cases = 0
    try:
        sections.clear()
        variables.clear()
        variables["@"] = str(ROOT / "@Resources") + "/"
        visited.clear()
        read_ini(ROOT / "CPU/Settings/Settings.ini")
        assert number("#Columns#") == 2
        assert number("#PanelHeight#") == 1000
        assert sections["MeasureCPUSettingsDecimalInput"]["StartInFolder"] == "#@#Scripts\\"
        assert 'CommitNumberInput()' in sections["MeasureCPUSettingsDecimalInput"]["FinishAction"]
        assert 'ScanSensors(false)' in sections["Rainmeter"]["OnRefreshAction"]
        fields = {'Decimals':'CPUDecimals', 'VoltageDecimals':'CPUVoltageDecimals',
                  'TemperatureDecimals':'CPUTemperatureDecimals', 'ProcessCount':'CPUProcessCount',
                  'Samples':'CPUHistorySamples', 'UpdateRate':'CPUUpdateInterval', 'SensorRate':'CPUSensorInterval'}
        for name in ('Appearance','Processes','Graph','Rates','Sensors'):
            assert effective('MeterSettings'+name+'Section')['FontColor'] == '#AccentColor#'
            assert sections['MeterSettings'+name+'Rule']['MeterStyle'] == 'StyleRule'
        for name, key in fields.items():
            prefix = 'MeterSettings'+name
            assert 'BeginNumberInput' in effective(prefix+'Input')['LeftMouseUpAction']
            assert effective(prefix+'Value')['FontColor'] == '#TextColor#'
            assert f"AdjustNumber('{key}',-1)" in effective(prefix+'Decrease')['LeftMouseUpAction']
            assert f"AdjustNumber('{key}',1)" in effective(prefix+'Increase')['LeftMouseUpAction']
        for column_width, scale, title_size in product((180,220,320),(.75,1,1.25,1.5,2),(6,10,12)):
            variables.update(ColumnWidth=str(column_width),Scale=str(scale),TitleFontSize=str(title_size))
            assert number('#Columns#') == 2
            assert number('#WindowWidth#') == 2*(math.floor(column_width*scale+.5)+number('#Gap#'))
            title, close = effective('MeterSettingsTitle'),effective('MeterSettingsClose')
            assert number(title['X'])+number(title['W']) <= number(close['X'])-number(close['W'])
            for name in fields:
                prefix='MeterSettings'+name
                label,prev,frame,value,nxt=[effective(prefix+x) for x in ('Label','Decrease','Input','Value','Increase')]
                assert number(label['X'])+number(label['W']) < number(prev['X'])-number(prev['W'])/2
                assert number(prev['X'])+number(prev['W'])/2 < number(frame['X'])
                assert number(frame['X'])+number(frame['W']) < number(nxt['X'])-number(nxt['W'])/2
                assert number(nxt['X'])+number(nxt['W'])/2 <= number('#ContentX#')+number('#ContentWidth#')
                assert abs(number(value['X'])-number(value['W'])/2-number(frame['X'])) < 1e-7
                for hidden in (0,1):
                    variables['CPUSettings'+name+'Hidden']=str(hidden)
                    if hidden:
                        for meter in (label,prev,frame,value,nxt):
                            assert number(meter['Y']) == number(meter['W']) == number(meter['H']) == 0
                    variables['CPUSettings'+name+'Hidden']='0'
            cases += 1
    finally:
        sections.clear()
        sections.update(saved_sections)
        variables.clear()
        variables.update(saved_variables)
        visited.clear()
        visited.extend(saved_visited)
    return cases


def validate_thread_colors():
    """Check the bounded CPU-only hex/swatch editor without loading Rainmeter."""
    saved_sections, saved_variables, saved_visited = sections.copy(), variables.copy(), visited.copy()
    cases = 0
    try:
        sections.clear()
        variables.clear()
        variables["@"] = str(ROOT / "@Resources") + "/"
        visited.clear()
        read_ini(ROOT / "CPU/Colors/Colors.ini")
        assert number("#Columns#") == 2
        assert number("#PanelHeight#") == 100
        assert sections["MeasureCPUThreadColors"]["ScriptFile"] == "#@#Modules\\CPU\\ThreadColors.lua"
        assert sections["MeasureCPUThreadColorInput"]["Plugin"] == "RunCommand"
        assert 'CommitInput()' in sections["MeasureCPUThreadColorInput"]["FinishAction"]
        title, close = effective("MeterThreadColorsTitle"), effective("MeterThreadColorsClose")
        assert title["StringAlign"] == "LeftCenter" and close["StringAlign"] == "RightCenter"
        assert effective("MeterThreadColorsRule")["MeterStyle"] == "StyleTableHeaderRule"
        for index in range(1, 65):
            label = effective(f"MeterThreadColorLabel{index}")
            value = effective(f"MeterThreadColorValue{index}")
            swatch = effective(f"MeterThreadColorSwatch{index}")
            expected_action = f'[!CommandMeasure MeasureCPUThreadColors "BeginEdit({index})"]'
            assert label["Hidden"] == value["Hidden"] == swatch["Hidden"] == "1"
            assert label["LeftMouseUpAction"] == value["LeftMouseUpAction"] == swatch["LeftMouseUpAction"] == expected_action
            assert f"CPUThreadColor{index}" in label["Group"].split("|")
            assert value["FontColor"] == "#TextColor#" and value["SolidColor"] == "#GraphBackgroundColor#"
            assert value["StringAlign"] == "Left"
            assert "Fill Color #CPUColor#" in swatch["Shape"]
            cases += 1
        for column_width, scale in product((180, 220, 320), (0.75, 1, 2)):
            variables.update(ColumnWidth=str(column_width), Scale=str(scale))
            assert number(title["Y"]) == number("#TitleRowCenterY#")
            assert number(close["Y"]) + number(close["H"]) / 2 == number("#TitleRowCenterY#")
            assert number("((#ContentWidth#-4*#Scale#)/2)-96*#Scale#") > 0
            cases += 1
    finally:
        sections.clear()
        sections.update(saved_sections)
        variables.clear()
        variables.update(saved_variables)
        visited.clear()
        visited.extend(saved_visited)
    return cases


def validate_title_rows():
    """Check CPU title/icon geometry at the supported typography extremes."""
    saved_variables = variables.copy()
    cases = 0
    try:
        title = effective("MeterTitle")
        icon = effective("MeterIcon")
        total = effective("MeterTotal")
        options = effective("MeterOptions")
        assert sections["MeterTitle"]["MeterStyle"] == "StyleTitle|StyleTitleRow"
        assert sections["MeterTotal"]["MeterStyle"] == "StyleTitle|StyleTitleRow"
        assert icon["Meter"] == "Image"
        assert icon["ImageName"] == "#@#Modules\\CPU\\Icons\\cpu.png"
        assert icon["Greyscale"] == "1" and icon["ImageTint"] == "#CPUColor#,255"
        assert title["StringAlign"] == "LeftCenter"
        assert total["StringAlign"] == "RightCenter"
        assert not any(re.fullmatch(r"Shape\\d*", key) for key in icon)
        for column_width, scale, title_size in product((180, 220), (0.75, 1, 2), (6, 10, 12)):
            variables.update(ColumnWidth=str(column_width), Scale=str(scale), TitleFontSize=str(title_size))
            row_center = number("#TitleRowCenterY#")
            assert number(icon["Y"]) + number(icon["H"]) / 2 == row_center
            assert number(icon["W"]) == number("#TitleIconSize#")
            assert number(icon["H"]) == number("#TitleIconSize#")
            assert number(title["Y"]) == row_center
            assert number(title["H"]) == number("#TitleRowHeight#")
            assert number(title["X"]) == number(icon["X"]) + number(icon["W"]) + number("#TitleIconGap#")
            assert number(title["X"]) + number(title["W"]) == number("#ContentX#") + number("#ContentWidth#") - 64 * scale
            assert number(total["Y"]) == row_center
            assert number(total["H"]) == number("#TitleRowHeight#")
            assert number(options["Y"]) + number(options["H"]) / 2 == row_center
            cases += 1
    finally:
        variables.clear()
        variables.update(saved_variables)
    return cases


def validate():
    read_ini(ENTRY)
    expected = ["Defaults.inc", "Settings.inc", "CPU.inc", "Geometry.inc", "Styles.inc"]
    assert [p.name for p in visited[1:6]] == expected
    assert 'Parallax' in sections["Rainmeter"]["Group"].split('|')
    assert 'ParallaxCPU' in sections["Rainmeter"]["Group"].split('|')
    assert sections["Rainmeter"]["Update"] == "#CPUUpdateInterval#"
    assert 'MeasureCPUInfo "Run"' in sections["Rainmeter"]["OnRefreshAction"]
    assert 'MeasureCPUSensors "Reconnect()"' in sections["Rainmeter"]["OnRefreshAction"]
    assert number(variables["CPUUpdateInterval"]) == 1000
    assert number(variables["CPUSensorInterval"]) == 2000
    sensor_sources = [ROOT / "@Resources/Modules/CPU/SensorMeasures.inc",
                      ROOT / "@Resources/Modules/CPU/CoreSensorMeasures.inc"]
    for source in sensor_sources:
        contents = source.read_text(encoding="utf-8-sig")
        assert "#SensorInterval#" not in contents and "#MetricsInterval#" not in contents
        assert "#CPUSensorInterval#/Max(1,#CPUUpdateInterval#)" in contents
    assert all("Meter" not in values for name, values in sections.items() if "Style" in name)
    for name, values in sections.items():
        if name.startswith("Meter"):
            assert "Meter" in values, name
        for key, value in values.items():
            if key == "MeterStyle" or key.startswith("MeasureName"):
                assert all(ref.strip() in sections for ref in value.split("|")), (name, key)
    measures = [name for name, values in sections.items() if "Measure" in values]
    assert len(measures) == 97 + 9 * 64
    assert measures[-1] == "MeasureCPUController", "Script must follow telemetry"
    for field in ("Sensor", "Label", "Formatted", "Raw"):
        clock_measure = sections[f"MeasureCPUSensorClock{field}"]
        assert clock_measure["Measure"] == "Registry" and clock_measure["Disabled"] == "1"
        for index in range(1, 65):
            assert f"MeasureCPUSensorCoreClock{field}{index}" not in sections
    assert "CPUClockIndex" not in variables, "Core Clocks is automatic; do not persist a sensor index"
    for index in range(1, 65):
        measure = sections[f"MeasureCPU{index}"]
        assert measure["Measure"] == "CPU"
        assert measure["Processor"] == "0" and measure["Disabled"] == "1"
        assert measure["MinValue"] == "0" and measure["MaxValue"] == "100"
        assert sections[f"MeterCoreBar{index}"]["MeasureName"] == f"MeasureCPU{index}"
        assert effective(f"MeterCoreBar{index}")["Hidden"] == "1"
        history_measure = sections[f"MeasureCPUHistory{index}"]
        assert history_measure["Measure"] == "CPU"
        assert history_measure["Processor"] == str(index) and history_measure["Disabled"] == "1"
        assert history_measure["MinValue"] == "0" and history_measure["MaxValue"] == "100"
        for prefix in ("MeterCoreVoltage", "MeterCoreTemperature"):
            meter = effective(f"{prefix}{index}")
            assert meter["Hidden"] == "1" and meter["Text"] == "-"
            assert f"CPUCore{index}" in meter["Group"].split("|")
            assert not any(key.startswith("MeasureName") for key in meter)
        assert f"MeterSensorCoreLabel{index}" not in sections
    assert not (ROOT / "@Resources/Modules/CPU/CoreSensorMeters.inc").exists()
    for index in range(1, 11):
        assert f"MeterProcessBar{index}" not in sections
    core_header = effective("MeterTableCoreHeader")
    assert core_header["Text"] == "Thread"
    assert core_header["FontSize"] == "(#HeaderFontSize#*#Scale#)"
    assert core_header["FontColor"] == "#HeaderTextColor#"

    license_text = (CPU_ICON_DIR / "LUCIDE-LICENSE.txt").read_text(encoding="utf-8")
    assert "ISC License" in license_text
    assert "Copyright (c) 2026 Lucide Icons and Contributors" in license_text
    assert "permission notice appear in all copies" in license_text
    for icon, path_data in LUCIDE_ICON_PATHS.items():
        source = (CPU_ICON_DIR / f"{icon}.svg").read_text(encoding="utf-8")
        png = (CPU_ICON_DIR / f"{icon}.png").read_bytes()
        assert "Lucide Icons v1.8.0 (ISC)" in source
        assert 'stroke="#ffffff"' in source
        assert f'd="{path_data}"' in source
        assert png[:8] == b"\x89PNG\r\n\x1a\n" and png[12:16] == b"IHDR"
        assert struct.unpack(">II", png[16:24]) == (128, 128)
    cpu_source = (CPU_ICON_DIR / "cpu.svg").read_text(encoding="utf-8")
    assert all(f'd="{path_data}"' in cpu_source for path_data in LUCIDE_CPU_PATHS)
    assert '<rect x="4" y="4" width="16" height="16" rx="2"/>' in cpu_source
    assert '<rect x="8" y="8" width="8" height="8" rx="1"/>' in cpu_source
    assert 'd="m12 14 4-4"' in (CPU_ICON_DIR / "gauge.svg").read_text(encoding="utf-8")

    voltage_header = effective("MeterTableVoltageHeader")
    assert voltage_header["Meter"] == "Image"
    assert voltage_header["ImageName"] == "#@#Modules\\CPU\\Icons\\zap.png"
    assert voltage_header["Greyscale"] == "1" and voltage_header["ImageTint"] == "#WarningColor#,255"
    assert voltage_header["W"] == "(14*#Scale#)" and voltage_header["H"] == "(14*#Scale#)"
    temperature_header = effective("MeterTableTemperatureHeader")
    assert temperature_header["Meter"] == "Image"
    assert temperature_header["ImageName"] == "#@#Modules\\CPU\\Icons\\flame.png"
    assert temperature_header["Greyscale"] == "1" and temperature_header["ImageTint"] == "#CPUColor#,255"
    assert temperature_header["W"] == "(14*#Scale#)" and temperature_header["H"] == "(14*#Scale#)"
    usage_header = effective("MeterTableUsageHeader")
    assert usage_header["Meter"] == "Image"
    assert usage_header["ImageName"] == "#@#Modules\\CPU\\Icons\\gauge.png"
    assert usage_header["Greyscale"] == "1" and usage_header["ImageTint"] == "#HeaderTextColor#,255"
    assert usage_header["W"] == "(14*#Scale#)" and usage_header["H"] == "(14*#Scale#)"
    process_usage_header = effective("MeterProcessUsageHeader")
    assert process_usage_header["Meter"] == "Image"
    assert process_usage_header["ImageName"] == "#@#Modules\\CPU\\Icons\\gauge.png"
    assert process_usage_header["Greyscale"] == "1" and process_usage_header["ImageTint"] == "#HeaderTextColor#,255"
    assert process_usage_header["W"] == "(14*#Scale#)" and process_usage_header["H"] == "(14*#Scale#)"
    assert variables["CPUProcessUsageWidth"] == "(42*#Scale#)"
    assert sections["CPUStyleRowValue"]["W"] == "#CPUProcessUsageWidth#"
    assert sections["CPUStyleRowValue"]["StringAlign"] == "Center"
    assert sections["CPUStyleRowValue"]["X"] == "(#ContentX#+#ContentWidth#-#CPUProcessUsageWidth#/2)"
    assert "#CPUProcessUsageWidth#/2-7*#Scale#" in sections["MeterProcessUsageHeader"]["X"]
    for name in ("MeterTableHeaderRule", "MeterProcessHeaderRule"):
        rule = effective(name)
        assert rule["H"] == "(#TableHeaderBorderThickness#*#Scale#)"
        assert "#TableHeaderBorderThickness#*#Scale#/2" in rule["Shape"]
        assert "Stroke Color #TableHeaderBorderColor#" in rule["Shape"]
        assert "StrokeWidth (#TableHeaderBorderThickness#*#Scale#)" in rule["Shape"]
    for name in ("MeterTableFooterRule", "MeterProcessFooterRule"):
        rule = effective(name)
        assert rule["H"] == "(#DividerThickness#*#Scale#)"
        assert "#DividerThickness#*#Scale#/2" in rule["Shape"]
        assert "Stroke Color #DividerColor#" in rule["Shape"]
        assert "StrokeWidth (#DividerThickness#*#Scale#)" in rule["Shape"]
    clock_label, clock_value = effective("MeterCurrentClockLabel"), effective("MeterCurrentClockValue")
    assert clock_label["Text"] == "Clock:" and clock_value["Text"] == "Unavailable"
    assert clock_value["FontColor"] == "#AccentColor2#"
    assert effective("MeterProcessorDetails")["FontColor"] == "#AccentColor#"
    assert clock_label["Hidden"] == "1" and clock_value["Hidden"] == "1"
    assert {"CPUInfo", "CPUClock", "CPUUI"}.issubset(clock_label["Group"].split("|"))
    assert {"CPUInfo", "CPUClock", "CPUUI"}.issubset(clock_value["Group"].split("|"))
    dimensions = []
    assert number(variables['ColumnWidth']) == 220
    assert number(variables['PanelPadding']) == 6
    assert number(variables['PanelHeight']) == 80
    assert number(variables['CPUAutoRows']) == 1
    assert number(variables['Columns']) == 1, "CPU remains one column by default"
    assert not re.search(r"^UnitWidth=", ENTRY.read_text(), re.M), "CPU inherits shared geometry"
    for column_width in (180, 200, 220, 240, 280, 320):
        for scale, columns in product((0.75, 1, 1.25, 1.5, 2), (1, 2)):
            variables.update(Scale=str(scale), Columns=str(columns), ColumnWidth=str(column_width))
            width, height = number("#WindowWidth#"), number("#WindowHeight#")
            unit_width = math.floor(column_width * scale + 0.5)
            assert number("#UnitWidth#") == unit_width
            assert width == columns * (unit_width + number("#Gap#"))
            assert width == columns * number("#Pitch#")
            assert number("#PanelWidth#") + number("#Gap#") == width
            assert number("#Inset#") * 2 == number("#Gap#")
            if (column_width, scale, columns) == (220, 1, 1):
                assert number("#PanelWidth#") == 220 and width == 228
            # Runtime table Y positions vary, but its source column widths do not.
            label, bar = effective('MeterCoreLabel1'), effective('MeterCoreBar1')
            assert number(label['X']) + number(label['W']) <= number(bar['X'])
            assert number(bar['W']) > 0
            assert bar['H'] == '#DataBarThicknessPx#'
            assert variables['DataBarThicknessPx'] == '(Max(1,Round(#DataBarThickness#*#Scale#)))'
            saved_thickness = variables['DataBarThickness']
            for thickness in range(1, 13):
                variables['DataBarThickness'] = str(thickness)
                thickness_px = number('#DataBarThicknessPx#')
                bar = effective('MeterCoreBar1')
                row_top = number('#Inset#') + 120 * scale
                bar_y, bar_h = number(bar['Y']), number(bar['H'])
                assert thickness_px == max(1, math.floor(thickness * scale + 0.5))
                assert bar_h == thickness_px
                assert row_top <= bar_y and bar_y + bar_h <= row_top + 16 * scale
                assert abs((bar_y - row_top) - (16 * scale - bar_h) / 2) < 0.01
            variables['DataBarThickness'] = saved_thickness
            assert number(bar['X']) + number(bar['W']) <= number('#ContentX#') + number('#CPUCoreColumnWidth#')
            assert number('#CPUCoreColumnWidth#') + 128 * scale == number('#ContentWidth#')
            assert number(bar['X']) + number(bar['W']) + 4 * scale == number('#ContentX#') + number('#CPUCoreColumnWidth#')
            voltage = effective('MeterCoreVoltage1')
            temperature = effective('MeterCoreTemperature1')
            usage = effective('MeterCoreValue1')
            voltage_left = number(voltage['X']) - number(voltage['W']) / 2
            temperature_left = number(temperature['X']) - number(temperature['W'])
            usage_left = number(usage['X']) - number(usage['W']) / 2
            assert number(bar['X']) + number(bar['W']) <= voltage_left
            assert number(voltage['X']) + number(voltage['W']) / 2 <= temperature_left
            assert usage_left - number(temperature['X']) == 8 * scale
            assert usage_left + number(usage['W']) == number('#ContentX#') + number('#ContentWidth#')
            assert number(voltage['W']) >= 44 * scale
            assert number(temperature['W']) == 34 * scale
            assert number(usage['W']) == 42 * scale
            assert temperature['StringAlign'] == 'Right'
            assert usage['StringAlign'] == 'Center'
            voltage_header = effective('MeterTableVoltageHeader')
            temperature_header = effective('MeterTableTemperatureHeader')
            usage_header = effective('MeterTableUsageHeader')
            assert number(voltage_header['X']) + number(voltage_header['W']) / 2 == number(voltage['X'])
            assert number(temperature_header['X']) + number(temperature_header['W']) / 2 == temperature_left + number(temperature['W']) / 2
            assert number(usage_header['X']) >= usage_left
            assert number(usage_header['X']) + number(usage_header['W']) <= usage_left + number(usage['W'])
            assert number(usage_header['X']) + number(usage_header['W']) / 2 == usage_left + number(usage['W']) / 2
            assert number(usage['X']) == number(usage_header['X']) + number(usage_header['W']) / 2
            history_track, history = effective('MeterHistoryTrack'), effective('MeterHistory')
            assert number(history_track['H']) == 62 * scale
            assert number(history['H']) == 62 * scale
            process_name, process_value = effective('MeterProcessName1'), effective('MeterProcessValue1')
            process_value_left = number(process_value['X']) - number(process_value['W']) / 2
            assert number(process_name['X']) + number(process_name['W']) + 4 * scale == process_value_left
            assert number(process_usage_header['X']) + number(process_usage_header['W']) / 2 == number(process_value['X'])
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
                alignment = meter.get("StringAlign", "")
                if alignment.startswith("Right"):
                    x -= w
                elif alignment.startswith("Center"):
                    x -= w / 2
                if alignment.endswith("Center") and alignment != "Center":
                    y -= h / 2
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
                                   ('MeterPage', 'MeterNext'), ('MeterHistoryTrack', 'MeterSensors')]:
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
    sensor_script = (ROOT / "@Resources/Modules/CPU/Sensors.lua").read_text()
    setup_script = (ROOT / "@Resources/Modules/CPU/Settings.lua").read_text()
    discovery_script = (ROOT / "@Resources/Modules/CPU/DiscoverSensors.ps1").read_text()
    assert not any(token in script for token in ("os.execute", "io.popen", "io.open"))
    assert 'SetSensorCores' not in script
    assert 'infoWrap' not in script and 'MeterProcessorClock' not in sections and 'MeterHistoryLabel' not in sections
    assert "set('MeterProcessorDetails', 'Text', summary)" in script
    assert "configuredTurboClock" in script and "CPUTurboClock" in script
    assert "Configured turbo boost clock" in script
    assert "MaxClockSpeed" not in sections["MeasureCPUInfo"]["Parameter"]
    assert 'MeterProcessBar' not in script
    assert 'local function centeredBarY(meter, top)' in script
    assert '#DataBarThicknessPx#' in script
    assert "centeredBarY('MeterCoreBar' .. slot, top)" in script
    assert "set('MeterCoreLabel' .. slot, 'Text', tostring(index))" in script
    assert "SKIN:Bang('!CommandMeasure', 'MeasureCPUSensors', 'SetThreadPage(' .. first .. ')')" in script
    for prefix in ('MeterCoreVoltage', 'MeterCoreTemperature'):
        assert "y('" + prefix + "' .. slot, top)" in script
        assert "y('" + prefix + "' .. slot, 0)" in script
    assert "!ShowMeterGroup' or '!HideMeterGroup', 'CPUInfo'" in script
    assert "y('MeterCurrentClockLabel', cursor)" in script and "cursor = cursor + 24" in script
    assert "y('MeterHistoryTrack', cursor)" in script and "y('MeterHistory', cursor)" in script
    assert "cursor = cursor + state.graphHeight + 8" in script
    assert "return graphTotalHeight" in script
    assert "tracePoints(state.threadHistory[index] or {}, width, 0, height)" in script
    assert "Every Windows logical processor is drawn as an overlaid trace" in script
    assert "CPUHistorySource = {'historySource', 0, 0, 1}" in script
    assert "local function bindHistoryMeasures()" in script
    assert "MeasureCPUHistory' .. index" in script
    assert "local function syncThreadColors()" in script
    assert "set('MeterCoreBar' .. slot, 'BarColor', state.threadColors[index]" in script
    assert "drawHistoryPath(index, path, state.threadColors[index]" in script
    assert "Stroke Color ' .. color" in script
    assert "state.threadHistory[index] = {}" in script
    assert "CPUHistorySource = {0, 0, 1}" in setup_script
    assert "function CycleHistorySource(direction)" in setup_script
    assert "CPUVoltageDecimals = {3, 0, 3}" in setup_script
    assert "CPUTemperatureDecimals = {0, 0, 1}" in setup_script
    assert "function AdjustDecimals(key, direction)" in setup_script
    assert "function BeginDecimalInput(key)" in setup_script and "function CommitDecimalInput()" in setup_script
    assert "CycleVoltageDecimals()" not in setup_script and "CycleTemperatureDecimals()" not in setup_script and "ToggleDecimals()" not in setup_script
    assert "[switch] $PrecisionInput" in discovery_script
    assert "function ConvertTo-CPUPrecisionValue" in discovery_script
    assert "function Invoke-CPUPrecisionInput" in discovery_script
    assert "PARALLAX_CPU_DECIMAL_V1|ok|" in discovery_script
    assert "CPUVoltageDecimals = @(0, 3)" in discovery_script
    assert "CPUTemperatureDecimals = @(0, 1)" in discovery_script
    assert "InputText" not in discovery_script
    assert "readBinding('Clock')" in sensor_script and 'local function formatClock(value)' in sensor_script
    assert "local providerStarted = state.providerRunning == false and providerRunning" in sensor_script
    assert "state.reconnectQueued = state.reconnectQueued or parameters ~= state.arguments" in sensor_script
    assert "local function formatVoltage(value)" in sensor_script
    assert "precisionChanged" in sensor_script
    assert "set('MeterCurrentClockValue', 'Text'" in sensor_script
    assert 'CPUClockIndex' not in sensor_script and 'CPUClockIndex' not in setup_script
    assert "parts[1] == 'CLOCK'" in setup_script and "normalizedLabel ~= 'Core Clocks'" in setup_script
    assert "CLOCK|HKEY_CURRENT_USER|index" in discovery_script
    assert "$label -eq 'Core Clocks'" in discovery_script
    assert "-Kind 'CLOCK' -RequestedIndex -1" in discovery_script
    title_cases = validate_title_rows()
    settings_cases = validate_settings_shared_width()
    color_cases = validate_thread_colors()
    print(f"PASS: {len(visited)} files, {len(measures)} measures, include/reference/startup checks.")
    print(f'PASS startup geometry: {len(dimensions)} combinations, shared widths180/200/220/240/280/320, Columns1/2, scales0.75/1/1.25/1.5/2; unified Thread/V/T/% columns, bar bounds, and frame geometry. Deferred section positions require native checks.')
    print(f'PASS CPU title rows: {title_cases} combinations; title sizes6/10/12, scales0.75/1/2, widths180/220.')
    print(f'PASS CPU Settings shared width/title row: {settings_cases} combinations; both utilities inherit shared ColumnWidth.')
    print(f'PASS CPU Thread Colors: {color_cases} bounded slot and width/scale checks; hex input remains event driven.')
    print('Startup220/1x: ' + '; '.join(f'{cols}col={w:g}x{h:g}'
          for cw,s,cols,w,h in dimensions if cw==220 and s==1))
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
