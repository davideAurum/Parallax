"""Check actual IO meter geometry against the supported appearance matrix.

No Rainmeter process is launched. This checks declared geometry and bindings,
not glyph ink, Windows DPI behavior, telemetry, or screenshot quality. Drive
rows start hidden at Y=0; ControllerSuite.lua checks their runtime compaction
and the placement of the one shared graph. Packaging excludes these tests.
"""
from pathlib import Path
from itertools import product
import configparser
import math
import re
import string


ROOT = Path(__file__).resolve().parents[4]
COMMON = (
    "@Resources/Defaults.inc",
    "@Resources/User/Settings.inc",
    "@Resources/User/IO.inc",
    "@Resources/Geometry.inc",
    "@Resources/Styles.inc",
)
PROFILES = {
    "monitor": (COMMON + ("@Resources/Modules/IO/View.inc", "@Resources/Modules/IO/DriveMeters.inc"), (1, 2)),
    "settings": (COMMON + ("IO/Settings/Settings.ini", "@Resources/UtilitySettingsNote.inc", "@Resources/Modules/IO/SettingsMeters.inc"), (2,)),
}
WIDTHS = (180, 200, 220, 240, 280, 320)
SCALES = (.75, 1, 1.25, 1.5, 2)
THICKNESSES = (1, 6, 6.01, 8.5, 12)
LETTERS = string.ascii_uppercase
DRIVE_METERS = ("Drive", "Capacity", "Used", "DiskReadLabel", "DiskWriteLabel", "DiskRead", "DiskWrite", "Legend")
GRAPH_MARKERS = {"MeterIOGraphPositive": "+", "MeterIOGraphZero": "0", "MeterIOGraphNegative": "-"}
STEPPERS = {
    "Names": ("CycleNamesMode", "CycleNamesMode()", 126),
    "Graph": ("CycleGraphMode", "CycleGraphMode()", 126),
    "Units": ("CycleUnits", "CycleUnits()", 56),
    "Limit": ("CycleLimit", "BeginLimitInput()", 104),
}


class CaseVariables(dict):
    """One immutable-after-construction case, with cached numeric expressions."""

    def __init__(self, values):
        super().__init__(values)
        self.formula_cache = {}


def formula(expression, variables):
    value = str(expression)
    cache = getattr(variables, "formula_cache", {})
    if value in cache:
        return cache[value]
    original = value
    for _ in range(30):
        expanded = re.sub(r"#([^#]+)#", lambda m: str(variables[m[1]]), value)
        if expanded == value:
            break
        value = expanded
    # Only local, trusted INI numeric formulas are evaluated, without builtins.
    result = eval(value, {"__builtins__": {}}, {
        "Round": lambda n: math.floor(n + .5), "Max": max,
        "Min": min, "Ceil": math.ceil,
    })
    cache[original] = result
    return result


def read_sections(includes):
    sections = {}
    for relative in includes:
        parser = configparser.ConfigParser(interpolation=None, comment_prefixes=(";",))
        parser.optionxform = str
        parser.read(ROOT / relative, encoding="utf-8-sig")
        for name in parser.sections():
            sections.setdefault(name, {}).update(dict(parser[name]))
    return sections


def resolved_options(name, sections):
    section = sections[name]
    options = {}
    for style in section.get("MeterStyle", "").split("|"):
        if style:
            assert style in sections, (name, "unknown meter style", style)
            options.update(sections[style])
    options.update(section)
    return options


