"""Offline Media include/geometry checks. Not a Rainmeter rendering emulator.

Developer-only stdlib test: no dependency install, live config, or provider access.
"""
import ast
from collections import OrderedDict
from dataclasses import dataclass
import math
import operator
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
RESOURCES = ROOT / '@Resources'
TOKEN = re.compile(r'#([^#]+)#')
WIDTHS = (180, 200, 240, 280, 320)
SCALES = (0.75, 1, 1.25, 1.5, 2)
COLUMNS = (1, 2)
CONFIGS = ('Setup.ini', 'Media.ini', 'Queue/Queue.ini', 'Settings/Settings.ini')
EPSILON = 0.001


def read_config(name, *, scale=1, columns=1, column_width=200,
                expanded=0, row_limit=5, show_details=1, typography='default', surface=1):
    sections = OrderedDict()
    variables = {'@': str(RESOURCES) + '/', 'CRLF': '\n'}
    visited = []

    def expand(value):
        for _ in range(50):
            changed = TOKEN.sub(lambda m: str(variables.get(m[1], m[0])), value)
            if changed == value:
                return value
            value = changed
        raise AssertionError('Variable cycle')

    def load(path):
        assert path.is_file(), path
        assert path not in visited, f'Duplicate or cyclic include: {path}'
        visited.append(path)
        section = None
        seen = set()
        for raw in path.read_text(encoding='utf-8-sig').splitlines():
            line = raw.strip()
            if not line or line.startswith(';'):
                continue
            if line.startswith('[') and line.endswith(']'):
                section = line[1:-1]
                assert section not in seen, f'Duplicate local section: {path} [{section}]'
                seen.add(section)
                sections.setdefault(section, {})
                continue
            key, value = line.split('=', 1)
            if key.lower().startswith('@include'):
                load(Path(expand(value).replace('\\', '/')))
            else:
                sections[section][key] = value
                if section == 'Variables':
                    variables[key] = value
        if path == RESOURCES / 'User' / 'Media.inc':
            # Simulate preserved user overrides, before geometry is included.
            variables.update(Scale=str(scale), Columns=str(columns),
                             ColumnWidth=str(column_width), QueueExpanded=str(expanded),
                             QueueRowLimit=str(row_limit), QueueShowDetails=str(show_details))
            variables.update(TitleFontSize='12' if typography == 'max' else '10',
                             HeaderFontSize='10' if typography == 'max' else '8',
                             FontSize='10' if typography == 'max' else '9',
                             TitleTextColor='211,181,249', HeaderTextColor='110,218,175',
                             TextColor='234,210,145', AccentColor='95,188,246',
                             AccentColor2='246,138,174', BorderThickness=str(surface),
                             DividerThickness=str(surface), DividerColor='219,122,81')

    load(ROOT / 'Media' / name)
    return sections, variables, visited, expand


