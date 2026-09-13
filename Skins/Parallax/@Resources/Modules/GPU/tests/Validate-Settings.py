"""Offline bounds and interaction wiring checks for the GPU settings utility."""
import contextlib
import io
import itertools
import math
import runpy
from pathlib import Path

with contextlib.redirect_stdout(io.StringIO()):
    api = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'Validate-GPU.py'))
api['sections'].clear()
api['loaded'].clear()
api['load'](api['ROOT'] / 'GPU' / 'Settings' / 'Settings.ini')
sections = api['sections']
assert sections['Rainmeter']['Group'] == 'Parallax'
assert sections['Variables']['Columns'] == '2'
assert sections['Variables']['PanelHeight'] == '648'
assert sections['Variables']['GPUPowerSource'] == '0'
assert sections['Variables']['GPUClockSource'] == '0'
assert sections['MeasureGPUSettings']['UpdateDivider'] == '-1'
assert 'OnRefreshAction' not in sections['Rainmeter'], 'opening must not launch discovery'
meters = {name: api['effective'](name) for name, opts in sections.items() if 'Meter' in opts}
steppers = {'Columns': 56, 'PowerSource': 56, 'ClockSource': 56, 'Hive': 112}
assert len(meters) == 61
assert sections['MeasureGPUSettingsInput']['StartInFolder'] == '#@#Scripts\\'
assert sections['MeasureGPUSettingsInput']['Parameter'] == ''
assert sections['MeasureGPUSettingsInput']['FinishAction'] == '[!UpdateMeasure MeasureGPUSettingsInput][!CommandMeasure MeasureGPUSettings "CommitColumnsInput()"]'
assert 'MeterSettingsPickerPanel' not in meters, 'value fields replace the enclosing shaded panel'
for name in ('MeterSettingsDisplaySection', 'MeterSettingsSensorsSection', 'MeterSettingsPickerTitle'):
    heading = meters[name]
    assert 'StyleUtilitySettingsSection' in heading['MeterStyle'], name
    assert heading['FontColor'] == '#AccentColor#', 'settings sections inherit Accent 1'
    assert heading['FontSize'] == '(#HeaderFontSize#*#Scale#)', name
    assert 'FontColor' not in sections[name], 'do not override shared section appearance'
    assert heading.get('Hidden', '0') == '0', 'setup headings remain accessible'
# GPUEnableSensors controls an optional provider, not section visibility. Keep
# setup and recovery accessible with exports disabled or unavailable.
for name in ('MeterSettingsHiveValue', 'MeterSettingsKeyValue', 'MeterSettingsPowerValue',
             'MeterSettingsClockValue', 'MeterSettingsRescan', 'MeterSettingsGuide',
             'MeterSettingsAdvanced', 'MeterSettingsTemperatureClear'):
    assert meters[name].get('Hidden', '0') == '0', 'provider setup must not collapse'
for field in ('Columns', 'Height', 'Temperature', 'PowerSource', 'ClockSource', 'Sensors', 'Hive', 'Key', 'Power', 'Clock'):
    label, value = meters['MeterSettings' + field + 'Label'], meters['MeterSettings' + field + 'Value']
    assert 'StyleUtilitySettingsLabel' in label['MeterStyle'], field
    assert value['FontColor'] == '#TextColor#', field
    if field in steppers:
        assert value['MeterStyle'] == 'StyleSettingsStepperValue', field
        assert value['StringAlign'] == 'Center', field
        frame = meters['MeterSettings' + field + 'Frame']
        assert frame['MeterStyle'] == 'StyleSettingsStepperFrame', field
        assert frame['LeftMouseUpAction'] == value['LeftMouseUpAction'] == label['LeftMouseUpAction'], field
        assert '#GraphBackgroundColor#' in frame['Shape']
        for side in ('Previous', 'Next'):
            arrow = meters['MeterSettings' + field + side]
            assert arrow['MeterStyle'] == 'StyleSettingsStepperButton'
            assert arrow['FontColor'] == '#AccentColor#'
    else:
        assert 'StyleUtilitySettingsValue' in value['MeterStyle'], field
        assert value['SolidColor'] == '#GraphBackgroundColor#', field
        assert value['StringAlign'] == 'Left', field
    assert 'SolidColor' not in label, 'shade values only'
for section in ('Display', 'Sensors', 'Picker'):
    rule = meters['MeterSettings' + section + 'Rule']
    assert rule['MeterStyle'] == 'StyleRule', 'sections use Divider appearance'
    assert '#DividerColor#' in rule['Shape'] and '#DividerThickness#' in rule['Shape']
for suffix in ('Label', 'Value'):
    temp = meters['MeterSettingsTemperature' + suffix]
    assert 'LeftMouseUpAction' not in temp and temp['MouseActionCursor'] == '0'
