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
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
RESOURCES = ROOT / '@Resources'
TOKEN = re.compile(r'#([^#]+)#')
WIDTHS = (180, 200, 220, 240, 280, 320)
SCALES = (0.75, 1, 1.25, 1.5, 2)
COLUMNS = (1, 2)
CONFIGS = ('Setup.ini', 'Media.ini', 'Queue/Queue.ini', 'Settings/Settings.ini')
EPSILON = 0.001

# Lifecycle.inc gives every view that can resume a provider one hidden launch
# host per provider. Rainmeter's own [] file bang ShellExecutes with a visible
# show state, so console-subsystem powershell.exe is given a console before it
# can parse -WindowStyle Hidden and hide itself; State=Hide creates the process
# hidden instead and nothing is ever shown. The hosts declare no Program,
# Parameter or StartInFolder, so loading a view still launches nothing: only a
# validated MediaLifecycle.ResumeProviders() supplies a command and runs them.
RESUME_HOSTS = ('MeasureMediaSourceResume', 'MeasureMediaQueueResume')
RESUME_HOST_OPTIONS = {'Measure': 'Plugin', 'Plugin': 'RunCommand', 'State': 'Hide',
                       'OutputType': 'UTF8', 'Timeout': '15000', 'UpdateDivider': '-1',
                       'DynamicVariables': '1'}
RESUME_HOST_FORBIDDEN = ('Program', 'Parameter', 'StartInFolder', 'FinishAction',
                         'OnUpdateAction', 'IfCondition', 'IfMatch')


def read_config(name, *, scale=1, columns=1, column_width=220,
                expanded=0, row_limit=5, show_details=1, typography='default', surface=1, bar_thickness=6):
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
                if section != 'Variables':
                    assert section not in seen, f'Duplicate local section: {path} [{section}]'
                    assert section not in sections, f'Duplicate section across includes: {path} [{section}]'
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
                             QueueRowLimit=str(row_limit), QueueShowDetails=str(show_details), DataBarThickness=str(bar_thickness))
            variables.update(TitleFontSize='12' if typography == 'max' else '6' if typography == 'min' else '10',
                             HeaderFontSize='10' if typography == 'max' else '8',
                             FontSize='10' if typography == 'max' else '9',
                             TitleTextColor='211,181,249', HeaderTextColor='110,218,175',
                             TextColor='234,210,145', AccentColor='95,188,246',
                             AccentColor2='246,138,174', BorderThickness=str(surface),
                             DividerThickness=str(surface), DividerColor='219,122,81')

    load(ROOT / 'Media' / name)
    if name=='Settings/Settings.ini':
        # Settings starts from safe collapsed geometry. Initialize applies only
        # the controller's validated binary preference before its first render.
        variables['MediaSettingsQueueDetailsVisible']='1' if variables.get('QueueExpanded')=='1' else '0'
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
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == 'Round':
                assert len(node.args) == 1
                return math.floor(walk(node.args[0]) + 0.5)
            if node.func.id == 'Ceil':
                assert len(node.args) == 1
                return math.ceil(walk(node.args[0]))
            if node.func.id == 'Max':
                assert len(node.args) == 2
                return max(walk(argument) for argument in node.args)
        raise AssertionError(ast.dump(node))
    return walk(ast.parse(expression, mode='eval').body)