def check_drive_bank():
    """Verify every per-letter readout maps to its own native providers."""
    providers = read_sections(("@Resources/Modules/IO/Inventory.inc", "@Resources/Modules/IO/Native.inc", "@Resources/Modules/IO/Disk.inc"))
    meters = read_sections(PROFILES["monitor"][0])
    expected_providers = set()
    expected_meters = set()
    for letter in LETTERS:
        kind_name = "MeasureIOType" + letter
        kind = providers[kind_name]
        expected_providers.add(kind_name)
        assert kind["Measure"] == "FreeDiskSpace" and kind["Drive"] == letter + ":"
        assert kind["Type"] == "1" and kind["IgnoreRemovable"] == "0"
        assert kind["Group"] == "IOInventory" and kind.get("Disabled", "0") == "0"
        assert "CapacityInterval" in kind["UpdateDivider"]
        label_name = "MeasureIOName" + letter
        label = providers[label_name]
        expected_providers.add(label_name)
        assert label["Measure"] == "FreeDiskSpace" and label["Drive"] == letter + ":"
        assert label["Type"] == "0" and label["Label"] == "1" and label["IgnoreRemovable"] == "0"
        assert label["Group"] == "IOInventory" and label.get("Disabled", "0") == "0"
        assert "CapacityInterval" in label["UpdateDivider"]
        for field in ("Total", "Free", "Used"):
            name = "MeasureIO" + field + letter
            options = providers[name]
            expected_providers.add(name)
            assert options["Group"] == "IOCapacity" + letter and options["Disabled"] == "1"
            if field == "Used":
                assert options["Measure"] == "Calc"
                assert set(re.findall(r"MeasureIO\w+", options["Formula"])) == {
                    "MeasureIOFree" + letter, "MeasureIOTotal" + letter}
                assert options["MinValue"] == "0" and options["MaxValue"] == "100"
            else:
                assert options["Measure"] == "FreeDiskSpace" and options["Drive"] == letter + ":"
                assert options["IgnoreRemovable"] == "0" and options["DiskQuota"] == "#IODiskQuota#"
                assert "CapacityInterval" in options["UpdateDivider"]
                assert options.get("Total", "0") == ("1" if field == "Total" else "0")
        for direction in ("Read", "Write"):
            name = "MeasureIODisk" + direction + letter
            options = providers[name]
            expected_providers.add(name)
            assert options["Measure"] == "Plugin" and options["Plugin"] == "UsageMonitor"
            assert options["Category"] == "LogicalDisk" and options["Name"] == letter + ":"
            assert options["Counter"] == "Disk " + direction + " Bytes/sec"
            assert options["Group"] == "IORates" + letter and options["Disabled"] == "1"
            assert all(options[key] == "0" for key in ("Rollup", "Percent", "RawValue"))
        for field in DRIVE_METERS:
            name = "MeterIO" + field + letter
            options = resolved_options(name, meters)
            expected_meters.add(name)
            assert options["Hidden"] == "1" and options["Y"] == "0", (name, "hidden runtime row must start at Y=0")
            if field == "Used":
                assert options["Meter"] == "Bar" and options["MeasureName"] == "MeasureIOUsed" + letter
                assert options["H"] == "#DataBarThicknessPx#", (name, "shared bar thickness")
            elif field == "Drive":
                assert options["Text"] == letter + ":", (name, "drive label")
                assert options["ClipString"] == "1" and "H" not in options, (name, "one-line automatic height with ellipsis")
            elif field in ("Capacity", "DiskRead", "DiskWrite"):
                assert options["ClipString"] == "1" and "H" not in options, (name, "single-line summary cell")
    assert set(providers) == expected_providers, "unexpected or incomplete native provider bank"
    actual_bank = read_sections(("@Resources/Modules/IO/DriveMeters.inc",))
    assert set(actual_bank) == expected_meters, "unexpected or incomplete drive meter bank"
    entrypoint = read_sections(("IO/IO-Disk.ini",))
    includes = {value for section in entrypoint.values() for key, value in section.items() if key.startswith("@Include")}
    for name in ("Inventory", "Native", "Disk", "Model", "View"):
        assert "#@#Modules\\IO\\" + name + ".inc" in includes, (name, "provider/view include missing from monitor")
    view = read_sections(("@Resources/Modules/IO/View.inc",))
    includes = {value for section in view.values() for key, value in section.items() if key.startswith("@Include")}
    assert "#@#Modules\\IO\\DriveMeters.inc" in includes, "drive meter bank missing from view"
    graphs = {name for name, section in meters.items() if section.get("Meter") == "Shape" and "Graph" in name}
    assert graphs == {"MeterIODiskGraphTrack", "MeterIODiskGraph"}, "history graph must not be duplicated per drive"
    for name, symbol in GRAPH_MARKERS.items():
        marker = resolved_options(name, meters)
        assert marker["Meter"] == "String" and marker["Text"] == symbol, (name, "split graph axis marker")
        assert marker["Hidden"] == "1" and marker["Y"] == "0", (name, "split markers must start hidden")
        assert marker["StringAlign"] == "Right" and marker["ClipString"] == "1", (name, "bounded axis alignment")
        assert marker["FontFace"] == "#FontFace#" and marker["FontColor"] == "#MutedColor#", (name, "shared metadata styling")
        assert marker.get("ToolTipText") and not any(key.endswith("Action") for key in marker), (name, "axis markers are passive")
    model = read_sections(("@Resources/Modules/IO/Model.inc",))
    assert set(model) == {"MeasureIOModelQuery"}, "one explicit model query provider"
    query = model["MeasureIOModelQuery"]
    assert query["Plugin"] == "RunCommand" and query["State"] == "Hide"
    assert query["OutputType"] == "UTF8" and query["Timeout"] == "12000"
    assert query["FinishAction"] == "[!UpdateMeasure MeasureIOModelQuery]#IONameFinishAction#"
    for path, controller in (("IO/IO-Disk.ini", "MeasureIO"), ("IO/Settings/Settings.ini", "MeasureIOSettings")):
        entry = read_sections((path,))
        assert entry["Variables"]["IONameFinishAction"] == '[!CommandMeasure ' + controller + ' "NamesReady()"]'
        assert "#@#Modules\\IO\\Model.inc" in {value for section in entry.values() for key, value in section.items() if key.startswith("@Include")}
    print(f"PASS: {len(expected_providers)} per-letter native bindings; {len(expected_meters)} hidden drive meters; exactly one graph frame and trace meter.")