def numeric(expression):
    """Evaluate only the arithmetic subset actually used by this module."""
    def walk(node):
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            return node.value
        if isinstance(node, ast.BinOp):
            fn = {ast.Add: operator.add, ast.Sub: operator.sub,
                  ast.Mult: operator.mul, ast.Div: operator.truediv}[type(node.op)]
            return fn(walk(node.left), walk(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -walk(node.operand)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'Round':
            assert len(node.args) == 1
            return math.floor(walk(node.args[0]) + 0.5)
        raise AssertionError(ast.dump(node))
    return walk(ast.parse(expression, mode='eval').body)


def split_arguments(text):
    """Split coordinates without splitting commas inside formula parentheses."""
    parts, start, depth = [], 0, 0
    for index, character in enumerate(text):
        if character == '(':
            depth += 1
        elif character == ')':
            depth -= 1
        elif character == ',' and depth == 0:
            parts.append(text[start:index].strip())
            start = index + 1
        assert depth >= 0, text
    assert depth == 0, text
    parts.append(text[start:].strip())
    return parts


@dataclass(frozen=True)
class Bounds:
    left: float
    top: float
    right: float
    bottom: float

    @property
    def width(self):
        return self.right - self.left

    @property
    def height(self):
        return self.bottom - self.top

    def inside(self, other):
        return (self.left >= other.left - EPSILON and
                self.top >= other.top - EPSILON and
                self.right <= other.right + EPSILON and
                self.bottom <= other.bottom + EPSILON)

    def before(self, other):
        return self.right <= other.left + EPSILON

    def above(self, other):
        return self.bottom <= other.top + EPSILON


def resolve_style(sections, name, stack=()):
    assert name not in stack, f'Cyclic MeterStyle: {stack + (name,)}'
    section = sections[name]
    merged = {}
    for reference in section.get('MeterStyle', '').split('|'):
        if reference.strip():
            reference = reference.strip()
            assert 'Meter' not in sections[reference], f'Drawing style: {reference}'
            merged.update(resolve_style(sections, reference, stack + (name,)))
    merged.update(section)
    return merged


def shape_bounds(shape, value, offset_x=0, offset_y=0):
    """Conservative geometric bounds, including the centered stroke.

    Only the untransformed primitives used by Media are accepted. Unknown
    primitives or modifiers fail closed instead of silently skipping artwork.
    This excludes antialias coverage and Rainmeter pixel quantization.
    """
    primitive, *modifiers = (part.strip() for part in shape.split('|'))
    kind, coordinates = primitive.split(' ', 1)
    points = [value(part) for part in split_arguments(coordinates)]
    stroke = 1.0  # Rainmeter Shape default, not an unstroked assumption.
    for modifier in modifiers:
        if modifier.startswith('StrokeWidth '):
            stroke = value(modifier[len('StrokeWidth '):])
        elif modifier.startswith(('Fill Color ', 'Stroke Color ',
                                  'StrokeStartCap ', 'StrokeEndCap ',
                                  'StrokeLineJoin ')):
            pass
        else:
            raise AssertionError(f'Uncovered Shape modifier: {modifier}')
    assert stroke >= 0, shape
    if kind == 'Rectangle':
        assert len(points) in (4, 5, 6), shape
        x, y, width, height = points[:4]
        assert width >= 0 and height >= 0, shape
        left, top, right, bottom = x, y, x + width, y + height
    elif kind == 'Line':
        assert len(points) == 4, shape
        left, right = sorted((points[0], points[2]))
        top, bottom = sorted((points[1], points[3]))
    elif kind == 'Ellipse':
        assert len(points) in (3, 4), shape
        x, y, radius_x = points[:3]
        radius_y = points[3] if len(points) == 4 else radius_x
        assert radius_x >= 0 and radius_y >= 0, shape
        left, top, right, bottom = x-radius_x, y-radius_y, x+radius_x, y+radius_y
    else:
        raise AssertionError(f'Uncovered Shape primitive: {kind}')
    half_stroke = stroke / 2
    return Bounds(offset_x + left - half_stroke, offset_y + top - half_stroke,
                  offset_x + right + half_stroke, offset_y + bottom + half_stroke)


def meter_bounds(style, value):
    x, y = value(style.get('X', '0')), value(style.get('Y', '0'))
    if style['Meter'] == 'Shape':
        def covered_shape(shape):
            if not shape.startswith('Path '):
                return shape_bounds(shape, value, x, y)
            primitive, *modifiers = [part.strip() for part in shape.split('|')]
            self_path = style[primitive.split(' ', 1)[1]]
            assert modifiers == ['Fill Color #AccentColor2#', 'StrokeWidth 0'], shape
            parts = self_path.split('|')
            points = []
            for index, part in enumerate(parts):
                part = part.strip()
                if part == 'ClosePath 1':
                    assert index == len(parts)-1
                    continue
                if index:
                    assert part.startswith('LineTo '), part
                    part = part[len('LineTo '):]
                pair = [value(coordinate) for coordinate in split_arguments(part)]
                assert len(pair) == 2
                points.append(pair)
            assert len(points) >= 3
            return Bounds(x+min(p[0] for p in points), y+min(p[1] for p in points),
                          x+max(p[0] for p in points), y+max(p[1] for p in points))
        shapes = [covered_shape(shape) for key, shape in style.items()
                  if re.fullmatch(r'Shape\d*', key)]
        assert shapes, 'Shape meter has no covered primitives'
        if 'W' in style or 'H' in style:
            assert 'W' in style and 'H' in style, 'Partially specified Shape canvas'
            width, height = value(style['W']), value(style['H'])
            assert width > 0 and height > 0, style
            # Also validate an explicit canvas; do not lose invisible extent
            # simply because the icon artwork paints a smaller rectangle.
            shapes.append(Bounds(x, y, x + width, y + height))
        return Bounds(min(b.left for b in shapes), min(b.top for b in shapes),
                      max(b.right for b in shapes), max(b.bottom for b in shapes))
    assert 'W' in style and 'H' in style, 'Meter requires fixed W/H'
    width, height = value(style['W']), value(style['H'])
    assert width > 0 and height > 0, style
    padding = [value(part) for part in split_arguments(style.get('Padding', '0,0,0,0'))]
    assert len(padding) == 4 and min(padding) >= 0, style
    width += padding[0] + padding[2]
    height += padding[1] + padding[3]
    if style['Meter'] == 'String':
        alignment = style.get('StringAlign', 'Left')
        assert re.fullmatch(r'(Left|Center|Right)(Top|Center|Bottom)?', alignment), alignment
        if alignment.startswith('Center'):
            x -= width / 2
        elif alignment.startswith('Right'):
            x -= width
        vertical = re.sub(r'^(Left|Center|Right)', '', alignment)
        if vertical == 'Center':
            y -= height / 2
        elif vertical == 'Bottom':
            y -= height
    return Bounds(x, y, x + width, y + height)


def layouts():
    for name in CONFIGS:
        for column_width in WIDTHS:
            for scale in SCALES:
                for columns in COLUMNS:
                    yield name, column_width, scale, columns


def layout_states():
    for name, width, scale, columns in layouts():
        if name in ('Setup.ini', 'Media.ini'):
            for expanded in (0, 1):
                for rows in range(1, 6):
                    yield name, width, scale, columns, expanded, rows
        else:
            yield name, width, scale, columns, 0, 5


def presentation_style(sections, meter, config, expanded, row_limit):
    style = resolve_style(sections, meter)
    row = re.fullmatch(r'MeterQueueRow([1-5])', meter)
    if config in ('Setup.ini','Media.ini') and row:
        assert style['Y'] == '#Inset#', 'Hidden anchors must not grow native window bounds'
        if expanded and int(row[1]) <= row_limit:
            # QueueReader applies this trusted coordinate only for active rows.
            # The native matrix independently verifies the actual Lua result.
            style['Y'] = f'(#Inset#+(#PanelHeight#+{2+18*(int(row[1])-1)})*#Scale#)'
    return style


class SkinContractTests(unittest.TestCase):
    def test_typography_roles_and_surface_edges(self):
        for config in CONFIGS:
            for profile in ('default','max'):
                for width in (180,200):
                    for scale in SCALES:
                        for surface in (0,4):
                            with self.subTest(config=config,profile=profile,width=width,scale=scale,surface=surface):
                                sections, _, _, expand = read_config(config, column_width=width, scale=scale,
                                    expanded=1, typography=profile, surface=surface)
                                val=lambda expression: numeric(expand(expression))
                                title='MeterTitle' if config=='Settings/Settings.ini' else 'MeterHeading'
                                title_style=resolve_style(sections,title)
                                self.assertEqual(val(title_style['FontSize']), (12 if profile=='max' else 10)*scale)
                                self.assertEqual(expand(title_style['FontColor']), '211,181,249')
                                if config!='Queue/Queue.ini':
                                    header=resolve_style(sections,'MeterQueueHeading')
                                    self.assertEqual(val(header['FontSize']), (10 if profile=='max' else 8)*scale)
                                    self.assertEqual(expand(header['FontColor']), '110,218,175')
                                body_meter='MeterQueuePollLabel' if config=='Settings/Settings.ini' else 'MeterQueueRow1'
                                body=resolve_style(sections,body_meter)
                                self.assertEqual(val(body['FontSize']), (10 if profile=='max' else 9)*scale)
                                self.assertEqual(expand(body['FontColor']), '234,210,145')
                                secondary='MeterStop' if config=='Settings/Settings.ini' else 'MeterQueueStop' if config=='Queue/Queue.ini' else 'MeterMediaOptions'
                                secondary_style=resolve_style(sections,secondary)
                                secondary_color=secondary_style.get('FontColor',secondary_style.get('Shape'))
                                self.assertIn('246,138,174',expand(secondary_color))
                                rule=resolve_style(sections,'MeterQueueRule')
                                self.assertIn('#DividerColor#',rule['Shape'])
                                self.assertIn('#DividerThickness#',rule['Shape'])
                                panel=resolve_style(sections,'MeterPanel')
                                self.assertIn('#BorderThickness#',panel['Shape'])
                                window=Bounds(0,0,val('#WindowWidth#'),val('#WindowHeight#'))
                                self.assertTrue(meter_bounds(panel,val).inside(window))
                                self.assertTrue(meter_bounds(rule,val).inside(window))

    def test_provider_free_setup_and_include_order(self):
        sections, _, visited, _ = read_config('Setup.ini')
        self.assertFalse(any('Plugin' in section for section in sections.values()))
        scripts = [(name, section) for name, section in sections.items() if 'ScriptFile' in section]
        self.assertEqual([name for name, _ in scripts], ['MeasureMediaOptions', 'MeasureQueueStatus'])
        self.assertTrue(all(section['Measure'] == 'Script' for _, section in scripts))
        self.assertEqual(scripts[-1][1]['ScriptFile'], '#@#Modules\\Media\\Queue\\QueueReader.lua')
        self.assertEqual([p.name for p in visited[1:] if p.name in
                          ('Defaults.inc','Settings.inc','Media.inc','Geometry.inc','Styles.inc')],
                         ['Defaults.inc', 'Settings.inc', 'Media.inc', 'Geometry.inc', 'Styles.inc'])

    def test_plugin_types_commands_and_script_order(self):
        sections, _, _, _ = read_config('Media.ini')
        expected = {'Status', 'Player', 'Title', 'Artist', 'Album', 'Cover', 'State',
                    'Position', 'Duration', 'Progress', 'SupportsSkipPrevious',
                    'SupportsPlayPause', 'SupportsSkipNext'}
        plugins = [s for s in sections.values() if s.get('Plugin') == 'WebNowPlaying']
        self.assertEqual({s['PlayerType'] for s in plugins}, expected)
        measures = [name for name, s in sections.items() if 'Measure' in s]
        self.assertEqual(measures[-1], 'MeasureMediaUI')
        self.assertEqual(sections['MeasureSourceArtist']['Plugin'], 'WebNowPlaying')
        self.assertEqual(sections['MeasureSourceArtist']['PlayerType'], 'Artist')
        self.assertNotIn('Substitute', sections['MeasureSourceArtist'])
        self.assertIn('Substitute', sections['MeasureArtist'])
        self.assertEqual(sections['MeasureMediaSource']['Measure'], 'Script')
        self.assertEqual(sections['MeasureMediaSource']['ScriptFile'], '#@#Modules\\Media\\Source\\SourceReader.lua')
        self.assertLess(measures.index('MeasureSourceArtist'), measures.index('MeasureMediaSource'))
        self.assertLess(measures.index('MeasureCanNext'), measures.index('MeasureMediaSource'))
        self.assertLess(measures.index('MeasureMediaSource'), measures.index('MeasureMediaUI'))
        self.assertEqual(sections['MeterPlayerName']['MeasureName'], 'MeasureMediaSource')
        for meter_name, command in [('MeterPrevious', 'Previous'), ('MeterPlayPause', 'PlayPause'), ('MeterNext', 'Next')]:
            self.assertEqual(sections[meter_name]['LeftMouseUpAction'],
                             f'[!CommandMeasure "MeasureMediaUI" "Control(\'{command}\')"]')

    def test_settings_persistence_and_no_provider_launch_in_actions(self):
        prefix = '["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" '
        provider = '"-File" "#@#Modules\\Media\\Queue\\QueueProvider.ps1" "-Command" '
        hidden = '"-WindowStyle" "Hidden" '
        queue_allowed = {
            ('Rainmeter', 'ContextAction4'): prefix + hidden + provider + '"Disconnect" "-Quiet"]',
            ('Rainmeter', 'ContextAction5'): prefix + hidden + provider + '"Start" "-ResumeAfterQuota" "-Quiet"]',
            ('MeterQueueConnect', 'LeftMouseUpAction'): prefix + '"-NoExit" ' + provider + '"Connect" "-PollSeconds" "#QueuePollSeconds#"]',
            ('MeterQueueStart', 'LeftMouseUpAction'): prefix + hidden + provider + '"Start" "-PollSeconds" "#QueuePollSeconds#" "-Quiet"]',
            ('MeterQueueStop', 'LeftMouseUpAction'): prefix + hidden + provider + '"Stop" "-Quiet"]',
        }
        interval = ' "-PollSeconds" "#QueuePollSeconds#"'
        settings_allowed = {
            ('MeterSignIn','LeftMouseUpAction'): prefix+'"-NoExit" '+provider+'"Connect"'+interval+']',
            ('MeterStart','LeftMouseUpAction'): prefix+hidden+provider+'"Start"'+interval+' "-Quiet"]',
            ('MeterStop','LeftMouseUpAction'): prefix+hidden+provider+'"Stop" "-Quiet"]',
            ('MeterRestart','LeftMouseUpAction'): prefix+hidden+provider+'"Restart"'+interval+' "-Quiet"]',
            ('MeterDisconnect','LeftMouseUpAction'): prefix+hidden+provider+'"Disconnect" "-Quiet"]',
        }
        source_provider='"-File" "#@#Modules\\Media\\Source\\SourceProvider.ps1" "-Command" '
        settings_allowed.update({
            ('MeterSourceStart','LeftMouseUpAction'): prefix+hidden+source_provider+'"Start" "-Quiet"]',
            ('MeterSourceStop','LeftMouseUpAction'): prefix+hidden+source_provider+'"Stop" "-Quiet"]',
        })
        for name in CONFIGS:
            sections, variables, _, _ = read_config(name, columns=2)
            self.assertEqual(variables['Columns'], '2')
            config = sections['Rainmeter']
            self.assertEqual(config['Group'], 'Parallax')
            self.assertIn('Parallax\\Settings', config['ContextAction'])
            if name != 'Settings/Settings.ini':
                for index, columns in [(2, 1), (3, 2)]:
                    action = config[f'ContextAction{index}']
                    self.assertIn(f'"Columns" "{columns}" "#@#User\\Media.inc"', action)
                    self.assertTrue(action.endswith('[!Refresh]'))
                self.assertEqual(config['MouseOverAction'], '[!ShowMeter MeterMediaOptions][!Redraw]')
                self.assertEqual(config['MouseLeaveAction'], '[!HideMeter MeterMediaOptions][!Redraw]')
                self.assertEqual(sections['MeterMediaOptions']['Hidden'], '1')
                self.assertEqual(sections['MeterMediaOptions']['LeftMouseUpAction'],
                                 '[!ActivateConfig "Parallax\\Media\\Settings" "Settings.ini"]')
            allowed = queue_allowed if name == 'Queue/Queue.ini' else settings_allowed if name == 'Settings/Settings.ini' else {}
            for section_name, s in sections.items():
                for key, value in s.items():
                    if (section_name, key) in allowed:
                        self.assertEqual(value, allowed[(section_name, key)])
                    elif 'Action' in key or key in ('Plugin', 'Program', 'Parameter'):
                        self.assertNotRegex(value.lower(), r'python|powershell|cmd\.exe|runcommand|spotify:|authorize')
            for section_name, key in allowed:
                self.assertIn(key, sections[section_name])
            self.assertFalse(any(key.startswith(('OnRefresh', 'OnUpdate', 'OnClose'))
                                 for key in config), 'No automatic helper start or stop')
            if name == 'Queue/Queue.ini':
                for section_name, key in allowed:
                    self.assertIn(key, sections[section_name])
                self.assertFalse(any(s.get('Plugin') for s in sections.values()))
                self.assertEqual([s['ScriptFile'] for s in sections.values() if 'ScriptFile' in s],
                                 ['#@#Modules\\Media\\Queue\\QueueReader.lua'])
                self.assertNotIn('QueueCachePath', sections['MeasureQueueStatus'])

    def test_accordion_and_settings_controls_have_bounded_persisted_preferences(self):
        for name in ('Media.ini', 'Setup.ini'):
            sections, variables, _, _ = read_config(name)
            self.assertEqual(sections['MeasureQueueStatus']['QueueExpanded'], '#QueueExpanded#')
            self.assertEqual(sections['MeasureQueueStatus']['QueueInline'], '1')
            for meter in ('MeterQueueHeading', 'MeterQueueStatus'):
                self.assertEqual(sections[meter]['LeftMouseUpAction'],
                                 '[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]')
            self.assertEqual(variables['PanelHeight'], '162')
            for row in range(1, 6):
                style = resolve_style(sections, f'MeterQueueRow{row}')
                self.assertEqual(style['Group'], 'QueueRows')
                self.assertEqual(style['Hidden'], '1')
        sections, _, _, _ = read_config('Settings/Settings.ini')
        for meter, function in [('Width', 'ToggleColumns'), ('QueueExpanded', 'ToggleQueueExpanded'),
                                ('QueueRows', 'CycleQueueRows'), ('QueueDetails', 'ToggleQueueDetails'),
                                ('QueuePoll', 'CycleQueuePoll')]:
            self.assertEqual(sections[f'Meter{meter}Value']['LeftMouseUpAction'],
                             f'[!CommandMeasure MeasureMediaSettings "{function}()"]')
        self.assertFalse(any(s.get('Plugin') for s in sections.values()))
        self.assertEqual([s['ScriptFile'] for s in sections.values() if 'ScriptFile' in s],
                         ['#@#Modules\\Media\\Settings.lua'])

    def test_meters_remain_inside_window_for_all_layouts(self):
        checked = 0
        self.assertEqual(len(list(layout_states())), 1100)
        for name, column_width, scale, columns, expanded, rows in layout_states():
            with self.subTest(config=name, width=column_width, scale=scale, columns=columns, expanded=expanded, rows=rows):
                sections, _, _, expand = read_config(name, scale=scale, columns=columns,
                                                     column_width=column_width, expanded=expanded, row_limit=rows)
                val = lambda v: numeric(expand(v))
                window = Bounds(0, 0, val('#WindowWidth#'), val('#WindowHeight#'))
                inset = val('#Inset#')
                panel = Bounds(inset, inset, window.right-inset, window.bottom-inset)
                expected_columns = 2 if name == 'Settings/Settings.ini' else columns
                self.assertEqual(window.width, expected_columns * (val('#UnitWidth#') + val('#Gap#')))
                logical_height = 360 if name == 'Settings/Settings.ini' else 162
                if name in ('Setup.ini','Media.ini'):
                    logical_height += expanded * (8+18*rows)
                self.assertEqual(window.height, math.floor(logical_height*scale+0.5)+val('#Gap#'))
                self.assertEqual(val('#UnitWidth#'), math.floor(column_width * scale + 0.5))
                self.assertEqual(val('#Gap#') % 2, 0)
                for section_name, section in sections.items():
                    if 'MeterStyle' in section:
                        self.assertIn('Meter', section, section_name)
                    if 'Meter' not in section:
                        continue
                    style = presentation_style(sections, section_name, name, expanded, rows)
                    bounds = meter_bounds(style, val)
                    inline_row = re.fullmatch(r'MeterQueueRow([1-5])', section_name)
                    if inline_row and name in ('Setup.ini','Media.ini') and (not expanded or int(inline_row[1])>rows):
                        # Inactive rows have zero native dimensions, but even
                        # their anchor must remain inside the collapsed bounds.
                        self.assertLessEqual(val(style['Y']), window.height)
                        continue
                    self.assertTrue(bounds.inside(window), f'{section_name}: {bounds} outside {window}')
                    if section_name == 'MeterBounds':
                        self.assertEqual(bounds, window)
                        self.assertEqual(style.get('SolidColor'), '0,0,0,0')
                    else:
                        # Includes the panel stroke: it must not paint the snap gutter.
                        self.assertTrue(bounds.inside(panel), f'{section_name}: {bounds} outside {panel}')
                    if style['Meter'] == 'String':
                        self.assertIn(style.get('ClipString'), ['1', '2'], section_name)
                        self.assertIn('FontFace', style, section_name)
                        if any(k.endswith('Action') for k in style):
                            self.assertTrue(style.get('ToolTipText'), section_name)
                    checked += 1
        self.assertGreater(checked, 2400)

    def test_compact_rows_and_controls_do_not_collide(self):
        """Check competing visible content, not intentionally overlaid states."""
        for name, column_width, scale, columns, expanded, rows in layout_states():
            with self.subTest(config=name, width=column_width, scale=scale, columns=columns, expanded=expanded, rows=rows):
                sections, _, _, expand = read_config(name, scale=scale, columns=columns,
                                                     column_width=column_width, expanded=expanded, row_limit=rows)
                val = lambda v: numeric(expand(v))
                box = lambda meter: meter_bounds(presentation_style(sections, meter, name, expanded, rows), val)
                if name == 'Queue/Queue.ini':
                    self.assertTrue(box('MeterHeading').before(box('MeterMediaOptions')))
                    self.assertTrue(box('MeterHeading').above(box('MeterQueueStatus')))
                    self.assertTrue(box('MeterQueueStatus').above(box('MeterQueueRow1')))
                    for index in range(1, 6):
                        row = f'MeterQueueRow{index}'
                        self.assertGreaterEqual(box(row).width / scale, 160)
                        self.assertTrue(box(row).above(box('MeterQueueRule')))
                        if index < 5:
                            self.assertTrue(box(row).above(box(f'MeterQueueRow{index+1}')))
                    controls = ('MeterQueueConnect', 'MeterQueueStart', 'MeterQueueStop')
                elif name != 'Settings/Settings.ini':
                    self.assertTrue(box('MeterMediaIcon').before(box('MeterHeading')))
                    self.assertTrue(box('MeterHeading').before(box('MeterMediaOptions')))
                    self.assertTrue(box('MeterQueueHeading').before(box('MeterQueueStatus')))
                    if expanded:
                        self.assertTrue(box('MeterQueueHeading').above(box('MeterQueueRow1')))
                        for row in range(1, rows):
                            self.assertTrue(box(f'MeterQueueRow{row}').above(box(f'MeterQueueRow{row+1}')))
                else:
                    self.assertTrue(box('MeterTitle').before(box('MeterClose')))
                    pairs = ('Width', 'QueueExpanded', 'QueueRows', 'QueueDetails', 'QueuePoll')
                    for label in pairs:
                        self.assertTrue(box(f'Meter{label}Label').before(box(f'Meter{label}Value')))
                    for previous, following in zip(pairs, pairs[1:]):
                        self.assertTrue(box(f'Meter{previous}Value').above(box(f'Meter{following}Value')))
                    self.assertTrue(box('MeterQueuePollValue').above(box('MeterSourceLabel')))
                    self.assertTrue(box('MeterSourceLabel').before(box('MeterSourceStart')))
                    self.assertTrue(box('MeterSourceStart').before(box('MeterSourceStop')))
                    self.assertTrue(box('MeterSourceStart').above(box('MeterStatus')))
                    self.assertTrue(box('MeterSourceStop').above(box('MeterStatus')))
                    for controls in [('MeterSignIn','MeterStart','MeterStop'), ('MeterRestart','MeterDisconnect'),
                                     ('MeterOpenQueue','MeterPlayerSetup','MeterHelp')]:
                        for previous, following in zip(controls, controls[1:]):
                            self.assertTrue(box(previous).before(box(following)))
                    continue
                if name == 'Media.ini':
                    self.assertTrue(box('MeterConnection').before(box('MeterPlayerName')))
                    for meter in ('MeterTrackTitle', 'MeterArtist', 'MeterAlbum'):
                        self.assertTrue(box('MeterCover').before(box(meter)), meter)
                        self.assertGreaterEqual(box(meter).width / scale, 100, meter)
                    self.assertTrue(box('MeterTrackTitle').above(box('MeterArtist')))
                    self.assertTrue(box('MeterArtist').above(box('MeterAlbum')))
                    if columns == 1:
                        self.assertTrue(box('MeterCover').above(box('MeterProgress')))
                    else:
                        self.assertTrue(box('MeterCover').before(box('MeterProgress')))
                    self.assertTrue(box('MeterProgress').above(box('MeterTiming')))
                    self.assertTrue(box('MeterTiming').before(box('MeterPrevious')))
                    self.assertTrue(box('MeterTimingUnavailable').before(box('MeterPrevious')))
                    controls = ('MeterPrevious', 'MeterPlayPause', 'MeterNext')
                elif name == 'Setup.ini':
                    self.assertTrue(box('MeterSetupStatus').above(box('MeterSetupInstructions')))
                    self.assertTrue(box('MeterSetupInstructions').above(box('MeterDesktopNote')))
                    self.assertTrue(box('MeterDesktopNote').above(box('MeterLoadPlayer')))
                    controls = ('MeterWNPDocs', 'MeterLoadPlayer')
                for previous, following in zip(controls, controls[1:]):
                    self.assertTrue(box(previous).before(box(following)), (previous, following))
                for meter in controls:
                    self.assertGreaterEqual(box(meter).width / scale, 20 - EPSILON, meter)
                    self.assertGreaterEqual(box(meter).height / scale, 18 - EPSILON, meter)
                    if name == 'Queue/Queue.ini':
                        self.assertTrue(box('MeterQueueRule').above(box(meter)), meter)
                    else:
                        self.assertTrue(box(meter).above(box('MeterQueueRule')), meter)

    def test_bound_metadata_cannot_expand_the_panel(self):
        for config in CONFIGS:
            sections, _, _, expand = read_config(config, column_width=180, scale=0.75)
            for name, section in sections.items():
                if section.get('Meter') != 'String' or not ('MeasureName' in section or re.fullmatch(r'MeterQueueRow[1-5]', name)):
                    continue
                with self.subTest(config=config, meter=name):
                    style = resolve_style(sections, name)
                    self.assertIn('W', style)
                    self.assertIn('H', style)
                    self.assertIn(style.get('ClipString'), ('1', '2'))
                    # A bound long label is confined by positive, constant dimensions.
                    for option in ('W', 'H'):
                        self.assertNotIn('[', expand(style[option]))
                        self.assertGreater(numeric(expand(style[option])), 0)

    def test_layered_artwork_preserves_outer_pitch_and_content_clearance(self):
        for config in ('Setup.ini', 'Media.ini'):
            for width in WIDTHS:
                for scale in SCALES:
                    for columns in COLUMNS:
                        for expanded in (0, 1):
                            with self.subTest(config=config,width=width,scale=scale,columns=columns,expanded=expanded):
                                sections, _, _, expand = read_config(config,column_width=width,scale=scale,
                                    columns=columns,expanded=expanded,typography='max')
                                val=lambda v: numeric(expand(v))
                                box=lambda meter: meter_bounds(presentation_style(sections,meter,config,expanded,5),val)
                                inset,padding=val('#Inset#'),val('#Padding#')
                                wide=columns-1
                                art=box('MeterArtworkPlaceholder')
                                self.assertAlmostEqual(art.width,(48+96*wide)*scale)
                                self.assertAlmostEqual(art.height,art.width)
                                self.assertAlmostEqual(art.left,inset+padding*(1-wide))
                                self.assertAlmostEqual(art.top,inset+(44-35*wide)*scale)
                                self.assertAlmostEqual(box('MeterPanel').left,inset+96*wide*scale)
                                self.assertAlmostEqual(box('MeterPanel').right,inset+val('#PanelWidth#'))
                                self.assertEqual(val(sections['MeterArtworkPlaceholder']['Hidden']),1-wide)
                                self.assertEqual(val(sections['MeterArtworkLabel']['Hidden']),1-wide)
                                if config=='Media.ini':
                                    self.assertEqual(box('MeterCover'),art)
                                    self.assertEqual(box('MeterCoverPlaceholder'),art)
                                    self.assertEqual(sections['MeterCover']['PreserveAspectRatio'],'2')
                                if wide:
                                    self.assertAlmostEqual(val('#ContentX#'),inset+156*scale)
                                    self.assertAlmostEqual(val('#ContentX#')-art.right,12*scale)
                                    meters=['MeterMediaIcon','MeterHeading','MeterQueueHeading','MeterQueueStatus']
                                    meters+=['MeterTrackTitle','MeterArtist','MeterAlbum','MeterConnection','MeterTiming','MeterProgress'] if config=='Media.ini' else ['MeterSetupStatus','MeterSetupInstructions','MeterDesktopNote','MeterWNPDocs']
                                    if expanded: meters += ['MeterQueueRow'+str(n) for n in range(1,6)]
                                    for meter in meters:
                                        self.assertTrue(art.before(box(meter)),meter)
                                else:
                                    self.assertAlmostEqual(val('#ContentX#'),inset+padding)
                                    if config=='Media.ini':
                                        self.assertAlmostEqual(box('MeterTrackTitle').left,val('#ContentX#')+54*scale)

    def test_geometry_checker_accounts_for_strokes_ellipses_and_anchors(self):
        panel = Bounds(0, 0, 180, 158)
        self.assertTrue(shape_bounds('Rectangle 0.5,0.5,179,157,3 | StrokeWidth 1', numeric).inside(panel))
        self.assertFalse(shape_bounds('Rectangle 0,0,180,158,3 | StrokeWidth 1', numeric).inside(panel))
        self.assertEqual(shape_bounds('Ellipse 5,10,3,2 | StrokeWidth 0', numeric), Bounds(2, 8, 8, 12))
        self.assertEqual(shape_bounds('Line 10,2,0,2 | StrokeWidth 2', numeric), Bounds(-1, 1, 11, 3))
        button = {'Meter': 'String', 'X': '50', 'Y': '20', 'W': '20', 'H': '18',
                  'StringAlign': 'CenterCenter', 'Padding': '3,1,3,1'}
        self.assertEqual(meter_bounds(button, numeric), Bounds(37, 10, 63, 30))
        with self.assertRaisesRegex(AssertionError, 'Uncovered Shape'):
            shape_bounds('Rectangle 0,0,5,5 | Rotate 30', numeric)


if __name__ == '__main__':
    unittest.main()
