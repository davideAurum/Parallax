"""Offline Media include/geometry checks. Not a Rainmeter rendering emulator.

Developer-only stdlib test: no dependency install, live config, or provider access.
"""
from collections import OrderedDict
from dataclasses import dataclass
import functools
import math
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
RESOURCES = ROOT / '@Resources'
TOKEN = re.compile(r'#([^#]+)#')
SHAPE_KEY = re.compile(r'Shape\d*')
WIDTHS = (180, 200, 220, 240, 280, 320)
SCALES = (0.75, 1, 1.25, 1.5, 2)
COLUMNS = (1, 2)
CONFIGS = ('Setup.ini', 'Media.ini', 'Queue/Queue.ini', 'Settings/Settings.ini')
EPSILON = 0.001
# User\Media.inc VisualizerDrawer: 0 hidden, 1 collapsed (tab only), 2 open.
DRAWER_STATES = (0, 1, 2)
# The Audio settings Height presets that have a HeightPresets\<n>.inc file.
HEIGHT_PRESETS = (126, 146, 186)
# Measures the open spectrum drawer adds through Visualizer\Capture.inc.
CAPTURE_CHILDREN = (('MeasureVisualizerDevice', 'MeasureVisualizerFormat', 'MeasureVisualizerRMS') +
                    tuple(f'MeasureVisualizerBand{index}' for index in range(24)))
DRAWER_METERS = ('MeterVisualizerSheet', 'MeterVisualizerToggle')
OPEN_DRAWER_METERS = ('MeterVisualizerPlot', 'MeterVisualizerUnavailable',
                      'MeterVisualizerSpectrumMask', 'MeterVisualizerFill')


@functools.lru_cache(maxsize=None)
def source_lines(path):
    """One read per file per run; every config re-reads the same includes."""
    assert path.is_file(), path
    return tuple(path.read_text(encoding='utf-8-sig').splitlines())


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


PLAIN_NUMBER = re.compile(r'-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?')


def wrapped_formula(text):
    """True when a single outer parenthesis pair encloses the whole value.

    Only such a value can be replaced by its number without changing how a
    textual substitution would parse: (a)+(b) is not wrapped.
    """
    if not (text.startswith('(') and text.endswith(')')):
        return False
    depth = 0
    for index, character in enumerate(text):
        if character == '(':
            depth += 1
        elif character == ')':
            depth -= 1
            if depth == 0:
                return index == len(text) - 1
    return False


def number_text(number):
    """Exact, re-parseable text; negatives keep their own parentheses."""
    text = str(int(number)) if float(number).is_integer() and abs(number) < 2**53 else repr(float(number))
    return f'({text})' if text.startswith('-') else text


def read_config(name, *, scale=1, columns=1, column_width=220,
                expanded=0, row_limit=5, show_details=1, typography='default', surface=1, bar_thickness=6,
                drawer=1, corner=None, preset=None, visualizer_columns=None, simulate_user=True,
                missing=None):
    """Load an entrypoint like Rainmeter: includes in file order, paths eagerly.

    Rainmeter expands an @Include path as it reads it, with the variables known
    at that point; Media.ini depends on that to name HeightPresets\\<n>.inc
    while PanelHeight still holds the Visualizer's preset, and to pick
    VisualizerDrawer<n>.inc. Option values are resolved only after every file.
    simulate_user=False reads the shipped User files without the overrides.
    A missing include fails closed unless the caller passes a `missing` list:
    then, as Rainmeter does (it logs the missing file and reads on), the path
    is recorded there and skipped.
    """
    sections = OrderedDict()
    variables = {'@': str(RESOURCES) + '/', 'CRLF': '\n'}
    visited = []
    resolved = {}
    expansions = {}
    frozen = False

    def textual(value):
        for _ in range(50):
            changed = TOKEN.sub(lambda m: str(variables.get(m[1], m[0])), value)
            if changed == value:
                return value
            value = changed
        raise AssertionError('Variable cycle')

    def resolve(name, stack):
        # A variable's final text, with every wrapped formula it references
        # already reduced to its number, so option strings stay short.
        if name in resolved:
            return resolved[name]
        assert name not in stack, f'Variable cycle: {stack + (name,)}'
        raw = variables[name]
        text = substitute(raw, stack + (name,)).strip()
        if not PLAIN_NUMBER.fullmatch(text) and wrapped_formula(raw.strip()):
            try:
                text = number_text(numeric(text))
            except (AssertionError, ArithmeticError, ValueError):
                pass  # Section variables, colors and text stay textual.
        resolved[name] = text
        return text

    def substitute(value, stack=()):
        return TOKEN.sub(lambda m: resolve(m[1], stack) if m[1] in variables else m[0], value)

    def expand(value):
        if not frozen:
            return textual(value)
        if value not in expansions:
            expansions[value] = substitute(value)
        return expansions[value]

    def load(path):
        assert path not in visited, f'Duplicate or cyclic include: {path}'
        visited.append(path)
        section = None
        seen = set()
        for raw in source_lines(path):
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
                include = Path(textual(value).replace('\\', '/'))
                if missing is not None and not include.is_file():
                    missing.append(include)
                    continue
                load(include)
            else:
                sections[section][key] = value
                if section == 'Variables':
                    variables[key] = value
        if not simulate_user:
            return
        if path == RESOURCES / 'User' / 'Visualizer.inc':
            # Simulate the Audio settings choices Media's drawer reads first.
            if preset is not None:
                variables['PanelHeight'] = str(preset)
            if visualizer_columns is not None:
                variables['Columns'] = str(visualizer_columns)
        if path == RESOURCES / 'User' / 'Media.inc':
            # Simulate preserved user overrides, before geometry is included.
            variables.update(Scale=str(scale), Columns=str(columns),
                             ColumnWidth=str(column_width), QueueExpanded=str(expanded),
                             QueueRowLimit=str(row_limit), QueueShowDetails=str(show_details), DataBarThickness=str(bar_thickness),
                             VisualizerDrawer=str(drawer))
            variables.update(TitleFontSize='12' if typography == 'max' else '6' if typography == 'min' else '10',
                             HeaderFontSize='10' if typography == 'max' else '8',
                             FontSize='10' if typography == 'max' else '9',
                             TitleTextColor='211,181,249', HeaderTextColor='110,218,175',
                             TextColor='234,210,145', AccentColor='95,188,246',
                             AccentColor2='246,138,174', BorderThickness=str(surface),
                             DividerThickness=str(surface), DividerColor='219,122,81')
            if corner is not None:
                variables['CornerRadius'] = str(corner)

    load(ROOT / 'Media' / name)
    if name=='Settings/Settings.ini':
        # Settings starts from safe collapsed geometry. Initialize applies only
        # the controller's validated binary preference before its first render.
        variables['MediaSettingsQueueDetailsVisible']='1' if variables.get('QueueExpanded')=='1' else '0'
    frozen = True
    return sections, variables, visited, expand


FORMULA_TOKEN = re.compile(r'\s*(?:(\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)'
                           r'|([A-Za-z_]\w*)|(\*\*|<=|>=|==|!=|<>|&&|\|\||[-+*/%(),?:=<>!]))')
# C-like precedence, as Rainmeter's MathParser; the ternary sits below all.
BINARY_PRECEDENCE = {'||': 2, '&&': 3, '=': 4, '==': 4, '!=': 4, '<>': 4,
                     '<': 5, '>': 5, '<=': 5, '>=': 5, '+': 6, '-': 6,
                     '*': 7, '/': 7, '%': 7, '**': 8}
UNARY_PRECEDENCE = 9
BINARY_OPERATIONS = {
    '||': lambda a, b: int(a != 0 or b != 0), '&&': lambda a, b: int(a != 0 and b != 0),
    '=': lambda a, b: int(a == b), '==': lambda a, b: int(a == b),
    '!=': lambda a, b: int(a != b), '<>': lambda a, b: int(a != b),
    '<': lambda a, b: int(a < b), '>': lambda a, b: int(a > b),
    '<=': lambda a, b: int(a <= b), '>=': lambda a, b: int(a >= b),
    '+': lambda a, b: a + b, '-': lambda a, b: a - b, '*': lambda a, b: a * b,
    '/': lambda a, b: a / b, '%': math.fmod, '**': lambda a, b: a ** b,
}
# Rainmeter function names are case-insensitive. Arity is checked exactly.
FUNCTIONS = {
    'round': ((1, 2), lambda x, digits=0: (math.floor(x * 10**digits + 0.5) / 10**digits
                                           if digits else math.floor(x + 0.5))),
    'ceil': ((1,), math.ceil), 'floor': ((1,), math.floor), 'trunc': ((1,), math.trunc),
    'abs': ((1,), abs), 'min': ((2,), min), 'max': ((2,), max),
    'clamp': ((3,), lambda x, low, high: max(low, min(high, x))),
}


class Formula:
    """Precedence-climbing parser for the Rainmeter formula subset in use.

    Unknown tokens, functions, arities or section variables fail closed.
    """
    def __init__(self, text):
        self.text, self.tokens, position = text, [], 0
        stripped = text.rstrip()
        while position < len(stripped):
            match = FORMULA_TOKEN.match(stripped, position)
            assert match and match.end() > position, f'Unsupported formula text at {position}: {text!r}'
            number, name, operator = match.groups()
            if number is not None:
                self.tokens.append(('number', int(number) if number.isdigit() else float(number)))
            elif name is not None:
                self.tokens.append(('name', name))
            else:
                self.tokens.append(('op', operator))
            position = match.end()
        self.tokens.append(('end', None))
        self.index = 0

    def peek(self):
        return self.tokens[self.index]

    def take(self):
        token = self.tokens[self.index]
        self.index += 1
        return token

    def expect(self, operator):
        token = self.take()
        assert token == ('op', operator), f'Expected {operator!r}, got {token} in {self.text!r}'

    def value(self):
        tree = self.expression(0)
        assert self.peek()[0] == 'end', f'Trailing formula text in {self.text!r}'
        return evaluate(tree)

    def expression(self, minimum):
        left = self.unary()
        while True:
            kind, operator = self.peek()
            if kind != 'op':
                return left
            if operator == '?' and minimum <= 1:
                self.take()
                chosen = self.expression(1)
                self.expect(':')
                left = ('?', left, chosen, self.expression(1))
                continue
            precedence = BINARY_PRECEDENCE.get(operator)
            if precedence is None or precedence < minimum:
                return left
            self.take()
            right = self.expression(precedence if operator == '**' else precedence + 1)
            left = ('binary', operator, left, right)

    def unary(self):
        kind, operator = self.peek()
        if kind == 'op' and operator in ('-', '+', '!'):
            self.take()
            return ('unary', operator, self.expression(UNARY_PRECEDENCE))
        return self.primary()

    def primary(self):
        kind, token = self.take()
        if kind == 'number':
            return ('number', token)
        if kind == 'op' and token == '(':
            inner = self.expression(0)
            self.expect(')')
            return inner
        assert kind == 'name', f'Unexpected {token!r} in {self.text!r}'
        function = FUNCTIONS.get(token.lower())
        assert function, f'Uncovered formula function or name {token!r} in {self.text!r}'
        self.expect('(')
        arguments = [self.expression(0)]
        while self.peek() == ('op', ','):
            self.take()
            arguments.append(self.expression(0))
        self.expect(')')
        assert len(arguments) in function[0], f'{token} takes {function[0]} arguments: {self.text!r}'
        return ('call', function[1], arguments)


def evaluate(tree):
    kind = tree[0]
    if kind == 'number':
        return tree[1]
    if kind == 'unary':
        operand = evaluate(tree[2])
        return -operand if tree[1] == '-' else operand if tree[1] == '+' else int(operand == 0)
    if kind == 'binary':
        return BINARY_OPERATIONS[tree[1]](evaluate(tree[2]), evaluate(tree[3]))
    if kind == '?':
        return evaluate(tree[2]) if evaluate(tree[1]) != 0 else evaluate(tree[3])
    return tree[1](*(evaluate(argument) for argument in tree[2]))


@functools.lru_cache(maxsize=None)
def numeric(expression):
    """Evaluate a Rainmeter formula from the subset this module uses."""
    return Formula(expression).value()


def media_theme_metrics(scale):
    """Gutter=8 and PanelPadding=6 from Defaults.inc, through Geometry.inc."""
    rounded=lambda value: math.floor(value+0.5)
    gap=2*rounded(8*scale/2)
    return gap, gap//2, rounded(6*scale)


