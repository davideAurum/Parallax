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
  let expression = source.includes('#') ? expand(source, { ...variables, ...overrides }) : source;
  for (const [key, value] of (expression.includes('Measure') ? Object.entries(measures) : [])) {
    expression = expression.replaceAll('[' + key + ']', '(' + value + ')');
    expression = expression.replaceAll(new RegExp('\\b' + key + '\\b', 'g'), String(value));
  }
  assert.ok(!expression.includes('#'), 'Unresolved variable: ' + expression);
  assert.ok(/^[\d\s()+*/,?.:<>=!&|_-]+$/.test(expression.replace(/\b(Max|Min|Round|Ceil)\b/g, '')),
    'Unknown formula identifier: ' + expression);
  assert.ok(!/[;{}\[\]'"\\]/.test(expression), 'Unexpected formula syntax');
  expression = expression.replace(/(?<![<>=!])=(?!=)/g, '===').replaceAll('<>', '!==');
  return Function('Max', 'Min', 'Round', 'Ceil', 'return (' + expression + ')')(
    Math.max, Math.min, Math.round, Math.ceil);
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
const volume = sections.get('MeasureVisualizerVolume');
const volumeValue = sections.get('MeasureVisualizerVolumeValue');
const volumeMeter = effective('MeterVisualizerVolume');
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
assert.equal(rainmeter.ContextAction12, '[!Refresh]');
assert.equal(rainmeter.ContextAction13, '[!DeactivateConfig]');
assert.match(rainmeter.ContextTitle12, /Reconnect output device/i);
assert.match(rainmeter.ContextTitle13, /Stop capture.*unload/i);
for (const removed of ['Stop', 'Retry', 'Scope', 'Status']) {
  assert.ok(!sections.has('MeterVisualizer' + removed), removed + ' still consumes visible layout');
}
const options = effective('MeterVisualizerOptions');
assert.equal(options.Meter, 'Shape');
assert.equal(options.Hidden, '1');
assert.equal(options.LeftMouseUpAction, '[!ActivateConfig "Parallax\\Visualizer\\Settings" "Settings.ini"]');
assert.ok(options.ToolTipText);
assert.match(options.Shape, /Fill Color #AccentColor2#/);
assert.equal(rainmeter.MouseOverAction, '[!HideMeter MeterVisualizerVolume][!ShowMeter MeterVisualizerOptions][!Redraw]');
assert.equal(rainmeter.MouseLeaveAction, '[!HideMeter MeterVisualizerOptions][!ShowMeter MeterVisualizerVolume][!Redraw]');
assert.notEqual(volumeMeter.Hidden, '1');
assert.equal(volumeMeter.FontColor, '#TextColor#');
assert.equal(volumeMeter.StringAlign, 'RightCenter');
assert.equal(volumeMeter.MeasureName, 'MeasureVisualizerVolumeValue');
assert.equal(volumeMeter.NumOfDecimals, '0');
assert.equal(volumeMeter.DynamicVariables, '1');
assert.equal(volumeMeter.Text, '--');
assert.equal(volume.Plugin, 'Win7AudioPlugin');
assert.equal([...sections.values()].filter(section => section.Plugin === 'Win7AudioPlugin').length, 1);
assert.equal(volume.IfMatchMode, '0');
assert.equal(volume.IfMatchAction, '[!SetVariable VisualizerVolumeAvailable 0]');
assert.equal(volume.IfNotMatchAction, '[!SetVariable VisualizerVolumeAvailable 1]');
assert.equal(volumeValue.Measure, 'Calc');
assert.equal(volumeValue.DynamicVariables, '1');
assert.equal(volumeValue.IfConditionMode, '0');
assert.equal(formula(volumeValue.MinValue), -1);
assert.equal(formula(volumeValue.MaxValue), 100);
assert.equal(formula('#VisualizerVolumeAvailable#'), 0);
// The two boxes intentionally occupy the same header area. Hover must expose
// only one at a time, and leaving must restore the passive volume readout.
let gearVisible = options.Hidden !== '1', volumeVisible = volumeMeter.Hidden !== '1';
for (const [action, expectedGear] of [
  [rainmeter.MouseOverAction, true], [rainmeter.MouseOverAction, true],
  [rainmeter.MouseLeaveAction, false], [rainmeter.MouseLeaveAction, false]
]) {
  for (const [, operation, target] of action.matchAll(/!(ShowMeter|HideMeter) (MeterVisualizer\w+)/g)) {
    if (target === 'MeterVisualizerOptions') gearVisible = operation === 'ShowMeter';
    if (target === 'MeterVisualizerVolume') volumeVisible = operation === 'ShowMeter';
  }
  assert.equal(gearVisible, expectedGear);
  assert.equal(volumeVisible, !expectedGear);
}
assert.equal(effective('MeterVisualizerTitle').FontColor, '#TitleTextColor#');
assert.equal(effective('MeterVisualizerDeviceName').FontColor, '#TextColor#');
const outputIcon = effective('MeterVisualizerOutputIcon');
assert.equal(outputIcon.Meter, 'Shape');
assert.equal(outputIcon.W, '(14*#Scale#)');
assert.equal(outputIcon.H, '(14*#Scale#)');
assert.equal(outputIcon.UpdateDivider, '-1');
assert.equal(outputIcon.ToolTipText, undefined);
assert.match(outputIcon.LucideSpeakerStroke, /Stroke Color #MediaColor#/);
assert.match(outputIcon.LucideSpeakerStroke, /StrokeStartCap Round/);
assert.match(outputIcon.LucideSpeakerStroke, /StrokeEndCap Round/);
assert.match(outputIcon.LucideSpeakerStroke, /StrokeLineJoin Round/);
const speakerSvg = readFileSync(resolve(skinRoot, '@Resources/Modules/Visualizer/Icons/Lucide/speaker.svg'), 'utf8').trim();
assert.equal(speakerSvg, '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-speaker"><rect width="16" height="20" x="4" y="2" rx="2"/><path d="M12 6h.01"/><circle cx="12" cy="14" r="4"/><path d="M12 14h.01"/></svg>');
assert.match(readFileSync(resolve(skinRoot, '@Resources/Modules/Visualizer/Icons/Lucide/LICENSE'), 'utf8'), /ISC License/);
assert.match(readFileSync(resolve(skinRoot, '@Resources/Modules/Visualizer/Icons/Lucide/README.md'), 'utf8'), /8F578D9AADB55DEFA7C1EBFF1C1391FEB5B97CE0D868DE44F67B7C84F54E9B79/);
const deviceHit = effective('MeterVisualizerDeviceHit');
const switchPrefix = '[!CommandMeasure MeasureVisualizerVolume ';
const clearCaptureId = '[!WriteKeyValue Variables VisualizerDeviceID "" "#@#User\\Visualizer.inc"]';
assert.equal(deviceHit.Meter, 'Image');
assert.equal(deviceHit.SolidColor, '0,0,0,1');
assert.equal(deviceHit.MouseActionCursor, '1');
assert.equal(deviceHit.UpdateDivider, '-1');
assert.equal(deviceHit.LeftMouseUpAction, switchPrefix + '"ToggleNext"]' + clearCaptureId + '[!Refresh]');
assert.equal(deviceHit.MouseScrollDownAction, deviceHit.LeftMouseUpAction);
assert.equal(deviceHit.MouseScrollUpAction, switchPrefix + '"TogglePrevious"]' + clearCaptureId + '[!Refresh]');
assert.match(deviceHit.ToolTipText, /changes the system default output/i);
assert.match(deviceHit.ToolTipText, /clears a custom Visualizer device ID/i);
assert.deepEqual(meters.filter(([, meter]) => meter.ToolTipText).map(([name]) => name),
  ['MeterVisualizerOptions', 'MeterVisualizerDeviceHit']);
const spectrumMask = effective('MeterVisualizerSpectrumMask');
const spectrumFill = effective('MeterVisualizerFill');
assert.equal(meters.filter(([, meter]) => meter.Meter === 'Bar').length, 0);
assert.equal(spectrumMask.Meter, 'Shape');
assert.equal(spectrumMask.SolidColor, '0,0,0,0');
assert.equal(spectrumMask.DynamicVariables, '1');
assert.equal(spectrumFill.Meter, 'Shape');
assert.equal(spectrumFill.Container, 'MeterVisualizerSpectrumMask');
assert.equal(spectrumFill.UpdateDivider, '-1');
assert.equal(spectrumFill.Shape, 'Rectangle 0,0,#VisualizerPlotInnerWidth#,#VisualizerBarHeight# | Fill Color #MediaColor# | StrokeWidth 0');
assert.equal(spectrumFill.SpectrumGradient, '180 | #AccentColor# ; 0 | #AccentColor2# ; 1');
assert.deepEqual(meters.filter(([, meter]) => meter.Container).map(([name]) => name), ['MeterVisualizerFill']);
for (const meter of [spectrumMask, spectrumFill]) {
  assert.equal(meter.Group, 'VisualizerSpectrum');
  assert.equal(meter.Hidden, '1');
  assert.equal(meter.W, '#VisualizerPlotInnerWidth#');
  assert.equal(meter.H, '#VisualizerPlotInnerHeight#');
}
for (const name of ['Low', 'High', 'DbMax', 'DbMid', 'DbMin']) {
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
    assert.ok(!action.includes('LIVE - MIXED OUTPUT'), 'Removed live caption remains in ' + name + '.' + key);
    const volumeCommands = [...action.matchAll(/!CommandMeasure\s+"?MeasureVisualizerVolume"?\s+"([^"]+)"/gi)];
    if (volumeCommands.length) {
      assert.equal(name, 'MeterVisualizerDeviceHit', 'Only the current-output row may switch devices');
      assert.ok(['ToggleNext', 'TogglePrevious'].includes(volumeCommands[0][1]),
        'Current-output row may switch devices but must not control volume or mute');
      assert.equal(volumeCommands.length, 1, 'One output switch per action');
      assert.ok(action.includes(clearCaptureId), 'Output switch must clear a custom AudioLevel endpoint ID');
    }
    assert.ok(!/!PluginBang[^\]]*Win7Audio/i.test(action),
      'Volume readout must not send legacy Win7Audio control commands');
    for (const target of action.matchAll(/!(?:SetOption|UpdateMeter|ShowMeter|HideMeter)\s+(MeterVisualizer\w+)/g)) {
      assert.ok(sections.has(target[1]), name + '.' + key + ' targets removed meter ' + target[1]);
    }
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
  assert.ok(!sections.has('MeterVisualizerBand' + i), 'Old Bar meter remains');
  const shapeKey = i ? 'Shape' + (i + 1) : 'Shape';
  assert.equal(spectrumMask[shapeKey], 'Path BandPath' + i + ' | Fill Color 255,255,255,255 | StrokeWidth 0');
  assert.deepEqual([...variables['VisualizerBandHeight' + i].matchAll(/\[(MeasureVisualizerBand\d+)\]/g)].map(match => match[1]),
    ['MeasureVisualizerBand' + i], 'Each path must follow exactly its own band');
  assert.ok(spectrumMask['BandPath' + i]);
}
assert.equal(Object.keys(spectrumMask).filter(key => /^Shape\d*$/.test(key)).length, 24);
assert.equal(Object.keys(spectrumMask).filter(key => /^BandPath\d+$/.test(key)).length, 24);
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
// Plugin, numeric binding, and meter must share the slower volume cadence.
// This is the configured schedule, not a benchmark of actual update timing.
for (const [interval, expectedMs] of [[50, 250], [33, 264], [100, 300]]) {
  const vars = { VisualizerUpdateOverride: String(interval) };
  const divider = formula(volume.UpdateDivider, vars);
  assert.ok(Number.isInteger(divider) && divider > 0);
  assert.equal(divider * formula(rainmeter.Update, vars), expectedMs);
  assert.equal(formula(volumeValue.UpdateDivider, vars), divider);
  assert.equal(formula(volumeMeter.UpdateDivider, vars), divider);
}
const volumeError = new RegExp(volume.IfMatch);
for (const [description, expected] of [
  ['', true], ['ERROR', true], ['ERROR - Failed to find default output', true],
  ['Speakers (Audio Device)', false], ['Headphones', false]
]) assert.equal(volumeError.test(description), expected, 'Volume device/error classification');
// Model only the shipped transitions and numeric String binding. Error strings
// deliberately carry old numbers to verify that unavailable never displays them.
let volumeAvailable = formula('#VisualizerVolumeAvailable#');
let priorVolumeError;
let volumeConditions = [false, false, false];
let volumeTemplate = volumeMeter.Text;
let validVolumeTransitions = 0;
for (const [description, rawVolume, expected] of [
  ['Speakers (Audio Device)', 0, '0%'],
  ['Speakers (Audio Device)', 100, '100%'],
  ['Speakers (Audio Device)', -1, 'Muted'],
  ['ERROR - Failed to find default output', -1, '--'],
  ['Headphones', 37, '37%'],
  ['Headphones', 64, '64%'],
  ['ERROR', 64, '--'],
  ['', 64, '--'],
  ['Speakers (Audio Device)', 0, '0%'],
  ['Speakers (Audio Device)', -1, 'Muted'],
  ['Speakers (Audio Device)', 100, '100%']
]) {
  const failed = volumeError.test(description);
  if (failed !== priorVolumeError) {
    const action = failed ? volume.IfMatchAction : volume.IfNotMatchAction;
    volumeAvailable = Number(/!SetVariable VisualizerVolumeAvailable ([01])/.exec(action)[1]);
  }
  priorVolumeError = failed;
  const numeric = formula(volumeValue.Formula, {}, { MeasureVisualizerVolume: rawVolume });
  assert.equal(numeric, rawVolume, 'The readout must bind numeric volume, not plugin device text');
  for (let i = 0; i < volumeConditions.length; i++) {
    const suffix = i === 0 ? '' : i + 1;
    const active = Boolean(formula(volumeValue['IfCondition' + suffix],
      { VisualizerVolumeAvailable: String(volumeAvailable) }, { MeasureVisualizerVolumeValue: numeric }));
    if (active && !volumeConditions[i]) {
      const action = volumeValue['IfTrueAction' + suffix];
      assert.ok(!/!(?:Show|Hide)Meter/.test(action), 'Volume state updates must preserve hover visibility');
      assert.ok(action.includes('[!UpdateMeter MeterVisualizerVolume]'));
      volumeTemplate = /!SetOption MeterVisualizerVolume Text "([^"]+)"/.exec(action)[1];
      if (i === 2) validVolumeTransitions++;
    }
    volumeConditions[i] = active;
  }
  const rendered = volumeTemplate.replaceAll('%1', numeric.toFixed(Number(volumeMeter.NumOfDecimals)));
  assert.equal(rendered, expected, 'Wrong volume state for ' + description + ' / ' + rawVolume);
  assert.ok(!rendered.includes(description) || !description, 'Plugin device name leaked into numeric readout');
}
assert.equal(validVolumeTransitions, 4, 'Valid-to-valid values should use the existing numeric binding');
const palette = sections.get('MeasureVisualizerColor');
assert.equal(palette.Measure, 'Script');
assert.equal(palette.ScriptFile, '#@#Modules\\Visualizer\\Color.lua');
assert.equal(palette.UpdateDivider, '-1', 'Appearance selection must not add recurring work');
assert.ok(!palette.Formula && !palette.IfConditionMode, 'The old Calc palette selector must not overwrite gradients');
assert.equal(rainmeter.OnRefreshAction, '[!CommandMeasure MeasureVisualizerColor "Apply()"]');
const paletteCallbacks = [...sections].flatMap(([name, section]) =>
  Object.entries(section).filter(([key, value]) => key.includes('Action') &&
    /!CommandMeasure\s+"?MeasureVisualizerColor(?:"|\s)/i.test(value)).map(([key]) => name + '.' + key));