assert meters['MeterSettingsTemperatureValue']['Text'] == 'Driver'
assert meters['MeterSettingsTemperatureClear']['LeftMouseUpAction'] == '[!CommandMeasure MeasureGPUSettings "RefreshGPU()"]'
assert meters['MeterSettingsSensorsValue']['LeftMouseUpAction'] == '[!CommandMeasure MeasureGPUSettings "ToggleSensors()"]'
assert meters['MeterSettingsGlobal']['LeftMouseUpAction'] == '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]'
assert meters['MeterSettingsClose']['LeftMouseUpAction'] == '[!CommandMeasure MeasureGPUSettings "Close()"]'
assert meters['MeterSettingsColumnsValue']['LeftMouseUpAction'] == '[!CommandMeasure MeasureGPUSettings "BeginColumnsEdit()"]'
for side, direction in (('Previous', -1), ('Next', 1)):
    assert meters['MeterSettingsColumns' + side]['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "StepColumns({direction})"]'
    assert meters['MeterSettingsHive' + side]['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "CycleHive({direction})"]'
    for field in ('Power', 'Clock'):
        assert meters['MeterSettings' + field + 'Source' + side]['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "CycleSource(\'{field}\',{direction})"]'
for field in ('Power', 'Clock'):
    for suffix in ('Label', 'Value'):
        assert meters['MeterSettings' + field + suffix]['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "Browse(\'{field}\')"]'
        assert meters['MeterSettings' + field + 'Source' + suffix]['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "CycleSource(\'{field}\')"]'
        assert meters['MeterSettings' + field + 'Source' + suffix].get('Hidden', '0') == '0'
    assert meters['MeterSettings' + field + 'SourceValue']['Text'] == 'Driver'
    assert meters['MeterSettings' + field + 'Clear']['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "Clear(\'{field}\')"]'
for index in range(1, 6):
    row = meters['MeterSettingsPick' + str(index)]
    assert 'StyleUtilitySettingsValue' in row['MeterStyle']
    assert row['LeftMouseUpAction'] == f'[!CommandMeasure MeasureGPUSettings "Select({index})"]'
cases = 0
for width, scale, monitor_columns, title_size in itertools.product(
        (180, 200, 220, 240, 280, 320), (.75, 1, 1.25, 1.5, 2), (1, 2), (6, 10, 12)):
    variables = dict(sections['Variables'], ColumnWidth=str(width), Scale=str(scale), TitleFontSize=str(title_size))
    n = lambda value: api['number'](value, variables)
    bounds = (n('#WindowWidth#'), n('#WindowHeight#'))
    assert n('#Columns#') == 2
    top = lambda field: n(meters['MeterSettings' + field + ('Frame' if field in steppers else 'Value')]['Y'])
    assert top('Height') - top('Columns') == 28 * scale
    fields = ('Temperature', 'PowerSource', 'ClockSource', 'Sensors', 'Hive', 'Key', 'Power', 'Clock')
    for before, after in zip(fields, fields[1:]):
        assert math.isclose(top(after) - top(before), 28 * scale)
    for field in ('Columns', 'Height') + fields:
        label, value = meters['MeterSettings' + field + 'Label'], meters['MeterSettings' + field + 'Value']
        assert math.isclose(n(label['X']), n('#ContentX#'))
        assert math.isclose(n(label['Y']), top(field) + 2 * scale)
        if field in steppers:
            frame = meters['MeterSettings' + field + 'Frame']
            assert math.isclose(n(frame['X']), n('#ContentX#') + 160 * scale)
            assert math.isclose(n(frame['W']), steppers[field] * scale)
            assert math.isclose(n(value['X']) - n(value['W']) / 2, n(frame['X']))
            assert math.isclose(n(value['W']), n(frame['W']))
            assert math.isclose(n(value['Y']), top(field) + scale)
            assert math.isclose(n(frame['H']), 20 * scale)
        else:
            assert math.isclose(n(value['X']), n('#ContentX#') + 140 * scale)
    boxes = {}
    for name, opts in meters.items():
        x, y = n(opts.get('X', '0')), n(opts.get('Y', '0'))
        if name == 'MeterPanel':
            w, h = n('#PanelWidth#'), n('#PanelHeightPx#')
        elif opts['Meter'] == 'Shape':
            w, h = n(opts['W']), n(opts['H'])
        else:
            w, h = n(opts['W']), n(opts['H'])
            padding = [n(v) for v in opts.get('Padding', '0,0,0,0').split(',')]
            w += padding[0] + padding[2]
            h += padding[1] + padding[3]
        if opts['Meter'] == 'String':
            x, y = api['string_origin'](x, y, w, h, opts.get('StringAlign', 'Left'))
        assert min(x, y, w, h) >= 0, (name, width, scale, title_size)
        assert x + w <= bounds[0] and y + h <= bounds[1], (name, width, scale, title_size, bounds)
        if opts['Meter'] == 'String':
            assert opts['ClipString'] == '1', name
            boxes[name] = (x, y, w, h)
    for name, box in boxes.items():
        for other, rect in boxes.items():
            if other <= name:
                continue
            overlap = min(box[0]+box[2],rect[0]+rect[2])-max(box[0],rect[0])
            vertical = min(box[1]+box[3],rect[1]+rect[3])-max(box[1],rect[1])
            assert overlap <= .01 or vertical <= .01, (name, other, width, scale, title_size)
    title, close = meters['MeterSettingsTitle'], meters['MeterSettingsClose']
    assert title['StringAlign'] == 'LeftCenter'
    assert close['StringAlign'] == 'RightCenter'
    assert math.isclose(n(title['Y']), n('#TitleRowCenterY#'))
    assert math.isclose(n(close['Y']), n('#TitleRowCenterY#'))
    cases += 1
print(f'PASS: {len(meters)} settings meters; {cases} independent geometry cases; no string overlap; Accent 1 sections, accessible provider setup, Global-style values and preserved actions.')
print('Offline checks do not validate font rendering, registry exports, or provider behavior.')