def check_monitor_layout(bounds, variables, scale, thickness):
    """Check static widths and baseline frame, not runtime Y=0 row overlap."""
    panel = bounds["MeterIOPanel"]
    graph = bounds["MeterIODiskGraph"]
    frame = bounds["MeterIODiskGraphTrack"]
    saved_height = formula(variables["PanelHeight"], variables)
    physical_thickness = max(1, math.floor(thickness * scale + .5))
    extra = max(0, physical_thickness / scale - 6)
    expected_height = math.floor(max(saved_height, 157 + extra) * scale + .5)
    content_x = formula(variables["ContentX"], variables)
    content_width = formula(variables["ContentWidth"], variables)
    for name in GRAPH_MARKERS:
        x, y, width, height = bounds[name]
        assert math.isclose(width, 12 * scale, abs_tol=.001) and math.isclose(height, 14 * scale, abs_tol=.001), (name, "axis envelope")
        assert y == 0 and math.isclose(x + width, content_x + content_width - 2 * scale, abs_tol=.001), (name, "axis right inset")
    for letter in LETTERS:
        bar = bounds["MeterIOUsed" + letter]
        assert bar[3] == physical_thickness, (letter, thickness, scale, bar[3], "shared physical bar thickness")
        assert math.isclose(formula(variables["DataBarThicknessPx"], variables), bar[3], abs_tol=.001)
        assert math.isclose(bar[0], content_x, abs_tol=.001) and math.isclose(bar[2], content_width, abs_tol=.001)
        drive, capacity = (bounds["MeterIO" + field + letter] for field in ("Drive", "Capacity"))
        assert math.isclose(drive[0], content_x, abs_tol=.001) and math.isclose(drive[2], content_width, abs_tol=.001), (letter, "full-width name")
        assert math.isclose(capacity[2], (content_width - 8 * scale) * .44, abs_tol=.001)
        read, write = (bounds["MeterIODisk" + field + letter] for field in ("Read", "Write"))
        for direction, rate in (("Read", read), ("Write", write)):
            glyph = bounds["MeterIODisk" + direction + "Label" + letter]
            assert rate[0] >= glyph[0] + glyph[2] + scale - .001, (letter, direction, "rate/glyph horizontal gap")
        assert read[0] + read[2] + 4 * scale <= bounds["MeterIODiskWriteLabel" + letter][0] + .001
        assert write[0] + write[2] + 4 * scale <= capacity[0] + .001, (letter, "speed/capacity cell gap")
    assert all(math.isclose(a, b, abs_tol=.001) for a, b in zip(graph, frame)), "trace/frame alignment"
    assert math.isclose(graph[3], formula(variables["IOGraphHeight"], variables) * scale, abs_tol=.001)
    assert panel[3] == expected_height, (thickness, scale, saved_height, "initial panel height")
    # PanelHeightPx rounds to a physical pixel; the painted bottom can lose .5 px.
    assert graph[1] + graph[3] + 6 * scale <= panel[1] + panel[3] + .501, "graph bottom padding"
    baseline_height = math.floor(max(saved_height, 157) * scale + .5)
    assert panel[3] >= baseline_height, "panel shrank below saved minimum"
    if saved_height >= 157 + extra:
        assert panel[3] == math.floor(saved_height * scale + .5), "larger saved height changed"
    elif (157 + extra - max(saved_height, 157)) * scale >= 1:
        assert panel[3] > baseline_height, "thicker bar did not grow panel"


