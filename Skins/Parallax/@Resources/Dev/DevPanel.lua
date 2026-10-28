-- Global Settings > Developer (Settings.ini; design in docs/DEVMODE.md).
--
-- Dev mode creates a second copy of the suite, <Skins>\ParallaxDev, and loads it beside
-- the release so edits can be seen against the build they change. Every click runs one
-- hidden helper (@Resources\Dev\DevMode.ps1) whose ASCII reply is read as data: the
-- RESULT line, and CONFIG lines naming the dev configs to load, unload or tell to
-- re-read the comparison. No process stays running between clicks.
--
-- While an action runs, a thin bar under the status line follows it: the helper writes
-- "<phase>|<done>|<total>" to a file in TEMP, a short self-rescheduling tick reads it
-- (only while the helper is running), and loading or unloading the utilities steps
-- through them one at a time so each step moves the bar. The tick stops with the action.
--
-- In the copy itself (ParallaxDevBuild=1) the Dev mode row is replaced by a label and
-- only Compare and Report are live: the copy compares itself with the release beside it.
local common
local busy = nil
local note = nil
local mode = '0'
local isCopy = false
local resumeLoad = false
local RUN = 'MeasureDevPanelRun'

local TOGGLE_GROUP = 'DevToggle'
local COPY_GROUP = 'DevCopyUI'
local UPDATED = { 'MeterDevCopyValue', 'MeterDevModeValue', 'MeterDevStatus', 'MeterDevCompare', 'MeterDevReport', 'MeterDevReset' }
local resetWasOn = false

-- Progress: the action's flow (common.FLOWS), the stage in it, and the label for the status line.
local flow, stage, stageFrac, stageLabel = nil, nil, 0, ''
local ticking = false
local seq = nil
local progressPath = nil
local TICK_MS, STEP_MS = 120, 220

function Initialize()
    common = dofile(SKIN:GetVariable('@') .. 'Dev\\DevCommon.lua')
    isCopy = SKIN:GetVariable('ParallaxDevBuild', '0') == '1'
    mode = SKIN:GetVariable('DevMode', '0') == '1' and '1' or '0'
    -- Set just before the Rainmeter refresh that a new copy needs; see Finished().
    resumeLoad = SKIN:GetVariable('DevPending', '0') == '1'
    local temp = os.getenv('TEMP')
    if temp and temp ~= '' and not temp:find('"', 1, true) then progressPath = temp .. '\\ParallaxDevProgress.txt' end
end

local function resources() return SKIN:GetVariable('@') end
local function releaseName() return common.releaseName(SKIN:GetVariable('ROOTCONFIG', 'Parallax')) end
local function devRootName() return releaseName() .. 'Dev' end
local function selfName() return SELF:GetName() end

local function number(name)
    return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end

local function copyFile(name)
    if isCopy then return resources() .. 'Dev\\' .. name end
    return SKIN:GetVariable('SKINSPATH') .. devRootName() .. '\\@Resources\\Dev\\' .. name
end

