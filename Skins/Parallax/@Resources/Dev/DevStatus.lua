-- Developer copy: the status icon beside each dev utility's title (Hook1.inc).
--
-- Red git-branch-plus: this utility (or a shared file) differs from the release.
-- Green git-compare-arrows: it matches. Muted git-compare-arrows: not compared yet,
-- or the comparison could not run (never a false green).
--
-- Nothing here polls. The state is read from @Resources\Dev\Status.inc when the skin
-- loads and on Reload() (Global Settings sends it after a comparison). A click runs
-- one comparison through the hidden RunCommand measure and then opens the report.
local common
local MODULE, TITLE, TITLE_MEASURE
local DIFFER, SAME, UNKNOWN = 'MeterParallaxDevDiffer', 'MeterParallaxDevSame', 'MeterParallaxDevUnknown'
local PROBE, RUN = 'MeterParallaxDevProbe', 'MeasureParallaxDevRun'
local state = 'unknown'
local started, running, openAfter = false, false, false

function Initialize()
    common = dofile(SKIN:GetVariable('@') .. 'Dev\\DevCommon.lua')
    MODULE = SKIN:GetVariable('ParallaxDevModule', '')
    TITLE = SKIN:GetVariable('ParallaxDevTitle', '')
    TITLE_MEASURE = SKIN:GetVariable('ParallaxDevTitleMeasure', '')
end

local function resources() return SKIN:GetVariable('@') end

local function readFile(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local text = file:read('*a')
    file:close()
    return text
end

local function number(name)
    return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end

local function titleText()
    if TITLE_MEASURE ~= '' then
        local measure = SKIN:GetMeasure(TITLE_MEASURE)
        if measure then return measure:GetStringValue() end
    end
    local meter = SKIN:GetMeter(TITLE)
    if not meter then return '' end
    return SKIN:ReplaceVariables(meter:GetOption('Text', '', true))
end

local function iconFor(which)
    if which == 'differ' then return DIFFER end
    if which == 'same' then return SAME end
    return UNKNOWN
end

local function self() return SELF:GetName() end

-- Reads the saved comparison and measures the title; Place() finishes after the
-- probe meter has been laid out.
function Apply()
    state = common.stateFor(common.parseStatus(readFile(resources() .. 'Dev\\Status.inc')), MODULE)
    SKIN:Bang('!SetOption', PROBE, 'Text', titleText())
    SKIN:Bang('!UpdateMeter', PROBE)
    SKIN:Bang('[!Delay 40][!CommandMeasure ' .. self() .. ' "Place()"]')
end

-- Puts the icon just after the title text, held inside the title's own width so a
-- long title or a gear/readout to its right is never covered.
function Place()
    local title, probe = SKIN:GetMeter(TITLE), SKIN:GetMeter(PROBE)
    if not title or not probe then return false end
    local size, gap = number('TitleIconSize'), number('TitleIconGap')
    local left = title:GetX()
    local x = left + probe:GetW() + gap
    local limit = left + title:GetW() - size
    if x > limit then x = limit end
    if x < left then x = left end
    x = math.floor(x + 0.5)
    for _, name in ipairs({ DIFFER, SAME, UNKNOWN }) do
        SKIN:Bang('!SetOption', name, 'X', tostring(x))
        SKIN:Bang(name == iconFor(state) and '!ShowMeter' or '!HideMeter', name)
    end
    SKIN:Bang('!UpdateMeter', iconFor(state))
    SKIN:Bang('!Redraw')
    return true
end

function Update()
    if not started then
        started = true
        -- Meters are laid out after the first measure pass; place the icon once they are.
        SKIN:Bang('[!Delay 100][!CommandMeasure ' .. self() .. ' "Apply()"]')
    end
    return 0
end

-- Global Settings (and the sync tool) call this after writing Status.inc.
function Reload() Apply() end

local function compare(open)
    if running then return false end
    local args = common.commandArguments(resources(), SKIN:GetVariable('SKINSPATH'),
        common.releaseName(SKIN:GetVariable('ROOTCONFIG')), 'Compare')
    if not args then return false end
    running, openAfter = true, open
    SKIN:Bang('!SetOption', RUN, 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', RUN)
    SKIN:Bang('!CommandMeasure', RUN, 'Run')
    return true
end

-- Click on the icon: compare now, then show what differs.
function Click() return compare(true) end

function Finished()
    local wasOpen = openAfter
    running, openAfter = false, false
    local measure = SKIN:GetMeasure(RUN)
    local result = common.parseResult(measure and measure:GetStringValue() or '', SKIN:GetVariable('ROOTCONFIG'))
    if not result.ok then
        state = 'unknown'
        Place()
        return false
    end
    Apply()
    if wasOpen then
        local report = resources() .. 'Dev\\Diff.txt'
        if readFile(report) and not report:find('"', 1, true) then SKIN:Bang('["notepad.exe" "' .. report .. '"]') end
    end
    return true
end
