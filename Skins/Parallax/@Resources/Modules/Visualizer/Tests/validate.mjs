// Offline checks against the shipped INI expressions. No Rainmeter commands run.
// Run: node Skins/Parallax/@Resources/Modules/Visualizer/Tests/validate.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const skinRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const sections = new Map();
const variables = { '@': skinRoot + '/@Resources/' };
const readFiles = [];
function expand(value, vars = variables) {
  for (let n = 0; n < 30; n++) {
    const next = value.replace(/#([^#]+)#/g, (match, name) => vars[name] ?? match);
    if (next === value) return value;
    value = next;
  }
  throw new Error('Variable expansion did not terminate');
}
function readIni(path) {
  assert.ok(!readFiles.includes(path), 'Repeated include: ' + path);
  readFiles.push(path);
  let section;
  const localSections = new Set();
  for (const raw of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith(';')) continue;
    const heading = /^\[([^\]]+)\]$/.exec(line);
    if (heading) {
      section = heading[1];
      assert.ok(!localSections.has(section), 'Duplicate section ' + section);
      localSections.add(section);
      if (!sections.has(section)) sections.set(section, {});
      continue;
    }
    const option = /^([^=]+)=(.*)$/.exec(line);
    assert.ok(option && section, 'Invalid INI line: ' + line);
    const [, key, value] = option;
    if (key.startsWith('@Include')) {
      readIni(resolve(skinRoot, expand(value).replaceAll('\\', '/')));
    } else {
      sections.get(section)[key] = value;
      if (section === 'Variables') variables[key] = value;
    }
  }
}
readIni(resolve(skinRoot, 'Visualizer/Visualizer.ini'));
function formula(source, overrides = {}, measures = {}) {
  let expression = expand(source, { ...variables, ...overrides });
  for (const [key, value] of Object.entries(measures)) {
    expression = expression.replaceAll(new RegExp('\\b' + key + '\\b', 'g'), String(value));
  }
  assert.ok(!expression.includes('#'), 'Unresolved variable: ' + expression);
  assert.ok(/^[\d\s()+*/,?.:<>=!&|_-]+$/.test(expression.replace(/\b(Max|Min|Round)\b/g, '')),
    'Unknown formula identifier: ' + expression);
  assert.ok(!/[;{}\[\]'"\\]/.test(expression), 'Unexpected formula syntax');
  expression = expression.replace(/(?<![<>=!])=(?!=)/g, '===').replaceAll('<>', '!==');
  return Function('Max', 'Min', 'Round', 'return (' + expression + ')')(
    Math.max, Math.min, Math.round);
}
function effective(section) {
  const own = sections.get(section);
  assert.ok(own, 'Missing section: ' + section);
  const result = {};
  for (const style of (own.MeterStyle ?? '').split('|').filter(Boolean)) {
    Object.assign(result, effective(style));
  }
  return { ...result, ...own };
}
const rainmeter = sections.get('Rainmeter');
const audio = sections.get('MeasureVisualizerAudio');
const state = sections.get('MeasureVisualizerState');
const format = sections.get('MeasureVisualizerFormat');
const meters = [...sections].filter(([name]) => name.startsWith('MeterVisualizer'));
const pluginMeasures = [...sections].filter(([, s]) => s.Plugin === 'AudioLevel');
assert.equal(rainmeter.Group, 'Parallax');
assert.equal(audio.Port, 'Output');
assert.equal(pluginMeasures.filter(([, s]) => !s.Parent).length, 1);
assert.equal(formula(audio.Bands), 24);
assert.equal(formula(audio.FFTOverlap), 0);
assert.equal(variables.VisualizerDeviceID, '');
assert.equal(formula(rainmeter.Update), 50);
assert.equal(formula(audio.FFTSize), 1024);
assert.ok(rainmeter.ContextAction.includes('Parallax\\Settings'));
assert.equal(effective('MeterVisualizerStop').LeftMouseUpAction, '[!DeactivateConfig]');
assert.equal(effective('MeterVisualizerRetry').LeftMouseUpAction, '[!Refresh]');
assert.equal(effective('MeterVisualizerTitle').FontColor, '#TitleTextColor#');
assert.equal(effective('MeterVisualizerDeviceName').FontColor, '#TextColor#');
assert.equal(effective('MeterVisualizerStop').FontColor, '#AccentColor#');
assert.equal(effective('MeterVisualizerRetry').FontColor, '#AccentColor2#');
assert.equal(effective('MeterVisualizerBand0').BarColor, '#MediaColor#');
for (const name of ['Scope', 'Low', 'High']) {
  assert.equal(effective('MeterVisualizer' + name).FontColor, '#MutedColor#');
}
assert.equal(state.IfConditionMode, '0');
assert.equal(state.DynamicVariables, '1');
assert.equal(format.IfMatchAction, '[!SetVariable VisualizerFormatInvalid 1]');
assert.equal(format.IfNotMatchAction, '[!SetVariable VisualizerFormatInvalid 0]');
for (const [description, expected] of [['48000Hz <invalid> 2ch', true], ['48000Hz f32 2ch', false], ['', false]]) {
  assert.equal(new RegExp(format.IfMatch).test(description), expected);
}

for (const [name, section] of sections) {
  if (name.startsWith('Style')) assert.ok(!section.Meter, name + ' draws a meter');
  if (name.startsWith('MeterVisualizer')) assert.ok(section.Meter, name + ' lacks Meter');
  if (section.MeasureName) assert.ok(sections.has(section.MeasureName));
  if (section.Parent) assert.equal(section.Parent, 'MeasureVisualizerAudio');
  for (const [key, action] of Object.entries(section).filter(([key]) => key.includes('Action'))) {
    if (action.includes('!WriteKeyValue')) {
      assert.ok(action.includes('"#@#User\\Visualizer.inc"'), name + '.' + key + ' writes shared settings');
      assert.ok(action.endsWith('[!Refresh]'));
    }
  }
}
for (let i = 0; i < 24; i++) {
  const band = sections.get('MeasureVisualizerBand' + i);
  assert.equal(band.Type, 'Band');
  assert.equal(Number(band.BandIdx), i);
  assert.equal(effective('MeterVisualizerBand' + i).MeasureName, 'MeasureVisualizerBand' + i);
}
for (const override of [-100, 0, 1, 33, 50, 100, 999999]) {
  for (const global of [1, 33, 50, 100, 999999]) {
    const interval = formula(rainmeter.Update, {
      VisualizerUpdateOverride: String(override), VisualizerInterval: String(global)
    });
    assert.ok([33, 50, 100].includes(interval));
    const selected = override === 0 ? global : override;
    assert.equal(interval, selected === 33 ? 33 : selected === 100 ? 100 : 50);
  }
}
for (const quality of [-999, 0, 0.5, 1, 2, 999]) {
  assert.ok([512, 1024, 2048].includes(formula(audio.FFTSize, { VisualizerQuality: String(quality) })));
}
for (const value of [-100, 0, 50, 999999]) {
  const attack = formula(audio.FFTAttack, { VisualizerAttack: String(value) });
  const decay = formula(audio.FFTDecay, { VisualizerDecay: String(value) });
  assert.ok(attack >= 0 && attack <= 2000);
  assert.ok(decay >= 0 && decay <= 5000);
}
// Simulate transition-triggered IfConditions using the actual shipped actions.
// A disconnected or silent endpoint must never keep stale bands visible.
let previousConditions = [false, false, false, false];
let spectrumVisible = false;
let status = '';
for (const [device, rms, invalid, expected] of [
  [0, 0, 0, 0], [1, 0, 0, 1], [1, 0.1, 0, 2], [1, 0.05, 0, 2],
  [1, 0, 0, 1], [1, 0.001, 0, 1], [1, 0.002, 0, 2], [0, 0.1, 0, 0],
  [1, 0, 0, 1], [1, 0, 1, 3], [1, 0.1, 1, 3], [0, 0.1, 1, 0],
  [1, 0.1, 0, 2], [1, 0.1, 1, 3], [1, 0, 0, 1]
]) {
  const value = formula(state.Formula, { VisualizerFormatInvalid: String(invalid) },
    { MeasureVisualizerDevice: device, MeasureVisualizerRMS: rms });
  assert.equal(value, expected);
  for (let i = 0; i < 4; i++) {
    const suffix = i === 0 ? '' : i + 1;
    const active = Boolean(formula(state['IfCondition' + suffix], {}, { MeasureVisualizerState: value }));
    if (active && !previousConditions[i]) {
      const action = state['IfTrueAction' + suffix];
      if (action.includes('!HideMeterGroup VisualizerSpectrum')) spectrumVisible = false;
      if (action.includes('!ShowMeterGroup VisualizerSpectrum')) spectrumVisible = true;
      status = /!SetOption MeterVisualizerStatus Text "([^"]+)"/.exec(action)[1];
    }
    previousConditions[i] = active;
  }
  assert.equal(spectrumVisible, expected === 2, 'Stale spectrum visible');
  assert.equal(status, ['OUTPUT UNAVAILABLE', 'IDLE - QUIET', 'LIVE - MIXED OUTPUT', 'FORMAT UNSUPPORTED'][expected]);
}
const dimensions = [];
function args(source) {
  const values = [];
  let depth = 0, start = 0;
  for (let i = 0; i < source.length; i++) {
    if (source[i] === '(') depth++;
    if (source[i] === ')') depth--;
    if (source[i] === ',' && depth === 0) {
      values.push(source.slice(start, i));
      start = i + 1;
    }
  }
  values.push(source.slice(start));
  return values;
}
function rect(meter, f) {
  let x = f(meter.X ?? '0'), y = f(meter.Y ?? '0');
  const padding = args(meter.Padding ?? '0,0,0,0').map(f);
  const w = f(meter.W) + padding[0] + padding[2];
  const h = f(meter.H) + padding[1] + padding[3];
  if (meter.StringAlign === 'Right') x -= w;
  if (meter.StringAlign === 'Center') x -= w / 2;
  return { x, y, w, h };
}
function within(small, large, label) {
  const epsilon = 0.001;
  assert.ok(small.x >= large.x - epsilon && small.y >= large.y - epsilon &&
    small.x + small.w <= large.x + large.w + epsilon &&
    small.y + small.h <= large.y + large.h + epsilon, label + ' exceeds bounds');
}
function nonoverlap(a, b, label) {
  assert.ok(a.x + a.w <= b.x || b.x + b.w <= a.x ||
    a.y + a.h <= b.y || b.y + b.h <= a.y, label + ' overlap');
}
const fontProfiles = [
  { profile: 'default', TitleFontSize: '10', HeaderFontSize: '8', FontSize: '9' },
  { profile: 'maximum', TitleFontSize: '12', HeaderFontSize: '10', FontSize: '10' }
];
const surfaceProfiles = [
  { BorderThickness: '0', DividerThickness: '0' },
  { BorderThickness: '1', DividerThickness: '1' },
  { BorderThickness: '4', DividerThickness: '4' }
];
for (const surfaceProfile of surfaceProfiles) {
for (const fontProfile of fontProfiles) {
for (const ColumnWidth of [180, 200, 240, 280, 320]) {
  for (const Scale of [0.75, 1, 1.25, 1.5, 2]) {
    for (const Columns of [1, 2]) {
      const vars = { ...fontProfile, ...surfaceProfile, Scale: String(Scale), Columns: String(Columns), ColumnWidth: String(ColumnWidth) };
      const f = value => formula(value, vars);
      const windowWidth = f('#WindowWidth#');
      const windowHeight = f('#WindowHeight#');
      const bounds = effective('MeterVisualizerBounds');
      const window = { x: 0, y: 0, w: windowWidth, h: windowHeight };
      const border = Number(surfaceProfile.BorderThickness) * Scale;
      const panel = { x: f('#Inset#'), y: f('#Inset#'), w: f('#PanelWidth#'), h: f('#PanelHeightPx#') };
      const interior = { x: panel.x + border, y: panel.y + border, w: panel.w - 2 * border, h: panel.h - 2 * border };
      const rectangles = new Map();
      assert.equal(f(bounds.W), windowWidth);
      assert.equal(f(bounds.H), windowHeight);
      assert.equal(windowWidth, Columns * f('#Pitch#'));
      assert.equal(f('#PanelWidth#') + f('#Gap#'), windowWidth);
      assert.equal(f('#Gap#') % 2, 0);
      let lastBandEnd = f('#ContentX#') + 1;
      const plot = rect(effective('MeterVisualizerPlot'), f);
      const plotInterior = { x: plot.x + 1, y: plot.y + 1, w: plot.w - 2, h: plot.h - 2 };
      const scenario = fontProfile.profile + ' fonts border ' + surfaceProfile.BorderThickness + ' width ' + ColumnWidth + ' scale ' + Scale + ' columns ' + Columns;
      for (const [name] of meters) {
        const meter = effective(name);
        const box = name === 'MeterVisualizerPanel' ? panel : rect(meter, f);
        rectangles.set(name, box);
        assert.ok(box.w > 0 && box.h > 0, name + ' has empty dimensions');
        within(box, window, name + ' ' + scenario);
        if (!['MeterVisualizerPanel', 'MeterVisualizerBounds'].includes(name)) {
          within(box, interior, name + ' inside panel border ' + scenario);
        }
        if (meter.Meter === 'String') {
          const roleSize = Number(name === 'MeterVisualizerTitle' ? fontProfile.TitleFontSize : fontProfile.FontSize);
          assert.equal(f(meter.FontSize), roleSize * Scale, name + ' must honor its chosen font size without a clamp or offset');
          assert.equal(meter.FontFace, '#FontFace#');
        }
        if (meter.Meter === 'Shape') {
          for (const [key, shape] of Object.entries(meter).filter(([key]) => /^Shape\d*$/.test(key))) {
            const [primitive, ...modifiers] = shape.split('|').map(part => part.trim());
            const match = /^(Rectangle|Line) (.*)$/.exec(primitive);
            assert.ok(match, 'Unhandled shape: ' + primitive);
            const p = args(match[2]).map(f);
            const sw = f(modifiers.find(mod => mod.startsWith('StrokeWidth '))?.slice(12) ?? '1');
            const local = match[1] === 'Rectangle' ?
              { x: p[0] - sw / 2, y: p[1] - sw / 2, w: p[2] + sw, h: p[3] + sw } :
              { x: Math.min(p[0], p[2]) - sw / 2, y: Math.min(p[1], p[3]) - sw / 2,
                w: Math.abs(p[2] - p[0]) + sw, h: Math.abs(p[3] - p[1]) + sw };
            within(local, { x: 0, y: 0, w: box.w, h: box.h }, name + '.' + key + ' stroke ' + scenario);
          }
        }
        if (meter.Meter === 'Bar') {
          within(box, plotInterior, name + ' plot ' + scenario);
          assert.ok(box.x >= lastBandEnd, 'Band order/spacing ' + scenario);
          lastBandEnd = box.x + box.w;
        }
        if (meter.LeftMouseUpAction) assert.ok(meter.ToolTipText);
      }
      const pairs = [
        ['Icon', 'Title'], ['Title', 'Scope'], ['Title', 'DeviceName'], ['Scope', 'DeviceName'],
        ['DeviceName', 'Status'], ['Status', 'Plot'], ['Plot', 'Low'], ['Plot', 'High'],
        ['Low', 'Stop'], ['High', 'Retry'], ['Stop', 'Retry']
      ];
      for (const [a, b] of pairs) nonoverlap(rectangles.get('MeterVisualizer' + a),
        rectangles.get('MeterVisualizer' + b), a + '/' + b + ' ' + scenario);
      for (const name of ['DeviceName', 'Status', 'Unavailable']) {
        const meter = effective('MeterVisualizer' + name);
        assert.equal(meter.ClipString, '1');
        assert.ok(f(meter.H) >= 18 * Scale);
      }
      assert.equal(f(effective('MeterVisualizerStatus').W), f('#ContentWidth#'));
      dimensions.push({ profile: fontProfile.profile, border: surfaceProfile.BorderThickness, ColumnWidth, Scale, Columns, windowWidth, windowHeight, panelWidth: f('#PanelWidth#') });
    }
  }
}
}
}
assert.equal(dimensions.length, 300);
console.log('PASS: includes; one output parent; 24 band mappings; setting bounds; four-state transitions; action scope; semantic typography/colors; 300 default/max-font and border/divider 0/1/4 geometry cases; shape/stroke extents; content inside panel borders; nonoverlapping rows/controls.');
console.table(dimensions.filter(row => row.profile === 'maximum' && row.border === '4' && (row.ColumnWidth === 180 || row.ColumnWidth === 200)));
console.log('Checked ' + readFiles.length + ' files: ' + readFiles.map(p => relative(skinRoot, p)).join(', '));
console.log('Offline checks do not verify Rainmeter rendering, audio capture, timing, DPI, persistence, or CPU cost.');
