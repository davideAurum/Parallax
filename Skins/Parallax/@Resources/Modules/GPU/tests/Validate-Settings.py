"""Offline bounds and interaction wiring checks for the GPU settings utility."""
import contextlib
import io
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
assert sections['Variables']['PanelHeight'] == '422'
assert sections['MeasureGPUSettings']['UpdateDivider'] == '-1'
assert 'OnRefreshAction' not in sections['Rainmeter'], 'opening must not launch discovery'
meters = {name: api['effective'](name) for name, opts in sections.items() if 'Meter' in opts}
cases = 0
for width in (180, 200, 240, 280, 320):
    for scale in (.75, 1, 1.25, 1.5, 2):
        for monitor_columns in (1, 2):
            variables = dict(sections['Variables'], ColumnWidth=str(width), Scale=str(scale))
            n = lambda value: api['number'](value, variables)
            bounds = (n('#WindowWidth#'), n('#WindowHeight#'))
            assert n('#Columns#') == 2
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
                alignment = opts.get('StringAlign', '').lower()
                if alignment == 'right':
                    x -= w
                elif alignment == 'center':
                    x -= w / 2
                assert min(x, y, w, h) >= 0, (name, width, scale)
                assert x + w <= bounds[0] and y + h <= bounds[1], (name, width, scale, bounds)
                if opts['Meter'] == 'String':
                    assert opts['ClipString'] == '1', name
                    boxes[name] = (x, y, w, h)
            for name, box in boxes.items():
                for other, rect in boxes.items():
                    if other <= name:
                        continue
                    overlap = min(box[0]+box[2],rect[0]+rect[2])-max(box[0],rect[0])
                    vertical = min(box[1]+box[3],rect[1]+rect[3])-max(box[1],rect[1])
                    assert overlap <= .01 or vertical <= .01, (name, other, width, scale)
            cases += 1
print(f'PASS: {len(meters)} settings meters; {cases} independent geometry cases; no string overlap.')
print('Offline checks do not validate font rendering, registry exports, or provider behavior.')