def pre_drawer_geometry(width, scale, columns, expanded, rows, bar_thickness=6):
    """The player formulas from before the spectrum drawer, kept verbatim.

    The closed-identity contract compares the skin against these: hiding the
    drawer (VisualizerDrawer=0) at either width, or collapsing it at double
    width, must reproduce exactly this layout. Returns (cover, surface offset,
    body, window), offsets #Inset#-relative and the window absolute.
    """
    rounded=lambda value: math.floor(value+0.5)
    wide=columns-1
    gap,inset,padding=media_theme_metrics(scale)
    base_cover=rounded(rounded(width*scale)*0.9) if wide else 48*scale
    legacy_cover=rounded(base_cover*0.75)
    offset=rounded(12*wide*scale)
    bar=max(1,rounded(bar_thickness*scale))
    progress=offset+112*scale
    body=math.ceil(progress+bar+20*scale+padding)
    cover=rounded(body+offset) if wide else legacy_cover
    cover_bottom=30*(1-wide)*scale+cover
    transport_bottom=body+(34*scale+2*5*scale)/2
    overhang_bottom=max(cover_bottom,transport_bottom)
    queue_top=max(cover_bottom,body)+4*scale
    queue_bottom=queue_top+(1+rows)*18*scale+5*scale
    drawer_bottom=queue_bottom+8*scale if expanded else body
    window=max(max(body+gap,math.ceil(overhang_bottom+2*inset)),
               math.ceil(drawer_bottom+2*inset))
    return cover,offset,body,window


def visualizer_plot_height(scale, preset=146, border=1, baseline_gap=0):
    """Options.inc VisualizerPlotHeightPx for one Height preset, re-derived."""
    rounded=lambda value: math.floor(value+0.5)
    top_shift=max(0,border-2)
    baseline=rounded(max(0,min(24,baseline_gap))*scale)
    return max(rounded((preset-66-top_shift)*scale),math.ceil(54*scale)+baseline+2)


def media_visualizer_plot_inset(scale, corner=6, border=1):
    """MediaVisualizerPlotInset: the drawer padding, or more for a big corner.

    Re-derived from the two corner circles on the 45-degree diagonal: the open
    sheet's inner stroke edge (radius R-B/2, centred B/2+R in from its box) and
    the plot frame's outer edge (radius 2S+0.5, the 1px stroke drawn at 0.5,
    centred that far in from the plot). The frame's corner keeps the clearance
    the straight sides have, padding minus border, once
    inset >= B/2+R-f - (R-B/2-f-(P-B))/sqrt(2), f = 2S+0.5.
    """
    radius,stroke,padding,frame=corner*scale,border*scale,8*scale,2*scale+0.5
    needed=stroke/2+radius-frame-(radius-stroke/2-frame-(padding-stroke))/math.sqrt(2)
    # Rounded first so float noise at an exact integer cannot add a pixel.
    return max(padding,math.ceil(round(needed,9)))


def media_visualizer_lift(scale, preset=146, border=1, corner=6):
    """MediaVisualizerOpenLift: plot inset + plot + section gap, whole px."""
    return math.ceil(media_visualizer_plot_inset(scale,corner,border)+visualizer_plot_height(scale,preset,border)+4*scale)


def media_body_geometry(width, scale, columns, bar_thickness=6, drawer=1):
    """Physical dimensions from the current drawer contract.

    The panel no longer reserves a footer for inline queue rows: the queue is
    a separate sheet behind the panel (MediaQueueHidden=1), so the body ends a
    fixed distance below the progress bar's timing text. Everything here is
    re-derived from the same primitives the skin uses rather than read back
    from it, so a geometry edit has to agree with an independent calculation.

    Returned offsets are relative to #MediaTop# (#Inset# plus the spectrum
    drawer's lift), matching the skin's own "-#MediaTop#" convention. The
    surface offset is the strip above the panel: the double-width art's
    overhang, which the compact layout also reserves while the spectrum tab
    can show (VisualizerDrawer 1 or 2).
    """
    rounded=lambda value: math.floor(value+0.5)
    wide=columns-1
    shown=1 if drawer in (1,2) else 0
    _,inset,padding=media_theme_metrics(scale)
    base_cover=rounded(rounded(width*scale)*0.9) if wide else 48*scale
    legacy_cover=rounded(base_cover*0.75)
    offset=rounded(12*max(wide,shown)*scale)
    bar=max(1,rounded(bar_thickness*scale))
    # MediaProgressY: header bottom (26 at both widths, since the player name
    # joined the title row), then three metadata rows, a section gap and the
    # bar's optical pad. MediaTimingTextBottom sits 20*Scale below it.
    progress=offset+112*scale
    body=math.ceil(progress+bar+20*scale+padding)
    # Wide artwork is sized to reach the body's lower edge, so it overhangs
    # the panel by exactly the surface offset; narrow keeps the thumbnail.
    cover=rounded(body+offset) if wide else legacy_cover
    return cover,offset,body


def media_drawer_geometry(width, scale, columns, expanded, rows, bar_thickness=6,
                          drawer=1, host=1, preset=146, border=1, corner=6):
    """Overhang, queue sheet and window height for the drawer contract.

    Offsets are #MediaTop#-relative like media_body_geometry; window height is
    absolute. MeterPanel draws its rectangle #MediaSurfaceOffset# shorter than
    #PanelHeightPx#, so the panel's lower border is the body height, not
    #MediaSurfaceY#+#PanelHeightPx#. The open spectrum drawer (host and
    drawer=2) lifts the whole player by a whole-pixel amount, so the window
    grows by exactly that lift.
    """
    cover,offset,body=media_body_geometry(width,scale,columns,bar_thickness,drawer)
    gap,inset,_=media_theme_metrics(scale)
    wide=columns-1
    lift=media_visualizer_lift(scale,preset,border,corner) if host and drawer==2 else 0
    # Compact art tops the metadata block (surface offset, header bottom 26
    # and the section gap 4).
    cover_bottom=(1-wide)*(offset+30*scale)+cover
    panel_bottom=body
    # Transport circles are centred on the panel's lower border.
    transport_bottom=panel_bottom+(34*scale+2*5*scale)/2
    overhang_bottom=max(cover_bottom,transport_bottom)
    queue_top=max(cover_bottom,panel_bottom)+4*scale
    queue_bottom=queue_top+(1+rows)*18*scale+5*scale
    drawer_bottom=queue_bottom+8*scale if expanded else panel_bottom
    window=lift+max(max(body+gap,math.ceil(overhang_bottom+2*inset)),
                    math.ceil(drawer_bottom+2*inset))
    return overhang_bottom,queue_top,drawer_bottom,window


@functools.lru_cache(maxsize=None)
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
    return tuple(parts)


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


def circular_arc(start, coordinates):
    """Endpoint-form Rainmeter circular arc: (kind, extrema, centre, svg_sweep).

    kind is 'arc', 'chord' (a zero radius draws the straight chord) or
    'empty' (coincident endpoints draw nothing). Extrema are the endpoints
    plus any axis extreme the arc passes, without a full-circle hull.
    """
    assert len(coordinates)==7, coordinates
    end_x,end_y,radius,radius_y,rotation,sweep,large=coordinates
    assert radius>=0 and abs(radius-radius_y)<EPSILON and rotation==0, 'Only unrotated circular arcs are covered'
    assert sweep in (0,1) and large in (0,1), 'Arc flags must be binary'
    # Rainmeter sweep 1 is counterclockwise: the opposite of SVG's flag.
    svg_sweep=1-sweep
    dx,dy=(start[0]-end_x)/2,(start[1]-end_y)/2
    chord=dx*dx+dy*dy
    # A rounded outline at CornerRadius 0 degenerates its corner arcs: the
    # endpoints coincide (nothing is drawn), or a zero radius draws the chord.
    if chord<EPSILON*EPSILON:
        return 'empty',[list(start)],None,None
    if radius<EPSILON:
        return 'chord',[list(start),[end_x,end_y]],None,None
    assert chord<=radius*radius+EPSILON, 'Unsupported out-of-radius arc endpoints'
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
    return 'arc',points,(cx,cy),svg_sweep


def circular_arc_points(start, coordinates):
    """Endpoint-form Rainmeter circular arc extrema, without a full-circle hull."""
    return circular_arc(start, coordinates)[1]


# Rainmeter's default StrokeLineJoin is Miter, with Direct2D's miter limit of
# 10 half-strokes; a longer miter is clipped there (or bevelled), never longer.
MITER_LIMIT = 10
DEGENERATE = 1e-9


def unit_vector(dx, dy):
    """The direction of (dx, dy), or None for a segment that has no length."""
    length=math.hypot(dx,dy)
    return None if length<DEGENERATE else (dx/length, dy/length)


@dataclass(frozen=True)
class PathSegment:
    start: tuple
    end: tuple
    start_tangent: tuple
    end_tangent: tuple
    extrema: tuple


def path_segments(path, value):
    """The drawn segments of a Path option, and whether ClosePath closes it.

    A segment that draws nothing - the coincident corner arcs of a CornerRadius
    0 outline, or the zero-length edge between two corner arcs that meet - is
    dropped: it neither extends the shape nor forms a join of its own, so the
    segments either side of it join directly. Closing a figure adds the
    implicit closing edge when its ends differ.
    """
    parts=[part.strip() for part in path.split('|')]
    first=tuple(value(coordinate) for coordinate in split_arguments(parts[0]))
    assert len(first)==2, parts[0]
    segments=[]
    position=first
    closed=False

    def line(start, end):
        direction=unit_vector(end[0]-start[0],end[1]-start[1])
        if direction:
            segments.append(PathSegment(start,end,direction,direction,(start,end)))

    for index,part in enumerate(parts[1:],1):
        if part=='ClosePath 1':
            assert index==len(parts)-1, 'ClosePath must end the figure'
            closed=True
            continue
        if part.startswith('ArcTo '):
            coordinates=[value(coordinate) for coordinate in split_arguments(part[len('ArcTo '):])]
            end=tuple(coordinates[0:2])
            kind,extrema,centre,svg_sweep=circular_arc(position,coordinates)
            if kind=='chord':
                line(position,end)
            elif kind=='arc':
                # SVG's positive-angle sweep is clockwise on screen (y down).
                def tangent(point):
                    rx,ry=point[0]-centre[0],point[1]-centre[1]
                    return unit_vector(-ry,rx) if svg_sweep else unit_vector(ry,-rx)
                segments.append(PathSegment(position,end,tangent(position),tangent(end),
                                            tuple(tuple(point) for point in extrema)))
        elif part.startswith('CurveTo '):
            coordinates=[value(coordinate) for coordinate in split_arguments(part[len('CurveTo '):])]
            assert len(coordinates)==6, part
            # Rainmeter: endpoint, control 1, control 2. A cubic Bezier lies
            # inside the hull of its four points; its end tangents follow the
            # first control point that differs from each end.
            end,control1,control2=(tuple(coordinates[i:i+2]) for i in (0,2,4))
            starts=[unit_vector(p[0]-position[0],p[1]-position[1]) for p in (control1,control2,end)]
            ends=[unit_vector(end[0]-p[0],end[1]-p[1]) for p in (control2,control1,position)]
            start_tangent=next((t for t in starts if t),None)
            if start_tangent:
                segments.append(PathSegment(position,end,start_tangent,next(t for t in ends if t),
                                            (position,control1,control2,end)))
        else:
            assert part.startswith('LineTo '), part
            end=tuple(value(coordinate) for coordinate in split_arguments(part[len('LineTo '):]))
            assert len(end)==2, part
            line(position,end)
        position=end
    if closed:
        line(position,first)
    assert segments, f'Path draws nothing: {path}'
    return segments, closed


def miter_points(vertex, incoming, outgoing, half):
    """Outermost points of a mitered join, beyond the disk a stroke already covers.

    A tangent join (incoming == outgoing direction) adds nothing. Otherwise
    the miter tip lies on the outer bisector at half/cos(turn/2); past the miter
    limit Direct2D clips it at limit*half along that bisector, and the clip
    line's two corners bound the clipped (or bevelled) join.
    """
    cosine=max(-1.0,min(1.0,incoming[0]*outgoing[0]+incoming[1]*outgoing[1]))
    if cosine>=1-DEGENERATE:
        return []
    limit=MITER_LIMIT*half
    if cosine<=-1+DEGENERATE:
        # A reversal: the clipped miter runs on along the incoming direction.
        nx,ny=-incoming[1],incoming[0]
        return [(vertex[0]+limit*incoming[0]+side*half*nx,vertex[1]+limit*incoming[1]+side*half*ny)
                for side in (-1,1)]
    half_cosine=math.sqrt((1+cosine)/2)
    half_sine=math.sqrt((1-cosine)/2)
    bisector=unit_vector(incoming[0]-outgoing[0],incoming[1]-outgoing[1])
    if 1/half_cosine<=MITER_LIMIT:
        distance=half/half_cosine
        return [(vertex[0]+distance*bisector[0],vertex[1]+distance*bisector[1])]
    def outer(direction):
        nx,ny=-direction[1],direction[0]
        return (nx,ny) if nx*bisector[0]+ny*bisector[1]>0 else (-nx,-ny)
    run=(limit-half*half_cosine)/half_sine
    (ax,ay),(bx,by)=outer(incoming),outer(outgoing)
    return [(vertex[0]+half*ax+run*incoming[0],vertex[1]+half*ay+run*incoming[1]),
            (vertex[0]+half*bx-run*outgoing[0],vertex[1]+half*by-run*outgoing[1])]