def media_body_geometry(width, scale, columns, bar_thickness=6):
    """Physical dimensions from the current anchored-artwork contract."""
    rounded=lambda value: math.floor(value+0.5)
    wide=columns-1
    base_cover=rounded(rounded(width*scale)*0.9) if wide else 48*scale
    legacy_cover=rounded(base_cover*0.75)
    cover=legacy_cover+rounded(20*wide*scale)
    offset=rounded(12*wide*scale)
    legacy_cover_bottom=44*(1-wide)*scale+legacy_cover
    cover_bottom=44*(1-wide)*scale+cover
    bar=max(1,rounded(bar_thickness*scale))
    legacy_progress=offset+122*scale+max(2*scale,6*scale-bar/2)
    legacy_controls_bottom=legacy_progress+bar+34*scale
    progress=offset+(122-20*wide)*scale+max(2*scale,6*scale-bar/2)
    controls_bottom=progress+bar+34*scale
    legacy_body=max(rounded(162*scale)+offset,
                    math.ceil(max(legacy_cover_bottom,legacy_controls_bottom)+37*scale))
    body=max(legacy_body,math.ceil(max(cover_bottom,controls_bottom)+37*scale))
    return cover,offset,body


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

    Only the primitives and fixed offsets used by Media are accepted. Unknown
    primitives or modifiers fail closed instead of silently skipping artwork.
    This excludes antialias coverage and Rainmeter pixel quantization.
    """
    primitive, *modifiers = (part.strip() for part in shape.split('|'))
    kind, coordinates = primitive.split(' ', 1)
    points = [value(part) for part in split_arguments(coordinates)]
    stroke = 1.0  # Rainmeter Shape default, not an unstroked assumption.
    translated=False
    for modifier in modifiers:
        if modifier.startswith('StrokeWidth '):
            stroke = value(modifier[len('StrokeWidth '):])
        elif modifier.startswith(('Fill Color ', 'Stroke Color ',
                                  'StrokeStartCap ', 'StrokeEndCap ',
                                  'StrokeLineJoin ')):
            pass
        elif modifier.startswith('Offset '):
            shift=[value(part) for part in split_arguments(modifier[len('Offset '):])]
            assert len(shift)==2 and not translated, 'Only one fixed Offset is covered'
            offset_x+=shift[0]; offset_y+=shift[1]; translated=True
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


def circular_arc_points(start, coordinates):
    """Endpoint-form Rainmeter circular arc extrema, without a full-circle hull."""
    assert len(coordinates)==7, coordinates
    end_x,end_y,radius,radius_y,rotation,sweep,large=coordinates
    assert radius>0 and abs(radius-radius_y)<EPSILON and rotation==0, 'Only unrotated circular arcs are covered'
    assert sweep in (0,1) and large in (0,1), 'Arc flags must be binary'
    # Rainmeter sweep 1 is counterclockwise: the opposite of SVG's flag.
    svg_sweep=1-sweep
    dx,dy=(start[0]-end_x)/2,(start[1]-end_y)/2
    chord=dx*dx+dy*dy
    assert 0<chord<=radius*radius+EPSILON, 'Unsupported coincident or out-of-radius arc endpoints'
    coefficient=(-1 if large==svg_sweep else 1)*math.sqrt(max(0,(radius*radius-chord)/chord))
    cx=(start[0]+end_x)/2+coefficient*dy
    cy=(start[1]+end_y)/2-coefficient*dx
    first=math.atan2(start[1]-cy,start[0]-cx)
    last=math.atan2(end_y-cy,end_x-cx)
    tau=2*math.pi
    distance=(last-first)%tau if svg_sweep else (first-last)%tau
    points=[list(start),[end_x,end_y]]
    for angle in (0,math.pi/2,math.pi,3*math.pi/2):
        progress=(angle-first)%tau if svg_sweep else (first-angle)%tau
        if progress<=distance+EPSILON:
            points.append([cx+radius*math.cos(angle),cy+radius*math.sin(angle)])
    return points


def meter_bounds(style, value):
    x, y = value(style.get('X', '0')), value(style.get('Y', '0'))
    if style['Meter'] == 'Shape':
        def expanded_shape(shape, stack=()):
            parts=[]
            for part in shape.split('|'):
                part=part.strip()
                if part.startswith('Extend '):
                    reference=part[len('Extend '):]
                    assert reference not in stack, 'Cyclic Shape Extend'
                    parts.append(expanded_shape(style[reference],stack+(reference,)))
                else: parts.append(part)
            return ' | '.join(parts)
        def covered_shape(shape):
            shape=expanded_shape(shape)
            if not shape.startswith('Path '):
                return shape_bounds(shape, value, x, y)
            primitive, *modifiers = [part.strip() for part in shape.split('|')]
            self_path = style[primitive.split(' ', 1)[1]]
            stroke=1.0
            round_join=False
            offset_x,offset_y=x,y
            translated=False
            for modifier in modifiers:
                if modifier.startswith('StrokeWidth '): stroke=value(modifier[len('StrokeWidth '):])
                elif modifier=='StrokeLineJoin Round': round_join=True
                elif modifier in ('StrokeStartCap Round','StrokeEndCap Round'): pass
                elif modifier.startswith('Offset '):
                    shift=[value(part) for part in split_arguments(modifier[len('Offset '):])]
                    assert len(shift)==2 and not translated, 'Only one fixed Offset is covered'
                    offset_x+=shift[0]; offset_y+=shift[1]; translated=True
                else: assert modifier.startswith(('Fill Color ','Stroke Color ')), f'Uncovered Path modifier: {modifier}'
            assert stroke>=0
            parts = self_path.split('|')
            points = []
            position=None
            closed=False
            curved=False
            for index, part in enumerate(parts):
                part = part.strip()
                if part == 'ClosePath 1':
                    assert index == len(parts)-1
                    closed=True
                    continue
                if index:
                    if part.startswith('ArcTo '):
                        coordinates=[value(coordinate) for coordinate in split_arguments(part[len('ArcTo '):])]
                        points.extend(circular_arc_points(position,coordinates))
                        position=coordinates[0:2]
                        curved=True
                        continue
                    if part.startswith('CurveTo '):
                        coordinates=[value(coordinate) for coordinate in split_arguments(part[len('CurveTo '):])]
                        assert len(coordinates)==6, part
                        # Rainmeter: endpoint, control 1, control 2. A cubic
                        # Bezier lies inside the hull of its four points.
                        points.extend([coordinates[0:2],coordinates[2:4],coordinates[4:6]])
                        position=coordinates[0:2]
                        curved=True
                        continue
                    assert part.startswith('LineTo '), part
                    part = part[len('LineTo '):]
                pair = [value(coordinate) for coordinate in split_arguments(part)]
                assert len(pair) == 2
                points.append(pair)
                position=pair
            assert len(points) >= 2
            assert not curved or round_join, 'Curved path joins require bounded round strokes'
            # Conservatively include centered strokes and mitered joins for
            # these fixed straight polylines, including open Spotify paths.
            extent=stroke/2
            join_points=[] if round_join else points[-1:]+points+points[:1] if closed else points
            for a,b,c in zip(join_points,join_points[1:],join_points[2:]):
                u=(b[0]-a[0],b[1]-a[1]); v=(c[0]-b[0],c[1]-b[1])
                length=math.hypot(*u)*math.hypot(*v)
                if stroke and length:
                    cosine=max(-1,min(1,(u[0]*v[0]+u[1]*v[1])/length))
                    extent=max(extent,(stroke/2)*min(10,1/max(0.1,math.sqrt((1+cosine)/2))))
            return Bounds(offset_x+min(p[0] for p in points)-extent, offset_y+min(p[1] for p in points)-extent,
                          offset_x+max(p[0] for p in points)+extent, offset_y+max(p[1] for p in points)+extent)
        shapes = [covered_shape(shape) for key, shape in style.items()
                  if re.fullmatch(r'Shape\d*', key)]
        assert shapes, 'Shape meter has no covered primitives'
        if 'W' in style or 'H' in style:
            assert 'W' in style and 'H' in style, 'Partially specified Shape canvas'
            width, height = value(style['W']), value(style['H'])
            assert (width > 0 and height > 0) or (width == height == 0 and
                value(style.get('Hidden','0')) == 1 and all(b.width == b.height == 0 for b in shapes)), style
            # Also validate an explicit canvas; do not lose invisible extent
            # simply because the icon artwork paints a smaller rectangle.
            shapes.append(Bounds(x, y, x + width, y + height))
        return Bounds(min(b.left for b in shapes), min(b.top for b in shapes),
                      max(b.right for b in shapes), max(b.bottom for b in shapes))
    # ClipString=2 may auto-size within a fixed width cap. Use the cap as
    # the conservative source envelope; native tests measure its actual ink.
    width_option='W' if 'W' in style else 'ClipStringW'
    assert width_option in style and 'H' in style, 'Meter requires bounded W/H'
    if width_option=='ClipStringW':
        assert style['Meter']=='String' and style.get('ClipString')=='2'
    width, height = value(style[width_option]), value(style['H'])
    padding = [value(part) for part in split_arguments(style.get('Padding', '0,0,0,0'))]
    assert len(padding) == 4 and min(padding) >= 0, style
    assert (width > 0 and height > 0) or (width == height == 0 and
        value(style.get('Hidden','0')) == 1 and not any(padding)), style
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
    if 'Container' in style:
        # Rainmeter resolves child coordinates relative to its container.
        # See Library/Meter.cpp GetX/GetY in rainmeter/rainmeter.
        parent = resolve_style(sections, style['Container'])
        assert parent['Meter'] == 'Shape' and 'Container' not in parent
        for axis in ('X', 'Y'):
            style[axis] = f"({parent.get(axis, '0')}+{style.get(axis, '0')})"
    row = re.fullmatch(r'MeterQueueRow([1-5])', meter)
    if config in ('Setup.ini','Media.ini') and row:
        assert style['Y'] == '#Inset#', 'Hidden anchors must not grow native window bounds'
        if expanded and int(row[1]) <= row_limit:
            # QueueReader applies this trusted coordinate only for active rows.
            # The native matrix independently verifies the actual Lua result.
            style['Y'] = f'(#Inset#+#MediaBodyHeightPx#+{2+18*(int(row[1])-1)}*#Scale#)'
    return style


class SkinContractTests(unittest.TestCase):
    def test_duplicate_meter_sections_across_includes_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='Parallax-Media-section-test-') as directory:
            fixture=Path(directory)
            child=fixture/'gear.inc'
            child.write_text('[MeterMediaOptions]\nMeter=Shape\n',encoding='utf-8')
            entry=fixture/'skin.ini'
            entry.write_text(f'[Variables]\n@Include1={child.as_posix()}\n[MeterMediaOptions]\nY=12\n',encoding='utf-8')
            with self.assertRaisesRegex(AssertionError,'Duplicate section across includes'):
                read_config(entry)

    def test_gear_origin_follows_each_entrypoint_header(self):
        for config in ('Media.ini','Setup.ini','Queue/Queue.ini'):
            for columns in COLUMNS:
                for scale in SCALES:
                    with self.subTest(config=config,columns=columns,scale=scale):
                        sections,variables,_,expand=read_config(config,columns=columns,scale=scale)
                        val=lambda v: numeric(expand(v))
                        gear=resolve_style(sections,'MeterMediaOptions')
                        self.assertEqual(gear['Y'],'(#MediaHeaderY#+#TitleRowCenterY#-#Inset#-9*#Scale#)')
                        self.assertEqual(variables['MediaHeaderY'],'#Inset#' if config=='Queue/Queue.ini' else '#MediaSurfaceY#')
                        offset=0 if config=='Queue/Queue.ini' else math.floor(12*(columns-1)*scale+0.5)
                        self.assertAlmostEqual(val(gear['Y']),val('#Inset#')+offset+6*scale)

    def test_player_header_uses_measure_data_and_fixed_icons(self):
        names={'MeterMediaIcon','MeterPlayerIcon'}
        for config in ('Media.ini','Setup.ini'):
            sections,_,visited,_=read_config(config)
            header=sections['MeterHeading']
            self.assertNotIn('MeasureName',header)
            self.assertEqual(header['Text'],'Media Player')
            player=sections['MeterPlayerName']
            self.assertEqual(player['MeasureName'],'MeasureMediaHeader')
            self.assertEqual(player['Text'],'%1')
            self.assertEqual(player['ToolTipText'],'%1')
            self.assertEqual(player['UpdateDivider'],'1')
            self.assertEqual(visited[-1].name,'Header.inc')
            actual={name for name,section in sections.items() if 'Meter' in section and resolve_style(sections,name).get('Group')=='MediaPlayerIcons'}
            self.assertEqual(actual,names)
            self.assertFalse(any(re.fullmatch(r'MeterPlayer\w+Icon', name) for name in sections))
            for name in names:
                icon=resolve_style(sections,name)
                self.assertEqual(icon['Meter'],'Shape')
                self.assertEqual(icon['Hidden'],'0')
                self.assertFalse(any(key.endswith('Action') for key in icon))
            if config=='Media.ini':
                for name in ('MeterSongIcon','MeterArtistIcon','MeterAlbumIcon'):
                    icon=resolve_style(sections,name)
                    self.assertEqual(icon['DynamicVariables'],'1')
                    self.assertEqual(icon['UpdateDivider'],'-1')
                    self.assertEqual(icon['Group'],'MediaTrack')
            for width in (180,220):
                for scale in SCALES:
                    for columns in COLUMNS:
                        for profile in ('default','max'):
                            with self.subTest(config=config,width=width,scale=scale,columns=columns,profile=profile):
                                sections,_,_,expand=read_config(config,column_width=width,scale=scale,columns=columns,typography=profile)
                                val=lambda expression:numeric(expand(expression))
                                box=lambda name:meter_bounds(resolve_style(sections,name),val)
                                surface=val('#MediaSurfaceY#')
                                title_size=val('#TitleIconSize#')
                                self.assertAlmostEqual(box('MeterHeading').left,val('#ContentX#')+title_size+4*scale)
                                expected_heading=97*scale if columns==2 else val('#ContentWidth#')-title_size-28*scale
                                self.assertAlmostEqual(box('MeterHeading').width,expected_heading)
                                self.assertTrue(box('MeterHeading').before(box('MeterMediaOptions')))
                                if columns==2: self.assertTrue(box('MeterHeading').before(box('MeterPlayerIcon')))
                                else: self.assertTrue(box('MeterHeading').above(box('MeterPlayerName')))
                                self.assertAlmostEqual(box('MeterMediaIcon').width,title_size)
                                self.assertAlmostEqual(box('MeterMediaIcon').height,title_size)
                                self.assertAlmostEqual(box('MeterMediaIcon').left,val('#ContentX#'))
                                self.assertAlmostEqual(box('MeterMediaIcon').top+title_size/2,surface+15*scale)
                                self.assertAlmostEqual(box('MeterPlayerIcon').width,14*scale)
                                self.assertAlmostEqual(box('MeterPlayerIcon').height,14*scale)
                                self.assertAlmostEqual(box('MeterPlayerIcon').top,surface+(8 if columns==2 else 32)*scale)
                                self.assertAlmostEqual(box('MeterPlayerName').top,surface+(6 if columns==2 else 30)*scale)
                                self.assertAlmostEqual(box('MeterPlayerName').height,18*scale)
                                self.assertAlmostEqual(box('MeterPlayerName').left-box('MeterPlayerIcon').right,4*scale)
                                self.assertAlmostEqual(box('MeterPlayerName').right,
                                                       val('#ContentX#')+val('#ContentWidth#')-24*(columns-1)*scale)
                                if columns==2:
                                    self.assertAlmostEqual((box('MeterHeading').top+box('MeterHeading').bottom)/2,
                                                           (box('MeterPlayerName').top+box('MeterPlayerName').bottom)/2)
                                style=resolve_style(sections,'MeterPlayerName')
                                self.assertEqual(val(style['FontSize']),(10 if profile=='max' else 9)*scale)
                                self.assertEqual(expand(style['FontColor']),expand('#TextColor#'))
                                self.assertEqual(style['ClipString'],'1')
                                first='MeterTrackTitle' if config=='Media.ini' else 'MeterSetupStatus'
                                self.assertAlmostEqual(box(first).top,surface+(30 if columns==2 else 50)*scale)
                                self.assertTrue(box('MeterPlayerName').above(box(first)))
                                if columns==1:
                                    self.assertAlmostEqual(box('MeterPlayerIcon').left,val('#ContentX#')+54*scale)
                                    self.assertTrue(box('MeterArtworkPlaceholder').before(box('MeterPlayerIcon')))
                                if config=='Media.ini':
                                    self.assertTrue(box('MeterAlbum').above(box('MeterProgress')))
                                    self.assertTrue(box('MeterProgress').above(box('MeterTiming')))
                                else:
                                    self.assertTrue(box('MeterSetupStatus').above(box('MeterSetupInstructions')))
                                    self.assertTrue(box('MeterSetupInstructions').above(box('MeterDesktopNote')))
                                    self.assertTrue(box('MeterDesktopNote').above(box('MeterLoadPlayer')))
                                control='MeterPrevious' if config=='Media.ini' else 'MeterLoadPlayer'
                                self.assertTrue(box(control).above(box('MeterQueueRule')))
                                self.assertEqual(val('#WindowHeight#'),media_body_geometry(width,scale,columns)[2]+val('#Gap#'))

    def test_title_rows_scale_and_center_across_supported_extremes(self):
        for config in CONFIGS:
            for profile,size in (('min',6),('default',10),('max',12)):
                for scale in (0.75,1,2):
                    for width in (180,220):
                        for columns in COLUMNS:
                            with self.subTest(config=config,title=size,scale=scale,width=width,columns=columns):
                                sections,_,_,expand=read_config(config,typography=profile,scale=scale,column_width=width,columns=columns)
                                val=lambda expression: numeric(expand(expression))
                                box=lambda name: meter_bounds(resolve_style(sections,name),val)
                                window=Bounds(0,0,val('#WindowWidth#'),val('#WindowHeight#'))
                                settings=config=='Settings/Settings.ini'
                                queue=config=='Queue/Queue.ini'
                                title_name='MeterTitle' if settings else 'MeterHeading'
                                title=resolve_style(sections,title_name)
                                center=val('#Inset#')+15*scale+(0 if settings or queue else math.floor(12*(columns-1)*scale+0.5))
                                self.assertEqual(title['StringAlign'],'CenterCenter' if settings else 'LeftCenter')
                                self.assertAlmostEqual(val(title['Y']),center)
                                self.assertAlmostEqual((box(title_name).top+box(title_name).bottom)/2,center)
                                self.assertAlmostEqual(box(title_name).height,22*scale)
                                self.assertTrue(box(title_name).inside(window))
                                if settings:
                                    close=resolve_style(sections,'MeterClose')
                                    self.assertEqual(close['StringAlign'],'CenterCenter')
                                    self.assertAlmostEqual(val(close['Y']),center)
                                    self.assertTrue(box(title_name).before(box('MeterClose')))
                                else:
                                    gear=box('MeterMediaOptions')
                                    self.assertAlmostEqual((gear.top+gear.bottom)/2,center)
                                    self.assertTrue(box(title_name).before(gear))
                                    if queue:
                                        self.assertNotIn('MeterMediaIcon',sections)
                                        self.assertAlmostEqual(box('MeterQueueStatus').top,val('#Inset#')+26*scale)
                                        self.assertTrue(box(title_name).above(box('MeterQueueStatus')))
                                    else:
                                        for name in ('MeterMediaIcon',):
                                            icon=resolve_style(sections,name)
                                            expected=14*scale*size/10
                                            self.assertAlmostEqual(box(name).width,expected)
                                            self.assertAlmostEqual(box(name).height,expected)
                                            self.assertAlmostEqual((box(name).top+box(name).bottom)/2,center)
                                            self.assertAlmostEqual(box(title_name).left-box(name).right,4*scale)
                                            if columns==2: self.assertTrue(box(title_name).before(box('MeterPlayerIcon')))
                                            else: self.assertTrue(box(title_name).above(box('MeterPlayerName')))
                                            self.assertTrue(box(name).inside(window))
                                            for key,value in icon.items():
                                                if re.fullmatch(r'Shape\d*|.*Path',key):
                                                    self.assertNotIn('#Scale#',value)

    def test_typography_roles_and_surface_edges(self):
        for config in CONFIGS:
            for profile in ('default','max'):
                for width in (180,220):
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
                                    self.assertEqual(expand(header['FontColor']), '95,188,246' if config=='Settings/Settings.ini' else '110,218,175')
                                body_meter='MeterQueuePollLabel' if config=='Settings/Settings.ini' else 'MeterQueueRow1'
                                body=resolve_style(sections,body_meter)
                                self.assertEqual(val(body['FontSize']), (10 if profile=='max' else 9)*scale)
                                self.assertEqual(expand(body['FontColor']), '234,210,145')
                                if config=='Settings/Settings.ini':
                                    for name in ('Width','QueueExpanded','QueueRows','QueueDetails','QueuePoll'):
                                        self.assertEqual(expand(resolve_style(sections,'Meter'+name+'Value')['FontColor']),'234,210,145')
                                if config=='Media.ini':
                                    for meter in ('MeterTrackTitle','MeterArtist','MeterAlbum'):
                                        metadata=resolve_style(sections,meter)
                                        self.assertEqual(val(metadata['FontSize']),(10 if profile=='max' else 9)*scale)
                                        self.assertEqual(metadata['StringAlign'],'LeftCenter')
                                        self.assertEqual(val(metadata['H']),24*scale)
                                    for meter in ('MeterPrevious','MeterPlayPause','MeterNext'):
                                        control=resolve_style(sections,meter)
                                        self.assertEqual(control['Meter'],'Shape')
                                        self.assertNotIn('FontSize',control)
                                        self.assertEqual(val(control['W']),28*scale)
                                        self.assertEqual(val(control['H']),26*scale)
                                    self.assertEqual(sections['MeterTimingUnavailable']['Text'],'-- / --')
                                    self.assertEqual(val(sections['MeterProgress']['H']),max(1,math.floor(6*scale+0.5)))
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

    def assert_inert_resume_hosts(self, sections):
        """The hosts may hide a launch, but must not be able to start one."""
        for name in RESUME_HOSTS:
            host = sections[name]
            self.assertEqual({key: host.get(key) for key in RESUME_HOST_OPTIONS}, RESUME_HOST_OPTIONS)
            for option in RESUME_HOST_FORBIDDEN:
                self.assertNotIn(option, host, f'{name} cannot declare a launchable {option}')

    def test_provider_free_setup_and_include_order(self):
        sections, _, visited, _ = read_config('Setup.ini')
        # Setup is still the entrypoint that unloads the player: it holds no
        # WebNowPlaying measure and nothing else that can collect or launch,
        # only the two inert hidden hosts a validated resume needs.
        self.assertEqual([name for name, section in sections.items() if 'Plugin' in section],
                         list(RESUME_HOSTS))
        self.assert_inert_resume_hosts(sections)
        scripts = [(name, section) for name, section in sections.items() if 'ScriptFile' in section]
        self.assertEqual([name for name, _ in scripts], ['MeasureMediaOptions', 'MeasureQueueStatus', 'MeasureMediaLifecycle', 'MeasureMediaHeader'])
        self.assertTrue(all(section['Measure'] == 'Script' for _, section in scripts))
        self.assertEqual(scripts[-1][1]['ScriptFile'], '#@#Modules\\Media\\MediaHeader.lua')
        self.assertEqual([p.name for p in visited[1:] if p.name in
                          ('Defaults.inc','Settings.inc','Media.inc','Geometry.inc','Styles.inc')],
                         ['Defaults.inc', 'Settings.inc', 'Media.inc', 'Geometry.inc', 'Styles.inc'])

    def test_lifecycle_is_once_on_view_load_and_absent_from_settings(self):
        for config in ('Media.ini', 'Setup.ini', 'Queue/Queue.ini'):
            sections, _, _, _ = read_config(config)
            self.assertEqual(sections['Rainmeter']['OnRefreshAction'],
                             '[!CommandMeasure MeasureMediaLifecycle "ResumeProviders()"]')
            self.assertEqual(sections['MeasureMediaLifecycle']['UpdateDivider'], '-1')
            self.assert_inert_resume_hosts(sections)
        sections, _, _, _ = read_config('Settings/Settings.ini')
        self.assertNotIn('MeasureMediaLifecycle', sections)
        self.assertNotIn('ResumeProviders', str(sections))
        for host in RESUME_HOSTS:
            self.assertNotIn(host, sections)

    def test_plugin_types_commands_and_script_order(self):
        sections, _, _, _ = read_config('Media.ini')
        expected = {'Status', 'Player', 'Title', 'Artist', 'Album', 'Cover', 'State',
                    'Position', 'Duration', 'Progress', 'SupportsSkipPrevious',
                    'SupportsPlayPause', 'SupportsSkipNext'}
        plugins = [s for s in sections.values() if s.get('Plugin') == 'WebNowPlaying']
        self.assertEqual({s['PlayerType'] for s in plugins}, expected)
        measures = [name for name, s in sections.items() if 'Measure' in s]
        self.assertEqual(measures[-1], 'MeasureMediaHeader')
        self.assertLess(measures.index('MeasureMediaUI'), measures.index('MeasureMediaHeader'))
        self.assertEqual(sections['MeasureSourceArtist']['Plugin'], 'WebNowPlaying')
        self.assertEqual(sections['MeasureSourceArtist']['PlayerType'], 'Artist')
        self.assertNotIn('Substitute', sections['MeasureSourceArtist'])
        self.assertIn('Substitute', sections['MeasureArtist'])
        self.assertEqual(sections['MeasureMediaSource']['Measure'], 'Script')
        self.assertEqual(sections['MeasureMediaSource']['ScriptFile'], '#@#Modules\\Media\\Source\\SourceReader.lua')
        self.assertLess(measures.index('MeasureSourceArtist'), measures.index('MeasureMediaSource'))
        self.assertLess(measures.index('MeasureCanNext'), measures.index('MeasureMediaSource'))
        self.assertLess(measures.index('MeasureMediaSource'), measures.index('MeasureMediaUI'))
        self.assertEqual(sections['MeterPlayerName']['MeasureName'],'MeasureMediaHeader')
        self.assertNotIn('MeterConnection', sections)
        self.assertFalse(any(s.get('Meter') and s.get('MeasureName') in ('MeasureMediaSource','MeasureMediaUI')
                             for s in sections.values()), 'Playback/source status remains visible')
        for meter_name, command in [('MeterPrevious', 'Previous'), ('MeterPlayPause', 'PlayPause'), ('MeterNext', 'Next')]:
            self.assertEqual(sections[meter_name]['LeftMouseUpAction'],
                             f'[!CommandMeasure "MeasureMediaUI" "Control(\'{command}\')"]')

    def test_settings_persistence_and_no_provider_launch_in_actions(self):
        prefix = '["powershell.exe" "-NoLogo" "-NoProfile" "-ExecutionPolicy" "Bypass" '
        provider = '"-File" "#@#Modules\\Media\\Queue\\QueueProvider.ps1" "-Command" '
        powershell = r'%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe'
        queue_allowed = {
            ('Rainmeter', 'ContextAction4'): '[!CommandMeasure MeasureQueueControl "Run(\'Disconnect\')"]',
            ('Rainmeter', 'ContextAction5'): '[!CommandMeasure MeasureQueueControl "Run(\'ResumeQuota\')"]',
            ('MeterQueueConnect', 'LeftMouseUpAction'): prefix + '"-NoExit" ' + provider + '"Connect" "-PollSeconds" "#QueuePollSeconds#"]',
            ('MeterQueueStart', 'LeftMouseUpAction'): '[!CommandMeasure MeasureQueueControl "Run(\'Start\')"]',
            ('MeterQueueStop', 'LeftMouseUpAction'): '[!CommandMeasure MeasureQueueControl "Run(\'Stop\')"]',
            ('MeasureQueueProviderControl', 'Plugin'): 'RunCommand',
            ('MeasureQueueProviderControl', 'Program'): powershell,
            ('MeasureQueueProviderControl', 'Parameter'): '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "Stop" -Quiet',
        }
        interval = ' "-PollSeconds" "#QueuePollSeconds#"'
        settings_allowed = {
            ('MeterSignIn','LeftMouseUpAction'): prefix+'"-NoExit" '+provider+'"Connect"'+interval+']',
            ('MeterStart','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Queue\',\'Start\')"]',
            ('MeterStop','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Queue\',\'Stop\')"]',
            ('MeterRestart','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Queue\',\'Restart\')"]',
            ('MeterDisconnect','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Queue\',\'Disconnect\')"]',
        }
        settings_allowed.update({
            ('MeterSourceStart','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Source\',\'Start\')"]',
            ('MeterSourceStop','LeftMouseUpAction'): '[!CommandMeasure MeasureMediaSettings "ProviderControl(\'Source\',\'Stop\')"]',
        })
        settings_allowed.update({
            ('MeasureMediaSettingsInput','Plugin'):'RunCommand',
            ('MeasureMediaSettingsInput','Program'):powershell,
            ('MeasureMediaSettingsInput','Parameter'):'-NoProfile -NonInteractive',
            ('MeasureMediaSettingsInput','FinishAction'):'[!UpdateMeasure MeasureMediaSettingsInput][!CommandMeasure MeasureMediaSettings "CommitNumberInput()"]',
            ('MeasureMediaSourceControl','Plugin'):'RunCommand',
            ('MeasureMediaSourceControl','Program'):powershell,
            ('MeasureMediaSourceControl','Parameter'):'-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "SourceProvider.ps1" -Command "Stop" -Quiet',
            ('MeasureMediaQueueControl','Plugin'):'RunCommand',
            ('MeasureMediaQueueControl','Program'):powershell,
            ('MeasureMediaQueueControl','Parameter'):'-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "Stop" -Quiet',
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
            # Every lifecycle view owns the two inert hidden hosts. They are the
            # only RunCommand named here without a command: the launch itself
            # still comes from a validated resume, never from the skin file.
            lifecycle_allowed = {(host, 'Plugin'): 'RunCommand' for host in RESUME_HOSTS}
            allowed = dict(settings_allowed) if name == 'Settings/Settings.ini' else dict(lifecycle_allowed)
            if name == 'Queue/Queue.ini':
                allowed.update(queue_allowed)
            for section_name, s in sections.items():
                for key, value in s.items():
                    if (section_name, key) in allowed:
                        self.assertEqual(value, allowed[(section_name, key)])
                    elif 'Action' in key or key in ('Plugin', 'Program', 'Parameter'):
                        self.assertNotRegex(value.lower(), r'python|powershell|cmd\.exe|runcommand|spotify:|authorize')
            for section_name, key in allowed:
                self.assertIn(key, sections[section_name])
            self.assertFalse(any(key.startswith(('OnUpdate', 'OnClose'))
                                 for key in config), 'No polling or close-time helper action')
            if name == 'Settings/Settings.ini':
                self.assertNotIn('OnRefreshAction', config)
            else:
                self.assertEqual(config['OnRefreshAction'],
                                 '[!CommandMeasure MeasureMediaLifecycle "ResumeProviders()"]')
            if name == 'Queue/Queue.ini':
                for section_name, key in allowed:
                    self.assertIn(key, sections[section_name])
                self.assertEqual([n for n, s in sections.items() if s.get('Plugin')],
                                 list(RESUME_HOSTS) + ['MeasureQueueProviderControl'])
                self.assertEqual([s['Plugin'] for s in sections.values() if s.get('Plugin')], ['RunCommand'] * 3)
                self.assertEqual([s['ScriptFile'] for s in sections.values() if 'ScriptFile' in s],
                                 ['#@#Modules\\Media\\MediaLifecycle.lua',
                                  '#@#Modules\\Media\\Queue\\QueueReader.lua',
                                  '#@#Modules\\Media\\Queue\\QueueControl.lua'])
                self.assertNotIn('QueueCachePath', sections['MeasureQueueStatus'])

    def test_accordion_and_settings_controls_have_bounded_persisted_preferences(self):
        for name in ('Media.ini', 'Setup.ini'):
            sections, variables, _, _ = read_config(name)
            self.assertEqual(sections['MeasureQueueStatus']['QueueExpanded'], '#QueueExpanded#')
            self.assertEqual(sections['MeasureQueueStatus']['QueueInline'], '1')
            for meter in ('MeterQueueHeading', 'MeterQueueToggle', 'MeterQueueStatus'):
                self.assertEqual(sections[meter]['LeftMouseUpAction'],
                                 '[!CommandMeasure MeasureMediaOptions "ToggleQueue()"]')
            toggle=sections['MeterQueueToggle']
            self.assertEqual(toggle['Meter'],'Shape')
            self.assertEqual(toggle['DynamicVariables'],'1')
            self.assertIn('StrokeWidth (2*14*#Scale#/24*(1-#QueueExpanded#))',toggle['Shape6'])
            self.assertNotIn('Extend',toggle['Shape6'], 'Expansion must control the actual vertical stroke')
            self.assertEqual(sections['MeterQueueHeading']['StringAlign'],'LeftCenter')
            self.assertEqual(sections['MeterQueueStatus']['StringAlign'],'LeftCenter')
            self.assertEqual(variables['PanelHeight'], '162')
            for row in range(1, 6):
                style = resolve_style(sections, f'MeterQueueRow{row}')
                self.assertEqual(style['Group'], 'QueueRows')
                self.assertEqual(style['Hidden'], '1')
        sections, variables, visited, expand = read_config('Settings/Settings.ini')
        self.assertEqual(variables['PanelHeight'],'162')
        self.assertEqual(sections['Variables']['MediaSettingsQueueDetailsVisible'],'0')
        self.assertEqual(numeric(expand('#SettingsPanelHeight#')),498)
        self.assertEqual(sections['Rainmeter']['ContextAction2'],'["#CONFIGEDITOR#" "#@#User\\Media.inc"]')
        self.assertIn('SettingsMeters.inc',[path.name for path in visited])
        self.assertEqual(variables['SettingsUtilityName'],'Media')
        self.assertIn('UtilitySettingsNote.inc',[path.name for path in visited])
        self.assertEqual(sections['MeterUtilitySettingsNote']['Text'],'#SettingsUtilityName# settings are found here.')
        self.assertEqual(sections['MeterUtilitySettingsGlobalLink']['LeftMouseUpAction'],
                         '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]')
        for meter, function in [('QueueExpanded','ToggleQueueExpanded'),('QueueDetails','ToggleQueueDetails')]:
            self.assertEqual(sections[f'Meter{meter}Value']['LeftMouseUpAction'],
                             f'[!CommandMeasure MeasureMediaSettings "{function}()"]')
            self.assertEqual(sections[f'Meter{meter}Label']['LeftMouseUpAction'],sections[f'Meter{meter}Value']['LeftMouseUpAction'])
        for meter,key in [('Width','Columns'),('QueueRows','QueueRowLimit'),('QueuePoll','QueuePollSeconds')]:
            for part in ('Label','Frame','Value'):
                self.assertEqual(sections[f'Meter{meter}{part}']['LeftMouseUpAction'],
                                 f'''[!CommandMeasure MeasureMediaSettings "BeginNumberInput('{key}')"]''')
            for part,direction in [('Decrease',-1),('Increase',1)]:
                self.assertEqual(sections[f'Meter{meter}{part}']['LeftMouseUpAction'],
                                 f'''[!CommandMeasure MeasureMediaSettings "StepNumber('{key}',{direction})"]''')
        plugins=[(name,s) for name,s in sections.items() if s.get('Plugin')]
        self.assertEqual([name for name,s in plugins],
                         ['MeasureMediaSettingsInput','MeasureMediaSourceControl','MeasureMediaQueueControl'])
        input_measure=plugins[0][1]
        for key,value in {'Plugin':'RunCommand','State':'Hide','OutputType':'UTF8','Timeout':'300000','UpdateDivider':'-1'}.items():
            self.assertEqual(input_measure[key],value)
        self.assertEqual(input_measure['Parameter'],'-NoProfile -NonInteractive')
        self.assertNotIn('Run',input_measure['FinishAction'])
        for name,folder,script in (
                ('MeasureMediaSourceControl','#@#Modules\\Media\\Source\\','SourceProvider.ps1'),
                ('MeasureMediaQueueControl','#@#Modules\\Media\\Queue\\','QueueProvider.ps1')):
            control=sections[name]
            for key,value in {'Plugin':'RunCommand','State':'Hide','OutputType':'UTF8',
                              'Timeout':'15000','UpdateDivider':'-1','DynamicVariables':'1'}.items():
                self.assertEqual(control[key],value)
            self.assertEqual(control['StartInFolder'],folder)
            self.assertIn(f'-File "{script}" -Command "Stop" -Quiet',control['Parameter'])
            self.assertIn('-NonInteractive -WindowStyle Hidden',control['Parameter'])
        self.assertEqual([s['ScriptFile'] for s in sections.values() if 'ScriptFile' in s],
                         ['#@#Modules\\Media\\Settings.lua'])
        for width in (180,220):
            for scale in SCALES:
                for columns in COLUMNS:
                    for profile,expanded in ((p,e) for p in ('default','max') for e in (0,1)):
                        with self.subTest(settings_width=width,scale=scale,columns=columns,profile=profile,expanded=expanded):
                            sections,variables,_,expand=read_config('Settings/Settings.ini',scale=scale,column_width=width,columns=columns,typography=profile,expanded=expanded)
                            val=lambda expression:numeric(expand(expression))
                            box=lambda name:meter_bounds(resolve_style(sections,name),val)
                            panel=Bounds(val('#Inset#'),val('#Inset#'),val('#WindowWidth#')-val('#Inset#'),val('#WindowHeight#')-val('#Inset#'))
                            shift=0 if expanded else 56
                            self.assertEqual(val('#WindowHeight#'),math.floor((554-shift)*scale+0.5)+val('#Gap#'))
                            self.assertEqual(variables['Columns'],str(columns))
                            self.assertEqual(variables['PanelHeight'],'162')
                            for name,section in sections.items():
                                if 'Meter' in section and name!='MeterBounds': self.assertTrue(box(name).inside(panel),name)
                            for stem,y in [('Width',100),('QueueExpanded',128),('QueueRows',156),('QueueDetails',184),('QueuePoll',244)]:
                                label,value='Meter'+stem+'Label','Meter'+stem+'Value'
                                numeric_field=stem in ('Width','QueueRows','QueuePoll')
                                parts=[label,value]+(['Meter'+stem+p for p in ('Decrease','Frame','Increase')] if numeric_field else [])
                                hidden=not expanded and stem in ('QueueRows','QueueDetails')
                                if hidden:
                                    for name in parts:
                                        style=resolve_style(sections,name)
                                        self.assertEqual(val(style['Hidden']),1)
                                        self.assertEqual(box(name).width,0)
                                        self.assertEqual(box(name).height,0)
                                        self.assertEqual(box(name).top,val('#Inset#'))
                                elif numeric_field:
                                    decrease,frame,increase=['Meter'+stem+p for p in ('Decrease','Frame','Increase')]
                                    self.assertTrue(box(label).before(box(decrease)))
                                    self.assertTrue(box(decrease).before(box(frame)))
                                    self.assertTrue(box(frame).before(box(increase)))
                                    self.assertAlmostEqual(box(increase).right-box(decrease).left,96*scale)
                                    self.assertAlmostEqual(box(frame).left,val('#ContentX#')+142*scale)
                                    self.assertAlmostEqual(box(frame).height,20*scale)
                                    self.assertAlmostEqual(box(value).width,56*scale)
                                    self.assertAlmostEqual(box(value).height,18*scale)
                                    self.assertAlmostEqual(box(value).top,box(frame).top+scale)
                                    self.assertTrue(box(value).inside(box(frame)))
                                    self.assertAlmostEqual(box(frame).top,val('#Inset#')+(y-(shift if stem=='QueuePoll' else 0))*scale)
                                else:
                                    self.assertTrue(box(label).before(box(value)))
                                    self.assertAlmostEqual(box(value).left,val('#ContentX#')+122*scale)
                                    self.assertAlmostEqual(box(value).height,20*scale)
                                self.assertNotIn('SolidColor',resolve_style(sections,label))
                                if numeric_field:
                                    self.assertIn('#GraphBackgroundColor#',resolve_style(sections,'Meter'+stem+'Frame')['Shape'])
                                    self.assertEqual(resolve_style(sections,value)['FontColor'],'#TextColor#')
                                    self.assertEqual(resolve_style(sections,'Meter'+stem+'Decrease')['FontColor'],'#AccentColor#')
                                else: self.assertEqual(resolve_style(sections,value)['SolidColor'],'#GraphBackgroundColor#')
                            for name,y in [('MeterSamplingHeading',218),('MeterStatus',272),('MeterSourceLabel',302),
                                           ('MeterQueueHeading',386),('MeterLinksHeading',498)]:
                                self.assertAlmostEqual(box(name).top,val('#Inset#')+(y-shift)*scale)
                            for name in ('MeterQueueExpandedLabel','MeterQueueExpandedValue','MeterSourceStart','MeterSourceStop',
                                         'MeterSignIn','MeterStart','MeterStop','MeterRestart','MeterDisconnect','MeterOpenQueue','MeterPlayerSetup','MeterHelp'):
                                self.assertGreater(box(name).width,0)
                                self.assertEqual(val(resolve_style(sections,name).get('Hidden','0')),0)
                            for stem in ('Display','Sampling','Source','Queue','Links'):
                                rule=resolve_style(sections,'Meter'+stem+'Rule')
                                self.assertIn('#DividerColor#',rule['Shape'])
                                self.assertNotIn('#TableHeaderBorderColor#',rule['Shape'])
                            for name in ('MeterDisplayHeading','MeterSamplingHeading','MeterSourceLabel','MeterQueueHeading','MeterLinksHeading'):
                                self.assertEqual(expand(resolve_style(sections,name)['FontColor']),expand('#AccentColor#'))
                            self.assertEqual(sections['MeterClose']['LeftMouseUpAction'],'[!DeactivateConfig]')

    def test_meters_remain_inside_window_for_all_layouts(self):
        checked = 0
        self.assertEqual(len(list(layout_states())), 1320)
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
                expected_height = math.floor(((554 if expanded else 498) if name == 'Settings/Settings.ini' else 162)*scale+0.5)
                if name in ('Setup.ini','Media.ini'):
                    expected_height=media_body_geometry(column_width,scale,columns)[2]+math.floor(expanded*(8+18*rows)*scale+0.5)
                self.assertEqual(window.height, expected_height+val('#Gap#'))
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
                        if any('Mouse' in k and k.endswith('Action') for k in style):
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
                    self.assertTrue(box('MeterPlayerIcon').before(box('MeterPlayerName')))
                    if columns==2: self.assertTrue(box('MeterHeading').before(box('MeterPlayerIcon')))
                    else: self.assertTrue(box('MeterHeading').above(box('MeterPlayerName')))
                    self.assertTrue(box('MeterHeading').before(box('MeterMediaOptions')))
                    self.assertTrue(box('MeterQueueHeading').before(box('MeterQueueToggle')))
                    self.assertTrue(box('MeterQueueToggle').before(box('MeterQueueStatus')))
                    if expanded:
                        self.assertTrue(box('MeterQueueHeading').above(box('MeterQueueRow1')))
                        for row in range(1, rows):
                            self.assertTrue(box(f'MeterQueueRow{row}').above(box(f'MeterQueueRow{row+1}')))
                else:
                    self.assertTrue(box('MeterTitle').before(box('MeterClose')))
                    pairs = ('Width', 'QueueExpanded', 'QueueRows', 'QueueDetails', 'QueuePoll') if expanded else ('Width','QueueExpanded','QueuePoll')
                    for label in pairs:
                        self.assertTrue(box(f'Meter{label}Label').before(box(f'Meter{label}Value')))
                    for previous, following in zip(pairs, pairs[1:]):
                        self.assertTrue(box(f'Meter{previous}Value').above(box(f'Meter{following}Value')))
                    self.assertTrue(box('MeterQueuePollValue').above(box('MeterSourceLabel')))
                    self.assertTrue(box('MeterSourceLabel').above(box('MeterSourceStart')))
                    self.assertTrue(box('MeterSourceStart').before(box('MeterSourceStop')))
                    self.assertTrue(box('MeterStatus').above(box('MeterSourceLabel')))
                    self.assertTrue(box('MeterSourceStart').above(box('MeterSourceGuidance')))
                    self.assertTrue(box('MeterSourceStop').above(box('MeterSourceGuidance')))
                    for controls in [('MeterSignIn','MeterStart','MeterStop'), ('MeterRestart','MeterDisconnect'),
                                     ('MeterOpenQueue','MeterPlayerSetup','MeterHelp')]:
                        for previous, following in zip(controls, controls[1:]):
                            self.assertTrue(box(previous).before(box(following)))
                    continue
                if name == 'Media.ini':
                    for icon, label in [('MeterSongIcon','MeterTrackTitle'),('MeterArtistIcon','MeterArtist'),('MeterAlbumIcon','MeterAlbum')]:
                        self.assertEqual(sections[icon]['Meter'],'Shape')
                        self.assertEqual(resolve_style(sections,icon)['Group'],'MediaTrack')
                        self.assertTrue(box(icon).before(box(label)), icon)
                        self.assertAlmostEqual(box(icon).width,14*scale)
                        self.assertAlmostEqual(box(icon).height,14*scale)
                    for meter in ('MeterTrackTitle', 'MeterArtist', 'MeterAlbum'):
                        self.assertTrue(box('MeterCover').before(box(meter)), meter)
                        self.assertGreaterEqual(box(meter).width / scale, 90, meter)
                    self.assertTrue(box('MeterTrackTitle').above(box('MeterArtist')))
                    self.assertTrue(box('MeterArtist').above(box('MeterAlbum')))
                    if columns == 1:
                        self.assertTrue(box('MeterCover').above(box('MeterProgress')))
                    else:
                        self.assertTrue(box('MeterCover').before(box('MeterProgress')))
                    self.assertTrue(box('MeterProgress').above(box('MeterTiming')))
                    self.assertTrue(box('MeterNext').before(box('MeterTiming')))
                    self.assertTrue(box('MeterNext').before(box('MeterTimingUnavailable')))
                    self.assertEqual(resolve_style(sections,'MeterTiming')['StringAlign'],'Right')
                    self.assertEqual(resolve_style(sections,'MeterTimingUnavailable')['StringAlign'],'Right')
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
                    width_option='W' if 'W' in style else 'ClipStringW'
                    self.assertIn(width_option, style)
                    if width_option=='ClipStringW':
                        self.assertEqual(style.get('ClipString'),'2')
                    self.assertIn('H', style)
                    self.assertIn(style.get('ClipString'), ('1', '2'))
                    # A bound long label is confined by positive, constant dimensions.
                    for option in (width_option, 'H'):
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
                                cover_size,surface_offset,body_height=media_body_geometry(width,scale,columns)
                                base_cover=math.floor(math.floor(width*scale+0.5)*0.9+0.5) if wide else 48*scale
                                old_metadata_x=inset+(base_cover+8*scale if wide else padding+54*scale)
                                art=box('MeterArtworkPlaceholder')
                                self.assertAlmostEqual(art.width,cover_size)
                                self.assertAlmostEqual(art.width,math.floor(base_cover*0.75+0.5)+math.floor(20*wide*scale+0.5))
                                self.assertAlmostEqual(art.height,art.width)
                                self.assertAlmostEqual(art.left,inset+padding*(1-wide))
                                self.assertAlmostEqual(art.top,inset+44*(1-wide)*scale)
                                self.assertAlmostEqual(box('MeterPanel').left,inset+96*wide*scale)
                                self.assertAlmostEqual(box('MeterPanel').top,inset+surface_offset)
                                self.assertAlmostEqual(box('MeterPanel').right,inset+val('#PanelWidth#'))
                                self.assertAlmostEqual(val('#MediaBodyHeightPx#'),body_height)
                                self.assertAlmostEqual(box('MeterQueueHeading').top,inset+body_height-21*scale)
                                queue_x=box('MeterPanel').left+padding
                                queue_right=box('MeterPanel').right-padding
                                self.assertAlmostEqual(box('MeterQueueHeading').left,queue_x)
                                self.assertAlmostEqual(box('MeterQueueHeading').width,42*scale)
                                self.assertAlmostEqual(box('MeterQueueToggle').left,queue_x+44*scale)
                                self.assertAlmostEqual(box('MeterQueueToggle').width,18*scale)
                                self.assertAlmostEqual(box('MeterQueueToggle').top,box('MeterQueueHeading').top)
                                self.assertAlmostEqual(box('MeterQueueStatus').left,queue_x+66*scale)
                                self.assertAlmostEqual(box('MeterQueueStatus').right,queue_right)
                                self.assertGreaterEqual(val(sections['MeterQueueRule']['Y']),art.bottom+8*scale-0.5)
                                if expanded:
                                    self.assertAlmostEqual(box('MeterQueueRow1').top,inset+body_height+2*scale)
                                    for row in range(1,6):
                                        self.assertAlmostEqual(box('MeterQueueRow'+str(row)).left,queue_x)
                                        self.assertAlmostEqual(box('MeterQueueRow'+str(row)).right,queue_right)
                                self.assertEqual(val(sections['MeterArtworkPlaceholder']['Hidden']),1-wide)
                                self.assertEqual(val(sections['MeterArtworkLabel']['Hidden']),1-wide)
                                if config=='Media.ini':
                                    for timing in ('MeterTiming','MeterTimingUnavailable'):
                                        self.assertAlmostEqual(box(timing).top-box('MeterProgress').bottom,2*scale)
                                        self.assertAlmostEqual(box(timing).right,box('MeterProgress').right)
                                    for row,name in enumerate(('MeterTrackTitle','MeterArtist','MeterAlbum')):
                                        self.assertAlmostEqual(box(name).left,old_metadata_x+20*scale)
                                        self.assertAlmostEqual(box(name).width,box('MeterPanel').right-padding-old_metadata_x-20*scale)
                                        self.assertAlmostEqual(box(name).top,inset+surface_offset+(50-20*wide+row*24)*scale)
                                        icon=('MeterSongIcon','MeterArtistIcon','MeterAlbumIcon')[row]
                                        self.assertAlmostEqual((box(name).top+box(name).bottom)/2,(box(icon).top+box(icon).bottom)/2)
                                    self.assertEqual(box('MeterCover'),art)
                                    self.assertEqual(box('MeterCoverPlaceholder'),art)
                                    self.assertEqual(box('MeterCoverMask'),art)
                                    self.assertEqual(box('MeterCoverFrame'),art)
                                    self.assertEqual(sections['MeterCover']['Container'],'MeterCoverMask')
                                    self.assertEqual(sections['MeterCover']['X'],'0')
                                    self.assertEqual(sections['MeterCover']['Y'],'0')
                                    self.assertNotIn('MediaTrack',sections['MeterCoverMask'].get('Group',''))
                                    self.assertEqual(val(sections['MeterCoverMask'].get('Hidden','0')),0)
                                    self.assertEqual(sections['MeterCover']['PreserveAspectRatio'],'2')
                                rounded=['MeterArtworkPlaceholder']
                                if config=='Media.ini': rounded+=['MeterCoverPlaceholder','MeterCoverMask','MeterCoverFrame']
                                for meter in rounded:
                                    shape=sections[meter]['Shape']
                                    primitive,*modifiers=[part.strip() for part in shape.split('|')]
                                    self.assertTrue(primitive.startswith('Rectangle '))
                                    coordinates=[val(v) for v in split_arguments(primitive[len('Rectangle '):])]
                                    self.assertEqual(len(coordinates),5)
                                    framed=meter in ('MeterArtworkPlaceholder','MeterCoverFrame')
                                    self.assertAlmostEqual(coordinates[4],(6+4*wide-(0.5 if framed else 0))*scale)
                                    stroke=next(val(m[len('StrokeWidth '):]) for m in modifiers if m.startswith('StrokeWidth '))
                                    self.assertAlmostEqual(stroke,scale if framed else 0)
                                    if framed:
                                        self.assertIn('Stroke Color 255,255,255',modifiers)
                                if wide:
                                    self.assertAlmostEqual(val('#ContentX#'),art.right+8*scale)
                                    self.assertAlmostEqual(val('#ContentX#')-art.right,8*scale)
                                    self.assertAlmostEqual(box('MeterPanel').top-art.top,surface_offset)
                                    self.assertAlmostEqual(box('MeterHeading').top,inset+surface_offset+4*scale)
                                    self.assertAlmostEqual(box('MeterMediaOptions').top,inset+surface_offset+6*scale)
                                    if config=='Media.ini':
                                        self.assertAlmostEqual(box('MeterTrackTitle').top,inset+surface_offset+30*scale)
                                        self.assertAlmostEqual(box('MeterArtist').top-box('MeterTrackTitle').top,24*scale)
                                        self.assertAlmostEqual(box('MeterAlbum').top-box('MeterArtist').top,24*scale)
                                        self.assertTrue(box('MeterHeading').above(box('MeterTrackTitle')))
                                    meters=['MeterMediaIcon','MeterHeading']
                                    meters+=['MeterSongIcon','MeterArtistIcon','MeterAlbumIcon','MeterTrackTitle','MeterArtist','MeterAlbum','MeterTiming','MeterProgress'] if config=='Media.ini' else ['MeterSetupStatus','MeterSetupInstructions','MeterDesktopNote','MeterWNPDocs']
                                    for meter in meters:
                                        self.assertTrue(art.before(box(meter)),meter)
                                else:
                                    self.assertAlmostEqual(val('#ContentX#'),inset+padding)
                                    if config=='Media.ini':
                                        self.assertAlmostEqual(box('MeterTrackTitle').left,val('#ContentX#')+74*scale)
        self.assertEqual([media_body_geometry(width,1,2)[2] for width in (180,220,320)],[214,214,273])
        for thickness in (1,6,6.25,12):
            for width in (180,220,320):
                for scale in (0.75,1,2):
                    for columns in COLUMNS:
                        with self.subTest(thickness=thickness,width=width,scale=scale,columns=columns):
                            sections,_,_,expand=read_config('Media.ini',scale=scale,columns=columns,column_width=width,bar_thickness=thickness)
                            val=lambda expression:numeric(expand(expression))
                            box=lambda name:meter_bounds(resolve_style(sections,name),val)
                            self.assertEqual(box('MeterProgress').height,max(1,math.floor(thickness*scale+0.5)))
                            self.assertGreaterEqual(box('MeterProgress').top-box('MeterAlbum').bottom,2*scale-EPSILON)
                            for timing in ('MeterTiming','MeterTimingUnavailable'):
                                self.assertAlmostEqual(box(timing).top-box('MeterProgress').bottom,2*scale)
                                self.assertAlmostEqual(box(timing).right,box('MeterProgress').right)
                            self.assertAlmostEqual(box('MeterPrevious').top-box('MeterProgress').bottom,8*scale)
                            self.assertGreaterEqual(val(sections['MeterQueueRule']['Y'])-box('MeterNext').bottom,8*scale-EPSILON)
                            self.assertEqual(val('#MediaBodyHeightPx#'),media_body_geometry(width,scale,columns,thickness)[2])

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
