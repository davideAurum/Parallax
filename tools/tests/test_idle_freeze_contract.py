"""Idle stand-down freeze contract (docs/ARCHITECTURE.md, idle stand-down).

Developer-only stdlib checks; no Rainmeter, live profile or provider access.
Resolves each consumer entrypoint like Rainmeter (includes where their key
appears, variables as known then, later keys win) and checks the groups the
shared hook (@Resources/Idle/Hook.inc, StandDown.lua) depends on:

* every meter that can repaint (static divider 0 or more, or a divider set by
  a static !SetOption / !SetOptionGroup action) is in ParallaxIdleFreeze;
* no measure is in ParallaxIdleFreeze;
* every periodic measure is in ParallaxIdlePause, except the hook, lease and
  join measures, RunCommand measures and MeasureMediaLifecycle;
* hook and join members are never paused;
* a static member whose explicit divider differs from what deleting the key
  restores (its style or the skin default) is listed in RESTORED, which names
  the module controller that re-applies it (ReapplyDividers);
* each Lua file that sets UpdateDivider belongs to a module listed in
  LUA_DIVIDER_OWNERS (the module suites check those ReapplyDividers);
* shipped runtime state files are all zero;
* the "Paused (idle)" line has no fill, and each entrypoint's
  ParallaxIdleHeadline names existing meters including every meter in the
  line's row (hidden while paused, never merely covered); a hover pair's
  value is a headline meter and the hover-out action re-hides it while paused.

Run: python -m unittest tools/tests/test_idle_freeze_contract.py
Survey: python tools/tests/test_idle_freeze_contract.py --survey [overrides]
"""
from collections import OrderedDict
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2] / 'Skins' / 'Parallax'
RESOURCES = ROOT / '@Resources'
TOKEN = re.compile(r'#([^#\s]+)#')

FREEZE = 'PARALLAXIDLEFREEZE'
PAUSE = 'PARALLAXIDLEPAUSE'
HOOK = 'PARALLAXIDLEHOOK'
JOIN = 'PARALLAXIDLEJOIN'

# Consumer entrypoints wired to the hook, and the variant sets to check. Each
# set is applied on top of IdlePauseMinutes=5 (the hook) and checked
# separately. Every utility entrypoint is listed once it carries the hook.
CONSUMERS = OrderedDict([
    ('Chronometer/Chronometer.ini', [{}]),
    ('RAM/RAM.ini', [{}, {'RAMShowProcesses': '0'}]),
    ('GPU/GPU.ini', [{}, {'GPUShowProcesses': '0'}, {'GPUShowProcessMemory': '0'}]),
    ('CPU/CPU.ini', [{}, {'CPUShowProcesses': '0'}]),
    ('IO/IO-Disk.ini', [{}]),
    ('Network/Network.ini', [{}]),
    ('Media/Media.ini', [{}, {'VisualizerDrawer': '0'}, {'VisualizerDrawer': '2', 'MediaDrawerCapture': '0'},
                         {'VisualizerDrawer': '2', 'MediaDrawerCapture': '1'}, {'VisualizerDrawer': '2', 'MediaDrawerCapture': '2'},
                         {'MediaStandby': '1'}, {'MediaStandby': '1', 'VisualizerDrawer': '2', 'MediaDrawerCapture': '1'},
                         {'MediaTitleAnimation': '0'}]),
    ('Media/Setup.ini', [{}]),
    ('Media/Queue/Queue.ini', [{}]),
    ('Visualizer/Visualizer.ini', [{}, {'VisualizerStandby': '1'}]),
])

# Every utility entrypoint, wired or not yet (all ten once C2 is complete).
UTILITY_ENTRYPOINTS = ('Chronometer/Chronometer.ini', 'CPU/CPU.ini', 'GPU/GPU.ini', 'RAM/RAM.ini', 'IO/IO-Disk.ini',
                       'Network/Network.ini', 'Media/Media.ini', 'Media/Setup.ini', 'Media/Queue/Queue.ini',
                       'Visualizer/Visualizer.ini')