def check_settings_steppers(bounds, sections, variables, scale):
    """Check actual arrow/value/frame bounds, semantic styles and fixed actions."""
    content_x = formula(variables["ContentX"], variables)
    content_right = content_x + formula(variables["ContentWidth"], variables)
    expected_parts = set()
    for stem, (function, center_command, field_width) in STEPPERS.items():
        names = {part: "MeterIOSettings" + stem + part for part in ("Label", "Decrease", "Frame", "Value", "Increase")}
        expected_parts.update(names[part] for part in ("Decrease", "Frame", "Value", "Increase"))
        options = {part: resolved_options(name, sections) for part, name in names.items()}
        boxes = {part: bounds[name] for part, name in names.items()}
        center_action = '[!CommandMeasure MeasureIOSettings "' + center_command + '"]'
        for part, style in (("Label", "StyleUtilitySettingsLabel"), ("Decrease", "StyleSettingsStepperButton"), ("Frame", "StyleSettingsStepperFrame"),
                            ("Value", "StyleSettingsStepperValue"), ("Increase", "StyleSettingsStepperButton")):
            item = options[part]
            assert style in item.get("MeterStyle", "").split("|"), (names[part], "shared stepper style")
            assert item.get("Group") == "IOSettingsUI" and item.get("MouseActionCursor") == "1"
            assert item.get("ToolTipText") and not item.get("RightMouseUpAction"), (names[part], "explicit directional interaction")
            assert item.get("Hidden", "0") == "0", (names[part], "stepper must remain accessible")
            box = boxes[part]
            assert content_x <= box[0] and box[0] + box[2] <= content_right + .001, (names[part], "stepper outside content")
        for part in ("Label", "Frame", "Value"):
            assert options[part].get("LeftMouseUpAction") == center_action, (names[part], "center action binding")
            assert not options[part].get("RightMouseUpAction"), (names[part], "center must not retain an implicit reverse action")
        for part, direction, symbol in (("Decrease", -1, "<"), ("Increase", 1, ">")):
            item = options[part]
            assert item["Meter"] == "String" and item["Text"] == symbol
            assert item.get("LeftMouseUpAction") == '[!CommandMeasure MeasureIOSettings "' + function + '(' + str(direction) + ')"]', (names[part], "directional action binding")
        for part in ("Label", "Decrease", "Value", "Increase"):
            item = options[part]
            assert item["Meter"] == "String", (names[part], "stepper text meter type")
            expected_color = "#AccentColor#" if part in ("Decrease", "Increase") else "#TextColor#"
            assert item["FontFace"] == "#FontFace#" and item["FontColor"] == expected_color, (names[part], "semantic stepper text")
            assert math.isclose(formula(item["FontSize"], variables), formula(variables["FontSize"], variables) * scale, abs_tol=.001)
        for part in ("Decrease", "Value", "Increase"):
            item = options[part]
            assert item["StringAlign"] == "Center" and item["ClipString"] == "1", (names[part], "centered bounded stepper text")
            assert all(formula(value, variables) == 0 for value in item.get("Padding", "0,0,0,0").split(",")), (names[part], "stepper padding must not enlarge hit targets")
            assert math.isclose(boxes[part][3], 18 * scale, abs_tol=.001)
        frame, value, previous, following, label = (boxes[part] for part in ("Frame", "Value", "Decrease", "Increase", "Label"))
        assert options["Frame"]["Meter"] == "Shape" and math.isclose(frame[3], 20 * scale, abs_tol=.001)
        assert math.isclose(frame[2], field_width * scale, abs_tol=.001) and math.isclose(value[2], frame[2], abs_tol=.001)
        assert math.isclose(value[0] + value[2] / 2, frame[0] + frame[2] / 2, abs_tol=.001), (stem, "field horizontal center")
        assert math.isclose(label[1] + label[3], frame[1] + frame[3], abs_tol=.001), (stem, "label/field baseline row")
        for part in ("Decrease", "Value", "Increase"):
            box = boxes[part]
            assert math.isclose(box[1] + box[3] / 2, frame[1] + frame[3] / 2, abs_tol=.001), (names[part], "frame vertical center")
        assert math.isclose(previous[2], 18 * scale, abs_tol=.001) and math.isclose(following[2], 18 * scale, abs_tol=.001)
        assert math.isclose(frame[0] - previous[0] - previous[2], 2 * scale, abs_tol=.001), (stem, "previous/field gap")
        assert math.isclose(following[0] - frame[0] - frame[2], 2 * scale, abs_tol=.001), (stem, "field/next gap")
        assert previous[0] >= label[0] + label[2] + 10 * scale - .001, (stem, "label/stepper clearance")
        assert math.isclose(following[0] + following[2] - previous[0], (40 + field_width) * scale, abs_tol=.001), (stem, "complete stepper group width")
        # Validate the actual frame paint, including its centered stroke.
        shape = options["Frame"]["Shape"].split("|")
        assert shape[0].strip().startswith("Rectangle ")
        rectangle = [formula(item.strip(), variables) for item in shape[0].strip().removeprefix("Rectangle ").split(",")]
        assert len(rectangle) == 5
        modifiers = [part.strip() for part in shape[1:]]
        assert "Fill Color #GraphBackgroundColor#" in modifiers and "Stroke Color #BorderColor#" in modifiers
        stroke = next(part.removeprefix("StrokeWidth ") for part in modifiers if part.startswith("StrokeWidth "))
        stroke = formula(stroke, variables)
        assert math.isclose(stroke, scale, abs_tol=.001)
        rx, ry, rw, rh, radius = rectangle
        assert math.isclose(rx - stroke / 2, 0, abs_tol=.001) and math.isclose(ry - stroke / 2, 0, abs_tol=.001)
        assert math.isclose(rx + rw + stroke / 2, frame[2], abs_tol=.001) and math.isclose(ry + rh + stroke / 2, frame[3], abs_tol=.001), (stem, "frame paint fits declared bounds")
        assert 0 <= radius <= min(rw, rh) / 2
    actual_parts = {name for name, section in sections.items() if "Meter" in section
                    and any(style.startswith("StyleSettingsStepper") for style in section.get("MeterStyle", "").split("|"))}
    assert actual_parts == expected_parts, "expected exactly four complete settings steppers"
    frames = [bounds["MeterIOSettings" + stem + "Frame"] for stem in STEPPERS]
    assert all(math.isclose(frame[0], frames[0][0], abs_tol=.001) for frame in frames), "stepper fields must share a left edge"
    for previous, following in zip(frames[1:], frames[2:]):
        assert math.isclose(following[1] - previous[1], 28 * scale, abs_tol=.001), "graph/display steppers retain 28px row pitch"