def stroked_path_bounds(segments, closed, stroke, round_join):
    """Conservative bounds of a stroked path, joins included.

    Every segment's stroke lies within its extrema grown by half the stroke
    (flat and round caps add nothing beyond that disk); a round join adds
    nothing either. A miter join adds its tip, so a corner made of tangent
    arcs, or a right angle whose centre line is inset by half the stroke,
    stays inside its box while a sharper or un-inset corner does not.
    """
    half=stroke/2
    points=[point for segment in segments for point in segment.extrema]
    left=min(p[0] for p in points)-half
    top=min(p[1] for p in points)-half
    right=max(p[0] for p in points)+half
    bottom=max(p[1] for p in points)+half
    if stroke and not round_join:
        joins=list(zip(segments,segments[1:]))
        if closed:
            joins.append((segments[-1],segments[0]))
        for incoming,outgoing in joins:
            for x,y in miter_points(incoming.end,incoming.end_tangent,outgoing.start_tangent,half):
                left,top,right,bottom=min(left,x),min(top,y),max(right,x),max(bottom,y)
    return Bounds(left,top,right,bottom)


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
        def combine_parts(shape):
            """(base, operations) for a Combine shape, else None.

            Rainmeter draws only the combined result, so the shapes a Combine
            names are not separate artwork and must not be measured twice.
            """
            primitive, *modifiers = [part.strip() for part in expanded_shape(shape).split('|')]
            kind, _, argument = primitive.partition(' ')
            if kind != 'Combine':
                return None
            operations=[]
            for modifier in modifiers:
                operation, _, reference = modifier.partition(' ')
                assert operation in ('Union','Exclude','XOR','Intersect'), \
                    f'Uncovered Combine operation: {operation}'
                operations.append((operation, reference.strip()))
            return argument.strip(), operations
        def covered_shape(shape, stack=()):
            shape=expanded_shape(shape)
            combined=combine_parts(shape)
            if combined is not None:
                base, operations = combined
                assert base not in stack, 'Cyclic Shape Combine'
                bounds=covered_shape(style[base], stack+(base,))
                for operation, reference in operations:
                    assert reference not in stack, 'Cyclic Shape Combine'
                    other=covered_shape(style[reference], stack+(reference,))
                    if operation in ('Union','XOR'):
                        bounds=Bounds(min(bounds.left,other.left),min(bounds.top,other.top),
                                      max(bounds.right,other.right),max(bounds.bottom,other.bottom))
                    # Exclude and Intersect only remove area, so the running
                    # bounds stay a conservative cover of the drawn result.
                return bounds
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
            # Centred strokes with their joins: exact miter tips at corners
            # (tangent arc joins add none), the stroke's half-width elsewhere.
            # Unstroked paths (the spectrum mask's bars) are their hull.
            segments,closed=path_segments(self_path,value)
            bounds=stroked_path_bounds(segments,closed,stroke,round_join)
            return Bounds(offset_x+bounds.left,offset_y+bounds.top,offset_x+bounds.right,offset_y+bounds.bottom)
        consumed=set()
        for key, shape in style.items():
            if SHAPE_KEY.fullmatch(key):
                combined=combine_parts(shape)
                if combined is not None:
                    base, operations = combined
                    consumed.add(base)
                    consumed.update(reference for _, reference in operations)
        shapes = [covered_shape(shape) for key, shape in style.items()
                  if SHAPE_KEY.fullmatch(key) and key not in consumed]
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
            # QueueReader applies this trusted coordinate only for active rows,
            # stepping from the drawer's first row rather than the panel body.
            # The native matrix independently verifies the actual Lua result.
            style['Y'] = f'(#MediaQueueRowsY#+{int(row[1])-1}*#MediaQueueRowPitch#)'
    return style


BAND_VARIABLE = re.compile(r'\[MeasureVisualizerBand\d+\]')


def value_of(expand, band=1):
    """Option evaluator in which the spectrum's band section variables read
    as one level (1 = every bar at full height, the largest extent)."""
    return lambda expression: numeric(BAND_VARIABLE.sub(str(band), expand(expression)))


def parked(style, expanded):
    """Queue meters parked at #Inset# while hidden never follow the player."""
    y = style.get('Y', '0')
    return y == '#Inset#' or (not expanded and y in ('#MediaQueueHeaderY#', '#MediaQueueDividerY#'))


def presented_boxes(sections, value, config, expanded, rows, skip=()):
    """Every meter's presented style and conservative bounds, in draw order."""
    boxes = OrderedDict()
    for name, section in sections.items():
        if 'Meter' in section and name not in skip:
            style = presentation_style(sections, name, config, expanded, rows)
            boxes[name] = (style, meter_bounds(style, value))
    return boxes


def shifted(bounds, dy):
    return Bounds(bounds.left, bounds.top + dy, bounds.right, bounds.bottom + dy)