assert.deepEqual(paletteCallbacks, ['Rainmeter.OnRefreshAction'], 'Palette changes must only run on refresh');
// Actual Color.lua gradient binding, parsing, solid-mode reset and forbidden side
// effects are executed separately by Tests/ColorSuite.lua under mocked SKIN.
// User includes may hold valid concurrent edits. Verify option wiring here;
// the matrix below supplies explicit gap choices and ColorSuite supplies modes.
assert.ok(Object.hasOwn(variables, 'VisualizerBandGap'), 'Missing band-gap option');
assert.ok(Object.hasOwn(variables, 'VisualizerColorMode'), 'Missing color-mode option');
for (const Scale of [0.75, 1, 1.25, 1.5, 2]) {
  for (const gap of [-99, 0, 1, 3, 4, 99]) {
    const physical = formula('#VisualizerBandGapPx#', { Scale: String(Scale), VisualizerBandGap: String(gap) });
    assert.equal(physical, Math.round(Math.max(0, Math.min(4, gap)) * Scale));
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
// A disconnected or silent endpoint must never keep stale bands visible, while
// live audio must hide the overlay completely rather than show a live caption.
const transitions = [
  [0, 0, 0, 0], [1, 0, 0, 1], [1, 0.1, 0, 2], [1, 0.05, 0, 2],
  [1, 0, 0, 1], [1, 0.001, 0, 1], [1, 0.002, 0, 2], [0, 0.1, 0, 0],
  [1, 0, 0, 1], [1, 0, 1, 3], [1, 0.1, 1, 3], [0, 0.1, 1, 0],
  [1, 0.1, 0, 2], [1, 0.1, 1, 3], [1, 0, 0, 1]
];
const initialStates = [[0, 0, 0, 0], [1, 0, 0, 1], [1, 0.1, 0, 2], [1, 0, 1, 3]];
for (const sequence of [transitions, ...initialStates.map(sample => [sample])]) {
let previousConditions = [false, false, false, false];
let spectrumVisible = spectrumMask.Hidden !== '1';
let overlayVisible = effective('MeterVisualizerUnavailable').Hidden !== '1';
let status = effective('MeterVisualizerUnavailable').Text;
let statusColor = effective('MeterVisualizerUnavailable').FontColor;
for (const [device, rms, invalid, expected] of sequence) {
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
      if (action.includes('!HideMeter MeterVisualizerUnavailable')) overlayVisible = false;
      if (action.includes('!ShowMeter MeterVisualizerUnavailable')) overlayVisible = true;
      const text = /!SetOption MeterVisualizerUnavailable Text "([^"]+)"/.exec(action);
      const color = /!SetOption MeterVisualizerUnavailable FontColor "([^"]+)"/.exec(action);
      if (text) status = text[1];
      if (color) statusColor = color[1];
    }
    previousConditions[i] = active;
  }
  assert.equal(spectrumVisible, expected === 2, 'Stale spectrum visible');
  assert.equal(overlayVisible, expected !== 2, 'Live caption or missing non-live state');
  if (expected !== 2) {
    assert.equal(status, ['Output unavailable', 'Idle - quiet', '', 'Unsupported format'][expected]);
    assert.equal(statusColor, expected === 1 ? '#MutedColor#' : '#WarningColor#');
  }
}
}
const dimensions = [];
const bandValues = value => Object.fromEntries(Array.from({ length: 24 }, (_, i) => ['MeasureVisualizerBand' + i, value]));
function evaluator(vars, measures = bandValues(0.5)) {
  const cache = new Map();
  const values = { ...variables, ...vars };
  const pending = new Set();
  const evaluate = value => {
    if (!cache.has(value)) {
      assert.ok(!pending.has(value), 'Circular numeric variable: ' + value);
      pending.add(value);
      // Evaluate each actual numeric variable once per scenario instead of
      // repeatedly expanding the same long path expressions as raw strings.
      const expanded = value.replace(/#([^#]+)#/g, (_, key) => {
        assert.ok(Object.hasOwn(values, key), 'Missing numeric variable ' + key);
        return '(' + evaluate(values[key]) + ')';
      });
      cache.set(value, formula(expanded, {}, measures));
      pending.delete(value);
    }
    return cache.get(value);
  };
  return evaluate;
}
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
function shapeGeometry(meter, shape, f) {
  const [primitive, ...modifiers] = shape.split('|').map(part => part.trim());
  const match = /^(Rectangle|Line|Ellipse|Path) (.*)$/.exec(primitive);
  assert.ok(match, 'Unhandled shape: ' + primitive);
  assert.ok(!modifiers.some(mod => /^(Rotate|Scale|Skew|Offset|Transform)\b/.test(mod)),
    'Transformed shapes require explicit bounds support: ' + primitive);
  const sw = f(modifiers.find(mod => mod.startsWith('StrokeWidth '))?.slice(12) ?? '1');
  assert.ok(Number.isFinite(sw) && sw >= 0, 'Invalid stroke width');
  let p, bounds, padding = sw / 2;
  if (match[1] === 'Path') {
    const identifier = match[2].trim();
    assert.match(identifier, /^\w+$/);
    assert.ok(meter[identifier], 'Missing path definition ' + identifier);
    const [start, ...segments] = meter[identifier].split('|').map(part => part.trim());
    const points = [args(start).map(f)];
    assert.equal(points[0].length, 2, 'Path start must be X,Y');
    for (let i = 0; i < segments.length; i++) {
      const segment = /^(LineTo|CurveTo|ClosePath)\s+(.+)$/.exec(segments[i]);
      assert.ok(segment, 'Unsupported path segment: ' + segments[i]);
      if (segment[1] === 'LineTo') {
        const point = args(segment[2]).map(f);
        assert.equal(point.length, 2, 'LineTo must have X,Y');
        points.push(point);
      } else if (segment[1] === 'CurveTo') {
        const curve = args(segment[2]).map(f);
        assert.equal(curve.length, 6, 'Checked cubic must have endpoint and two control points');
        // A Bezier lies inside its control-point convex hull. These are safe
        // bounds, not a claim of exact native antialiasing or pixel coverage.
        points.push(curve.slice(0, 2), curve.slice(2, 4), curve.slice(4, 6));
      } else {
        assert.ok([0, 1].includes(f(segment[2])), 'Invalid ClosePath option');
        assert.equal(i, segments.length - 1, 'ClosePath must end this checked path');
      }
    }
    assert.ok(points.length >= 2, 'Empty path');
    p = points.flat();
    const xs = points.map(point => point[0]), ys = points.map(point => point[1]);
    bounds = { x: Math.min(...xs), y: Math.min(...ys),
      w: Math.max(...xs) - Math.min(...xs), h: Math.max(...ys) - Math.min(...ys) };
    // The current gear has no stroke. For future stroked polygons, bound miter
    // joins conservatively by their limit; half-width alone can miss sharp tips.
    const join = modifiers.find(mod => mod.startsWith('StrokeLineJoin '))?.slice(15) ?? 'Miter,10';
    if (/^Miter(?:OrBevel)?(?:,|$)/.test(join)) padding *= f(args(join)[1] ?? '10');
  } else {
    p = args(match[2]).map(f);
    if (match[1] === 'Rectangle') {
      assert.ok(p.length >= 4 && p.length <= 6);
      bounds = { x: p[0], y: p[1], w: p[2], h: p[3] };
    } else if (match[1] === 'Ellipse') {
      assert.ok(p.length === 3 || p.length === 4);
      const ry = p[3] ?? p[2];
      bounds = { x: p[0] - p[2], y: p[1] - ry, w: 2 * p[2], h: 2 * ry };
    } else {
      assert.equal(p.length, 4);
      bounds = { x: Math.min(p[0], p[2]), y: Math.min(p[1], p[3]),
        w: Math.abs(p[2] - p[0]), h: Math.abs(p[3] - p[1]) };
    }
  }
  assert.ok(p.every(Number.isFinite) && bounds.w >= 0 && bounds.h >= 0, 'Invalid shape geometry');
  return { parameters: p, bounds: { x: bounds.x - padding, y: bounds.y - padding,
    w: bounds.w + 2 * padding, h: bounds.h + 2 * padding } };
}
function rect(meter, f) {
  let x = f(meter.X ?? '0'), y = f(meter.Y ?? '0');
  if (meter.Container) {
    const container = rect(effective(meter.Container), f);
    x += container.x;
    y += container.y;
  }
  const padding = args(meter.Padding ?? '0,0,0,0').map(f);
  const w = f(meter.W) + padding[0] + padding[2];
  const h = f(meter.H) + padding[1] + padding[3];
  const alignment = meter.StringAlign ?? 'Left';
  if (alignment.startsWith('Right')) x -= w;
  if (alignment.startsWith('Center')) x -= w / 2;
  if (['LeftCenter', 'RightCenter', 'CenterCenter'].includes(alignment)) y -= h / 2;
  if (alignment.endsWith('Bottom')) y -= h;
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
  { profile: 'minimum-title', TitleFontSize: '6', HeaderFontSize: '8', FontSize: '9' },
  { profile: 'default', TitleFontSize: '10', HeaderFontSize: '8', FontSize: '9' },
  { profile: 'maximum', TitleFontSize: '12', HeaderFontSize: '10', FontSize: '10' }
];
const normalizedIconShapes = new Map();
const titleFocus = process.argv.includes('--title-focus');
const surfaceProfiles = [
  { BorderThickness: '0', DividerThickness: '0' },
  { BorderThickness: '1', DividerThickness: '1' },
  { BorderThickness: '4', DividerThickness: '4' }
];
for (const surfaceProfile of (titleFocus ? surfaceProfiles.filter(profile => profile.BorderThickness === '4') : surfaceProfiles)) {
for (const fontProfile of fontProfiles) {
for (const ColumnWidth of (titleFocus ? [180, 220] : [180, 200, 220, 240, 280, 320])) {
  for (const Scale of (titleFocus ? [0.75, 1, 2] : [0.75, 1, 1.25, 1.5, 2])) {
    for (const Columns of [1, 2]) {
      const vars = { ...fontProfile, ...surfaceProfile, Scale: String(Scale), Columns: String(Columns), ColumnWidth: String(ColumnWidth),
        PanelHeight: '146', VisualizerBandGap: '1', VisualizerBarRadius: '2', VisualizerBaselineGap: '0' };
      const f = evaluator(vars);
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
      const plot = rect(effective('MeterVisualizerPlot'), f);
      const plotInterior = { x: plot.x + 1, y: plot.y + 1, w: plot.w - 2, h: plot.h - 2 };
      const scenario = fontProfile.profile + ' fonts border ' + surfaceProfile.BorderThickness + ' width ' + ColumnWidth + ' scale ' + Scale + ' columns ' + Columns;
      assert.ok(Math.abs(plot.y - f('(#Inset#+(43+#VisualizerTopShift#)*#Scale#)')) < 0.00001);
      assert.equal(plot.x, f('#VisualizerPlotX#'));
      assert.equal(plot.h, f('#VisualizerPlotHeightPx#'));
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
            const geometry = shapeGeometry(meter, shape, f);
            if (name === 'MeterVisualizerIcon') {
              assert.ok(!shape.includes('#Scale#'), 'Identity paths must scale with title typography, not suite scale alone');
              const normalized = geometry.parameters.map(value => value / f('#TitleIconScale#'));
              if (!normalizedIconShapes.has(key)) normalizedIconShapes.set(key, normalized);
              normalized.forEach((value, index) => assert.ok(
                Math.abs(value - normalizedIconShapes.get(key)[index]) < 0.00001,
                'Identity path changes aspect at ' + scenario));
            }
            within(geometry.bounds, { x: 0, y: 0, w: box.w, h: box.h }, name + '.' + key + ' stroke ' + scenario);
          }
        }
        if (meter.LeftMouseUpAction) assert.ok(meter.ToolTipText);
      }
      const pairs = [
        ['Icon', 'Title'], ['Title', 'Volume'], ['Volume', 'DeviceName'],
        ['Title', 'Options'], ['Options', 'DeviceName'],
        ['OutputIcon', 'DeviceName'], ['OutputIcon', 'Plot'], ['DeviceName', 'Plot'],
        ['Plot', 'Low'], ['Plot', 'High'], ['Low', 'High'],
        ['DbMax', 'DbMid'], ['DbMid', 'DbMin'], ['DbMax', 'Plot'], ['DbMid', 'Plot'], ['DbMin', 'Plot']
      ];
      for (const [a, b] of pairs) nonoverlap(rectangles.get('MeterVisualizer' + a),
        rectangles.get('MeterVisualizer' + b), a + '/' + b + ' ' + scenario);
      const icon = rectangles.get('MeterVisualizerIcon');
      const title = rectangles.get('MeterVisualizerTitle');
      // Check the hidden gear's complete hover target, not its zero-size idle state.
      const gear = rectangles.get('MeterVisualizerOptions');
      const volumeReadout = rectangles.get('MeterVisualizerVolume');
      const center = f('#TitleRowCenterY#');
      // Preserve the first device row. Centered title rectangles include
      // transparent line padding; native ink clearance is reviewed separately.
      const deviceRow = rectangles.get('MeterVisualizerDeviceName');
      const outputIconBox = rectangles.get('MeterVisualizerOutputIcon');
      assert.ok(Math.abs(deviceRow.y - f('(#Inset#+(24+#VisualizerTopShift#)*#Scale#)')) < 0.00001);
      assert.ok(Math.abs(outputIconBox.x - f('#ContentX#')) < 0.00001);
      assert.ok(Math.abs(outputIconBox.y - f('(#Inset#+(26+#VisualizerTopShift#)*#Scale#)')) < 0.00001);
      assert.ok(Math.abs(outputIconBox.w - 14 * Scale) < 0.00001);
      assert.ok(Math.abs(outputIconBox.h - 14 * Scale) < 0.00001);
      assert.ok(Math.abs(deviceRow.x - outputIconBox.x - outputIconBox.w - 4 * Scale) < 0.00001);
      assert.ok(Math.abs(deviceRow.x + deviceRow.w - f('(#ContentX#+#ContentWidth#)')) < 0.00001);
      assert.ok(Math.abs(outputIconBox.y + outputIconBox.h / 2 - deviceRow.y - deviceRow.h / 2) < 0.00001);
      assert.ok(title.y + title.h - deviceRow.y <= 2.001 * Scale);
      assert.ok(gear.y + gear.h - deviceRow.y <= 0.001 * Scale);
      for (const [name, box] of [['icon', icon], ['title', title], ['gear', gear], ['volume', volumeReadout]]) {
        assert.ok(Math.abs(box.y + box.h / 2 - center) < 0.00001, name + ' not vertically centered ' + scenario);
      }
      assert.ok(Math.abs(icon.w - 14 * Scale * Number(fontProfile.TitleFontSize) / 10) < 0.00001);
      assert.ok(Math.abs(icon.h - icon.w) < 0.00001);
      assert.ok(Math.abs(title.x - icon.x - icon.w - f('#TitleIconGap#')) < 0.00001);
      assert.ok(Math.abs(gear.w - 18 * Scale) < 0.00001);
      assert.ok(Math.abs(gear.h - gear.w) < 0.00001);
      assert.ok(Math.abs(gear.x + gear.w - f('(#ContentX#+#ContentWidth#)')) < 0.00001);
      assert.ok(Math.abs(volumeReadout.w - 60 * Scale) < 0.00001);
      assert.ok(Math.abs(volumeReadout.h - 18 * Scale) < 0.00001);
      assert.ok(Math.abs(volumeReadout.x + volumeReadout.w - f('(#ContentX#+#ContentWidth#)')) < 0.00001);
      assert.ok(Math.abs(volumeReadout.x - title.x - title.w - 6 * Scale) < 0.00001,
        'Title must preserve six logical pixels before the volume readout');
      // Overlap is intentional: hover replaces the readout with the settings gear.
      within(gear, volumeReadout, 'Alternating gear/readout area ' + scenario);
      for (const name of ['DeviceName', 'Volume', 'Unavailable']) {
        const meter = effective('MeterVisualizer' + name);
        assert.equal(meter.ClipString, '1');
        assert.ok(f(meter.H) >= 18 * Scale);
      }
      const overlay = rectangles.get('MeterVisualizerUnavailable');
      within(overlay, plotInterior, 'State overlay ' + scenario);
      assert.ok(Math.abs(overlay.x + overlay.w / 2 - plot.x - plot.w / 2) < 0.00001,
        'State overlay must be horizontally centered ' + scenario);
      assert.ok(Math.abs(overlay.y + overlay.h / 2 - plot.y - plot.h / 2) < 0.00001,
        'State overlay must be vertically centered ' + scenario);
      for (const name of ['Low', 'High']) {
        assert.ok(Math.abs(rectangles.get('MeterVisualizer' + name).y - f('(#Inset#+#PanelHeightPx#-22*#Scale#)')) < 0.00001);
      }
      dimensions.push({ profile: fontProfile.profile, border: surfaceProfile.BorderThickness, ColumnWidth, Scale, Columns, windowWidth, windowHeight, panelWidth: f('#PanelWidth#') });
    }
  }
}
}
}
assert.equal(dimensions.length, titleFocus ? 36 : 540);
let appearanceCases = 0;
let pathCases = 0;
const shapeProfiles = [
  { VisualizerBarRadius: '-1', VisualizerBaselineGap: '-1' },
  { VisualizerBarRadius: '2', VisualizerBaselineGap: '4' },
  { VisualizerBarRadius: '99', VisualizerBaselineGap: '99' }
];
function checkPaths(vars, level, scenario) {
  const f = evaluator(vars, bandValues(level));
  const mask = rect(spectrumMask, f);
  const child = rect(spectrumFill, f);
  assert.deepEqual(child, mask, 'Fixed child and mask bounds differ ' + scenario);
  const paint = shapeGeometry(spectrumFill, spectrumFill.Shape, f).bounds;
  assert.equal(paint.x, 0);
  assert.equal(paint.y, 0);
  assert.equal(paint.w, mask.w);
  assert.equal(paint.h, f('#VisualizerBarHeight#'), 'Gradient extent must stay fixed ' + scenario);
  const baseline = paint.h;
  assert.ok(baseline >= Math.ceil(54 * Number(vars.Scale)), 'dB labels require54logical px of usable height');
  assert.equal(mask.h - baseline, f('#VisualizerBaselineGapPx#'), 'Baseline displacement');
  let previousEnd = 0;
  for (let i = 0; i < 24; i++) {
    const left = f('#VisualizerBandLeft' + i + '#');
    const width = f('#VisualizerBandWidth' + i + '#');
    const height = f('#VisualizerBandHeight' + i + '#');
    const top = f('#VisualizerBandTop' + i + '#');
    const radius = f('#VisualizerBandRadius' + i + '#');
    assert.equal(height, Math.round(Math.max(0, Math.min(1, level)) * baseline), 'Native normalized height');
    assert.equal(top + height, baseline, 'All band bottoms must share the displaced baseline');
    assert.ok(width >= 1 && left >= previousEnd && left + width <= mask.w + 0.001,
      'Positive, ordered, disjoint bands ' + scenario + ' / ' + i);
    // Very narrow slots keep one physical pixel even when the selected gap
    // exhausts a slot. The remaining gap may consequently be smaller.
    const slotEnd = Math.round((i + 1) * mask.w / 24);
    assert.equal(width, Math.max(1, slotEnd - left - f('#VisualizerBandGapPx#')));
    previousEnd = left + width;
    assert.ok(radius >= 0 && radius <= width / 2 && radius <= height);
    assert.equal(radius, Math.min(Math.max(0, Math.min(12, Number(vars.VisualizerBarRadius))) * Number(vars.Scale), width / 2, height));
    const source = spectrumMask['BandPath' + i].split('|').map(part => part.trim());
    assert.equal(source.length, 7, 'Each band needs two top curves and a flat closed bottom');
    const start = args(source[0]).map(f);
    const segments = source.slice(1).map(part => {
      const match = /^(LineTo|CurveTo|ClosePath)\s+(.+)$/.exec(part);
      assert.ok(match);
      return { type: match[1], points: args(match[2]).map(f) };
    });
    assert.deepEqual(segments.map(segment => segment.type), ['LineTo', 'CurveTo', 'LineTo', 'CurveTo', 'LineTo', 'ClosePath']);
    assert.deepEqual(start, [left, baseline]);
    assert.deepEqual(segments[0].points, [left, top + radius]);
    assert.deepEqual(segments[1].points.slice(0, 2), [left + radius, top]);
    assert.deepEqual(segments[2].points, [left + width - radius, top]);
    assert.deepEqual(segments[3].points.slice(0, 2), [left + width, top + radius]);
    assert.deepEqual(segments[4].points, [left + width, baseline]);
    assert.deepEqual(segments[5].points, [1]);
    // Verify cap tangency and sample the actual cubic geometry. The two
    // controls must remain inside each corner, and only top corners curve.
    const starts = [segments[0].points, segments[2].points];
    const curves = [segments[1].points, segments[3].points];
    for (let corner = 0; corner < 2; corner++) {
      const [endX, endY, c1x, c1y, c2x, c2y] = curves[corner];
      const [startX, startY] = starts[corner];
      if (corner === 0) { assert.equal(c1x, startX); assert.equal(c2y, endY); }
      else { assert.equal(c1y, startY); assert.equal(c2x, endX); }
      for (let step = 0; step <= 8; step++) {
        const t = step / 8, u = 1 - t;
        const x = u ** 3 * startX + 3 * u ** 2 * t * c1x + 3 * u * t ** 2 * c2x + t ** 3 * endX;
        const y = u ** 3 * startY + 3 * u ** 2 * t * c1y + 3 * u * t ** 2 * c2y + t ** 3 * endY;
        assert.ok(x >= left - 0.001 && x <= left + width + 0.001 && y >= top - 0.001 && y <= baseline + 0.001,
          'Cubic leaves band bounds ' + scenario);
      }
      if (radius === 0) assert.deepEqual(curves[corner], [...starts[corner], ...starts[corner], ...starts[corner]], 'r0 curve must collapse');
    }
    const shapeKey = i ? 'Shape' + (i + 1) : 'Shape';
    const geometry = shapeGeometry(spectrumMask, spectrumMask[shapeKey], f);
    assert.deepEqual(geometry.bounds, { x: left, y: top, w: width, h: height });
    within(geometry.bounds, { x: 0, y: 0, w: mask.w, h: baseline }, 'Measured path ' + i + ' ' + scenario);
    if (level <= 0) assert.equal(geometry.bounds.h, 0, 'Silence must have zero-area fill, without a stroke');
    pathCases++;
  }
}
for (const ColumnWidth of [180, 220]) {
for (const Scale of [0.75, 1, 2]) {
for (const Columns of [1, 2]) {
for (const PanelHeight of [126, 146, 186]) {
for (const VisualizerBandGap of [0, 1, 3, 4]) {
for (const shapeProfile of shapeProfiles) {
  const vars = { ColumnWidth: String(ColumnWidth), Scale: String(Scale), Columns: String(Columns),
    PanelHeight: String(PanelHeight), VisualizerBandGap: String(VisualizerBandGap),
    BorderThickness: '4', TitleFontSize: '12', FontSize: '10', ...shapeProfile };
  const f = evaluator(vars);
  const scenario = `height ${PanelHeight} gap ${VisualizerBandGap} width ${ColumnWidth} scale ${Scale} columns ${Columns} shape ${JSON.stringify(shapeProfile)}`;
  const border = 4 * Scale;
  const panelInterior = { x: f('#Inset#') + border, y: f('#Inset#') + border,
    w: f('#PanelWidth#') - 2 * border, h: f('#PanelHeightPx#') - 2 * border };
  const plotMeter = effective('MeterVisualizerPlot');
  const plot = rect(plotMeter, f);
  const insidePlot = { x: plot.x + 1, y: plot.y + 1, w: plot.w - 2, h: plot.h - 2 };
  within(plot, panelInterior, 'Plot ' + scenario);
  const baselineGap = Math.round(Math.max(0, Math.min(24, Number(shapeProfile.VisualizerBaselineGap))) * Scale);
  const expectedPlotHeight = Math.max(Math.round((PanelHeight - 68) * Scale), Math.ceil(54 * Scale) + baselineGap + 2);
  assert.equal(plot.h, expectedPlotHeight);
  assert.equal(f('#PanelHeight#'), PanelHeight, 'Derived minimum must not rewrite the imported preference');
  assert.equal(f('#PanelHeightPx#'), Math.round(68 * Scale) + expectedPlotHeight);
  assert.equal(f('#WindowHeight#'), f('#PanelHeightPx#') + f('#Gap#'));
  assert.equal(plot.x, f('#ContentX#') + 40 * Scale);
  assert.equal(plot.x + plot.w, f('#ContentX#') + f('#ContentWidth#'));
  for (const [key, shape] of Object.entries(plotMeter).filter(([key]) => /^Shape\d*$/.test(key))) {
    within(shapeGeometry(plotMeter, shape, f).bounds, { x: 0, y: 0, w: plot.w, h: plot.h }, key + ' ' + scenario);
  }
  const overlay = rect(effective('MeterVisualizerUnavailable'), f);
  within(overlay, insidePlot, 'Overlay ' + scenario);
  assert.ok(Math.abs(overlay.x + overlay.w / 2 - plot.x - plot.w / 2) < 0.00001);
  assert.ok(Math.abs(overlay.y + overlay.h / 2 - plot.y - plot.h / 2) < 0.00001);
  for (const name of ['Low', 'High']) {
    const label = rect(effective('MeterVisualizer' + name), f);
    within(label, panelInterior, name + ' ' + scenario);
    assert.ok(Math.abs(label.y - plot.y - plot.h - Scale) <= 0.50001,
      'Height choice must preserve label clearance ' + scenario);
  }
  const mask = rect(spectrumMask, f);
  assert.deepEqual(mask, insidePlot, 'Mask must align with the chart interior');
  const ticks = ['DbMax', 'DbMid', 'DbMin'].map(name => rect(effective('MeterVisualizer' + name), f));
  for (const tick of ticks) {
    within(tick, panelInterior, 'dB label ' + scenario);
    nonoverlap(tick, plot, 'dB label/plot ' + scenario);
  }
  nonoverlap(ticks[0], ticks[1], 'Maximum/midpoint labels ' + scenario);
  nonoverlap(ticks[1], ticks[2], 'Midpoint/minimum labels ' + scenario);
  assert.equal(ticks[0].y, mask.y);
  assert.equal(ticks[1].y + ticks[1].h / 2, mask.y + f('#VisualizerBarHeight#') / 2);
  assert.equal(ticks[2].y + ticks[2].h, mask.y + f('#VisualizerBarHeight#'));
  checkPaths(vars, 0.5, scenario);
  appearanceCases++;
}
}
}
}
}
}
assert.equal(appearanceCases, 432);
// Exercise every binding at all amplitude edges in the most constrained
// geometry, in both monitor widths; the layout matrix already covers the rest.
for (const Columns of [1, 2]) {
  for (const shapeProfile of shapeProfiles) {
    const vars = { ColumnWidth: '180', Scale: '0.75', Columns: String(Columns), PanelHeight: '126',
      VisualizerBandGap: '4', BorderThickness: '4', TitleFontSize: '12', FontSize: '10', ...shapeProfile };
    for (const level of [-1, 0, 0.001, 0.5, 1, 2]) checkPaths(vars, level, 'narrow amplitude edge ' + level);
  }
}
assert.equal(pathCases, appearanceCases * 24 + 2 * shapeProfiles.length * 6 * 24);
const dbMid = sections.get('MeasureVisualizerDbMid'), dbMin = sections.get('MeasureVisualizerDbMin');
for (const measure of [dbMid, dbMin]) {
  assert.equal(measure.Measure, 'Calc');
  assert.equal(measure.UpdateDivider, '-1');
}
for (const selected of [-100, 0, 10, 20, 35, 50, 65, 80, 999]) {
  const vars = { VisualizerSensitivity: String(selected) };
  const sensitivity = Math.max(10, Math.min(80, selected));
  assert.equal(formula(audio.Sensitivity, vars), sensitivity, 'Axis and provider must share the same clamp');
  assert.equal(formula(dbMid.Formula, vars), -sensitivity / 2);
  assert.equal(formula(dbMin.Formula, vars), -sensitivity);
  // Invert the reviewed AudioLevel normalization independently: dB=S*(y-1).
  for (const normalized of [0, 0.5, 1]) {
    const db = sensitivity * (normalized - 1);
    const power = 10 ** (db / 10);
    const back = Math.max(0, 1 + 10 / sensitivity * Math.log10(Math.max(0, Math.min(1, power))));
    assert.ok(Math.abs(back - normalized) < 1e-12);
  }
}
assert.equal(effective('MeterVisualizerDbMax').Text, '0 dB');
console.log('PASS: includes; one output parent; 24 band/path mappings; setting bounds; volume numeric/mute/error/recovery states and 250/264/300ms schedules; four-state visibility; alternating gear/readout; context reconnect/unload; semantic typography/colors; ' + dimensions.length + ' title/width/scale/column/surface cases; ' + appearanceCases + ' height/gap/radius/baseline cases and ' + pathCases + ' bounded cubic paths including six narrow amplitude edges; zero height/radius;54px axis clearance; nine sensitivity clamps/dB endpoints; one fixed container fill; refresh-only palette binding (ColorSuite.lua validates behavior separately); preserved device row.');
console.table(dimensions.filter(row => row.border === (titleFocus ? '4' : '1') && row.Columns === 1 && [0.75, 1, 2].includes(row.Scale) && [180, 220].includes(row.ColumnWidth)));
console.log('Checked ' + readFiles.length + ' files: ' + readFiles.map(p => relative(skinRoot, p)).join(', '));
console.log('Offline checks do not verify Rainmeter rendering, audio capture, timing, DPI, persistence, or CPU cost.');