def check_settings_layout(bounds, sections, variables, scale):
    """Validate padded value cells and static section/header declarations."""
    content_x = formula(variables["ContentX"], variables)
    content_right = content_x + formula(variables["ContentWidth"], variables)
    cells = set()
    for name, section in sections.items():
        if "Meter" not in section:
            continue
        options = resolved_options(name, sections)
        styles = options.get("MeterStyle", "").split("|")
        if options["Meter"] == "String":
            x, _, w, _ = bounds[name]
            assert options.get("ClipString") == "1", (name, "fixed text bounds")
            assert x >= content_x - .001 and x + w <= content_right + .001, (name, "padded text outside content")
        if "StyleUtilitySettingsValue" in styles:
            if re.fullmatch(r"MeterIOSettingsDrive[A-Z]", name):
                label_name = name + "Label"
            else:
                assert name.endswith("Value"), (name, "setting cell naming")
                label_name = name[:-5] + "Label"
            assert label_name in bounds, (name, "missing paired setting label")
            label_options = resolved_options(label_name, sections)
            if re.fullmatch(r"MeterIOSettingsDrive[A-Z]", name):
                assert label_options["ClipString"] == "1" and "H" not in label_options, (name, "one-line automatic name height with ellipsis")
            else:
                assert "StyleUtilitySettingsLabel" in label_options.get("MeterStyle", "").split("|")
            assert options.get("LeftMouseUpAction"), (name, "value action missing")
            assert options["LeftMouseUpAction"] == label_options.get("LeftMouseUpAction"), (name, "label/value action mismatch")
            assert options.get("RightMouseUpAction") == label_options.get("RightMouseUpAction"), (name, "label/value reverse action mismatch")
            for target, target_options in ((name, options), (label_name, label_options)):
                assert target_options["FontFace"] == "#FontFace#" and target_options["FontColor"] == "#TextColor#", (target, "shared body styling")
                assert math.isclose(formula(target_options["FontSize"], variables), formula(variables["FontSize"], variables) * scale, abs_tol=.001)
            cell, label = bounds[name], bounds[label_name]
            assert cell[0] >= label[0] + label[2] + 4 * scale - .001, (name, "label/cell clearance")
            assert math.isclose(cell[3], 20 * scale, abs_tol=.001), (name, "padded value cell height")
            if options.get("Hidden", "0") != "1":
                assert math.isclose(label[1] + label[3], cell[1] + cell[3], abs_tol=.001), (name, "label/cell baseline row")
            cells.add(name)
        elif "StyleUtilitySettingsSection" in styles:
            assert options["FontFace"] == "#FontFace#" and options["FontColor"] == "#AccentColor#"
            assert math.isclose(formula(options["FontSize"], variables), formula(variables["HeaderFontSize"], variables) * scale, abs_tol=.001)
            rule_name = name.removesuffix("Section") + "Rule"
            rule_options = resolved_options(rule_name, sections)
            assert "StyleRule" in rule_options.get("MeterStyle", "").split("|")
            assert "#DividerColor#" in rule_options["Shape"] and "#DividerThickness#" in rule_options["Shape"]
            heading, rule = bounds[name], bounds[rule_name]
            assert rule[1] >= heading[1] + heading[3] + 2 * scale - .001, (name, "section divider clearance")
    expected_cells = {"MeterIOSettingsAllValue", "MeterIOSettingsQuotaValue"} | {"MeterIOSettingsDrive" + letter for letter in LETTERS}
    assert cells == expected_cells, "All, quota and 26 drive booleans retain their shared compact cells"
    for letter in LETTERS:
        for field in ("Label", ""):
            name = "MeterIOSettingsDrive" + letter + field
            options = resolved_options(name, sections)
            assert options["Hidden"] == "1" and options["Y"] == "0", (name, "hidden settings drive row must start at Y=0")
            assert options["LeftMouseUpAction"] == '[!CommandMeasure MeasureIOSettings "ToggleDrive(\'' + letter + '\')"]', (name, "drive toggle binding")
        assert "MeterIOSettingsDrive" + letter in cells
    assert not any(name.endswith("Row") and "Meter" in section for name, section in sections.items()), "settings must use compact value cells, not full-width row backgrounds"
    check_settings_steppers(bounds, sections, variables, scale)


