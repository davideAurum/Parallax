// Focused offline settings checks. Does not launch Rainmeter or write preferences.
// Run: node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate-settings.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const sections = new Map(), variables = { '@': root + '/@Resources/' };
const files = new Set(), assignments = [];
let importedPreferences;
function expand(source, overrides = {}) {
  const values = { ...variables, ...overrides };
  for (let i = 0; i < 30; i++) {
    const next = source.replace(/#([^#]+)#/g, (whole, key) => values[key] ?? whole);
    if (source === next) return source;
    source = next;
  }
  throw new Error('Variable expansion did not terminate');
}
function readIni(path) {
  assert.ok(!files.has(path), 'Repeated include: ' + path);
  files.add(path);
  const local = new Set();
  let name;
  for (const raw of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith(';')) continue;
    const heading = /^\[([^\]]+)\]$/.exec(line);
    if (heading) {
      name = heading[1];
      assert.ok(!local.has(name), 'Duplicate section: ' + name);
      local.add(name);
      if (!sections.has(name)) sections.set(name, {});
      continue;
    }
    const option = /^([^=]+)=(.*)$/.exec(line);
    assert.ok(name && option, 'Malformed INI line: ' + line);
    const [, key, value] = option;
    if (key.startsWith('@Include')) {
      readIni(resolve(root, expand(value).replaceAll('\\', '/')));
    } else {
      sections.get(name)[key] = value;
      if (name === 'Variables') {
        variables[key] = value;
        assignments.push({ path, key, value });
      }
    }
  }
  if (path === resolve(root, '@Resources/User/Visualizer.inc')) {
    importedPreferences = { Columns: variables.Columns, PanelHeight: variables.PanelHeight };
  }
}
readIni(resolve(root, 'Visualizer/Settings/Settings.ini'));
function effective(name) {
  const own = sections.get(name);
  assert.ok(own, 'Missing section: ' + name);
  const base = {};
  for (const style of (own.MeterStyle ?? '').split('|').map(s => s.trim()).filter(Boolean)) {
    Object.assign(base, effective(style));
  }
  return { ...base, ...own };
}
function formula(source, overrides = {}) {
  let expression = expand(source, overrides);
  assert.match(expression.replace(/\b(Max|Min|Round)\b/g, ''), /^[\d\s()+*/,.?:<>=!&|_-]+$/);
  expression = expression.replaceAll('<>', '!=').replace(/(?<![<>=!])=(?!=)/g, '===');
  const result = Function('Max', 'Min', 'Round', 'return (' + expression + ')')(Math.max, Math.min, Math.round);
  assert.ok(Number.isFinite(result), 'Nonfinite formula result');
  return result;
}
const prefix = 'MeterVisualizerSettings';
const expected = [
  ['Width', 'Columns', [1, 2], ['Single', 'Double'], true],
  ['Height', 'PanelHeight', [126, 146, 186], ['126 px', '146 px', '186 px'], false, 126, 186, true],
  ['Spacing', 'VisualizerBandGap', [0, 1, 3, 4], ['0 px', '1 px', '3 px', '4 px'], false, 0, 4],
  ['Color', 'VisualizerColorMode', [0, 1, 2, 3], ['Media', 'Accent 1', 'Accent 2', 'Gradient'], true],
  ['Quality', 'VisualizerQuality', [0, 1, 2], ['Low', 'Normal', 'High'], true],
  ['Cadence', 'VisualizerUpdateOverride', [0, 33, 50, 100], ['Suite', '33 ms', '50 ms', '100 ms'], true],
  ['Sensitivity', 'VisualizerSensitivity', [10, 20, 35, 50, 65, 80], null, false, 10, 80],
  ['Attack', 'VisualizerAttack', [0, 50, 100, 200, 2000], null, false, 0, 2000],
  ['Decay', 'VisualizerDecay', [0, 100, 250, 500, 1000, 5000], null, false, 0, 5000]
];
const allowedKeys = new Set(expected.map(row => row[1]));
assert.equal(sections.get('Rainmeter').Update, '-1');
assert.equal(sections.get('Rainmeter').Group, 'Parallax');
assert.deepEqual({ Columns: variables.Columns, PanelHeight: variables.PanelHeight }, importedPreferences);
for (const entry of assignments.filter(entry => ['Columns', 'PanelHeight'].includes(entry.key))) {
  assert.ok(!entry.path.includes('Visualizer\\Settings') && !entry.path.endsWith('Modules\\Visualizer\\Settings.inc'),
    'Settings must not replace the imported spectrum preference: ' + entry.key);
}
const measures = [...sections].filter(([, section]) => section.Measure);
assert.equal(measures.length, 8, 'One event-only controller, one dormant input helper, six static display measures');
assert.equal(measures.filter(([, section]) => section.Measure === 'String').length, 6);
for (const [name, measure] of measures) {
  assert.equal(measure.UpdateDivider, '-1');
  if (measure.Measure === 'String') assert.ok(!Object.keys(measure).some(key => key.includes('Action')));
  else assert.ok(['MeasureVisualizerSettings', 'MeasureVisualizerSettingsInput'].includes(name));
}
assert.equal(sections.get('MeasureVisualizerSettings').Measure, 'Script');
assert.equal(sections.get('MeasureVisualizerSettings').ScriptFile, '#@#Modules\\Visualizer\\Settings.lua');
const helper = sections.get('MeasureVisualizerSettingsInput');
assert.equal(helper.Plugin, 'RunCommand');
assert.equal(helper.Program, '%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe');
assert.equal(helper.Parameter, '-NoProfile -NonInteractive');
assert.equal(helper.State, 'Hide');
assert.equal(helper.OutputType, 'UTF8');
assert.equal(helper.Timeout, '300000');
assert.equal(helper.FinishAction, '[!UpdateMeasure MeasureVisualizerSettingsInput][!CommandMeasure MeasureVisualizerSettings "CommitInput()"]');
const source = readFileSync(resolve(root, '@Resources/Modules/Visualizer/Settings.lua'), 'utf8');
const fields = [...source.matchAll(/^    (\w+) = \{ key='(\w+)', values=\{([^}]+)\}, ([^}]+) \}/gm)];
assert.equal(fields.length, 9);
assert.deepEqual(new Set(fields.map(field => field[2])), allowedKeys);
for (const [name, key, values, , categorical, minimum, maximum, discrete] of expected) {
  const field = fields.find(field => field[1] === name);
  assert.equal(field[2], key);
  assert.deepEqual(field[3].split(',').map(Number), values);
  assert.equal(field[4].includes('categorical=true'), categorical);
  if (!categorical) {
    assert.match(field[4], new RegExp('minimum=' + minimum + ', maximum=' + maximum));
    assert.equal(field[4].includes('discrete=true'), Boolean(discrete));
  }
}
assert.match(source, /-Key UtilityNumber -Minimum %d -Maximum %d -DecimalPlaces 0/);
assert.match(source, /function CommitInput\(\)/);
assert.ok(!/loadstring|os\.execute|io\.open|!RefreshGroup|!ActivateConfig|!PluginBang/.test(source));
const allowedActions = new Set([helper.FinishAction,
  '[!Refresh "Parallax\\Visualizer"][!Refresh]', '[!DeactivateConfig]',
  '["notepad.exe" "#@#User\\Visualizer.inc"]',
  '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]']);
