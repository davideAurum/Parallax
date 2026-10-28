-- Global Settings > Developer (Settings.ini; design in docs/DEVMODE.md).
--
-- Dev mode creates a second copy of the suite, <Skins>\ParallaxDev, and loads it beside
-- the release so edits can be seen against the build they change. Every click runs one
-- hidden helper (@Resources\Dev\DevMode.ps1) whose ASCII reply is read as data: the
-- RESULT line, and CONFIG lines naming the dev configs to load, unload or tell to
-- re-read the comparison. Nothing polls, and no process stays running.
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
local UPDATED = { 'MeterDevCopyValue', 'MeterDevModeValue', 'MeterDevStatus', 'MeterDevCompare', 'MeterDevReport' }

function Initialize()
    common = dofile(SKIN:GetVariable('@') .. 'Dev\\DevCommon.lua')
    isCopy = SKIN:GetVariable('ParallaxDevBuild', '0') == '1'
    mode = SKIN:GetVariable('DevMode', '0') == '1' and '1' or '0'
    -- Set just before the Rainmeter refresh that a new copy needs; see Finished().
    resumeLoad = SKIN:GetVariable('DevPending', '0') == '1'
end

local function resources() return SKIN:GetVariable('@') end
local function releaseName() return common.releaseName(SKIN:GetVariable('ROOTCONFIG', 'Parallax')) end
local function devRootName() return releaseName() .. 'Dev' end

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

local EXPLAIN = {
    Foreign = 'ParallaxDev is not a dev copy.',
    NoRelease = 'This release was not found.',
    NoCopy = 'No dev copy yet.',
    Reparse = 'A linked folder blocks the copy.',
    NoResult = 'The helper reported nothing.',
}

local function statusText()
    if busy == 'enable' then return 'Creating the copy...', false end
    if busy == 'disable' then return 'Unloading the copy...', false end
    if busy == 'compare' then return 'Comparing...', false end
    if note then return note.text, note.error end
    local status = common.parseStatus(readFile(copyFile('Status.inc')))
    if not status then return 'No dev copy yet.', false end
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
    for _, name in ipairs(UPDATED) do SKIN:Bang('!UpdateMeter', name) end
    SKIN:Bang('!Redraw')
end

function Update()
    render()
    if resumeLoad and not isCopy then
        resumeLoad = false
        -- The first load after the refresh that listed a new copy: clear the marker and load
        -- the copy's utilities once the panel has finished loading.
        SKIN:Bang('!WriteKeyValue', 'Variables', 'DevPending', '0', resources() .. 'User\\Settings.inc')
        SKIN:Bang('[!Delay 600][!CommandMeasure ' .. SELF:GetName() .. ' "Resume()"]')
    end
    return 0
end

local function run(action)
    local args = common.commandArguments(resources(), SKIN:GetVariable('SKINSPATH'), releaseName(), action, SKIN:GetVariable('SETTINGSPATH'))
    if not args then
        busy, note = nil, { text = 'This folder path is not supported.', error = true }
        render()
        return false
    end
    note = nil
    SKIN:Bang('!SetOption', RUN, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', RUN)
    SKIN:Bang('!CommandMeasure', RUN, 'Run')
    render()
    return true
end

-- Both arrows and the centre flip the switch; there are only two states.
function ToggleDev()
    if isCopy or busy then return false end
    busy = (mode == '1') and 'disable' or 'enable'
    return run(busy == 'disable' and 'Disable' or 'Enable')
end

-- After the refresh that listed a new copy: the copy exists now, so Enable only loads it.
function Resume()
    if isCopy or busy or mode ~= '1' then return false end
    busy = 'enable'
    return run('Enable')
end

function Compare()
    if busy then return false end
    if not isCopy and readFile(copyFile('Status.inc')) == nil then
        note = { text = 'No dev copy yet.', error = false }
        render()
        return false
    end
    busy = 'compare'
    return run('Compare')
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
        render()
        return false
    end
    note = nil
    if action == 'enable' then
        saveMode('1')
        if (result.detail or ''):find('cloned', 1, true) then
            -- Rainmeter lists skin folders when it starts or refreshes; it refuses to activate one
            -- created since ("exists, but is not available. Please refresh Rainmeter."). Refresh
            -- once, now that the copy is on disk; the panel reloads and Resume() loads the copy.
            SKIN:Bang('!WriteKeyValue', 'Variables', 'DevPending', '1', resources() .. 'User\\Settings.inc')
            note = { text = 'Refreshing Rainmeter to list the new copy...', error = false }
            render()
            SKIN:Bang('!RefreshApp')
            return true
        end
        for _, entry in ipairs(result.configs) do
            SKIN:Bang('!ActivateConfig', entry.config, entry.file)
            if entry.x and entry.y then
                SKIN:Bang(string.format('[!Delay 300][!Move %d %d "%s"]', entry.x, entry.y, entry.config))
            end
        end
    elseif action == 'disable' then
        saveMode('0')
        for _, entry in ipairs(result.configs) do SKIN:Bang('!DeactivateConfig', entry.config) end
    else
        -- A comparison: tell each loaded dev utility to re-read it.
        for _, entry in ipairs(result.configs) do
            SKIN:Bang('!CommandMeasure', 'MeasureParallaxDev', 'Reload()', entry.config)
        end
    end
    render()
    return true
end