def path_points(path, value):
    """Vertices of a straight Path option ("x,y | LineTo x,y | ...")."""
    points = []
    for index, part in enumerate(part.strip() for part in path.split('|')):
        if index:
            assert part.startswith('LineTo '), part
            part = part[len('LineTo '):]
        points.append(tuple(value(coordinate) for coordinate in split_arguments(part)))
    return points


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
                        # The surface strip: the double-width art's overhang, which
                        # the compact layout also reserves while the spectrum tab
                        # can show (VisualizerDrawer=1 here). The queue has neither.
                        offset=0 if config=='Queue/Queue.ini' else math.floor(12*scale+0.5)
                        self.assertAlmostEqual(val(gear['Y']),val('#Inset#')+offset+6*scale)

    def test_player_header_uses_measure_data_and_one_icon_slot(self):
        names={'MeterMediaIcon','MeterPlayerIcon'}
        for config in ('Media.ini','Setup.ini'):
            sections,_,visited,_=read_config(config)
            header=sections['MeterHeading']
            self.assertEqual(header['MeasureName'],'MeasureMediaHeader')
            self.assertEqual(header['Text'],'%1')
            self.assertNotIn('ToolTipText',header)
            self.assertEqual(header['UpdateDivider'],'1')
            self.assertNotIn('MeterPlayerName',sections)
            self.assertEqual(visited[-1].name,'Header.inc')
            actual={name for name,section in sections.items() if 'Meter' in section and resolve_style(sections,name).get('Group')=='MediaPlayerIcons'}
            self.assertEqual(actual,names)
            self.assertFalse(any(re.fullmatch(r'MeterPlayer\w+Icon', name) for name in sections))
            # Monitor-play is the default face. Only Media.ini's MediaPulse.lua
            # swaps in audio-lines, so Setup can never show it.
            for name,hidden in (('MeterMediaIcon','0'),('MeterPlayerIcon','1')):
                icon=resolve_style(sections,name)
                self.assertEqual(icon['Meter'],'Shape')
                self.assertEqual(icon['Hidden'],hidden)
                self.assertFalse(any(key.endswith('Action') for key in icon))
            for key in ('X','Y','W','H'):
                self.assertNotIn(key,sections['MeterPlayerIcon'])
                self.assertNotIn(key,sections['MeterMediaIcon'])
            if config=='Media.ini':
                pulse=sections['MeasureMediaPulse']
                self.assertEqual(pulse['ScriptFile'],'#@#Modules\\Media\\MediaPulse.lua')
                self.assertNotIn('UpdateDivider',pulse)
            else:
                self.assertNotIn('MeasureMediaPulse',sections)
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
                                heading=box('MeterHeading')
                                self.assertAlmostEqual(heading.left,val('#ContentX#')+title_size+4*scale)
                                # One title row at both widths, ending 24px (gear plus gap) short.
                                self.assertAlmostEqual(heading.width,val('#ContentWidth#')-title_size-28*scale)
                                self.assertAlmostEqual(heading.right,val('#ContentX#')+val('#ContentWidth#')-24*scale)
                                self.assertAlmostEqual((heading.top+heading.bottom)/2,surface+15*scale)
                                self.assertTrue(heading.before(box('MeterMediaOptions')))
                                # Both drawings occupy the one slot before the title.
                                self.assertEqual(box('MeterPlayerIcon'),box('MeterMediaIcon'))
                                self.assertAlmostEqual(box('MeterMediaIcon').width,title_size)
                                self.assertAlmostEqual(box('MeterMediaIcon').height,title_size)
                                self.assertAlmostEqual(box('MeterMediaIcon').left,val('#ContentX#'))
                                self.assertAlmostEqual(box('MeterMediaIcon').top+title_size/2,surface+15*scale)
                                self.assertAlmostEqual(heading.left-box('MeterMediaIcon').right,4*scale)
                                style=resolve_style(sections,'MeterHeading')
                                self.assertEqual(val(style['FontSize']),(12 if profile=='max' else 10)*scale)
                                self.assertEqual(style['ClipString'],'1')
                                first='MeterTrackTitle' if config=='Media.ini' else 'MeterSetupStatus'
                                self.assertAlmostEqual(box(first).top,surface+30*scale)
                                self.assertTrue(heading.above(box(first)))
                                if columns==1:
                                    # Compact art sits under the title icon, topped with the metadata.
                                    art=box('MeterArtworkPlaceholder')
                                    self.assertAlmostEqual(art.top,box(first).top)
                                    self.assertTrue(box('MeterMediaIcon').above(art))
                                    self.assertTrue(heading.above(art))
                                    # Setup shows no compact art (the placeholder is
                                    # double-width only), so only the player's rows sit beside it.
                                    if config=='Media.ini': self.assertTrue(art.before(box(first)))
                                if config=='Media.ini':
                                    self.assertTrue(box('MeterAlbum').above(box('MeterProgress')))
                                    self.assertTrue(box('MeterProgress').above(box('MeterTiming')))
                                else:
                                    self.assertTrue(box('MeterSetupStatus').above(box('MeterSetupInstructions')))
                                    self.assertTrue(box('MeterSetupInstructions').above(box('MeterDesktopNote')))
                                    self.assertTrue(box('MeterDesktopNote').above(box('MeterLoadPlayer')))
                                control='MeterPrevious' if config=='Media.ini' else 'MeterLoadPlayer'
                                # MeterQueueRule belonged to the inline queue footer that the
                                # drawer replaced, and is permanently hidden now. The live
                                # contract is that the transport clears the sheet's first row;
                                # the circles deliberately hang past the header, not the rows.
                                self.assertLessEqual(box(control).bottom,val('#MediaQueueRowsY#')+EPSILON)
                                self.assertEqual(val('#WindowHeight#'),
                                                 media_drawer_geometry(width,scale,columns,0,5)[3])

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
                                # Media/Setup reserve the 12px strip at both widths while the
                                # spectrum tab can show (the default VisualizerDrawer=1).
                                center=val('#Inset#')+15*scale+(0 if settings or queue else math.floor(12*scale+0.5))
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
                                        for name in ('MeterMediaIcon','MeterPlayerIcon'):
                                            icon=resolve_style(sections,name)
                                            expected=14*scale*size/10
                                            self.assertAlmostEqual(box(name).width,expected)
                                            self.assertAlmostEqual(box(name).height,expected)
                                            self.assertAlmostEqual((box(name).top+box(name).bottom)/2,center)
                                            self.assertAlmostEqual(box(title_name).left-box(name).right,4*scale)
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
                                    for name in ('Width','VisualizerDrawer','QueueExpanded','QueueRows','QueueDetails','QueuePoll'):
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
                                        # Circular buttons: a 34 face plus a 5 shadow pad
                                        # each side, square so the circle stays round.
                                        self.assertEqual(val(control['W']),(34+2*5)*scale)
                                        self.assertEqual(val(control['H']),(34+2*5)*scale)
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
        self.assertEqual(sections['MeterHeading']['MeasureName'],'MeasureMediaHeader')
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
        # The Spectrum drawer row added 28 to both heights (554/498 before).
        self.assertEqual(numeric(expand('#SettingsPanelHeight#')),526)
        self.assertEqual(sections['Variables']['VisualizerDrawer'],'1')
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
        # The three-way Spectrum drawer choice is the shared previous/value/next
        # stepper, wrapping: the label, field and value step forward like '>'.
        for part,direction in [('Label',1),('Decrease',-1),('Frame',1),('Value',1),('Increase',1)]:
            self.assertEqual(sections[f'MeterVisualizerDrawer{part}']['LeftMouseUpAction'],
                             f'''[!CommandMeasure MeasureMediaSettings "StepChoice('VisualizerDrawer',{direction})"]''')
            self.assertTrue(sections[f'MeterVisualizerDrawer{part}'].get('ToolTipText'),part)
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
        # Settings.lua rebuilds the same heights at runtime and owns the cycle.
        # Static text checks only; MediaSettingsSuite.luatest runs the script.
        controller=(RESOURCES/'Modules'/'Media'/'Settings.lua').read_text(encoding='ascii')
        self.assertIn('local settingsHeight = 582 - collapsedHeight',controller)
        self.assertIn("VisualizerDrawer = { '0', '1', '2' }",controller)
        self.assertIn("drawerNames = { ['0'] = 'Hidden', ['1'] = 'Collapsed', ['2'] = 'Expanded' }",controller)
        self.assertIn("SKIN:Bang('!CommandMeasure', 'MeasureMediaOptions', 'ApplyVisualizerPreference()', 'Parallax\\\\Media')",controller)
        # One categorical stepper; the old toggle name remains a forward step.
        self.assertEqual(controller.count('function StepChoice(key, delta)'),1)
        self.assertIn("function ToggleVisualizerDrawer() return StepChoice('VisualizerDrawer', 1) end",controller)
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
                            self.assertEqual(val('#WindowHeight#'),math.floor((582-shift)*scale+0.5)+val('#Gap#'))
                            self.assertEqual(variables['Columns'],str(columns))
                            self.assertEqual(variables['PanelHeight'],'162')
                            for name,section in sections.items():
                                if 'Meter' in section and name!='MeterBounds': self.assertTrue(box(name).inside(panel),name)
                            # The Spectrum drawer row takes Queue section's old slot;
                            # every later row moved down by exactly 28.
                            for stem,y in [('Width',100),('VisualizerDrawer',128),('QueueExpanded',156),('QueueRows',184),
                                           ('QueueDetails',212),('QueuePoll',272)]:
                                label,value='Meter'+stem+'Label','Meter'+stem+'Value'
                                numeric_field=stem in ('Width','QueueRows','QueuePoll')
                                # Number fields and the categorical Spectrum drawer
                                # share the previous/value/next group; the drawer's
                                # field is 76 wide (Collapsed/Expanded at max type).
                                stepper=numeric_field or stem=='VisualizerDrawer'
                                field=76 if stem=='VisualizerDrawer' else 56
                                parts=[label,value]+(['Meter'+stem+p for p in ('Decrease','Frame','Increase')] if stepper else [])
                                hidden=not expanded and stem in ('QueueRows','QueueDetails')
                                if hidden:
                                    for name in parts:
                                        style=resolve_style(sections,name)
                                        self.assertEqual(val(style['Hidden']),1)
                                        self.assertEqual(box(name).width,0)
                                        self.assertEqual(box(name).height,0)
                                        self.assertEqual(box(name).top,val('#Inset#'))
                                elif stepper:
                                    decrease,frame,increase=['Meter'+stem+p for p in ('Decrease','Frame','Increase')]
                                    row_y=val('#Inset#')+(y-(shift if stem=='QueuePoll' else 0))*scale
                                    self.assertTrue(box(label).before(box(decrease)))
                                    self.assertTrue(box(decrease).before(box(frame)))
                                    self.assertTrue(box(frame).before(box(increase)))
                                    self.assertAlmostEqual(box(increase).right-box(decrease).left,(field+40)*scale)
                                    self.assertAlmostEqual(box(decrease).left,val('#ContentX#')+122*scale)
                                    self.assertAlmostEqual(box(frame).left-box(decrease).right,2*scale)
                                    self.assertAlmostEqual(box(increase).left-box(frame).right,2*scale)
                                    self.assertAlmostEqual(box(frame).left,val('#ContentX#')+142*scale)
                                    self.assertAlmostEqual(box(frame).width,field*scale)
                                    self.assertAlmostEqual(box(frame).height,20*scale)
                                    # The frame draws its own field width, not the style's 56.
                                    frame_style=resolve_style(sections,frame)
                                    self.assertEqual(shape_bounds(frame_style['Shape'],val),
                                                     Bounds(0,0,box(frame).width,box(frame).height))
                                    self.assertAlmostEqual(box(value).width,field*scale)
                                    self.assertAlmostEqual(box(value).height,18*scale)
                                    self.assertAlmostEqual(box(value).left,box(frame).left)
                                    self.assertAlmostEqual(box(value).right,box(frame).right)
                                    self.assertTrue(box(value).inside(box(frame)))
                                    self.assertAlmostEqual(box(frame).top,row_y)
                                    for name in (decrease,value,increase):
                                        self.assertAlmostEqual(box(name).top,row_y+scale,msg=name)
                                    # Labels sit 2px below the field, as the plain rows do.
                                    self.assertAlmostEqual(val(resolve_style(sections,label)['Y']),row_y+2*scale)
                                else:
                                    self.assertTrue(box(label).before(box(value)))
                                    self.assertAlmostEqual(box(value).left,val('#ContentX#')+122*scale)
                                    self.assertAlmostEqual(box(value).height,20*scale)
                                    # Labels sit 2px below their value boxes, as before.
                                    self.assertAlmostEqual(val(resolve_style(sections,value)['Y']),val('#Inset#')+y*scale)
                                    self.assertAlmostEqual(val(resolve_style(sections,label)['Y']),val('#Inset#')+(y+2)*scale)
                                self.assertNotIn('SolidColor',resolve_style(sections,label))
                                if stepper:
                                    self.assertIn('#GraphBackgroundColor#',resolve_style(sections,'Meter'+stem+'Frame')['Shape'])
                                    self.assertEqual(resolve_style(sections,value)['FontColor'],'#TextColor#')
                                    self.assertEqual(resolve_style(sections,'Meter'+stem+'Decrease')['FontColor'],'#AccentColor#')
                                else: self.assertEqual(resolve_style(sections,value)['SolidColor'],'#GraphBackgroundColor#')
                            for name,y in [('MeterSamplingHeading',246),('MeterStatus',300),('MeterSourceLabel',330),
                                           ('MeterQueueHeading',414),('MeterLinksHeading',526)]:
                                self.assertAlmostEqual(box(name).top,val('#Inset#')+(y-shift)*scale)
                            for name in ('MeterVisualizerDrawerLabel','MeterVisualizerDrawerDecrease','MeterVisualizerDrawerFrame',
                                         'MeterVisualizerDrawerValue','MeterVisualizerDrawerIncrease',
                                         'MeterQueueExpandedLabel','MeterQueueExpandedValue','MeterSourceStart','MeterSourceStop',
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
                if name in ('Setup.ini','Media.ini'):
                    # The panel no longer grows to hold queue rows. The window
                    # instead clears whichever of the artwork overhang, the
                    # transport circles and the queue sheet reaches lowest.
                    self.assertEqual(window.height,
                                     media_drawer_geometry(column_width,scale,columns,expanded,rows)[3])
                else:
                    expected_height = math.floor(((582 if expanded else 526) if name == 'Settings/Settings.ini' else 162)*scale+0.5)
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
                # Bounds are pure per layout; the pairwise checks re-ask often.
                box = functools.lru_cache(maxsize=None)(
                    lambda meter: meter_bounds(presentation_style(sections, meter, name, expanded, rows), val))
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
                    self.assertTrue(box('MeterPlayerIcon').before(box('MeterHeading')))
                    self.assertTrue(box('MeterHeading').before(box('MeterMediaOptions')))
                    # The drawer tab reads icon-then-label, inverting the old
                    # footer strip where the label came first.
                    self.assertTrue(box('MeterQueueToggle').before(box('MeterQueueHeading')))
                    if expanded:
                        self.assertTrue(box('MeterQueueHeading').above(box('MeterQueueRow1')))
                        for row in range(1, rows):
                            self.assertTrue(box(f'MeterQueueRow{row}').above(box(f'MeterQueueRow{row+1}')))
                else:
                    self.assertTrue(box('MeterTitle').before(box('MeterClose')))
                    pairs = (('Width', 'VisualizerDrawer', 'QueueExpanded', 'QueueRows', 'QueueDetails', 'QueuePoll') if expanded
                             else ('Width','VisualizerDrawer','QueueExpanded','QueuePoll'))
                    for label in pairs:
                        self.assertTrue(box(f'Meter{label}Label').before(box(f'Meter{label}Value')))
                    stepper=[f'MeterVisualizerDrawer{part}' for part in ('Label','Decrease','Frame','Increase')]
                    for previous, following in zip(stepper, stepper[1:]):
                        self.assertTrue(box(previous).before(box(following)), (previous, following))
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
                    # The transport used to sit left of the timing text. It is now a
                    # centred row of circles straddling the panel's lower border, and
                    # the timing is right aligned - so its box spans the content width
                    # while its glyphs sit at the far right. Comparing the two boxes
                    # measures allocation, not ink; the real invariant is the centring.
                    for control in ('MeterPrevious','MeterPlayPause','MeterNext'):
                        self.assertAlmostEqual((box(control).top+box(control).bottom)/2,
                                               val('#Inset#')+val('#MediaBodyHeightPx#'),msg=control)
                    self.assertEqual(resolve_style(sections,'MeterTiming')['StringAlign'],'Right')
                    self.assertEqual(resolve_style(sections,'MeterTimingUnavailable')['StringAlign'],'Right')
                    controls = ('MeterPrevious', 'MeterPlayPause', 'MeterNext')
                elif name == 'Setup.ini':
                    self.assertTrue(box('MeterSetupStatus').above(box('MeterSetupInstructions')))
                    self.assertTrue(box('MeterSetupInstructions').above(box('MeterDesktopNote')))
                    self.assertTrue(box('MeterDesktopNote').above(box('MeterLoadPlayer')))
                    controls = ('MeterWNPDocs', 'MeterLoadPlayer')
                for previous, following in zip(controls, controls[1:]):
                    if controls[0] == 'MeterPrevious':
                        # Each circle's box carries a shadow pad, so adjacent boxes
                        # overlap by design while the faces keep a real gap. Order
                        # them by centre rather than by box edge.
                        self.assertLess((box(previous).left+box(previous).right)/2,
                                        (box(following).left+box(following).right)/2,
                                        (previous, following))
                    else:
                        self.assertTrue(box(previous).before(box(following)), (previous, following))
                for meter in controls:
                    self.assertGreaterEqual(box(meter).width / scale, 20 - EPSILON, meter)
                    self.assertGreaterEqual(box(meter).height / scale, 18 - EPSILON, meter)
                    if name == 'Queue/Queue.ini':
                        self.assertTrue(box('MeterQueueRule').above(box(meter)), meter)
                    elif name in ('Setup.ini','Media.ini'):
                        # MeterQueueRule belonged to the inline queue footer the
                        # drawer replaced. The live contract is that the controls
                        # clear the sheet's first row.
                        self.assertLessEqual(box(meter).bottom,val('#MediaQueueRowsY#')+EPSILON,meter)
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
                                old_metadata_x=inset+(cover_size+8*scale if wide else padding+54*scale)
                                art=box('MeterArtworkPlaceholder')
                                self.assertAlmostEqual(art.width,cover_size)
                                # Wide artwork is sized from the body so it reaches the
                                # panel's lower edge plus the surface offset it overhangs by.
                                self.assertAlmostEqual(art.width,math.floor(body_height+surface_offset+0.5)
                                                       if wide else math.floor(base_cover*0.75+0.5))
                                self.assertAlmostEqual(art.height,art.width)
                                self.assertAlmostEqual(art.left,inset+padding*(1-wide))
                                # Compact art tops the metadata block, below the strip.
                                self.assertAlmostEqual(art.top,inset+(1-wide)*(surface_offset+30*scale))
                                self.assertAlmostEqual(box('MeterPanel').left,inset+96*wide*scale)
                                self.assertAlmostEqual(box('MeterPanel').top,inset+surface_offset)
                                self.assertAlmostEqual(box('MeterPanel').right,inset+val('#PanelWidth#'))
                                self.assertAlmostEqual(val('#MediaBodyHeightPx#'),body_height)
                                # The tab holds the toggle then the label, both
                                # centred on the notch cut into the panel.
                                tab_x,tab_center=val('#MediaQueueTabX#'),val('#MediaQueueTabCenterY#')
                                for meter in ('MeterQueueToggle','MeterQueueHeading'):
                                    self.assertAlmostEqual((box(meter).top+box(meter).bottom)/2,tab_center,
                                                           delta=scale,msg=meter)
                                self.assertAlmostEqual(box('MeterQueueToggle').left,tab_x+6*scale)
                                self.assertAlmostEqual(box('MeterQueueToggle').width,18*scale)
                                self.assertAlmostEqual(box('MeterQueueHeading').left,tab_x+30*scale)
                                self.assertAlmostEqual(box('MeterQueueHeading').width,
                                                       max(1,val('#MediaQueueTabWidth#')-34*scale))
                                # The queue is the drawer's content now: it is
                                # indented inside the sheet, not the panel.
                                queue_x=val('#MediaQueueX#')
                                queue_right=queue_x+val('#MediaQueueWidth#')
                                if expanded:
                                    self.assertAlmostEqual(box('MeterQueueHeaderTrack').top,val('#MediaQueueTop#'))
                                    self.assertAlmostEqual(box('MeterQueueRow1').top,val('#MediaQueueRowsY#'))
                                    for row in range(1,6):
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
                                        self.assertAlmostEqual(box(name).top,inset+surface_offset+(30+row*24)*scale)
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
        # The drawer detaches the panel body from the artwork, so the body no
        # longer grows with column width - only Scale moves it - and the wide
        # cover is sized from the body rather than from the column.
        self.assertEqual([media_body_geometry(width,1,2)[2] for width in (180,220,320)],[156,156,156])
        self.assertEqual([media_body_geometry(width,1,2)[0] for width in (180,220,320)],[168,168,168])
        self.assertEqual([media_body_geometry(180,scale,2)[2] for scale in (0.75,1,2)],[118,156,312])
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
                            # The button box carries a shadow pad each side, so its top
                            # is no longer a fixed drop from the bar: the circles are
                            # centred on the panel's lower border instead.
                            self.assertAlmostEqual((box('MeterPrevious').top+box('MeterPrevious').bottom)/2,
                                                   val('#Inset#')+val('#MediaBodyHeightPx#'))
                            self.assertGreater(box('MeterPrevious').top,box('MeterProgress').bottom)
                            # MeterQueueRule is the hidden inline-footer remnant; the
                            # live clearance is from the circles to the sheet's rows.
                            self.assertLessEqual(box('MeterNext').bottom,val('#MediaQueueRowsY#')+EPSILON)
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
        # Corner arcs degenerate at CornerRadius 0: coincident endpoints draw
        # nothing and a zero radius draws the chord; neither may fail or bulge.
        self.assertEqual(circular_arc_points((3,3),[3,3,0,0,0,0,0]),[[3,3]])
        self.assertEqual(circular_arc_points((0,4),[4,0,0,0,0,0,0]),[[0,4],[4,0]])
        corner=circular_arc_points((0,6),[6,0,6,6,0,0,0])
        self.assertEqual((min(p[0] for p in corner),min(p[1] for p in corner)),(0,0))
        def path_meter(path, modifiers):
            return {'Meter':'Shape','X':'0','Y':'0','Shape':f'Path P | {modifiers}','P':path}
        curve='0,10 | CurveTo 10,0,0,5,5,0 | LineTo 10,10 | ClosePath 1'
        # Unstroked curves (the spectrum bars) have no join to bound.
        self.assertEqual(meter_bounds(path_meter(curve,'Fill Color 1,1,1 | StrokeWidth 0'),numeric),Bounds(0,0,10,10))
        self.assertEqual(meter_bounds(path_meter(curve,'StrokeWidth 2 | StrokeLineJoin Round'),numeric),Bounds(-1,-1,11,11))
        # The curve's ends meet its edges at right angles, so the default miter
        # tips land on the same box corners as the round joins.
        self.assertEqual(meter_bounds(path_meter(curve,'StrokeWidth 2'),numeric),Bounds(-1,-1,11,11))
        # A sheet outline (MeterVisualizerSheet): centre line inset by half
        # the 2px stroke, tangent corner arcs, an open bottom closed straight
        # across. Default miter joins keep it exactly on its 20 x 12 box, the
        # closing edge's stroke reaching half a stroke below.
        sheet='1,12 | LineTo 1,7 | ArcTo 7,1,6,6,0,0,0 | LineTo 13,1 | ArcTo 19,7,6,6,0,0,0 | LineTo 19,12 | ClosePath 1'
        self.assertEqual(meter_bounds(path_meter(sheet,'StrokeWidth 2'),numeric),Bounds(0,0,20,13))
        # Radius 0: the arcs draw nothing and the right-angle miters reach the
        # box corners exactly; square corners, not clipped or rounded ones.
        square='1,12 | LineTo 1,1 | ArcTo 1,1,0,0,0,0,0 | LineTo 19,1 | ArcTo 19,1,0,0,0,0,0 | LineTo 19,12 | ClosePath 1'
        self.assertEqual(meter_bounds(path_meter(square,'StrokeWidth 2'),numeric),Bounds(0,0,20,13))
        # Arcs whose radii fill the width meet with no edge between them.
        dome='1,12 | LineTo 1,10 | ArcTo 10,1,9,9,0,0,0 | LineTo 10,1 | ArcTo 19,10,9,9,0,0,0 | LineTo 19,12 | ClosePath 1'
        self.assertEqual(meter_bounds(path_meter(dome,'StrokeWidth 2'),numeric),Bounds(0,0,20,13))
        # Not inset: the stroke straddles the box edge by half its width.
        flush='0,12 | LineTo 0,6 | ArcTo 6,0,6,6,0,0,0 | LineTo 14,0 | ArcTo 20,6,6,6,0,0,0 | LineTo 20,12 | ClosePath 1'
        self.assertEqual(meter_bounds(path_meter(flush,'StrokeWidth 2'),numeric),Bounds(-1,-1,21,13))
        # A sharp corner's miter runs past the half-stroke: sqrt(26) here...
        sharp=meter_bounds(path_meter('0,0 | LineTo 10,2 | LineTo 0,4','StrokeWidth 2'),numeric)
        self.assertAlmostEqual(sharp.right,10+math.sqrt(26))
        self.assertEqual((sharp.left,sharp.top,sharp.bottom),(-1,-1,5))
        # ...and is clipped at the miter limit (10 half-strokes) past that.
        needle=meter_bounds(path_meter('0,0 | LineTo 10,0.5 | LineTo 0,1','StrokeWidth 2'),numeric)
        self.assertAlmostEqual(needle.right,10+MITER_LIMIT)
        self.assertEqual(meter_bounds(path_meter('0,0 | LineTo 10,0.5 | LineTo 0,1','StrokeWidth 2 | StrokeLineJoin Round'),numeric),
                         Bounds(-1,-1,11,2))
        # Joins and caps the model does not cover still fail closed.
        for modifier in ('StrokeLineJoin Bevel','StrokeStartCap Square','StrokeEndCap Triangle'):
            with self.subTest(modifier=modifier), self.assertRaisesRegex(AssertionError,'Uncovered Path modifier'):
                meter_bounds(path_meter(sheet,f'StrokeWidth 2 | {modifier}'),numeric)

    def test_formula_evaluator_covers_rainmeter_conditionals(self):
        # The skin now uses ternaries, comparisons and Min; Python's own
        # parser cannot read "a=1 ? b : c", so the subset is parsed here.
        cases = {'(1=1 ? 2 : 3)': 2, '(2=1 ? 1 : (2=2 ? 5 : 0))': 5, '(0<=0 ? 512 : 1)': 512,
                 '(1>=2 ? 2048 : 1024)': 1024, '(Max(0,Min(2000,2500)))': 2000, '(Ceil(1.2)+Round(2.5))': 5,
                 '(2*3-4/2)': 4, '(-(1+2)*2)': -6, '(1 ? 2 : 3 ? 4 : 5)': 2, '(0 ? 2 : 0 ? 4 : 5)': 5,
                 '(1+2=3 ? 7 : 8)': 7, '(Round(1.25,1))': 1.3, '(5 % 3)': 2, '(1 && 0 || 1)': 1}
        for formula, expected in cases.items():
            with self.subTest(formula=formula):
                self.assertAlmostEqual(numeric(formula), expected)
        for unsupported in ('(Sin(1))', '(Max(1))', '([MeasureVisualizerBand0]*2)', '(1 ? 2)', '(1 2)'):
            with self.subTest(unsupported=unsupported), self.assertRaises(AssertionError):
                numeric(unsupported)

    def test_include_paths_resolve_eagerly_like_rainmeter(self):
        # Media.ini names HeightPresets\#PanelHeight#.inc while PanelHeight
        # still holds the Visualizer's preset, and VisualizerDrawer#n#.inc from
        # the preference; option values resolve only after every file.
        with tempfile.TemporaryDirectory(prefix='Parallax-Media-include-test-') as directory:
            fixture=Path(directory)
            (fixture/'early.inc').write_text('[Variables]\nPicked=early\n',encoding='utf-8')
            entry=fixture/'skin.ini'
            entry.write_text('[Variables]\nWhich=early\n'
                             f'@Include1={fixture.as_posix()}/#Which#.inc\n'
                             'Which=late\nValue=(#Which#=0 ? 1 : 2)\n',encoding='utf-8')
            sections,variables,visited,expand=read_config(entry)
            self.assertEqual([path.name for path in visited],['skin.ini','early.inc'])
            self.assertEqual(variables['Picked'],'early')
            self.assertEqual(expand('#Which#'),'late')

    def test_entrypoints_read_visualizer_choices_first_and_header_last(self):
        relative=lambda visited:[path.relative_to(ROOT).as_posix() for path in visited]
        core=['@Resources/Defaults.inc','@Resources/User/Settings.inc','@Resources/User/Media.inc',
              '@Resources/Geometry.inc','@Resources/Modules/Visualizer/Options.inc',
              '@Resources/Modules/Media/InlineQueueGeometry.inc','@Resources/Styles.inc',
              '@Resources/Modules/Media/Common.inc']
        tracked=set(core)|{'@Resources/Modules/Visualizer/Fallbacks.inc','@Resources/User/Visualizer.inc',
                           '@Resources/Modules/Media/WebNowPlaying.inc','@Resources/Modules/Media/PlayerMeters.inc',
                           '@Resources/Modules/Media/SetupMeters.inc','@Resources/Modules/Media/Lifecycle.inc',
                           '@Resources/Modules/Media/Header.inc','@Resources/Modules/Visualizer/Capture.inc',
                           '@Resources/Modules/Visualizer/Spectrum.inc'}
        for drawer in DRAWER_STATES:
            with self.subTest(config='Media.ini',drawer=drawer):
                sections,_,visited,_=read_config('Media.ini',drawer=drawer)
                order=[path for path in relative(visited)
                       if path in tracked or 'HeightPresets/' in path or 'VisualizerDrawer' in path]
                self.assertEqual(order,['@Resources/Modules/Visualizer/Fallbacks.inc','@Resources/User/Visualizer.inc',
                    '@Resources/Modules/Visualizer/HeightPresets/146.inc']+core+[
                    '@Resources/Modules/Media/WebNowPlaying.inc','@Resources/Modules/Media/PlayerMeters.inc',
                    '@Resources/Modules/Media/Lifecycle.inc',f'@Resources/Modules/Media/VisualizerDrawer{drawer}.inc']+
                    (['@Resources/Modules/Visualizer/Capture.inc','@Resources/Modules/Visualizer/Spectrum.inc'] if drawer==2 else [])+
                    ['@Resources/Modules/Media/Header.inc'])
                self.assertEqual(visited[-1].name,'Header.inc')
                measures=[name for name,section in sections.items() if 'Measure' in section]
                self.assertEqual(measures[-1],'MeasureMediaHeader')
                if drawer!=2:
                    # The closed and hidden stubs hold comments only.
                    stub=RESOURCES/'Modules'/'Media'/f'VisualizerDrawer{drawer}.inc'
                    self.assertTrue(all(not line.strip() or line.lstrip().startswith(';') for line in source_lines(stub)))
        for drawer in DRAWER_STATES:
            with self.subTest(config='Setup.ini',drawer=drawer):
                sections,_,visited,_=read_config('Setup.ini',drawer=drawer)
                order=[path for path in relative(visited) if path in tracked or 'HeightPresets/' in path or 'VisualizerDrawer' in path]
                # Variables only from the Visualizer chain: no user choices,
                # preset, capture or drawer include.
                self.assertEqual(order,['@Resources/Modules/Visualizer/Fallbacks.inc']+core+[
                    '@Resources/Modules/Media/SetupMeters.inc','@Resources/Modules/Media/Lifecycle.inc',
                    '@Resources/Modules/Media/Header.inc'])
                self.assertEqual(visited[-1].name,'Header.inc')
        # Flags a later include's geometry depends on are set BEFORE the first
        # include: a late override leaks stale values through forward references
        # in Rainmeter's final variable pass (found natively).
        for config,host in (('Media.ini','1'),('Setup.ini','0'),('Settings/Settings.ini',None)):
            with self.subTest(entrypoint=config):
                keys=[]
                section=None
                for raw in source_lines(ROOT/'Media'/config):
                    line=raw.strip()
                    if line.startswith('[') and line.endswith(']'): section=line[1:-1]
                    elif section=='Variables' and '=' in line and not line.startswith(';'):
                        keys.append(line.split('=',1))
                index={key:position for position,(key,_) in reversed(list(enumerate(keys)))}
                self.assertEqual(dict(keys)['VisualizerDrawer'],'1')
                self.assertLess(index['VisualizerDrawer'],index['@Include3'],'Fallback precedes User\\Media.inc')
                if host is None:
                    self.assertNotIn('MediaVisualizerHost',index)
                    continue
                first_include=min(position for key,position in index.items() if key.lower().startswith('@include'))
                self.assertEqual(dict(keys)['MediaVisualizerHost'],host)
                self.assertLess(index['MediaVisualizerHost'],first_include)
                self.assertEqual([key for key,_ in keys].count('MediaVisualizerHost'),1)

    def test_closed_spectrum_drawer_preserves_the_pre_drawer_player(self):
        # Closed identity: hiding the drawer at either width, or collapsing it
        # at double width, reproduces the pre-drawer formulas exactly; the
        # compact tab only moves that layout down by the Round(12*Scale) strip.
        drawer_meters=set(DRAWER_METERS)
        for config in ('Media.ini','Setup.ini'):
            for width in (180,320):
                for scale in SCALES:
                    for columns in COLUMNS:
                        for expanded in (0,1):
                            with self.subTest(config=config,width=width,scale=scale,columns=columns,expanded=expanded):
                                wide=columns-1
                                cover,offset,body,window=pre_drawer_geometry(width,scale,columns,expanded,5)
                                states={}
                                for drawer in (0,1):
                                    sections,_,_,expand=read_config(config,column_width=width,scale=scale,
                                        columns=columns,expanded=expanded,drawer=drawer)
                                    val=value_of(expand)
                                    # Hidden at 0, where the compact toggle's canvas is
                                    # 18*Scale x 0 (no strip): checked by anchor below.
                                    states[drawer]=(sections,val,presented_boxes(sections,val,config,expanded,5,
                                                                                skip=drawer_meters if drawer==0 else ()))
                                strip=0 if wide else math.floor(12*scale+0.5)
                                for drawer,shift in ((0,0),(1,strip)):
                                    _,val,_=states[drawer]
                                    inset=val('#Inset#')
                                    self.assertEqual(val('#MediaVisualizerLift#'),0)
                                    self.assertEqual(val('#MediaTop#'),inset)
                                    self.assertEqual(val('#MediaSurfaceOffset#'),offset+shift)
                                    self.assertEqual(val('#MediaSurfaceY#'),inset+offset+shift)
                                    self.assertEqual(val('#MediaBodyHeightPx#'),body+shift)
                                    self.assertEqual(val('#MediaCoverSize#'),cover)
                                    self.assertEqual(val('#WindowHeight#'),window+shift)
                                    self.assertEqual(val('#WindowHeight#'),
                                        media_drawer_geometry(width,scale,columns,expanded,5,drawer=drawer,host=config=='Media.ini')[3])
                                _,val0,boxes0=states[0]
                                _,val1,boxes1=states[1]
                                for variable in ('ContentX','ContentWidth','MediaHeadingWidth','MediaSurfaceX',
                                                 'MediaSurfaceWidth','MediaQueueX','MediaQueueWidth','WindowWidth'):
                                    self.assertEqual(val1(f'#{variable}#'),val0(f'#{variable}#'),variable)
                                self.assertEqual([name for name in boxes1 if name not in drawer_meters],list(boxes0))
                                window0=Bounds(0,0,val0('#WindowWidth#'),val0('#WindowHeight#'))
                                for name in DRAWER_METERS:
                                    # Hidden meters still count toward native bounds.
                                    style=resolve_style(states[0][0],name)
                                    x,y=val0(style['X']),val0(style['Y'])
                                    self.assertTrue(Bounds(x,y,x+val0(style.get('W','0')),y+val0(style.get('H','0'))).inside(window0),name)
                                for name,(style,bounds) in boxes1.items():
                                    if name in drawer_meters:
                                        continue
                                    before=boxes0[name][1]
                                    if name=='MeterBounds':
                                        self.assertEqual(bounds,Bounds(0,0,val1('#WindowWidth#'),val1('#WindowHeight#')))
                                    elif parked(style,expanded):
                                        self.assertEqual(bounds,before,name)
                                    else:
                                        self.assertAlmostEqual(bounds.left,before.left,msg=name)
                                        self.assertAlmostEqual(bounds.right,before.right,msg=name)
                                        self.assertAlmostEqual(bounds.top,before.top+strip,msg=name)
                                        self.assertAlmostEqual(bounds.bottom,before.bottom+strip,msg=name)
                                # The tab exists only in Media.ini, only while not hidden.
                                for name in DRAWER_METERS:
                                    self.assertEqual(val0(states[0][0][name]['Hidden']),1)
                                    self.assertEqual(val1(states[1][0][name]['Hidden']),0 if config=='Media.ini' else 1)

    def test_open_spectrum_drawer_lifts_the_player_by_whole_pixels(self):
        drawer_meters=set(DRAWER_METERS)|set(OPEN_DRAWER_METERS)
        for width in (180,220,320):
            for scale in SCALES:
                for columns in COLUMNS:
                    for expanded in (0,1):
                        with self.subTest(width=width,scale=scale,columns=columns,expanded=expanded):
                            states={}
                            for drawer in (1,2):
                                sections,_,_,expand=read_config('Media.ini',column_width=width,scale=scale,
                                    columns=columns,expanded=expanded,drawer=drawer)
                                val=value_of(expand)
                                states[drawer]=(sections,val,presented_boxes(sections,val,'Media.ini',expanded,5))
                            sections,val,boxes=states[2]
                            _,val1,boxes1=states[1]
                            box=lambda name: boxes[name][1]
                            inset,gap,pad=val('#Inset#'),val('#MediaSectionGap#'),val('#MediaDrawerPadding#')
                            lift=val('#MediaVisualizerLift#')
                            # Whole pixels: the lift is also the config's AnchorY.
                            self.assertTrue(float(lift).is_integer() and lift>0,lift)
                            self.assertEqual(lift,val('#MediaVisualizerOpenLift#'))
                            self.assertEqual(lift,media_visualizer_lift(scale))
                            self.assertEqual(val('#MediaTop#'),inset+lift)
                            self.assertEqual(val('#WindowHeight#'),val1('#WindowHeight#')+lift)
                            self.assertEqual(val('#WindowHeight#'),
                                             media_drawer_geometry(width,scale,columns,expanded,5,drawer=2)[3])
                            for variable in ('ContentX','ContentWidth','MediaHeadingWidth','MediaSurfaceX','MediaSurfaceWidth',
                                             'MediaSurfaceOffset','MediaBodyHeightPx','MediaCoverSize','WindowWidth'):
                                self.assertEqual(val(f'#{variable}#'),val1(f'#{variable}#'),variable)
                            for variable in ('MediaTop','MediaSurfaceY','MediaCoverY','MediaProgressY','MediaTransportCenterY',
                                             'MediaQueueTabY','MediaQueueTop','MediaQueueRowsY','MediaQueueDrawerBottom'):
                                self.assertEqual(val(f'#{variable}#'),val1(f'#{variable}#')+lift,variable)
                            # Panel, art, transport and queue all move by exactly the lift.
                            self.assertEqual(list(boxes1),[name for name in boxes if name not in OPEN_DRAWER_METERS])
                            for name,(style,before) in boxes1.items():
                                if name in drawer_meters or name=='MeterBounds':
                                    continue
                                after=box(name)
                                if parked(style,expanded):
                                    self.assertEqual(after,before,name)
                                else:
                                    self.assertAlmostEqual(after.left,before.left,msg=name)
                                    self.assertAlmostEqual(after.right,before.right,msg=name)
                                    self.assertAlmostEqual(after.top,before.top+lift,msg=name)
                                    self.assertAlmostEqual(after.bottom,before.bottom+lift,msg=name)
                            # Mirrored queue spacing: the plot hangs MediaSectionGap
                            # above the player, and the Ceil slack lands in the far pad.
                            plot,sheet,panel=box('MeterVisualizerPlot'),box('MeterVisualizerSheet'),box('MeterPanel')
                            self.assertEqual(val('#MediaVisualizerPlotHeight#'),visualizer_plot_height(scale))
                            self.assertAlmostEqual(val('#MediaVisualizerPlotY#')+val('#MediaVisualizerPlotHeight#')+gap,val('#MediaTop#'))
                            self.assertAlmostEqual(plot.bottom+gap,val('#MediaTop#'))
                            self.assertAlmostEqual(plot.height,val('#MediaVisualizerPlotHeight#'))
                            self.assertAlmostEqual(sheet.top,inset)
                            self.assertAlmostEqual(sheet.left,val('#MediaSurfaceX#'))
                            self.assertAlmostEqual(sheet.right,val('#MediaQueueDrawerRight#'))
                            # At the default CornerRadius the plot's inset is the
                            # queue sheet's padding (larger radii: see the corner test).
                            plot_inset=val('#MediaVisualizerPlotInset#')
                            self.assertEqual(plot_inset,pad)
                            self.assertAlmostEqual(plot.left-sheet.left,plot_inset)
                            self.assertAlmostEqual(sheet.right-plot.right,plot_inset)
                            self.assertGreaterEqual(plot.top-sheet.top,plot_inset-EPSILON)
                            self.assertLess(plot.top-sheet.top,plot_inset+1)
                            self.assertTrue(plot.inside(sheet))
                            # The sheet's square lower edge tucks behind the panel,
                            # past the panel's own top corner curve.
                            self.assertGreaterEqual(sheet.bottom,panel.top+val('(#CornerRadius#*#Scale#)')-EPSILON)
                            self.assertLess(sheet.bottom,box('MeterTrackTitle').top)
                            self.assertLess(list(sections).index('MeterVisualizerSheet'),list(sections).index('MeterPanel'))
                            # The bars paint over the plot frame, inside it.
                            for name in ('MeterVisualizerSpectrumMask','MeterVisualizerFill','MeterVisualizerUnavailable'):
                                self.assertTrue(box(name).inside(plot),name)
                            self.assertGreater(list(sections).index('MeterVisualizerSpectrumMask'),
                                               list(sections).index('MeterVisualizerPlot'))
                            # Toggle: the clear band between the plot and the panel.
                            toggle=box('MeterVisualizerToggle')
                            self.assertAlmostEqual(toggle.top,plot.bottom)
                            self.assertAlmostEqual(toggle.bottom,panel.top)
                            # Every drawer meter stays inside the window, off the gutter.
                            window=Bounds(0,0,val('#WindowWidth#'),val('#WindowHeight#'))
                            surface=Bounds(inset,inset,window.right-inset,window.bottom-inset)
                            for name,(style,bounds) in boxes.items():
                                self.assertTrue(bounds.inside(window),f'{name}: {bounds} outside {window}')
                                if name!='MeterBounds':
                                    self.assertTrue(bounds.inside(surface),f'{name}: {bounds} outside {surface}')
                            unavailable=resolve_style(sections,'MeterVisualizerUnavailable')
                            self.assertIn(unavailable.get('ClipString'),('1','2'))
                            self.assertIn('FontFace',unavailable)

    def test_spectrum_tab_shares_the_gear_column_and_flips_its_chevron(self):
        for drawer in (1,2):
            for corner in (0,6,12):
                for scale in SCALES:
                    for columns in COLUMNS:
                        with self.subTest(drawer=drawer,corner=corner,scale=scale,columns=columns):
                            sections,_,_,expand=read_config('Media.ini',scale=scale,columns=columns,drawer=drawer,corner=corner)
                            val=value_of(expand)
                            box=lambda name: meter_bounds(resolve_style(sections,name),val)
                            toggle_style=resolve_style(sections,'MeterVisualizerToggle')
                            gear_style=resolve_style(sections,'MeterMediaOptions')
                            toggle,sheet,panel,gear=box('MeterVisualizerToggle'),box('MeterVisualizerSheet'),box('MeterPanel'),box('MeterMediaOptions')
                            inset=val('#Inset#')
                            self.assertEqual(toggle_style['LeftMouseUpAction'],'[!CommandMeasure MeasureMediaOptions "ToggleVisualizer()"]')
                            self.assertTrue(toggle_style.get('ToolTipText'))
                            # The chevron and its round stroke stay on the toggle's canvas.
                            x,y,w,h=(val(toggle_style[key]) for key in ('X','Y','W','H'))
                            self.assertEqual(toggle,Bounds(x,y,x+w,y+h))
                            # Whole-pixel tab edges: Rainmeter truncates meter X, so
                            # a fractional 18*Scale rounds the tab out to 14/23 px.
                            self.assertTrue(float(x).is_integer() and float(x+w).is_integer(),(x,w))
                            self.assertEqual(w,math.ceil(18*scale))
                            self.assertEqual(w,{0.75:14,1:18,1.25:23,1.5:27,2:36}[scale])
                            self.assertEqual((x,x+w),(val('#MediaVisualizerTabX#'),val('#MediaVisualizerTabRight#')))
                            self.assertAlmostEqual(toggle.bottom,panel.top)
                            self.assertTrue(toggle.above(gear))
                            self.assertAlmostEqual(sheet.top,inset)
                            # Centres are measured on the drawn art: the chevron's
                            # apex, and the gear's hub at its truncated origin.
                            chevron=path_points(toggle_style['MediaVisualizerChevron'],val)
                            self.assertEqual(len(chevron),3)
                            self.assertAlmostEqual(chevron[0][0]+chevron[2][0],2*chevron[1][0])
                            apex_x=math.trunc(x)+chevron[1][0]
                            hub=gear_style['Shape2'].split('|')[0].strip()
                            self.assertTrue(hub.startswith('Ellipse '),hub)
                            hub_x=val(split_arguments(hub[len('Ellipse '):])[0])
                            self.assertAlmostEqual(hub_x,val(gear_style['W'])/2)
                            gear_x=math.trunc(val(gear_style['X']))
                            gear_center=gear_x+hub_x
                            # The tab is the gear's own column unless the panel's
                            # corner would put it on the curve; then it moves left.
                            corner_px=corner*scale
                            if corner_px<=val('#Padding#'):
                                self.assertEqual(x,gear_x)
                                self.assertAlmostEqual(apex_x,gear_center)
                            else:
                                self.assertEqual(toggle.right,math.floor(panel.right-corner_px))
                                self.assertLess(apex_x,gear_center)
                            self.assertLessEqual(toggle.right,panel.right-corner_px+EPSILON)
                            # Kept 9*Scale into the tab, the chevron sits off the
                            # tab's own centre only by the whole-pixel rounding.
                            self.assertAlmostEqual(chevron[1][0],9*scale)
                            self.assertAlmostEqual((x+w/2)-apex_x,(math.ceil(18*scale)-18*scale)/2)
                            if drawer==1:
                                # Collapsed, the sheet is just the tab, protruding
                                # above the panel by the strip and tucked behind it.
                                self.assertAlmostEqual(sheet.left,toggle.left)
                                self.assertAlmostEqual(sheet.right,toggle.right)
                                self.assertAlmostEqual(panel.top-sheet.top,math.floor(12*scale+0.5))
                                self.assertGreater(sheet.bottom,panel.top)
                            # Points up to open, down to close.
                            self.assertAlmostEqual(chevron[0][1],chevron[2][1])
                            if drawer==1: self.assertLess(chevron[1][1],chevron[0][1])
                            else: self.assertGreater(chevron[1][1],chevron[0][1])
                            # Default miter joins: a square corner at CornerRadius 0,
                            # with the outline inset by half its stroke so the miter
                            # ends exactly on the box (checked by the bounds above).
                            sheet_style=resolve_style(sections,'MeterVisualizerSheet')
                            self.assertNotIn('StrokeLineJoin',sheet_style['Shape'])
                            start=path_points(sheet_style['MediaVisualizerSheetPath'].split('|')[0],val)[0]
                            self.assertAlmostEqual(start[0],val('(#BorderThickness#*#Scale#)')/2)

    def test_only_the_open_drawer_include_opens_the_geometry(self):
        # MediaOptions.lua compares SKIN:GetVariable('MediaVisualizerOpen') with
        # '1', so it is a literal digit in both places it is set: 0 in the shared
        # geometry and 1 only in the open drawer's own include. Nothing else -
        # entrypoint, User file or other include - may set it.
        definitions=[]
        for path in sorted(list(ROOT.rglob('*.inc'))+list(ROOT.rglob('*.ini'))):
            for raw in source_lines(path):
                key,_,value=raw.strip().partition('=')
                if key.strip()=='MediaVisualizerOpen':
                    definitions.append((path.relative_to(ROOT).as_posix(),value.strip()))
        self.assertEqual(definitions,[('@Resources/Modules/Media/InlineQueueGeometry.inc','0'),
                                      ('@Resources/Modules/Media/VisualizerDrawer2.inc','1')])
        for config in ('Media.ini','Setup.ini'):
            for drawer in DRAWER_STATES:
                with self.subTest(config=config,drawer=drawer):
                    _,_,_,expand=read_config(config,drawer=drawer)
                    self.assertEqual(numeric(expand('#MediaVisualizerOpen#')),int(config=='Media.ini' and drawer==2))
        # A saved value that is a number but not the literal digit (Settings.lua
        # and MediaOptions.lua read '02' and '2.0' as 1) names no include:
        # Rainmeter logs VisualizerDrawer02.inc as missing and the tab shows,
        # closed, exactly as at 1 - the window never lifts an empty sheet.
        for saved in ('02','2.0'):
            for columns in COLUMNS:
                with self.subTest(saved=saved,columns=columns):
                    missing=[]
                    sections,_,_,expand=read_config('Media.ini',drawer=saved,columns=columns,missing=missing)
                    self.assertEqual(missing,[RESOURCES/'Modules'/'Media'/f'VisualizerDrawer{saved}.inc'])
                    val=value_of(expand)
                    closed_sections,_,_,closed_expand=read_config('Media.ini',drawer=1,columns=columns)
                    closed=value_of(closed_expand)
                    for variable,expected in (('MediaVisualizerShown',1),('MediaVisualizerTab',1),
                                              ('MediaVisualizerOpen',0),('MediaVisualizerLift',0)):
                        self.assertEqual(val(f'#{variable}#'),expected,variable)
                    for variable in ('MediaTop','MediaSurfaceY','MediaBodyHeightPx','WindowHeight','MediaVisualizerSheetX',
                                     'MediaVisualizerSheetWidth','MediaVisualizerToggleY','MediaVisualizerToggleHeight'):
                        self.assertEqual(val(f'#{variable}#'),closed(f'#{variable}#'),variable)
                    for name in DRAWER_METERS:
                        self.assertEqual(meter_bounds(resolve_style(sections,name),val),
                                         meter_bounds(resolve_style(closed_sections,name),closed),name)
                    chevron=lambda sections,val: path_points(resolve_style(sections,'MeterVisualizerToggle')['MediaVisualizerChevron'],val)
                    self.assertEqual(chevron(sections,val),chevron(closed_sections,closed))
                    self.assertFalse([name for name,section in sections.items()
                                      if section.get('Plugin')=='AudioLevel' or name.startswith('MeasureVisualizer')])
                    for name in OPEN_DRAWER_METERS:
                        self.assertNotIn(name,sections)
        # Without that opt-in the loader still fails closed on a missing include.
        with self.assertRaises(AssertionError):
            read_config('Media.ini',drawer='02')

    def test_spectrum_plot_clears_the_open_sheet_corners(self):
        # Along its straight sides the plot frame keeps (padding - border) from
        # the sheet's inner stroke edge. A larger CornerRadius curves that edge
        # in towards the frame's own rounded corner, so MediaVisualizerPlotInset
        # grows until the corners keep the same clearance. Measured here on the
        # drawn outlines: the sheet path's radius and stroke, the frame's shape.
        def clearance(point, centre, radius):
            """How far an interior point is from a top-left rounded edge whose
            corner circle is (centre, radius); radius 0 is a square corner."""
            dx,dy=centre[0]-point[0],centre[1]-point[1]
            if dx<=0 and dy<=0:
                return radius+min(-dx,-dy)
            return radius-math.hypot(max(dx,0),max(dy,0))
        def corner_clearance(sheet_centre, inner_radius, frame_centre, outer_radius):
            """Least clearance along a frame's outer top-left corner arc. Past
            the arc its straight edges only lead away from the sheet's corner."""
            return min(clearance((frame_centre[0]+outer_radius*math.cos(angle),
                                  frame_centre[1]+outer_radius*math.sin(angle)),sheet_centre,inner_radius)
                       for angle in (math.pi*(1+step/1800) for step in range(901)))
        def modifier(shape, name):
            return next(part.strip()[len(name)+1:] for part in shape.split('|') if part.strip().startswith(name+' '))
        for corner in (0,6,12,24):
            for border in (1,4):
                for scale in (1,1.25,2):
                    with self.subTest(corner=corner,border=border,scale=scale):
                        sections,_,_,expand=read_config('Media.ini',drawer=2,corner=corner,surface=border,scale=scale)
                        val=value_of(expand)
                        box=lambda name: meter_bounds(resolve_style(sections,name),val)
                        sheet,plot=box('MeterVisualizerSheet'),box('MeterVisualizerPlot')
                        padding=val('#MediaDrawerPadding#')
                        inset=val('#MediaVisualizerPlotInset#')
                        self.assertEqual(inset,media_visualizer_plot_inset(scale,corner,border))
                        self.assertGreaterEqual(inset,padding)
                        # The plot hangs from the inset on both sides; the lift follows it.
                        self.assertEqual(val('#MediaVisualizerPlotX#'),val('#MediaSurfaceX#')+inset)
                        self.assertEqual(val('#MediaVisualizerPlotWidth#'),
                                         val('#MediaQueueDrawerRight#')-val('#MediaSurfaceX#')-2*inset)
                        self.assertEqual(val('#MediaVisualizerOpenLift#'),
                                         math.ceil(inset+val('#MediaVisualizerPlotHeight#')+val('#MediaSectionGap#')))
                        self.assertEqual(val('#MediaVisualizerLift#'),media_visualizer_lift(scale,146,border,corner))
                        self.assertAlmostEqual(plot.left-sheet.left,inset)
                        self.assertAlmostEqual(sheet.right-plot.right,inset)
                        self.assertGreaterEqual(plot.top-sheet.top,inset-EPSILON)
                        self.assertAlmostEqual(plot.bottom+val('#MediaSectionGap#'),val('#MediaTop#'))
                        # Sheet: inner stroke edge from the drawn path.
                        sheet_style=resolve_style(sections,'MeterVisualizerSheet')
                        stroke=val(modifier(sheet_style['Shape'],'StrokeWidth'))
                        arc=next(part.strip() for part in sheet_style['MediaVisualizerSheetPath'].split('|')
                                 if part.strip().startswith('ArcTo '))
                        radius=val(split_arguments(arc[len('ArcTo '):])[2])
                        self.assertAlmostEqual(stroke,border*scale)
                        self.assertAlmostEqual(radius,corner*scale)
                        inner=max(0,radius-stroke/2)
                        sheet_left=(sheet.left+stroke+inner,sheet.top+stroke+inner)
                        sheet_right=(sheet.right-stroke-inner,sheet.top+stroke+inner)
                        # Frame: its stroke centred on a rounded rectangle.
                        plot_style=resolve_style(sections,'MeterVisualizerPlot')
                        rectangle=plot_style['Shape'].split('|')[0].strip()
                        self.assertTrue(rectangle.startswith('Rectangle '),rectangle)
                        fx,fy,fw,_,frame_radius=(val(part) for part in split_arguments(rectangle[len('Rectangle '):]))
                        outer=frame_radius+val(modifier(plot_style['Shape'],'StrokeWidth'))/2
                        origin_x,origin_y=val(plot_style['X']),val(plot_style['Y'])
                        frame_left=(origin_x+fx+frame_radius,origin_y+fy+frame_radius)
                        frame_right=(origin_x+fx+fw-frame_radius,origin_y+fy+frame_radius)
                        mirrored=lambda point:(-point[0],point[1])
                        least=min(corner_clearance(sheet_left,inner,frame_left,outer),
                                  corner_clearance(mirrored(sheet_right),inner,mirrored(frame_right),outer))
                        self.assertGreaterEqual(least,padding-stroke-0.01)
                        if inset>padding:
                            # Not over-generous: one pixel less on both axes falls short.
                            nearer=(sheet.left+inset-1+fx+frame_radius,sheet.top+inset-1+fy+frame_radius)
                            self.assertLess(corner_clearance(sheet_left,inner,nearer,outer),padding-stroke)
        # Default scale and border: the padding holds up to CornerRadius 10.
        for corner in range(25):
            with self.subTest(corner=corner):
                _,_,_,expand=read_config('Media.ini',drawer=2,corner=corner)
                val=value_of(expand)
                inset=val('#MediaVisualizerPlotInset#')
                self.assertEqual(inset,media_visualizer_plot_inset(1,corner,1))
                if corner<=10:
                    self.assertEqual(inset,val('#MediaDrawerPadding#'))
                else:
                    self.assertGreater(inset,val('#MediaDrawerPadding#'))
        self.assertEqual((media_visualizer_plot_inset(1,6,1),media_visualizer_plot_inset(1,11,1),
                          media_visualizer_plot_inset(1,24,4)),(8,9,13))

    def test_spectrum_grid_lines_sit_on_pixel_centres(self):
        def grid(section):
            lines=[]
            for key in ('Shape2','Shape3','Shape4'):
                primitive,*modifiers=[part.strip() for part in section[key].split('|')]
                self.assertTrue(primitive.startswith('Line '),primitive)
                self.assertIn('StrokeWidth 1',modifiers)
                lines.append(split_arguments(primitive[len('Line '):]))
            return lines
        view,section={},None
        for raw in source_lines(RESOURCES/'Modules'/'Visualizer'/'View.inc'):
            line=raw.strip()
            if line.startswith('[') and line.endswith(']'):
                section=line[1:-1]
            elif section=='MeterVisualizerPlot' and '=' in line and not line.startswith(';'):
                key,value=line.split('=',1)
                view[key]=value
        drawer_lines=grid(read_config('Media.ini',drawer=2)[0]['MeterVisualizerPlot'])
        for quarter,(ours,theirs) in enumerate(zip(drawer_lines,grid(view)),1):
            with self.subTest(quarter=quarter):
                # The standalone Visualizer draws the same quarter rows.
                self.assertEqual((ours[0],ours[1],ours[3]),(theirs[0],theirs[1],theirs[3]))
                self.assertEqual((ours[0],ours[1]),('1',ours[3]))
                self.assertIn('Floor(',ours[1])
                # Any whole-pixel bar height: a pixel centre whose 1px row holds
                # the exact quarter, the bars starting one pixel inside the frame.
                for bar in range(4,512):
                    y=numeric(ours[1].replace('#VisualizerBarHeight#',str(bar)))
                    exact=1+bar*quarter/4
                    self.assertTrue(float(y-0.5).is_integer(),(bar,y))
                    self.assertTrue(y-0.5<=exact<y+0.5,(bar,y,exact))
        for preset in HEIGHT_PRESETS:
            for scale in SCALES:
                with self.subTest(preset=preset,scale=scale):
                    sections,_,_,expand=read_config('Media.ini',drawer=2,preset=preset,scale=scale)
                    val=value_of(expand)
                    height,width=val('#MediaVisualizerPlotHeight#'),val('#MediaVisualizerPlotWidth#')
                    bar=val('#VisualizerBarHeight#')
                    self.assertEqual(bar,height-2)
                    rows=[]
                    for quarter,(x1,y1,x2,y2) in enumerate(grid(sections['MeterVisualizerPlot']),1):
                        y=val(y1)
                        self.assertEqual((val(x1),val(x2),val(y2)),(1,width-1,y))
                        self.assertTrue(float(y-0.5).is_integer(),y)
                        self.assertLessEqual(abs(y-(1+bar*quarter/4)),0.5)
                        rows.append(y)
                    self.assertEqual(rows,sorted(set(rows)))
                    # Inside the frame's 1px border.
                    self.assertGreaterEqual(rows[0]-0.5,1)
                    self.assertLessEqual(rows[-1]+0.5,height-1)

    def test_visualizer_menu_reloads_an_open_media_drawer(self):
        # Quality and cadence feed Capture.inc, which the open drawer shares, so
        # the standalone menu also asks Media to reload; RefreshVisualizerDrawer
        # does so only while the drawer is open on screen.
        rainmeter,section={},None
        for raw in source_lines(ROOT/'Visualizer'/'Visualizer.ini'):
            line=raw.strip()
            if line.startswith('[') and line.endswith(']'):
                section=line[1:-1]
            elif section=='Rainmeter' and '=' in line and not line.startswith(';'):
                key,value=line.split('=',1)
                self.assertNotIn(key,rainmeter)
                rainmeter[key]=value
        refresh='[!CommandMeasure MeasureMediaOptions "RefreshVisualizerDrawer()" "Parallax\\Media"]'
        expected={5:('VisualizerQuality','0'),6:('VisualizerQuality','1'),7:('VisualizerQuality','2'),
                  8:('VisualizerUpdateOverride','0'),9:('VisualizerUpdateOverride','33'),
                  10:('VisualizerUpdateOverride','50'),11:('VisualizerUpdateOverride','100')}
        actions={int(key[len('ContextAction'):] or 1):value for key,value in rainmeter.items()
                 if key.startswith('ContextAction')}
        for index,action in actions.items():
            with self.subTest(action=index):
                if index in expected:
                    key,value=expected[index]
                    self.assertEqual(action,f'[!WriteKeyValue Variables {key} {value} "#@#User\\Visualizer.inc"]'
                                            +refresh+'[!Refresh]')
                else:
                    self.assertNotIn('RefreshVisualizerDrawer',action)
        lua=(RESOURCES/'Modules'/'Media'/'MediaOptions.lua').read_text(encoding='ascii')
        self.assertEqual(lua.count('function RefreshVisualizerDrawer()'),1)

    def test_spectrum_capture_exists_only_in_the_open_drawer(self):
        def audio_level(sections):
            return [name for name,section in sections.items() if section.get('Plugin')=='AudioLevel']
        for config,drawer in [('Media.ini',0),('Media.ini',1),('Setup.ini',0),('Setup.ini',1),('Setup.ini',2)]:
            for columns in COLUMNS:
                with self.subTest(config=config,drawer=drawer,columns=columns):
                    sections,_,visited,_=read_config(config,drawer=drawer,columns=columns)
                    self.assertEqual(audio_level(sections),[])
                    self.assertFalse([name for name in sections if name.startswith('MeasureVisualizer')])
                    for name in OPEN_DRAWER_METERS:
                        self.assertNotIn(name,sections)
                    self.assertFalse({'Capture.inc','Spectrum.inc','Color.lua'}&{path.name for path in visited})
        for columns in COLUMNS:
            with self.subTest(config='Media.ini',drawer=2,columns=columns):
                sections,variables,visited,expand=read_config('Media.ini',drawer=2,columns=columns)
                val=value_of(expand)
                capture=audio_level(sections)
                parents=[name for name in capture if 'Parent' not in sections[name]]
                self.assertEqual(parents,['MeasureVisualizerAudio'])
                parent=sections['MeasureVisualizerAudio']
                for key,value in {'Port':'Output','ID':'#VisualizerDeviceID#','Bands':'24','FreqMin':'40',
                                  'FreqMax':'16000','FFTOverlap':'0'}.items():
                    self.assertEqual(parent[key],value)
                self.assertEqual(expand('#VisualizerDeviceID#'),'')
                self.assertEqual(sorted(set(capture)-{'MeasureVisualizerAudio'}),sorted(CAPTURE_CHILDREN))
                self.assertEqual(len(capture),1+len(CAPTURE_CHILDREN))
                for name in CAPTURE_CHILDREN:
                    self.assertEqual(sections[name]['Parent'],'MeasureVisualizerAudio')
                for index in range(24):
                    self.assertEqual(sections[f'MeasureVisualizerBand{index}']['BandIdx'],str(index))
                self.assertEqual(sections['MeasureVisualizerState']['Measure'],'Calc')
                # Every capture measure runs on Media's 50 ms tick at the
                # Visualizer's default 50 ms cadence.
                for name in capture+['MeasureVisualizerState']:
                    self.assertEqual(sections[name]['UpdateDivider'],'#VisualizerCaptureDivider#',name)
                self.assertEqual(val('#VisualizerCaptureDivider#'),1)
                apply=sections['MeasureVisualizerColorApply']
                self.assertEqual({key:apply.get(key) for key in ('Measure','Formula','UpdateDivider','OnUpdateAction')},
                                 {'Measure':'Calc','Formula':'1','UpdateDivider':'-1',
                                  'OnUpdateAction':'[!CommandMeasure MeasureVisualizerColor "Apply(false)"]'})
                self.assertEqual(sections['MeasureVisualizerColor']['ScriptFile'],'#@#Modules\\Visualizer\\Color.lua')
                self.assertEqual(sections['MeasureVisualizerColor']['UpdateDivider'],'-1')
                # The other plugins are unchanged: the player and the inert hosts.
                plugins={section['Plugin'] for section in sections.values() if 'Plugin' in section}
                self.assertEqual(plugins,{'AudioLevel','WebNowPlaying','RunCommand'})
                self.assertEqual([name for name,section in sections.items() if section.get('Plugin')=='RunCommand'],list(RESUME_HOSTS))
                for name in capture+['MeasureVisualizerState','MeasureVisualizerColorApply']:
                    for key,value in sections[name].items():
                        if 'Action' in key:
                            self.assertNotRegex(value.lower(),r'python|powershell|cmd\.exe|runcommand|spotify:|authorize')
                # Media's own choices win over User\Visualizer.inc's.
                self.assertEqual(variables['Columns'],str(columns))
                self.assertEqual(variables['PanelHeight'],'162')
                self.assertEqual(val('#WindowWidth#'),columns*val('#Pitch#'))
        # Shipped files: the Visualizer saves Columns=2 / PanelHeight=146, and
        # neither reaches Media's own layout (Media.inc: Columns=2, 162).
        shipped={line.split('=',1)[0]:line.split('=',1)[1] for line in source_lines(RESOURCES/'User'/'Visualizer.inc') if '=' in line and not line.startswith(';')}
        self.assertEqual((shipped['Columns'],shipped['PanelHeight']),('2','146'))
        _,variables,_,_=read_config('Media.ini',drawer=2,simulate_user=False)
        self.assertEqual((variables['Columns'],variables['PanelHeight'],variables['VisualizerPresetHeight']),('2','162','146'))
        # Distinct values make the precedence observable.
        for media_columns in COLUMNS:
            with self.subTest(media_columns=media_columns):
                _,variables,_,expand=read_config('Media.ini',drawer=2,columns=media_columns,
                                                 visualizer_columns=3-media_columns,preset=186)
                self.assertEqual(variables['Columns'],str(media_columns))
                self.assertEqual(variables['PanelHeight'],'162')
                self.assertEqual(variables['VisualizerPresetHeight'],'186')
                self.assertEqual(numeric(expand('#VisualizerPanelHeight#')),186)

    def test_spectrum_height_presets_set_the_lift(self):
        # Media.ini captures the Audio settings Height preset by include NAME;
        # the lift follows Options.inc's plot height for it.
        self.assertEqual({preset:media_visualizer_lift(1,preset) for preset in HEIGHT_PRESETS},
                         {126:72,146:92,186:132})  # 92 and 132 measured natively at Scale 1.
        for preset in HEIGHT_PRESETS:
            for scale in SCALES:
                for surface in (1,4):
                    for columns in COLUMNS:
                        with self.subTest(preset=preset,scale=scale,surface=surface,columns=columns):
                            heights={}
                            for drawer in (1,2):
                                sections,variables,visited,expand=read_config('Media.ini',drawer=drawer,preset=preset,
                                                                             scale=scale,surface=surface,columns=columns)
                                val=value_of(expand)
                                heights[drawer]=val('#WindowHeight#')
                                self.assertIn(f'HeightPresets/{preset}.inc',[path.relative_to(RESOURCES/'Modules'/'Visualizer').as_posix()
                                                                              for path in visited if 'Visualizer' in path.parts])
                                self.assertEqual(variables['VisualizerPresetHeight'],str(preset))
                                self.assertEqual(variables['PanelHeight'],'162')
                            plot=val('#MediaVisualizerPlotHeight#')
                            lift=val('#MediaVisualizerLift#')
                            self.assertEqual(plot,visualizer_plot_height(scale,preset,surface))
                            self.assertEqual(plot,val('#VisualizerPlotHeightPx#'))
                            # The default CornerRadius keeps the plot at the padding.
                            self.assertEqual(val('#MediaVisualizerPlotInset#'),val('#MediaDrawerPadding#'))
                            self.assertEqual(lift,math.ceil(val('#MediaVisualizerPlotInset#')+plot+val('#MediaSectionGap#')))
                            self.assertEqual(lift,media_visualizer_lift(scale,preset,surface))
                            self.assertTrue(float(lift).is_integer())
                            self.assertEqual(heights[2]-heights[1],lift)
                            self.assertEqual(heights[2],media_drawer_geometry(220,scale,columns,0,5,drawer=2,preset=preset,border=surface)[3])
                            # Closed, the preset changes nothing.
                            self.assertEqual(heights[1],media_drawer_geometry(220,scale,columns,0,5,drawer=1)[3])

    def test_setup_hides_the_spectrum_tab_and_keeps_the_player_position(self):
        for drawer in DRAWER_STATES:
            for scale in SCALES:
                for columns in COLUMNS:
                    with self.subTest(drawer=drawer,scale=scale,columns=columns):
                        sections,variables,_,expand=read_config('Setup.ini',drawer=drawer,scale=scale,columns=columns)
                        val=value_of(expand)
                        self.assertEqual(variables['MediaVisualizerHost'],'0')
                        for variable,expected in (('MediaVisualizerHost',0),('MediaVisualizerTab',0),('MediaVisualizerOpen',0),
                                                  ('MediaVisualizerLift',0),('MediaTop',val('#Inset#'))):
                            self.assertEqual(val(f'#{variable}#'),expected,variable)
                        for name in DRAWER_METERS:
                            self.assertEqual(val(resolve_style(sections,name)['Hidden']),1,name)
                        # Same panel as Media.ini with the drawer closed (an open
                        # preference in Setup still only reserves the strip).
                        _,_,_,media_expand=read_config('Media.ini',drawer=min(drawer,1),scale=scale,columns=columns)
                        media=value_of(media_expand)
                        for variable in ('MediaSurfaceY','MediaBodyHeightPx','MediaCoverY','MediaCoverSize',
                                         'ContentX','ContentWidth','WindowHeight'):
                            self.assertEqual(val(f'#{variable}#'),media(f'#{variable}#'),variable)
                        lift=sections['MeasureMediaVisualizerLift']
                        self.assertEqual({key:lift.get(key) for key in ('Measure','Formula','UpdateDivider','OnUpdateAction')},
                                         {'Measure':'Calc','Formula':'#MediaVisualizerOpenLift#','UpdateDivider':'-1',
                                          'OnUpdateAction':'[!CommandMeasure MeasureMediaOptions "CheckAnchor()"]'})
                        measures=[name for name,section in sections.items() if 'Measure' in section]
                        self.assertEqual(measures.index('MeasureMediaVisualizerLift'),measures.index('MeasureMediaOptions')+1)


if __name__ == '__main__':
    unittest.main()