let choiceLabels = 0, controlTargets = 0;
function displayedValue(name, key, value) {
  const meter = effective(prefix + name + 'Value');
  const overrides = { [key]: String(value) };
  if (!meter.MeasureName) return expand(meter.Text, overrides);
  const measure = sections.get(meter.MeasureName);
  assert.equal(measure.Measure, 'String');
  let text = expand(measure.String, overrides);
  if (measure.Substitute) {
    assert.equal(measure.RegExpSubstitute, '1');
    const pairs = [...measure.Substitute.matchAll(/"([^"]*)":"([^"]*)"/g)];
    assert.equal(pairs.map(pair => pair[0]).join(','), measure.Substitute, 'Unhandled substitution syntax');
    for (const [, pattern, replacement] of pairs) text = text.replace(new RegExp(pattern), replacement);
  }
  return meter.Text.replaceAll('%1', text);
}
for (const [name, key, values, friendly] of expected) {
  for (const role of ['Row', 'Label', 'Value', 'Previous', 'Next']) {
    const raw = sections.get(prefix + name + role), meter = effective(prefix + name + role);
    assert.equal(raw.Meter, role === 'Row' ? 'Shape' : 'String');
    const style = role === 'Row' ? 'StyleSettingsStepperFrame' : role === 'Label' ? 'StyleUtilitySettingsLabel'
      : role === 'Value' ? 'StyleSettingsStepperValue' : 'StyleSettingsStepperButton';
    assert.ok(raw.MeterStyle.split('|').map(s => s.trim()).includes(style));
    const callback = ['Previous', 'Next'].includes(role) ? `Step('${name}',${role === 'Previous' ? -1 : 1})` : `Activate('${name}')`;
    const action = `[!CommandMeasure MeasureVisualizerSettings "${callback}"]`;
    assert.equal(meter.LeftMouseUpAction, action);
    allowedActions.add(action); controlTargets++;
    assert.ok(meter.ToolTipText); assert.equal(meter.UpdateDivider, '-1');
    if (role !== 'Row') {
      assert.equal(meter.FontColor, ['Previous', 'Next'].includes(role) ? '#AccentColor#' : '#TextColor#');
      assert.equal(meter.FontFace, '#FontFace#'); assert.equal(meter.ClipString, '1');
      assert.equal(raw.FontColor, undefined, 'Controls must inherit the shared color role');
    }
  }
  for (let i = 0; i < values.length; i++) {
    assert.equal(displayedValue(name, key, values[i]), friendly ? friendly[i] : `${values[i]} ${name === 'Sensitivity' ? 'dB' : 'ms'}`);
    choiceLabels++;
  }
  for (const custom of [-999, 0.5, 9999]) assert.ok(displayedValue(name, key, custom).includes(String(custom)), 'Custom value must stay visible');
}
assert.equal(controlTargets, 45);
assert.equal(choiceLabels, 37);
for (const [name, section] of sections) {
  if (name.startsWith('Style')) assert.ok(!section.Meter, 'Style draws a meter: ' + name);
  // Shared unused styles can carry other actions; only rendered meters/measures are reachable here.
  if (!section.Meter && !section.Measure && name !== 'Rainmeter') continue;
  for (const [key, action] of Object.entries(section).filter(([key]) => /Action\d*$/.test(key))) {
    assert.ok(allowedActions.has(action), 'Unexpected action: ' + name + '.' + key);
  }
}
for (const name of ['Appearance', 'Performance', 'Animation', 'Setup']) {
  const meter = effective(prefix + name);
  assert.ok(sections.get(prefix + name).MeterStyle.includes('StyleUtilitySettingsSection'));
  assert.equal(meter.FontColor, '#AccentColor#');
  assert.equal(meter.FontSize, '(#HeaderFontSize#*#Scale#)');
  const rule = effective(prefix + name + 'Rule');
  assert.ok(sections.get(prefix + name + 'Rule').MeterStyle.split('|').map(s => s.trim()).includes('StyleRule'));
  assert.match(rule.Shape, /Stroke Color #DividerColor#/); assert.match(rule.Shape, /#DividerThickness#/);
}
assert.equal(effective(prefix + 'Reconnect').LeftMouseUpAction, '[!Refresh "Parallax\\Visualizer"][!Refresh]');
assert.equal(effective(prefix + 'Close').LeftMouseUpAction, '[!DeactivateConfig]');
assert.equal(effective(prefix + 'Advanced').LeftMouseUpAction, '["notepad.exe" "#@#User\\Visualizer.inc"]');
assert.equal(effective('MeterUtilitySettingsGlobalLink').LeftMouseUpAction,
  '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]');

function args(source) {
  const result = []; let start = 0, depth = 0;
  for (let i = 0; i < source.length; i++) {
    if (source[i] === '(') depth++;
    if (source[i] === ')') depth--;
    if (source[i] === ',' && !depth) { result.push(source.slice(start, i)); start = i + 1; }
  }
  return [...result, source.slice(start)];
}
function shapeBounds(shape, f) {
  const [primitive, ...modifiers] = shape.split('|').map(part => part.trim());
  const match = /^(Rectangle|Line) (.*)$/.exec(primitive);
  assert.ok(match, 'Unhandled settings shape: ' + primitive);
  const p = args(match[2]).map(f);
  const stroke = f(modifiers.find(value => value.startsWith('StrokeWidth '))?.slice(12) ?? '1');
  return match[1] === 'Rectangle'
    ? { x: p[0] - stroke / 2, y: p[1] - stroke / 2, w: p[2] + stroke, h: p[3] + stroke }
    : { x: Math.min(p[0], p[2]) - stroke / 2, y: Math.min(p[1], p[3]) - stroke / 2,
      w: Math.abs(p[2] - p[0]) + stroke, h: Math.abs(p[3] - p[1]) + stroke };
}
function box(meter, f) {
  const shape = meter.Meter === 'Shape' ? shapeBounds(meter.Shape, f) : null;
  let x = f(meter.X ?? '0'), y = f(meter.Y ?? '0');
  const padding = args(meter.Padding ?? '0,0,0,0').map(f);
  const w = meter.W === undefined ? shape.w : f(meter.W) + padding[0] + padding[2];
  const h = meter.H === undefined ? shape.h : f(meter.H) + padding[1] + padding[3];
  if (meter.Meter === 'Shape') {
    x += shape.x; y += shape.y;
  } else {
    const align = meter.StringAlign ?? 'Left';
    if (align.startsWith('Right')) x -= w;
    if (align.startsWith('Center')) x -= w / 2;
    if (['LeftCenter', 'RightCenter', 'CenterCenter'].includes(align)) y -= h / 2;
  }
  return { x, y, w, h };
}
function within(a, b, label) {
  assert.ok(a.x >= b.x - 0.001 && a.y >= b.y - 0.001 &&
    a.x + a.w <= b.x + b.w + 0.001 && a.y + a.h <= b.y + b.h + 0.001, label + ' exceeds bounds');
}
function separated(a, b, label) {
  assert.ok(a.x + a.w <= b.x + 0.001 || b.x + b.w <= a.x + 0.001 ||
    a.y + a.h <= b.y + 0.001 || b.y + b.h <= a.y + 0.001, label + ' overlaps');
}
const meters = [...sections].filter(([, section]) => section.Meter);
let geometries = 0;
for (const ColumnWidth of [180, 220]) for (const Scale of [0.75, 1, 1.25, 1.5, 2]) {
for (const BorderThickness of [0, 4]) for (const Columns of [1, 2]) {
  const overrides = Object.fromEntries(Object.entries({ ColumnWidth, Scale, BorderThickness, Columns,
    DividerThickness: BorderThickness, PanelHeight: Columns === 1 ? 126 : 186,
    FontSize: 10, HeaderFontSize: 10, TitleFontSize: 12 }).map(([k, v]) => [k, String(v)]));
  const f = value => formula(value, overrides);
  const window = { x: 0, y: 0, w: f('#WindowWidth#'), h: f('#WindowHeight#') };
  const panel = { x: f('#Inset#'), y: f('#Inset#'), w: f('#PanelWidth#'), h: f('#PanelHeightPx#') };
  const border = BorderThickness * Scale;
  const interior = { x: panel.x + border, y: panel.y + border, w: panel.w - 2 * border, h: panel.h - 2 * border };
  const boxes = new Map();
  assert.equal(window.w, 2 * f('#Pitch#'), 'Imported spectrum Columns must not size settings');
  assert.equal(panel.h, Math.round(344 * Scale), 'Imported spectrum height must not size settings');
  assert.equal(window.h, panel.h + f('#Gap#'));
  for (const [name] of meters) {
    const meter = effective(name), bounds = box(meter, f);
    boxes.set(name, bounds);
    assert.ok(bounds.w >= 0 && bounds.h >= 0);
    within(bounds, window, name);
    if (![prefix + 'Bounds', prefix + 'Panel'].includes(name)) within(bounds, interior, name);
  }
  const rowBoxes = new Map();
  for (const [name] of expected) {
    const row = boxes.get(prefix + name + 'Row');
    const label = boxes.get(prefix + name + 'Label'), value = boxes.get(prefix + name + 'Value');
    const previous = boxes.get(prefix + name + 'Previous'), next = boxes.get(prefix + name + 'Next');
    within(value, row, name + ' value/frame');
    separated(label, previous, name + ' label/previous');
    separated(previous, row, name + ' previous/frame'); separated(row, next, name + ' frame/next');
    assert.equal(label.y - row.y, 2 * Scale);
    assert.equal(label.w, 70 * Scale);
    assert.equal(previous.x - label.x, 76 * Scale);
    assert.equal(row.x - previous.x - previous.w, 2 * Scale);
    assert.equal(next.x - row.x - row.w, 2 * Scale);
    assert.equal(value.x, row.x); assert.equal(value.w, row.w);
    assert.equal(row.w, f('#VisualizerSettingsColumnWidth#') - 116 * Scale);
    // Shared unit/padding rounding can reclaim less than one physical pixel.
    assert.ok(row.w >= 56 * Scale - 1, 'Minimum center field width after shared rounding');
    assert.equal(row.h, 20 * Scale);
    for (const [role, bounds] of [['Previous', previous], ['Value', value], ['Next', next]]) {
      assert.equal(bounds.y - row.y, Scale); assert.equal(bounds.h, 18 * Scale);
      assert.equal(effective(prefix + name + role).StringAlign, 'Center');
      assert.equal(effective(prefix + name + role).Padding, '0,0,0,0');
      assert.equal(f(effective(prefix + name + role).FontSize), 10 * Scale);
      if (role !== 'Value') assert.equal(bounds.w, 18 * Scale);
    }
    assert.equal(f(effective(prefix + name + 'Label').FontSize), 10 * Scale);
    rowBoxes.set(name, { x: label.x, y: row.y, w: next.x + next.w - label.x, h: row.h });
  }
  const groups = [['Appearance', ['Width', 'Height', 'Spacing', 'Color']],
    ['Performance', ['Quality', 'Cadence']], ['Animation', ['Sensitivity', 'Attack', 'Decay']]];
  for (const [heading, names] of groups) {
    const section = boxes.get(prefix + heading), rule = boxes.get(prefix + heading + 'Rule');
    assert.equal(section.w, f('#VisualizerSettingsColumnWidth#'));
    // An underline sits at the heading box bottom; native text-ink clearance
    // is reviewed separately from its padded rectangle at thick dividers.
    assert.ok(Math.abs(rule.y + rule.h / 2 - section.y - section.h) < 0.001);
    separated(rule, rowBoxes.get(names[0]), heading + ' rule/field');
    for (let i = 0; i < names.length; i++) {
      const row = rowBoxes.get(names[i]);
      assert.equal(row.x, section.x);
      assert.ok(Math.abs(row.w - section.w) < 0.001);
      if (i) assert.equal(row.y - rowBoxes.get(names[i - 1]).y, 28 * Scale, 'Setting pitch');
    }
  }
  const allRows = [...rowBoxes.values()];
  for (let i = 0; i < allRows.length; i++) for (let j = i + 1; j < allRows.length; j++) {
    separated(allRows[i], allRows[j], 'Distinct setting fields');
  }
  const title = boxes.get(prefix + 'Title'), note = boxes.get('MeterUtilitySettingsNote');
  const globalLink = boxes.get('MeterUtilitySettingsGlobalLink');
  separated(title, note, 'Title/note'); separated(note, globalLink, 'Shared settings notes');
  for (const name of ['Appearance', 'Performance']) separated(globalLink, boxes.get(prefix + name), 'Note/form');
  separated(rowBoxes.get('Cadence'), boxes.get(prefix + 'Animation'), 'Performance/animation');
  separated(rowBoxes.get('Color'), boxes.get(prefix + 'Setup'), 'Appearance/setup');
  separated(boxes.get(prefix + 'SetupRule'), boxes.get(prefix + 'Advanced'), 'Setup rule/actions');
  separated(boxes.get(prefix + 'Advanced'), boxes.get(prefix + 'SetupHint'), 'Setup actions/hint');
  separated(boxes.get(prefix + 'SetupHint'), boxes.get(prefix + 'Hint'), 'Setup/footer hint');
  separated(rowBoxes.get('Decay'), boxes.get(prefix + 'Hint'), 'Animation/footer hint');
  separated(boxes.get(prefix + 'Title'), boxes.get(prefix + 'Close'), 'Title/close');
  separated(boxes.get(prefix + 'Advanced'), boxes.get(prefix + 'Reconnect'), 'Footer commands');
  geometries++;
}
}
assert.equal(geometries, 40);
console.log(`PASS: nine allowlisted fields; ${choiceLabels} displayed preset/end-point choices; custom display; ${controlTargets} fixed controller action targets; one event-only Script, dormant RunCommand and six String measures; Accent 1 headings/arrows and body values; stepper/frame clearance; 28px pitch; preserved imported preferences; ${geometries} geometry cases.`);
console.log('Offline source checks do not execute Lua, native text rendering, actual clicks/persistence, or the helper dialog. Run SettingsSuite.lua against production Settings.lua in an isolated Lua host for controller behavior.');