# Measures that keep running while a skin is paused: the stand-down hook
# itself, the drawer's capture lease (a join member) and Media's lifecycle
# measure (provider resume and stop on close). Every RunCommand host is also
# exempt (event-only; pausing one could strand its FinishAction).
NEVER_PAUSED = {'MEASUREPARALLAXSTANDDOWN', 'MEASUREMEDIACAPTURELEASE', 'MEASUREMEDIALIFECYCLE'}

# Static freeze members whose explicit divider differs from what deleting the
# key restores, with the controller function that re-applies it on leave.
# Keys are (entrypoint, METER NAME); values describe the owner.
RESTORED = {
    ('Media/Setup.ini', 'METERHEADING'): 'UpdateDivider=#MediaLegacyDivider#, which is 1 in Setup.ini (no player, no drawer: '
                                         'MediaTickInterval is MediaInterval), the same as its default; the native probe compares it',
}

# Lua files that set a meter's UpdateDivider at runtime, with the controller
# whose ReapplyDividers covers it (its module suite checks that). Paths are
# relative to @Resources/Modules. StandDown.lua is the mechanism itself.
LUA_DIVIDER_OWNERS = {
    'RAM/Display.lua': 'MeasureRAMSettings ReapplyDividers: Used GB/MB by unit, history cover (Tests/DisplayIdleTests.lua)',
    'CPU/CPU.lua': 'MeasureCPUController ReapplyDividers: all 64 Thread slots from slotLive (tests/validate_controller.lua idle case)',
    'Media/MediaPulse.lua': 'MeterPlayerIcon: Media.ini leaves standby by reloading, so nothing is re-applied in place',
    'IO/IO.lua': 'MeasureIO ReapplyDividers: every IORow<letter> group from its row record (tests/ControllerSuite.lua idle case)',
    'GPU/Temperature.lua': 'its own ReapplyDividers: the restarted History cover (tests/TemperatureSuite.lua idle case)',
    'RAM/Process.lua':'its own measure MeasureRAMProcessView only (not a meter); paused with the skin and re-idled by its own Update',
}

# Meters whose divider a module's Lua sets at runtime (UpdateDivider=-1 in
# the INI): they can repaint once bound, so they must be in the freeze group
# even though their static divider is -1. Patterns match upper-case names.
LUA_MANAGED_METERS = {
    'CPU/CPU.ini': r'^METERCORE(LABEL|BAR|VALUE|VOLTAGE|TEMPERATURE)\d+$',
    'Media/Media.ini': r'^METERPLAYERICON$',
    'IO/IO-Disk.ini': r'^METERIO(DRIVE|CAPACITY|USED|DISKREADLABEL|DISKWRITELABEL|DISKREAD|DISKWRITE|LEGEND)[A-Z]$',
}

# Shipped runtime state files that must stay all zero (a release install
# resets them; a non-zero value would ship a paused or parked state).
STATE_FILES = ('Modules/Media/CaptureState.inc', 'Modules/Visualizer/StandbyState.inc')