def check_profile(includes, column_counts, fonts, widths=WIDTHS, panel_height=None):
    sections = read_sections(includes)
    defaults = sections["Variables"]
    checks = 0
    for width, scale, columns, thickness in product(widths, SCALES, column_counts, THICKNESSES):
        variables = dict(defaults, ColumnWidth=width, Scale=scale, Columns=columns, DataBarThickness=thickness)
        variables.update(fonts)
        if panel_height is not None:
            variables["PanelHeight"] = panel_height
        variables = CaseVariables(variables)
        window_width = formula(variables["WindowWidth"], variables)
        window_height = formula(variables["WindowHeight"], variables)
        bounds = {}
        for name, section in sections.items():
            if "Meter" not in section:
                continue
            options = resolved_options(name, sections)
            if name in GRAPH_MARKERS:
                assert math.isclose(formula(options["FontSize"], variables), max(6, fonts["FontSize"] - 2) * scale, abs_tol=.001), (name, "shared axis font")
            x, y, w, h = [formula(options.get(key, 0), variables) for key in "XYWH"]
            if re.fullmatch(r"MeterIO(?:Drive|Capacity|DiskRead|DiskWrite)[A-Z]|MeterIOSettingsDrive[A-Z]Label", name):
                assert "H" not in options and options["ClipString"] == "1"
                # Check the allocated row envelope here. Natural single-line
                # font height and ellipsis rendering require native validation.
                h = 18 * scale
            if options.get("MeterStyle") == "StylePanel":
                w = formula(variables["PanelWidth"], variables)
                h = formula(variables["PanelHeightPx"], variables)
            padding = [formula(item, variables) for item in options.get("Padding", "0,0,0,0").split(",")]
            assert len(padding) == 4 and all(item >= 0 for item in padding), (name, "invalid padding")
            w += padding[0] + padding[2]
            h += padding[1] + padding[3]
            if options.get("StringAlign", "").startswith("Right"):
                x -= w
            elif options.get("StringAlign", "").startswith("Center"):
                x -= w / 2
            if options.get("StringAlign", "") in ("LeftCenter", "RightCenter", "CenterCenter"):
                y -= h / 2
            assert w > 0 and h > 0, (name, "nonpositive dimensions")
            assert x >= 0 and y >= 0 and x+w <= window_width+.01 and y+h <= window_height+.01, (
                name, width, scale, columns, thickness, x, y, w, h, window_width, window_height)
            checks += 1
            bounds[name] = (x, y, w, h)
        center = formula(variables["TitleRowCenterY"], variables)
        row_meters = ("MeterIOIcon", "MeterIOTitle", "MeterIOTotal", "MeterIOOptions") if "MeterIOTitle" in bounds else ("MeterIOSettingsTitle", "MeterIOSettingsClose")
        for name in row_meters:
            x, y, w, h = bounds[name]
            assert math.isclose(y + h / 2, center, abs_tol=.001), (name, "title row center")
        if "MeterIOTitle" in bounds:
            icon, title, value = [bounds[name] for name in ("MeterIOIcon", "MeterIOTitle", "MeterIOTotal")]
            assert math.isclose(icon[2], 14 * scale * fonts["TitleFontSize"] / 10, abs_tol=.001)
            assert math.isclose(title[0] - icon[0] - icon[2], 4 * scale, abs_tol=.001)
            assert math.isclose(value[0] - title[0] - title[2], 4 * scale, abs_tol=.001)
            check_monitor_layout(bounds, variables, scale, thickness)
        else:
            title, note = bounds["MeterIOSettingsTitle"], bounds["MeterUtilitySettingsNote"]
            assert title[1] + title[3] <= note[1]
            check_settings_layout(bounds, sections, variables, scale)
        assert formula(variables["PanelWidth"], variables) == (
            columns * formula(variables["Pitch"], variables)
            - formula(variables["Gap"], variables))
    return checks