local function readFile(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local text = file:read('*a')
    file:close()
    return text
end

-- The release the copy was cloned from, when it is not the installed one. Dev mode rebuilds
-- such a copy on its next turn-on; the Reset button does it now. Never in the copy itself.
local function staleBase(status)
    if isCopy or type(status) ~= 'table' then return nil end
    local base, installed = status.DevBaseVersion, SKIN:GetVariable('ParallaxVersion', '')
    if base == nil or base == '' or installed == '' or base == installed then return nil end
    return base
end

local EXPLAIN = {
    Foreign = 'ParallaxDev is not a dev copy.',
    NoRelease = 'This release was not found.',
    NoCopy = 'No dev copy yet.',
    Reparse = 'A linked folder blocks the copy.',
    NoResult = 'The helper reported nothing.',
}

local function statusText()
    if flow then return stageLabel ~= '' and stageLabel or 'Working...', false end
    if note then return note.text, note.error end
    local status = common.parseStatus(readFile(copyFile('Status.inc')))
    if not status then return 'No dev copy yet.', false end
    if staleBase(status) then return 'Out of date: from ' .. staleBase(status), true end
    local count = common.differingUtilities(status)
    if count == nil then
        return isCopy and 'Not compared yet.' or (mode == '1' and 'Not compared yet.' or 'Dev copy is off.'), false
    end
    local clock = common.clock(status.DevComparedAt)
    local text = (count == 0) and 'All match' or (count .. ' of ' .. #common.MONITORS .. ' differ')
    if clock then text = text .. ' (' .. clock .. ')' end
    if not isCopy and mode ~= '1' then text = 'Off. Last: ' .. text end
    return text, false
end

-- The bar: a track meter and a fill meter whose rectangle is resized, shown only during an action.
local function drawBar()
    if not flow then
        SKIN:Bang('!HideMeter', 'MeterDevProgressTrack')
        SKIN:Bang('!HideMeter', 'MeterDevProgress')
        return
    end
    local width = number('ContentWidth')
    local height = 3 * number('Scale')
    local fill = math.floor(width * common.overall(flow, stage, stageFrac) + 0.5)
    SKIN:Bang('!SetOption', 'MeterDevProgress', 'Shape', string.format(
        'Rectangle 0,0,%d,%s,%s | Fill Color %s | StrokeWidth 0', fill, height, height / 2, SKIN:GetVariable('AccentColor2', '181,161,226')))
    SKIN:Bang('!ShowMeter', 'MeterDevProgressTrack')
    SKIN:Bang('!ShowMeter', 'MeterDevProgress')
    SKIN:Bang('!UpdateMeter', 'MeterDevProgress')
end

local function render()
    local text, failed = statusText()
    SKIN:Bang('!SetOption', 'MeterDevStatus', 'Text', text)
    SKIN:Bang('!SetOption', 'MeterDevStatus', 'FontColor', failed and SKIN:GetVariable('DangerColor', '235,55,75') or '175,175,175')
    SKIN:Bang('!SetOption', 'MeterDevModeValue', 'Text', mode == '1' and 'On' or 'Off')
    SKIN:Bang('!SetOption', 'MeterDevCopyValue', 'Text', isCopy and 'Developer copy' or '')
    SKIN:Bang(isCopy and '!HideMeterGroup' or '!ShowMeterGroup', TOGGLE_GROUP)
    -- Compare needs a copy to look at; Report needs a report that exists.
    local hasCopy = readFile(copyFile('Status.inc')) ~= nil
    SKIN:Bang((hasCopy or isCopy) and '!ShowMeter' or '!HideMeter', 'MeterDevCompare')
    SKIN:Bang(readFile(copyFile('Diff.txt')) ~= nil and '!ShowMeter' or '!HideMeter', 'MeterDevReport')
    -- Reset rebuilds the copy from the installed release; the copy cannot rebuild itself.
    SKIN:Bang((hasCopy and not isCopy) and '!ShowMeter' or '!HideMeter', 'MeterDevReset')
    for _, name in ipairs(UPDATED) do SKIN:Bang('!UpdateMeter', name) end
    drawBar()
    SKIN:Bang('!Redraw')
end

local function setStage(name, fraction, label)
    stage, stageFrac, stageLabel = name, fraction, label
    render()
end

local function beginFlow(name)
    flow, stage, stageFrac, stageLabel = name, nil, 0, 'Starting...'
    if progressPath then os.remove(progressPath) end
end

local function endFlow()
    flow, stage, stageFrac, stageLabel = nil, nil, 0, ''
    seq = nil
    render()
end

local function helperLabel(phase, done, total)
    if phase == 'build' then return string.format('Building the copy %d/%d', done, total) end
    if phase == 'compare' then return 'Comparing...' end
    if phase == 'list' then return 'Finding utilities...' end
    return 'Working...'
end

-- Reads the helper's progress while it runs; reschedules itself only while it does.
function Tick()
    if not ticking then return false end
    -- The helper is the only thing this follows: stepping through the utilities (seq) drives
    -- the bar itself, and run() restarts the tick for the next helper run.
    if not busy or not flow or seq then
        ticking = false
        return false
    end
    local phase, done, total
    if progressPath then phase, done, total = common.parseProgress(readFile(progressPath)) end
    if phase then
        setStage('helper', common.helperFraction(phase, done, total), helperLabel(phase, done, total))
    else
        setStage('helper', 0, 'Starting...')
    end
    SKIN:Bang(string.format('[!Delay %d][!CommandMeasure %s "Tick()"]', TICK_MS, selfName()))
    return true
end

local function startTick()
    if ticking then return end
    ticking = true
    SKIN:Bang(string.format('[!Delay %d][!CommandMeasure %s "Tick()"]', TICK_MS, selfName()))
end

-- Runs one bang per utility, STEP_MS apart, moving the bar after each, then calls onDone.
-- `items` are functions; `name` is the stage ('load' or 'unload') and `verb` the label.
local function runSteps(name, verb, items, onDone)
    if #items == 0 then
        onDone()
        return
    end
    seq = { name = name, verb = verb, items = items, i = 0, onDone = onDone }
    setStage(name, 0, string.format('%s 0/%d', verb, #items))
    SKIN:Bang(string.format('[!Delay %d][!CommandMeasure %s "Step()"]', STEP_MS, selfName()))
end

function Step()
    if not seq then return false end
    local current = seq
    current.i = current.i + 1
    current.items[current.i]()
    setStage(current.name, current.i / #current.items, string.format('%s %d/%d', current.verb, current.i, #current.items))
    if current.i >= #current.items then
        seq = nil
        current.onDone()
    else
        SKIN:Bang(string.format('[!Delay %d][!CommandMeasure %s "Step()"]', STEP_MS, selfName()))
    end
    return true
end

local function loadItems(configs)
    local items = {}
    for _, entry in ipairs(configs) do
        items[#items + 1] = function()
            SKIN:Bang('!ActivateConfig', entry.config, entry.file)
            if entry.x and entry.y then
                SKIN:Bang(string.format('[!Delay 300][!Move %d %d "%s"]', entry.x, entry.y, entry.config))
            end
        end
    end
    return items
end

local function unloadItems(configs)
    local items = {}
    for _, entry in ipairs(configs) do
        items[#items + 1] = function() SKIN:Bang('!DeactivateConfig', entry.config) end
    end
    return items
end

local function working() return busy ~= nil or seq ~= nil end

function Update()
    render()
    if resumeLoad and not isCopy then
        resumeLoad = false
        -- The first load after the refresh that listed a new copy: clear the marker and load
        -- the copy's utilities once the panel has finished loading.
        SKIN:Bang('!WriteKeyValue', 'Variables', 'DevPending', '0', resources() .. 'User\\Settings.inc')
        SKIN:Bang('[!Delay 600][!CommandMeasure ' .. selfName() .. ' "Resume()"]')
    end
    return 0
end

local function run(action)
    local args = common.commandArguments(resources(), SKIN:GetVariable('SKINSPATH'), releaseName(), action,
        SKIN:GetVariable('SETTINGSPATH'), progressPath and ('-ProgressFile "' .. progressPath .. '"') or nil)
    if not args then
        busy, note = nil, { text = 'This folder path is not supported.', error = true }
        endFlow()
        return false
    end
    note = nil
    if progressPath then os.remove(progressPath) end
    SKIN:Bang('!SetOption', RUN, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', RUN)
    SKIN:Bang('!CommandMeasure', RUN, 'Run')
    setStage('helper', 0, 'Starting...')
    startTick()
    return true
end

-- Both arrows and the centre flip the switch; there are only two states.
function ToggleDev()
    if isCopy or working() then return false end
    busy = (mode == '1') and 'disable' or 'enable'
    beginFlow(busy)
    return run(busy == 'disable' and 'Disable' or 'Enable')
end

-- After the refresh that listed a new copy: the copy exists now, so Enable only loads it.
function Resume()
    if isCopy or working() or mode ~= '1' then return false end
    busy = 'enable'
    beginFlow('enable')
    return run('Enable')
end

function Compare()
    if working() then return false end
    if not isCopy and readFile(copyFile('Status.inc')) == nil then
        note = { text = 'No dev copy yet.', error = false }
        render()
        return false
    end
    busy = 'compare'
    beginFlow('compare')
    return run('Compare')
end

-- Rebuilds the copy from the installed release; the old one is kept as @ParallaxDev-backup-<time>.
-- With dev mode on, the copy's utilities are unloaded first (the helper moves the folder), then
-- reloaded from the new copy. No Rainmeter refresh: the folder is replaced in place.
function Reset()
    if isCopy or working() then return false end
    if readFile(copyFile('Status.inc')) == nil then
        note = { text = 'No dev copy yet.', error = false }
        render()
        return false
    end
    resetWasOn = (mode == '1')
    busy = resetWasOn and 'unload' or 'reset'
    beginFlow(resetWasOn and 'resetOn' or 'reset')
    return run(resetWasOn and 'Disable' or 'Reset')
end

function ResetRun()
    if isCopy then return false end
    busy = 'reset'
    return run('Reset')
end

function OpenReport()
    local path = copyFile('Diff.txt')
    if path:find('"', 1, true) or readFile(path) == nil then return false end
    SKIN:Bang('["notepad.exe" "' .. path .. '"]')
    return true
end

local function saveMode(value)
    mode = value
    SKIN:Bang('!WriteKeyValue', 'Variables', 'DevMode', value, resources() .. 'User\\Settings.inc')
end

function Finished()
    local action = busy
    busy = nil
    local measure = SKIN:GetMeasure(RUN)
    local result = common.parseResult(measure and measure:GetStringValue() or '', devRootName())
    if not result.ok then
        note = { text = EXPLAIN[result.code] or 'The dev copy action failed.', error = true }
        endFlow()
        return false
    end
    note = nil
    if (result.detail or ''):find('rebuilt', 1, true) then
        note = { text = 'Rebuilt from the installed release; the old copy was kept as a backup.', error = false }
    end
    if action == 'unload' then
        -- Step one of Reset with dev mode on: unload the copy's utilities, then rebuild.
        busy = 'unload'
        runSteps('unload', 'Unloading', unloadItems(result.configs), function()
            busy = 'reset'
            setStage('helper', 0, 'Starting...')
            SKIN:Bang('[!Delay 800][!CommandMeasure ' .. selfName() .. ' "ResetRun()"]')
        end)
        return true
    elseif action == 'reset' then
        -- Reload the rebuilt copy's utilities only if dev mode was on; the helper lists the
        -- release's loaded utilities either way.
        local wasOn = resetWasOn
        resetWasOn = false
        if wasOn then
            runSteps('load', 'Loading', loadItems(result.configs), endFlow)
        else
            endFlow()
        end
        return true
    end
    if action == 'enable' then
        saveMode('1')
        if (result.detail or ''):find('cloned', 1, true) then
            -- Rainmeter lists skin folders when it starts or refreshes; it refuses to activate one
            -- created since ("exists, but is not available. Please refresh Rainmeter."). Refresh
            -- once, now that the copy is on disk; the panel reloads and Resume() loads the copy.
            SKIN:Bang('!WriteKeyValue', 'Variables', 'DevPending', '1', resources() .. 'User\\Settings.inc')
            note = { text = 'Refreshing Rainmeter to list the new copy...', error = false }
            stageLabel = 'Refreshing Rainmeter...'
            render()
            SKIN:Bang('!RefreshApp')
            return true
        end
        runSteps('load', 'Loading', loadItems(result.configs), endFlow)
        return true
    elseif action == 'disable' then
        saveMode('0')
        runSteps('unload', 'Unloading', unloadItems(result.configs), endFlow)
        return true
    end
    -- A comparison: tell each loaded dev utility to re-read it.
    for _, entry in ipairs(result.configs) do
        SKIN:Bang('!CommandMeasure', 'MeasureParallaxDev', 'Reload()', entry.config)
    end
    endFlow()
    return true
end