def read_text(path):
    data = path.read_bytes()
    if data[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return data.decode('utf-16')
    return data.decode('utf-8-sig', errors='replace')


class Config:
    """One entrypoint resolved like Rainmeter."""

    def __init__(self, relative, overrides=None):
        self.relative = relative
        self.path = ROOT / relative
        self.overrides = dict(overrides or {})
        self.variables = {
            '@': str(RESOURCES) + '\\',
            'ROOTCONFIGPATH': str(ROOT) + '\\',
            'CURRENTPATH': str(self.path.parent) + '\\',
            'CURRENTFILE': self.path.name,
            'ROOTCONFIG': 'Parallax',
        }
        self.variables.update(self.overrides)
        self.sections = OrderedDict()   # upper name -> {'name', 'keys': {upper key: (key, value, file)}}
        self.files = []
        self.missing = []
        self._visit(self.path)

    def expand(self, value, depth=30):
        for _ in range(depth):
            expanded = TOKEN.sub(lambda m: self.variables.get(m.group(1), m.group(0)), value)
            if expanded == value:
                break
            value = expanded
        return value

    def _visit(self, path):
        if path in self.files:
            return
        if not path.is_file():
            self.missing.append(str(path))
            return
        self.files.append(path)
        current = None
        for raw in read_text(path).splitlines():
            line = raw.strip()
            if not line or line.startswith(';'):
                continue
            match = re.match(r'^\[([^\]]+)\]\s*$', line)
            if match:
                name = match.group(1)
                current = self.sections.setdefault(name.upper(), {'name': name, 'keys': OrderedDict()})
                continue
            if current is None or '=' not in line:
                continue
            key, value = line.split('=', 1)
            key, value = key.strip(), value.strip()
            if key.lower().startswith('@include'):
                target = self.expand(value.strip('"'))
                if '#' in target:
                    self.missing.append(target)
                    continue
                target = Path(target)
                if not target.is_absolute():
                    target = path.parent / target
                self._visit(Path(str(target).replace('/', '\\')))
                continue
            current['keys'][key.upper()] = (key, value, path)
            if current['name'].upper() == 'VARIABLES':
                self.variables[key] = self.overrides.get(key, value)

    # -- section helpers -------------------------------------------------
    def own(self, section, key):
        entry = self.sections[section]['keys'].get(key.upper())
        return None if entry is None else entry[1]

    def styles(self, section):
        style = self.own(section, 'MeterStyle')
        if not style:
            return []
        return [name.strip().upper() for name in self.expand(style).split('|') if name.strip()]

    def option(self, section, key):
        """The value Rainmeter reads: own key, else the last style holding it."""
        value = self.own(section, key)
        if value is not None:
            return value
        if self.kind(section) == 'meter':
            for style in reversed(self.styles(section)):
                if style in self.sections and key.upper() in self.sections[style]['keys']:
                    return self.sections[style]['keys'][key.upper()][1]
        return None

    def kind(self, section):
        keys = self.sections[section]['keys']
        if 'METER' in keys:
            return 'meter'
        if 'MEASURE' in keys:
            return 'measure'
        return None

    def groups(self, section):
        value = self.option(section, 'Group')
        if not value:
            return set()
        return {name.strip().upper() for name in self.expand(value).split('|') if name.strip()}

    def default_divider(self):
        value = self.own('RAINMETER', 'DefaultUpdateDivider') if 'RAINMETER' in self.sections else None
        return self.number(value) if value is not None else 1

    def number(self, value):
        """A static number, or None when it is not one (runtime-dependent)."""
        if value is None:
            return None
        text = self.expand(value).strip()
        if re.fullmatch(r'\(?-?\d+\)?', text):
            return int(text.strip('()'))
        try:
            return int(evaluate(text))
        except Exception:
            return None

    def divider(self, section):
        """Effective divider and its origin: 'own', 'style' or 'default'."""
        own = self.own(section, 'UpdateDivider')
        if own is not None:
            return self.number(own), 'own'
        if self.kind(section) == 'meter':
            for style in reversed(self.styles(section)):
                if style in self.sections and 'UPDATEDIVIDER' in self.sections[style]['keys']:
                    return self.number(self.sections[style]['keys']['UPDATEDIVIDER'][1]), 'style'
        return self.default_divider(), 'default'

    def restored_divider(self, section):
        """What deleting the meter's own UpdateDivider leaves: style or default."""
        for style in reversed(self.styles(section)):
            if style in self.sections and 'UPDATEDIVIDER' in self.sections[style]['keys']:
                return self.number(self.sections[style]['keys']['UPDATEDIVIDER'][1])
        return self.default_divider()

    def meters(self):
        return [name for name in self.sections if self.kind(name) == 'meter']

    def measures(self):
        return [name for name in self.sections if self.kind(name) == 'measure']

    def actions(self):
        """Every static option value that can hold bangs, with its section."""
        for name, section in self.sections.items():
            for upper, (key, value, path) in section['keys'].items():
                if '[' in value and '!' in value:
                    yield name, key, self.expand(value)


def evaluate(text):
    """A tiny formula evaluator for static dividers: + - * / ( ) numbers.
    Walks the parsed expression; anything else raises ValueError."""
    import ast
    import operator
    binary = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}

    def walk(node):
        if isinstance(node, ast.Expression):
            return walk(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return node.value
        if isinstance(node, ast.BinOp) and type(node.op) in binary:
            return binary[type(node.op)](walk(node.left), walk(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            value = walk(node.operand)
            return -value if isinstance(node.op, ast.USub) else value
        raise ValueError(text)
    return walk(ast.parse(text, mode='eval'))


BANG = re.compile(r'\[\s*!(SetOption|SetOptionGroup)\s+("[^"]*"|\S+)\s+("?)UpdateDivider\3\s', re.IGNORECASE)


def runtime_divider_targets(config):
    """Meters named by a static !SetOption ... UpdateDivider, plus every member
    of a !SetOptionGroup ... UpdateDivider group (meters only)."""
    named, groups = set(), set()
    for _, _, value in config.actions():
        for match in BANG.finditer(value):
            target = match.group(2).strip('"').upper()
            if match.group(1).lower() == 'setoptiongroup':
                groups.add(target)
            else:
                named.add(target)
    found = {name for name in named if name in config.sections and config.kind(name) == 'meter'}
    for group in groups - {FREEZE}:
        found |= {name for name in config.meters() if group in config.groups(name)}
    return found


def hooked(overrides):
    values = {'IdlePauseMinutes': '5'}
    values.update(overrides)
    return values


def survey(overrides):
    for relative in UTILITY_ENTRYPOINTS:
        config = Config(relative, overrides)
        default = config.default_divider()
        print('=' * 72)
        print(relative, 'default divider', default, 'missing', config.missing)
        periodic = [m for m in config.meters() if (config.divider(m)[0] is None or config.divider(m)[0] >= 0)]
        runtime = runtime_divider_targets(config)
        print(' meters', len(config.meters()), 'periodic', len(periodic), 'runtime-set', len(runtime))
        untagged = [m for m in periodic if FREEZE not in config.groups(m)]
        print(' periodic meters not in freeze:', len(untagged))
        for name in untagged[:400]:
            divider, origin = config.divider(name)
            print('   M', config.sections[name]['name'], divider, origin, sorted(config.groups(name)),
                  config.sections[name]['keys']['METER'][2].name)
        for name in sorted(runtime - set(periodic)):
            print('   R', config.sections[name]['name'], sorted(config.groups(name)))
        measures = [m for m in config.measures() if (config.divider(m)[0] is None or config.divider(m)[0] >= 0)]
        unpaused = [m for m in measures if PAUSE not in config.groups(m)]
        print(' periodic measures', len(measures), 'not in pause:', len(unpaused))
        for name in unpaused:
            kind = config.own(name, 'Measure')
            plugin = config.own(name, 'Plugin') or ''
            print('   S', config.sections[name]['name'], kind, plugin, config.divider(name), sorted(config.groups(name)),
                  config.sections[name]['keys']['MEASURE'][2].name)
        explicit = [m for m in periodic if config.divider(m)[1] == 'own' and config.divider(m)[0] != config.restored_divider(m)]
        print(' explicit dividers differing from restore:', [(config.sections[m]['name'], config.own(m, 'UpdateDivider')) for m in explicit])


LUA_SET_DIVIDER = re.compile(r"""['"]UpdateDivider['"]""")


def strip_lua_comments(text):
    text = re.sub(r'--\[(=*)\[.*?\]\1\]', '', text, flags=re.S)
    return re.sub(r'--[^\n]*', '', text)


def periodic(config, name):
    divider = config.divider(name)[0]
    return divider is None or divider >= 0


def runcommand(config, name):
    return (config.own(name, 'Measure') or '').lower() == 'plugin' and \
        (config.own(name, 'Plugin') or '').lower() == 'runcommand'


class HookFiles(unittest.TestCase):
    def test_variants(self):
        idle = RESOURCES / 'Idle'
        body = [line for line in read_text(idle / 'Hook0.inc').splitlines() if line.strip() and not line.strip().startswith(';')]
        self.assertEqual(body, [], 'Hook0.inc is comment-only')
        bodies = []
        for minutes in (5, 10, 30):
            lines = [line for line in read_text(idle / f'Hook{minutes}.inc').splitlines()
                     if line.strip() and not line.strip().startswith(';')]
            bodies.append(lines)
            self.assertIn('@IncludeParallaxIdleHook=#@#Idle\\Hook.inc', lines)
            self.assertIn('ParallaxIdleJoinAction=[!Delay 100][!UpdateMeasureGroup ParallaxIdleJoin]'
                          '[!Delay 10500][!UpdateMeasureGroup ParallaxIdleJoin]', lines)
        self.assertEqual(bodies[0], bodies[1])
        self.assertEqual(bodies[0], bodies[2])

    def test_hook_sections(self):
        text = read_text(RESOURCES / 'Idle' / 'Hook.inc')
        self.assertIn('Group=ParallaxIdleHook | ParallaxIdleJoin', text)
        self.assertNotRegex(text, r'(?im)^Group=.*ParallaxIdlePause')
        self.assertRegex(text, r'(?m)^UpdateDivider=#ParallaxIdleHookDivider#')
        self.assertRegex(text, r'(?m)^Text=Paused \(idle\)')
        self.assertNotRegex(text, r'(?i)tooltip')
        # The line replaces hidden headline meters; a fill would only cover
        # them, and Background transparency makes BackgroundColor translucent.
        line = text.split('[MeterParallaxPaused]', 1)[1]
        self.assertNotRegex(line, r'(?im)^\s*SolidColor\s*=')
        self.assertRegex(text, r'(?m)^ParallaxIdleHoverAction=\[!CommandMeasure MeasureParallaxStandDown "Hover\(\)"\]\r?$')

    def test_defaults(self):
        text = read_text(RESOURCES / 'Defaults.inc')
        for line in ('IdlePauseMinutes=0', 'ParallaxIdleJoinAction=', 'ParallaxIdleHookMs=60000',
                     'ParallaxIdleHookDivider=60', 'ParallaxIdleControllers=', 'ParallaxIdleHeadline=',
                     'ParallaxIdleHoverSwap=', 'ParallaxIdleHoverAction='):
            self.assertRegex(text, '(?m)^' + re.escape(line) + r'\r?$')
        self.assertRegex(read_text(RESOURCES / 'User' / 'Settings.inc'), r'(?m)^IdlePauseMinutes=0\r?$')


class StateFiles(unittest.TestCase):
    def test_shipped_state_is_zero(self):
        for relative in STATE_FILES:
            path = RESOURCES / relative
            if not path.exists():
                continue
            values = re.findall(r'(?m)^\s*(\w+)\s*=\s*(.*?)\s*$', read_text(path))
            self.assertTrue(values, relative)
            for key, value in values:
                self.assertEqual(value, '0', f'{relative}: {key}={value}')


class LuaDividerOwners(unittest.TestCase):
    def test_every_runtime_setter_has_an_owner(self):
        modules = RESOURCES / 'Modules'
        found = set()
        for path in modules.rglob('*.lua'):
            if any(part.lower() in ('tests', 'test', 'qa') for part in path.parts):
                continue
            if LUA_SET_DIVIDER.search(strip_lua_comments(read_text(path))):
                found.add(path.relative_to(modules).as_posix())
        wired = {relative.split('/')[0] for relative in CONSUMERS}
        for relative in sorted(found):
            if relative.split('/')[0] in wired:
                self.assertIn(relative, LUA_DIVIDER_OWNERS, f'{relative} sets UpdateDivider at runtime')
        for relative in LUA_DIVIDER_OWNERS:
            self.assertIn(relative, found, f'{relative} no longer sets a divider')


class Consumers(unittest.TestCase):
    def test_off_loads_nothing(self):
        for relative in UTILITY_ENTRYPOINTS:
            config = Config(relative, {'IdlePauseMinutes': '0'})
            self.assertNotIn('MEASUREPARALLAXSTANDDOWN', config.sections, relative)
            self.assertNotIn('METERPARALLAXPAUSED', config.sections, relative)
            self.assertEqual(config.missing, [], relative)

    def test_entrypoint_wiring(self):
        for relative in CONSUMERS:
            raw = read_text(ROOT / relative)
            sections = re.findall(r'(?m)^\[([^\]]+)\]', raw)
            self.assertEqual(sections[-1], 'ParallaxIdleHookInclude', f'{relative}: the hook include is the last section')
            self.assertRegex(raw, r'(?m)^\[ParallaxIdleHookInclude\]\r?\n@Include\w*=#@#Idle\\Hook#IdlePauseMinutes#\.inc\r?$')
            config = Config(relative, hooked({}))
            refresh = config.own('RAINMETER', 'OnRefreshAction') or ''
            self.assertTrue(refresh.endswith('#ParallaxIdleJoinAction#'), f'{relative}: OnRefreshAction ends with the join')
            for name in ('ParallaxIdleControllers', 'ParallaxIdleHeadline', 'ParallaxIdleHookDivider', 'ParallaxPausedX',
                         'ParallaxPausedY', 'ParallaxPausedW', 'ParallaxPausedH', 'ParallaxPausedAlign'):
                self.assertRegex(raw, '(?m)^' + name + '=', f'{relative}: sets {name}')
            self.assertIn('#ParallaxIdleHookMs#', raw, relative)

    def test_groups(self):
        for relative, variants in CONSUMERS.items():
            for overrides in variants:
                label = f'{relative} {overrides}'
                config = Config(relative, hooked(overrides))
                self.assertEqual(config.missing, [], label)
                self.assertIn('MEASUREPARALLAXSTANDDOWN', config.sections, label)
                meters = config.meters()
                self.assertEqual(meters[-1], 'METERPARALLAXPAUSED', f'{label}: the paused line draws last')
                runtime = runtime_divider_targets(config)
                managed = re.compile(LUA_MANAGED_METERS[relative]) if relative in LUA_MANAGED_METERS else None
                if managed:
                    self.assertTrue(any(managed.match(name) for name in meters), f'{label}: no meter matches the Lua-managed pattern')
                for name in meters:
                    if managed and managed.match(name):
                        self.assertIn(FREEZE, config.groups(name), f'{label}: Lua-managed meter [{config.sections[name]["name"]}] is not in ParallaxIdleFreeze')
                    shown = config.sections[name]['name']
                    if name == 'METERPARALLAXPAUSED':
                        self.assertNotIn(FREEZE, config.groups(name))
                        continue
                    if periodic(config, name) or name in runtime:
                        self.assertIn(FREEZE, config.groups(name), f'{label}: meter [{shown}] can repaint '
                                      f'(divider {config.divider(name)}) but is not in ParallaxIdleFreeze')
                    if FREEZE in config.groups(name) and periodic(config, name):
                        divider, origin = config.divider(name)
                        if origin == 'own' and divider != config.restored_divider(name):
                            self.assertIn((relative, name), RESTORED, f'{label}: [{shown}] UpdateDivider='
                                          f'{config.own(name, "UpdateDivider")} is lost when the freeze key is deleted; '
                                          f'list it in RESTORED with its ReapplyDividers owner')
                for name in config.measures():
                    groups = config.groups(name)
                    shown = config.sections[name]['name']
                    self.assertNotIn(FREEZE, groups, f'{label}: measure [{shown}] in ParallaxIdleFreeze')
                    exempt = name in NEVER_PAUSED or runcommand(config, name) or HOOK in groups or JOIN in groups
                    if exempt:
                        self.assertNotIn(PAUSE, groups, f'{label}: [{shown}] must never be paused')
                    elif periodic(config, name):
                        self.assertIn(PAUSE, groups, f'{label}: periodic measure [{shown}] is not in ParallaxIdlePause')


def row_key(config, text):
    """A comparable form of a Y option: its value when the fully expanded
    formula is plain arithmetic, else the expanded text without spaces."""
    if text is None:
        return None
    expanded = re.sub(r'\s+', '', config.expand(text))
    try:
        return round(float(evaluate(expanded)), 6)
    except Exception:
        return expanded


def split_names(text):
    return [name.strip() for name in (text or '').split('|') if name.strip()]


class Headline(unittest.TestCase):
    """C.6: the paused line replaces the headline, which is hidden, never
    merely covered (the line has no fill). Every meter in the line's row is
    in ParallaxIdleHeadline, every listed name exists, and a gear/value hover
    pair keeps the frozen value hidden on a hover-out."""

    def test_headline_lists_cover_the_paused_row(self):
        for relative, variants in CONSUMERS.items():
            for overrides in variants:
                label = f'{relative} {overrides}'
                config = Config(relative, hooked(overrides))
                listed = split_names(config.expand(config.variables.get('ParallaxIdleHeadline') or ''))
                self.assertTrue(listed, f'{label}: ParallaxIdleHeadline is empty')
                upper = {name.upper() for name in listed}
                for name in listed:
                    self.assertTrue(name.upper() in config.sections, f'{label}: headline meter [{name}] does not exist')
                    self.assertEqual(config.kind(name.upper()), 'meter', f'{label}: [{name}] is not a meter')
                row = row_key(config, config.variables.get('ParallaxPausedY'))
                in_row = []
                for name in config.meters():
                    if name == 'METERPARALLAXPAUSED':
                        continue
                    if row_key(config, config.option(name, 'Y')) == row:
                        in_row.append(name)
                        self.assertIn(name, upper, f'{label}: [{config.sections[name]["name"]}] sits in the paused '
                                      f'line\'s row (Y {row}) but is not in ParallaxIdleHeadline')
                self.assertTrue(in_row, f'{label}: no meter shares the paused line\'s row; is ParallaxPausedY right?')

    def test_hover_pairs(self):
        for relative in CONSUMERS:
            config = Config(relative, hooked({}))
            pair = split_names(config.expand(config.variables.get('ParallaxIdleHoverSwap') or ''))
            listed = {name.upper() for name in split_names(config.expand(config.variables.get('ParallaxIdleHeadline') or ''))}
            leave = config.own('RAINMETER', 'MouseLeaveAction') or ''
            if not pair:
                # Without a pair, no hover action may show a headline meter.
                for name in listed:
                    self.assertNotRegex(leave, r'(?i)\[!ShowMeter\s+' + re.escape(name) + r'\]',
                                        f'{relative}: MouseLeaveAction shows headline meter {name} but no ParallaxIdleHoverSwap names it')
                continue
            self.assertEqual(len(pair), 2, f'{relative}: ParallaxIdleHoverSwap is "Gear|Value"')
            gear, value = pair[0].upper(), pair[1].upper()
            self.assertTrue(gear in config.sections, f'{relative}: hover gear [{pair[0]}] does not exist')
            self.assertIn(value, listed, f'{relative}: the hover value is a headline meter')
            self.assertNotIn(gear, listed, f'{relative}: the gear stays under the hover actions')
            shows = re.search(r'(?i)\[!ShowMeter\s+' + re.escape(pair[1]) + r'\]', leave)
            if shows:
                self.assertTrue(leave.endswith('#ParallaxIdleHoverAction#[!Redraw]'),
                                f'{relative}: MouseLeaveAction must end with #ParallaxIdleHoverAction#[!Redraw]: {leave}')
            else:
                # A script hover (RAM's Display.lua Hover) keeps the value
                # hidden itself while the line shows.
                self.assertIn('!CommandMeasure', leave, f'{relative}: hover value shown neither by bang nor by a script')


def write_lists(relative, meters_path, measures_path, overrides):
    """For Test-IdleStandDown.ps1: every meter, and every ParallaxIdlePause
    member, of an entrypoint resolved with these overrides, one per line."""
    config = Config(relative, overrides)
    if config.missing:
        raise SystemExit(f'{relative}: missing includes {config.missing}')
    Path(meters_path).write_text('\n'.join(config.sections[n]['name'] for n in config.meters()) + '\n', encoding='utf-8')
    Path(measures_path).write_text('\n'.join(config.sections[n]['name'] for n in config.measures()
                                             if PAUSE in config.groups(n)) + '\n', encoding='utf-8')
    print(f'{relative}: {len(config.meters())} meters, '
          f'{sum(1 for n in config.measures() if PAUSE in config.groups(n))} paused measures')


if __name__ == '__main__' and '--list' in sys.argv:
    arguments = sys.argv[sys.argv.index('--list') + 1:]
    write_lists(arguments[0], arguments[1], arguments[2], dict(arg.split('=', 1) for arg in arguments[3:]))
    sys.exit(0)

if __name__ == '__main__' and '--survey' in sys.argv:
    extra = dict(arg.split('=', 1) for arg in sys.argv[2:] if '=' in arg)
    survey(hooked(extra))
    sys.exit(0)

if __name__ == '__main__':
    unittest.main()