def main():
    shared = read_sections(("@Resources/Defaults.inc", "@Resources/Geometry.inc"))["Variables"]
    assert formula(shared["DataBarThickness"], shared) == 6, "shared thickness default"
    assert "DataBarThicknessPx" in shared, "missing shared thickness geometry"
    view = read_sections(("@Resources/Modules/IO/View.inc",))["Variables"]
    assert "PanelHeight" not in view, "view must preserve the saved panel minimum"
    settings = read_sections(("IO/Settings/Settings.ini",))
    assert settings["Variables"]["Columns"] == "2", "settings must retain independent double-column width"
    includes = {value for section in settings.values() for key, value in section.items() if key.startswith("@Include")}
    assert "#@#Modules\\IO\\Inventory.inc" in includes, "settings must load the native drive inventory"
    check_drive_bank()
    for typography, fonts in {
        "small title": dict(TitleFontSize=6, HeaderFontSize=8, FontSize=9),
        "default": dict(TitleFontSize=10, HeaderFontSize=8, FontSize=9),
        "maximum": dict(TitleFontSize=12, HeaderFontSize=10, FontSize=10),
        "minimum": dict(TitleFontSize=6, HeaderFontSize=6, FontSize=6),
    }.items():
        for name, (includes, column_counts) in PROFILES.items():
            checks = check_profile(includes, column_counts, fonts)
            print(f"PASS: {checks} IO {name} meter bounds, {typography} typography; six widths, five scales, five bar thicknesses, Columns={column_counts}.")
    fonts = dict(TitleFontSize=12, HeaderFontSize=10, FontSize=10)
    checks = check_profile(PROFILES["monitor"][0], (1,), fonts, widths=(180,), panel_height=200)
    print(f"PASS: {checks} IO monitor meter bounds with saved PanelHeight=200; width 180, maximum typography, five scales, five bar thicknesses.")
    print("LIMIT: name heights use their allocated 18px row envelopes; natural single-line font height/ellipsis require native validation. Hidden Y=0 rows check declared dimensions only; Lua suites check dynamic layout separately.")


if __name__ == "__main__":
    main()
