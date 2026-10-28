-- Offline suite for @Resources\Dev\DevCommon.lua, DevStatus.lua (the icon in each dev
-- utility) and DevPanel.lua (Global Settings > Developer), run against a mock SKIN that
-- records every bang. The production scripts are loaded unmodified, each in its own
-- environment (Rainmeter gives each script measure its own Lua state). Nothing outside
-- the private work directory is read or written.
-- suite.run(resourcesPath, workPath) returns the assertion count.
local suite = {}

local function readFile(path)
    local file = io.open(path, 'rb'); if not file then return nil end
    local text = file:read('*a'); file:close(); return text
end
local function writeFile(path, text)
    local file = assert(io.open(path, 'wb')); file:write(text); file:close()
end

local STATUS_BLANK = table.concat({
    '[Variables]', 'DevComparedAt=0', 'DevReleaseVersion=', 'DevDiffTotal=0', 'DevDiffShared=0', 'DevDiffSuite=0',
    'DevDiffChronometer=0', 'DevDiffCPU=0', 'DevDiffGPU=0', 'DevDiffIO=0', 'DevDiffMedia=0', 'DevDiffNetwork=0',
    'DevDiffRAM=0', 'DevDiffVisualizer=0', '' }, '\r\n')

local function status(overrides)
    local values = { DevComparedAt = '1793214560', DevReleaseVersion = '0.1.0-alpha.10', DevDiffTotal = '0', DevDiffShared = '0',
        DevDiffSuite = '0', DevDiffChronometer = '0', DevDiffCPU = '0', DevDiffGPU = '0', DevDiffIO = '0', DevDiffMedia = '0',
        DevDiffNetwork = '0', DevDiffRAM = '0', DevDiffVisualizer = '0' }
    for key, value in pairs(overrides or {}) do values[key] = value end
    local order = { 'DevComparedAt', 'DevReleaseVersion', 'DevDiffTotal', 'DevDiffShared', 'DevDiffSuite', 'DevDiffChronometer',
        'DevDiffCPU', 'DevDiffGPU', 'DevDiffIO', 'DevDiffMedia', 'DevDiffNetwork', 'DevDiffRAM', 'DevDiffVisualizer' }
    local lines = { '[Variables]' }
    for _, key in ipairs(order) do lines[#lines + 1] = key .. '=' .. values[key] end
    return table.concat(lines, '\r\n') .. '\r\n'
end

function suite.run(resourcesPath, workPath)
    local passed = 0
    local function check(value, message)
        if not value then error(message, 2) end
        passed = passed + 1
    end
    local function eq(a, b, label)
        if a ~= b then error(label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
        passed = passed + 1
    end

    local at = resourcesPath .. '\\'
    local common = dofile(at .. 'Dev\\DevCommon.lua')

    ---- DevCommon: status ---------------------------------------------------------------------------------------------
    local blank = common.parseStatus(STATUS_BLANK)
    eq(blank.DevComparedAt, 0, 'blank compared time')
    eq(common.stateFor(blank, 'CPU'), 'unknown', 'a copy never compared is unknown, not green')
    eq(common.differingUtilities(blank), nil, 'no count before a comparison')
    local same = common.parseStatus(status())
    eq(common.stateFor(same, 'CPU'), 'same', 'compared and equal')
    eq(common.differingUtilities(same), 0, 'no utility differs')
    eq(common.parseStatus(status()).DevReleaseVersion, '0.1.0-alpha.10', 'release version is text')
    local own = common.parseStatus(status({ DevDiffCPU = '2', DevDiffTotal = '2' }))
    eq(common.stateFor(own, 'CPU'), 'differ', 'own change turns it red')
    eq(common.stateFor(own, 'RAM'), 'same', 'another utility stays green')
    eq(common.differingUtilities(own), 1, 'one utility differs')
    local shared = common.parseStatus(status({ DevDiffShared = '1', DevDiffTotal = '1' }))
    for _, name in ipairs(common.MONITORS) do eq(common.stateFor(shared, name), 'differ', 'a shared change turns ' .. name .. ' red') end
    eq(common.differingUtilities(shared), 8, 'a shared change counts every utility')
    local suiteOnly = common.parseStatus(status({ DevDiffSuite = '3', DevDiffTotal = '3' }))
    eq(common.stateFor(suiteOnly, 'GPU'), 'same', 'a Global Settings change does not turn a utility red')
    eq(common.stateFor(common.parseStatus(status():gsub('DevDiffRAM=0\r\n', '')), 'RAM'), 'unknown', 'a missing count is unknown')
    eq(common.stateFor(nil, 'CPU'), 'unknown', 'no status file')
    eq(common.parseStatus(nil), nil, 'no text, no status')
    eq(common.stateFor(common.parseStatus('[Variables]\nDevComparedAt=5\nDevDiffShared=0\nOther=x\n'), 'CPU'), 'unknown', 'a utility with no count is unknown')
    eq(common.releaseName('ParallaxDev'), 'Parallax', 'release name from the copy')
    eq(common.releaseName('Parallax'), 'Parallax', 'release name from the release')
    eq(common.releaseName(nil), '', 'no root config')
    check(common.clock(1793214560):match('^%d%d:%d%d$'), 'clock text')
    eq(common.clock(0), nil, 'no clock before a comparison')

    ---- DevCommon: helper output is data ----------------------------------------------------------------------------
    local ok = common.parseResult('RESULT|OK|Enable|3|2|cloned 259 files\r\nCONFIG|ParallaxDev\\CPU|CPU.ini|-|-\r\nCONFIG|ParallaxDev\\RAM|RAM.ini|1200|-40\r\n', 'ParallaxDev')
    check(ok.ok, 'ok result')
    eq(ok.action, 'Enable', 'action'); eq(ok.changed, 3, 'changed'); eq(ok.differing, 2, 'differing'); eq(ok.detail, 'cloned 259 files', 'detail')
    eq(#ok.configs, 2, 'two configs'); eq(ok.configs[1].config, 'ParallaxDev\\CPU', 'config'); eq(ok.configs[1].x, nil, 'no position')
    eq(ok.configs[2].x, 1200, 'x'); eq(ok.configs[2].y, -40, 'negative y'); eq(ok.configs[2].module, 'RAM', 'module')
    local bad = common.parseResult(table.concat({ 'RESULT|OK|Compare|0|0|',
        'CONFIG|Parallax\\CPU|CPU.ini|-|-', 'CONFIG|ParallaxDev\\Settings|Settings.ini|-|-', 'CONFIG|ParallaxDev\\CPU|..\\x.ini|-|-',
        'CONFIG|ParallaxDev\\CPU|CPU.ini|1;!Quit|-', 'CONFIG|ParallaxDev\\CPU\\Settings|Settings.ini|-|-', 'CONFIG|ParallaxDev\\CPU|CPU.ini|-',
        'CONFIG|ParallaxDev\\GPU|GPU ini|-|-', 'CONFIG|ParallaxDev\\IO|IO-Disk.ini|-|-' }, '\n'), 'ParallaxDev')
    check(bad.ok, 'bad config lines do not spoil the result')
    eq(#bad.configs, 1, 'only the one valid config is accepted'); eq(bad.configs[1].config, 'ParallaxDev\\IO', 'the valid one')
    local err = common.parseResult('RESULT|ERR|Foreign|ParallaxDev is not a dev copy.\r\n', 'ParallaxDev')
    check(not err.ok, 'error result'); eq(err.code, 'Foreign', 'error code'); eq(err.message, 'ParallaxDev is not a dev copy.', 'error message')
    local none = common.parseResult('some text\r\n', 'ParallaxDev')
    check(not none.ok, 'no result line'); eq(none.code, 'NoResult', 'NoResult')
    eq(common.parseResult(nil, 'ParallaxDev').code, 'NoResult', 'nil output')

    local args = common.commandArguments('C:\\Skins\\ParallaxDev\\@Resources\\', 'C:\\Skins\\', 'Parallax', 'Compare', 'C:\\Users\\me\\AppData\\Roaming\\Rainmeter\\')
    eq(args, '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\\Skins\\ParallaxDev\\@Resources\\Dev\\DevMode.ps1" -Action Compare -SkinsPath "C:\\Skins\\." -Release "Parallax" -SettingsPath "C:\\Users\\me\\AppData\\Roaming\\Rainmeter\\."', 'command line')
    eq(common.commandArguments('C:\\a"b\\', 'C:\\Skins\\', 'Parallax', 'Compare'), nil, 'a quote in a path is refused')
    eq(common.commandArguments('C:\\a\\', 'C:\\Skins\\', 'Par"allax', 'Compare'), nil, 'a quote in the release is refused')
    eq(common.commandArguments('C:\\a\\', 'C:\\Skins\\', 'Parallax', 'Compare; calc'), nil, 'an action is one word')
    check(not common.commandArguments('C:\\a\\', 'C:\\Skins\\', 'Parallax', 'Compare'):find('SettingsPath', 1, true), 'no settings path, no argument')

    ---- A mock SKIN -------------------------------------------------------------------------------------------------
    local function mock(variables, meters, measures)
        local state = { bangs = {}, variables = variables, meters = meters or {}, measures = measures or {} }
        local skin = {}
        function skin:GetVariable(name, default)
            local value = state.variables[name]
            if value == nil then return default end
            return value
        end
        function skin:ReplaceVariables(text)
            return (tostring(text):gsub('#([%w_]+)#', function(name) return state.variables[name] or ('#' .. name .. '#') end))
        end
        function skin:ParseFormula(text) return tonumber((tostring(text):gsub('[()]', ''))) end
        function skin:GetMeter(name) return state.meters[name] end
        function skin:GetMeasure(name) return state.measures[name] end
        function skin:Bang(...)
            local parts = { ... }
            for i = 1, #parts do parts[i] = tostring(parts[i]) end
            state.bangs[#state.bangs + 1] = table.concat(parts, '|')
        end
        state.skin = skin
        function state.last() return state.bangs[#state.bangs] end
        function state.has(prefix)
            for _, bang in ipairs(state.bangs) do if bang:sub(1, #prefix) == prefix then return bang end end
            return nil
        end
        function state.count(prefix)
            local n = 0
            for _, bang in ipairs(state.bangs) do if bang:sub(1, #prefix) == prefix then n = n + 1 end end
            return n
        end
        function state.clear() state.bangs = {} end
        return state
    end
    local function load(file, state, selfName)
        local env = setmetatable({ SKIN = state.skin, SELF = { GetName = function() return selfName end } }, { __index = _G })
        local chunk = assert(loadfile(at .. 'Dev\\' .. file))
        setfenv(chunk, env)
        chunk()
        return env
    end
    local function meter(x, w, text)
        return { GetX = function() return x end, GetW = function() return w end, GetOption = function() return text or '' end }
    end

    ---- DevStatus: the icon in a dev utility ------------------------------------------------------------------------
    local devAt = workPath .. '\\@Resources\\'
    os.execute('mkdir "' .. workPath .. '\\@Resources\\Dev" >nul 2>&1')
    -- The scripts load DevCommon.lua from their own @Resources; the mock copy needs it too.
    writeFile(devAt .. 'Dev\\DevCommon.lua', assert(readFile(at .. 'Dev\\DevCommon.lua'), 'DevCommon.lua'))
    local statusFile = devAt .. 'Dev\\Status.inc'
    local reportFile = devAt .. 'Dev\\Diff.txt'
    local function iconVars(module, title)
        return { ['@'] = devAt, SKINSPATH = workPath .. '\\', ROOTCONFIG = 'ParallaxDev', ParallaxDevModule = module, ParallaxDevTitle = title,
            TitleIconSize = '14', TitleIconGap = '4' }
    end
    local function icon(state, selfName) return load('DevStatus.lua', state, 'MeasureParallaxDev') end
    local function shown(state)
        local result = {}
        for _, bang in ipairs(state.bangs) do
            local verb, name = bang:match('^(![HS][hi][od][we]Meter)|(.+)$')
            if verb then result[name] = (verb == '!ShowMeter') end
        end
        return result
    end
    local function xs(state)
        local result = {}
        for _, bang in ipairs(state.bangs) do
            local name, value = bang:match('^!SetOption|(MeterParallaxDev%a+)|X|(%-?%d+)$')
            if name then result[name] = tonumber(value) end
        end
        return result
    end

    -- Placement after the title text; the probe is the title's typography, sized by its text.
    writeFile(statusFile, status({ DevDiffCPU = '1', DevDiffTotal = '1' }))
    local state = mock(iconVars('CPU', 'MeterTitle'), { MeterTitle = meter(20, 150, 'CPU Meter'), MeterParallaxDevProbe = meter(0, 70) })
    local script = icon(state)
    script.Initialize()
    eq(script.Update(), 0, 'Update returns a number')
    check(state.has('[!Delay 100][!CommandMeasure MeasureParallaxDev "Apply()"]'), 'the first update schedules Apply once the meters exist')
    local scheduled = state.count('[!Delay 100]')
    script.Update()
    eq(state.count('[!Delay 100]'), scheduled, 'later updates schedule nothing')
    state.clear()
    script.Apply()
    eq(state.bangs[1], '!SetOption|MeterParallaxDevProbe|Text|CPU Meter', 'the probe gets the title text')
    eq(state.bangs[2], '!UpdateMeter|MeterParallaxDevProbe', 'and is laid out')
    check(state.has('[!Delay 40][!CommandMeasure MeasureParallaxDev "Place()"]'), 'placement follows the layout')
    state.clear()
    check(script.Place(), 'placed')
    local s, x = shown(state), xs(state)
    eq(s.MeterParallaxDevDiffer, true, 'a differing utility shows git-branch-plus')
    eq(s.MeterParallaxDevSame, false, 'and hides the green icon')
    eq(s.MeterParallaxDevUnknown, false, 'and the muted one')
    eq(x.MeterParallaxDevDiffer, 94, 'icon sits after the text: title x 20 + text 70 + gap 4')
    eq(x.MeterParallaxDevSame, 94, 'every icon variant shares the position')
    check(state.has('!Redraw'), 'one redraw')

    -- A title that fills its width keeps the icon inside it.
    state = mock(iconVars('CPU', 'MeterTitle'), { MeterTitle = meter(20, 100, 'x'), MeterParallaxDevProbe = meter(0, 400) })
    script = icon(state); script.Initialize(); script.Apply(); state.clear(); script.Place()
    eq(xs(state).MeterParallaxDevDiffer, 106, 'clamped to the title\'s right edge minus the icon: 20 + 100 - 14')
    state = mock(iconVars('CPU', 'MeterTitle'), { MeterTitle = meter(20, 100, 'x'), MeterParallaxDevProbe = meter(0, 0) })
    script = icon(state); script.Initialize(); script.Apply(); state.clear(); script.Place()
    eq(xs(state).MeterParallaxDevDiffer, 24, 'an empty title still leaves the gap')
    state = mock(iconVars('CPU', 'MeterTitle'), { MeterTitle = meter(20, 10, 'x'), MeterParallaxDevProbe = meter(0, 5) })
    script = icon(state); script.Initialize(); script.Apply(); state.clear(); script.Place()
    eq(xs(state).MeterParallaxDevDiffer, 20, 'a title narrower than the icon never moves the icon left of it')

    -- A title taken from a measure (Media).
    local mediaVars = iconVars('Media', 'MeterHeading'); mediaVars.ParallaxDevTitleMeasure = 'MeasureMediaHeader'
    state = mock(mediaVars, { MeterHeading = meter(20, 150, '%1'), MeterParallaxDevProbe = meter(0, 60) },
        { MeasureMediaHeader = { GetStringValue = function() return 'Media Player: stopped' end } })
    script = icon(state); script.Initialize(); script.Apply()
    eq(state.bangs[1], '!SetOption|MeterParallaxDevProbe|Text|Media Player: stopped', 'a measure-fed title is read from its measure')

    -- States.
    local function stateOf(module, content)
        if content then writeFile(statusFile, content) else os.remove(statusFile) end
        local st = mock(iconVars(module, 'MeterTitle'), { MeterTitle = meter(20, 150, 't'), MeterParallaxDevProbe = meter(0, 10) })
        local sc = icon(st); sc.Initialize(); sc.Apply(); st.clear(); sc.Place()
        local visible = shown(st)
        return visible.MeterParallaxDevDiffer and 'differ' or visible.MeterParallaxDevSame and 'same' or visible.MeterParallaxDevUnknown and 'unknown' or 'none'
    end
    eq(stateOf('RAM', status()), 'same', 'green when it matches')
    eq(stateOf('RAM', status({ DevDiffRAM = '4' })), 'differ', 'red when it differs')
    eq(stateOf('RAM', status({ DevDiffShared = '1' })), 'differ', 'red when a shared file differs')
    eq(stateOf('RAM', status({ DevDiffCPU = '4' })), 'same', 'another utility\'s change does not matter')
    eq(stateOf('RAM', STATUS_BLANK), 'unknown', 'never compared: muted, not green')
    eq(stateOf('RAM', nil), 'unknown', 'no status file: muted')
    eq(stateOf('RAM', 'garbage'), 'unknown', 'unreadable status: muted')

    -- Click: one comparison, then the report.
    writeFile(statusFile, status({ DevDiffCPU = '1', DevDiffTotal = '1' }))
    local run = { GetStringValue = function() return 'RESULT|OK|Compare|1|1|\r\n' end }
    state = mock(iconVars('CPU', 'MeterTitle'), { MeterTitle = meter(20, 150, 't'), MeterParallaxDevProbe = meter(0, 10) }, { MeasureParallaxDevRun = run })
    script = icon(state); script.Initialize(); state.clear()
    check(script.Click(), 'click starts a comparison')
    eq(state.bangs[1], '!SetOption|MeasureParallaxDevRun|Parameter|' .. common.commandArguments(devAt, workPath .. '\\', 'Parallax', 'Compare'), 'the helper is run from the copy against the release')
    eq(state.bangs[2], '!UpdateMeasure|MeasureParallaxDevRun', 'measure refreshed'); eq(state.bangs[3], '!CommandMeasure|MeasureParallaxDevRun|Run', 'then run')
    check(not script.Click(), 'a second click while one runs is ignored')
    eq(state.count('!CommandMeasure|MeasureParallaxDevRun|Run'), 1, 'one launch')
    writeFile(reportFile, 'report')
    state.clear()
    check(script.Finished(), 'finished')
    check(state.has('!SetOption|MeterParallaxDevProbe|Text'), 'the status is read again')
    eq(state.has('["notepad.exe"'), '["notepad.exe" "' .. reportFile .. '"]', 'the report opens in Notepad')
    -- a comparison that fails never opens a report and never shows green
    run.GetStringValue = function() return 'RESULT|ERR|NoCopy|There is no developer copy yet.\r\n' end
    script.Click(); state.clear()
    check(not script.Finished(), 'failed comparison')
    eq(state.has('["notepad.exe"'), nil, 'no report after a failure')
    check(shown(state).MeterParallaxDevUnknown, 'a failure shows the muted icon')
    -- the report is only opened when it exists
    os.remove(reportFile)
    run.GetStringValue = function() return 'RESULT|OK|Compare|1|1|\r\n' end
    script.Click(); state.clear(); script.Finished()
    eq(state.has('["notepad.exe"'), nil, 'no report file, nothing opened')
    -- Reload (sent by Global Settings after its own comparison) re-reads and never opens a report
    state.clear(); script.Reload()
    check(state.has('!SetOption|MeterParallaxDevProbe|Text'), 'Reload re-reads the status')
    eq(state.has('["notepad.exe"'), nil, 'Reload opens nothing')
    -- a path with a quote is never built into a command
    local quoted = iconVars('CPU', 'MeterTitle'); quoted.SKINSPATH = 'C:\\a"b\\'
    state = mock(quoted, {}, { MeasureParallaxDevRun = run })
    script = icon(state); script.Initialize(); state.clear()
    check(not script.Click(), 'a quoted path is refused'); eq(#state.bangs, 0, 'and nothing is sent')

    ---- DevPanel: Global Settings > Developer -----------------------------------------------------------------------
    local skinsDir = workPath .. '\\Skins\\'
    os.execute('mkdir "' .. skinsDir .. 'ParallaxDev\\@Resources\\Dev" >nul 2>&1')
    local copyStatus = skinsDir .. 'ParallaxDev\\@Resources\\Dev\\Status.inc'
    local copyReport = skinsDir .. 'ParallaxDev\\@Resources\\Dev\\Diff.txt'
    os.remove(copyStatus); os.remove(copyReport)
    local panelRun = { GetStringValue = function() return '' end }
    local function panelVars(extra)
        local v = { ['@'] = at, SKINSPATH = skinsDir, SETTINGSPATH = workPath .. '\\Settings\\', ROOTCONFIG = 'Parallax', DevMode = '0', ParallaxDevBuild = '0', DangerColor = '235,55,75' }
        for key, value in pairs(extra or {}) do v[key] = value end
        return v
    end
    local function panel(extra)
        panelRun.GetStringValue = function() return '' end
        local st = mock(panelVars(extra), {}, { MeasureDevPanelRun = panelRun })
        local sc = load('DevPanel.lua', st, 'MeasureDevPanel')
        sc.Initialize()
        return st, sc
    end
    local function option(st, meterName, key)
        local found
        for _, bang in ipairs(st.bangs) do
            local value = bang:match('^!SetOption|' .. meterName .. '|' .. key .. '|(.*)$')
            if value then found = value end
        end
        return found
    end
    local function visibility(st, meterName)
        local found
        for _, bang in ipairs(st.bangs) do
            if bang == '!ShowMeter|' .. meterName then found = true elseif bang == '!HideMeter|' .. meterName then found = false end
        end
        return found
    end

    -- No copy yet.
    local st, sc = panel()
    eq(sc.Update(), 0, 'panel Update returns a number')
    eq(option(st, 'MeterDevStatus', 'Text'), 'No dev copy yet.', 'no copy: say so')
    eq(option(st, 'MeterDevModeValue', 'Text'), 'Off', 'Dev mode is Off')
    eq(option(st, 'MeterDevCopyValue', 'Text'), '', 'a release names no copy')
    check(st.has('!ShowMeterGroup|DevToggle'), 'a release shows the Dev mode row')
    eq(visibility(st, 'MeterDevCompare'), false, 'no Compare without a copy')
    eq(visibility(st, 'MeterDevReport'), false, 'no Report without a report')
    st.clear(); check(not sc.Compare(), 'Compare needs a copy'); eq(option(st, 'MeterDevStatus', 'Text'), 'No dev copy yet.', 'and says so')
    eq(st.has('!CommandMeasure|MeasureDevPanelRun'), nil, 'nothing launched')
    check(not sc.OpenReport(), 'no report to open')

    -- Turn on.
    st.clear()
    check(sc.ToggleDev(1), 'toggle on starts the helper')
    eq(option(st, 'MeterDevStatus', 'Text'), 'Creating the copy...', 'busy text')
    eq(st.bangs[1], '!SetOption|MeasureDevPanelRun|Parameter|' .. common.commandArguments(at, skinsDir, 'Parallax', 'Enable', workPath .. '\\Settings\\'), 'Enable arguments')
    check(st.has('!CommandMeasure|MeasureDevPanelRun|Run'), 'helper launched')
    check(not sc.ToggleDev(1), 'a click while busy is ignored')
    check(not sc.Compare(), 'so is Compare')
    eq(st.count('!CommandMeasure|MeasureDevPanelRun|Run'), 1, 'one launch')
    writeFile(copyStatus, status({ DevDiffCPU = '2', DevDiffTotal = '2' }))
    -- A copy created just now is not in Rainmeter's skin list yet: one refresh, then the load resumes.
    panelRun.GetStringValue = function()
        return 'RESULT|OK|Enable|2|1|cloned 259 files\r\nCONFIG|ParallaxDev\\CPU|CPU.ini|2000|16\r\n'
    end
    st.clear()
    check(sc.Finished(), 'created')
    eq(st.bangs[1], '!WriteKeyValue|Variables|DevMode|1|' .. at .. 'User\\Settings.inc', 'DevMode=1 is saved in this release\'s settings')
    eq(st.bangs[2], '!WriteKeyValue|Variables|DevPending|1|' .. at .. 'User\\Settings.inc', 'the load is marked to resume after the refresh')
    eq(st.last(), '!RefreshApp', 'Rainmeter refreshes once so it lists the new skin folder')
    eq(st.has('!ActivateConfig'), nil, 'a skin Rainmeter does not list yet is not activated')
    eq(option(st, 'MeterDevStatus', 'Text'), 'Refreshing Rainmeter to list the new copy...', 'status while it refreshes')

    -- After the refresh the panel reloads with DevPending=1: it clears the marker and resumes.
    st, sc = panel({ DevMode = '1', DevPending = '1' })
    sc.Update()
    eq(st.has('!WriteKeyValue|Variables|DevPending|0|' .. at .. 'User\\Settings.inc') ~= nil, true, 'the marker is cleared')
    eq(st.has('[!Delay 600][!CommandMeasure MeasureDevPanel "Resume()"]') ~= nil, true, 'the load resumes once the panel is up')
    sc.Update()
    eq(st.count('[!Delay 600]'), 1, 'the marker acts once per load')
    st.clear()
    check(sc.Resume(), 'resume starts the helper')
    eq(st.bangs[1], '!SetOption|MeasureDevPanelRun|Parameter|' .. common.commandArguments(at, skinsDir, 'Parallax', 'Enable', workPath .. '\\Settings\\'), 'resume runs Enable')
    check(not sc.Resume(), 'not twice')
    panelRun.GetStringValue = function()
        return 'RESULT|OK|Enable|2|1|\r\nCONFIG|ParallaxDev\\CPU|CPU.ini|2000|16\r\nCONFIG|ParallaxDev\\Media|Setup.ini|-|-\r\nCONFIG|Parallax\\RAM|RAM.ini|-|-\r\n'
    end
    st.clear()
    check(sc.Finished(), 'enabled')
    eq(st.bangs[1], '!WriteKeyValue|Variables|DevMode|1|' .. at .. 'User\\Settings.inc', 'DevMode=1 stays saved')
    eq(st.bangs[2], '!ActivateConfig|ParallaxDev\\CPU|CPU.ini', 'the copy\'s CPU is loaded')
    eq(st.bangs[3], '[!Delay 300][!Move 2000 16 "ParallaxDev\\CPU"]', 'beside the release window')
    eq(st.bangs[4], '!ActivateConfig|ParallaxDev\\Media|Setup.ini', 'Media loads the file the release has loaded')
    eq(st.count('!ActivateConfig'), 2, 'a config outside the copy is refused')
    eq(st.count('[!Delay 300][!Move'), 1, 'only a placed window is moved')
    eq(st.has('!RefreshApp'), nil, 'no refresh when the copy already existed')
    eq(option(st, 'MeterDevModeValue', 'Text'), 'On', 'Dev mode shows On')
    eq(option(st, 'MeterDevStatus', 'Text'):match('^1 of 8 differ %(%d%d:%d%d%)$') ~= nil, true, 'status line: 1 of 8 differ with the time')
    eq(visibility(st, 'MeterDevCompare'), true, 'Compare appears with a copy')
    -- Resume is for a panel that has dev mode on, and never inside the copy.
    st, sc = panel({ DevMode = '0' }); check(not sc.Resume(), 'no resume while dev mode is off')
    st, sc = panel({ DevMode = '1', DevPending = '1', ROOTCONFIG = 'ParallaxDev', ParallaxDevBuild = '1' }); sc.Update()
    eq(st.has('[!Delay 600]'), nil, 'the copy never resumes a load')

    -- A failure leaves Dev mode where it was.
    st, sc = panel(); st.clear(); sc.ToggleDev(1)
    panelRun.GetStringValue = function() return 'RESULT|ERR|Foreign|ParallaxDev exists but is not a Parallax developer copy.\r\n' end
    st.clear(); check(not sc.Finished(), 'failed')
    eq(st.has('!WriteKeyValue'), nil, 'nothing saved'); eq(st.has('!ActivateConfig'), nil, 'nothing loaded')
    eq(option(st, 'MeterDevStatus', 'Text'), 'ParallaxDev is not a dev copy.', 'the reason is shown')
    eq(option(st, 'MeterDevStatus', 'FontColor'), '235,55,75', 'in the danger color')
    eq(option(st, 'MeterDevModeValue', 'Text'), 'Off', 'still Off')
    panelRun.GetStringValue = function() return 'unexpected' end
    st, sc = panel(); sc.ToggleDev(1); st.clear(); sc.Finished()
    eq(option(st, 'MeterDevStatus', 'Text'), 'The helper reported nothing.', 'no RESULT line is an error')

    -- Turn off.
    st, sc = panel({ DevMode = '1' })
    sc.Update()
    eq(option(st, 'MeterDevModeValue', 'Text'), 'On', 'On from the saved setting')
    st.clear(); sc.ToggleDev(-1)
    eq(st.bangs[1], '!SetOption|MeasureDevPanelRun|Parameter|' .. common.commandArguments(at, skinsDir, 'Parallax', 'Disable', workPath .. '\\Settings\\'), 'Disable arguments')
    eq(option(st, 'MeterDevStatus', 'Text'), 'Unloading the copy...', 'busy text')
    panelRun.GetStringValue = function() return 'RESULT|OK|Disable|2|1|\r\nCONFIG|ParallaxDev\\CPU|CPU.ini|-|-\r\nCONFIG|ParallaxDev\\GPU|GPU.ini|-|-\r\n' end
    st.clear(); check(sc.Finished(), 'disabled')
    eq(st.bangs[1], '!WriteKeyValue|Variables|DevMode|0|' .. at .. 'User\\Settings.inc', 'DevMode=0 saved')
    eq(st.bangs[2], '!DeactivateConfig|ParallaxDev\\CPU', 'unloads the loaded copy'); eq(st.bangs[3], '!DeactivateConfig|ParallaxDev\\GPU', 'every one')
    eq(option(st, 'MeterDevModeValue', 'Text'), 'Off', 'Off again')
    check(option(st, 'MeterDevStatus', 'Text'):match('^Off%. Last: '), 'the last comparison stays visible while off')

    -- Compare from the release: every loaded dev utility re-reads the status.
    st, sc = panel({ DevMode = '1' })
    check(sc.Compare(), 'Compare starts')
    eq(st.bangs[1], '!SetOption|MeasureDevPanelRun|Parameter|' .. common.commandArguments(at, skinsDir, 'Parallax', 'Compare', workPath .. '\\Settings\\'), 'Compare arguments')
    eq(option(st, 'MeterDevStatus', 'Text'), 'Comparing...', 'busy text')
    panelRun.GetStringValue = function() return 'RESULT|OK|Compare|0|0|\r\nCONFIG|ParallaxDev\\RAM|RAM.ini|-|-\r\n' end
    writeFile(copyStatus, status())
    st.clear(); check(sc.Finished(), 'compared')
    eq(st.bangs[1], '!CommandMeasure|MeasureParallaxDev|Reload()|ParallaxDev\\RAM', 'the loaded dev utility is told to re-read')
    eq(st.has('!WriteKeyValue'), nil, 'a comparison saves nothing')
    eq(option(st, 'MeterDevStatus', 'Text'):match('^All match %(%d%d:%d%d%)$') ~= nil, true, 'status line: all match')
    -- Report
    check(not sc.OpenReport(), 'no report yet')
    writeFile(copyReport, 'report'); st.clear(); sc.Update()
    eq(visibility(st, 'MeterDevReport'), true, 'Report appears once a report exists')
    st.clear(); check(sc.OpenReport(), 'report opens')
    eq(st.bangs[1], '["notepad.exe" "' .. copyReport .. '"]', 'in Notepad')

    -- Never compared.
    writeFile(copyStatus, STATUS_BLANK)
    st, sc = panel({ DevMode = '1' }); sc.Update()
    eq(option(st, 'MeterDevStatus', 'Text'), 'Not compared yet.', 'a blank status is not green')

    -- Inside the copy: no Dev mode row, compare against the release beside it.
    writeFile(statusFile, status({ DevDiffRAM = '1', DevDiffTotal = '1' }))
    writeFile(reportFile, 'report')
    local copyVars = { ['@'] = devAt, ROOTCONFIG = 'ParallaxDev', ParallaxDevBuild = '1' }
    st, sc = panel(copyVars); sc.Update()
    eq(option(st, 'MeterDevCopyValue', 'Text'), 'Developer copy', 'the heading names the copy')
    check(st.has('!HideMeterGroup|DevToggle'), 'the Dev mode row is hidden')
    eq(visibility(st, 'MeterDevCompare'), true, 'Compare stays')
    eq(visibility(st, 'MeterDevReport'), true, 'Report stays')
    eq(option(st, 'MeterDevStatus', 'Text'):match('^1 of 8 differ') ~= nil, true, 'the copy reads its own status')
    st.clear(); check(not sc.ToggleDev(1), 'the copy cannot turn dev mode on or off')
    eq(#st.bangs, 0, 'and does nothing')
    st.clear(); check(sc.Compare(), 'the copy compares itself')
    eq(st.bangs[1], '!SetOption|MeasureDevPanelRun|Parameter|' .. common.commandArguments(devAt, skinsDir, 'Parallax', 'Compare', workPath .. '\\Settings\\'), 'against the release (Dev suffix removed), with the copy\'s own helper')
    st.clear(); check(sc.OpenReport(), 'the copy opens its own report')
    eq(st.bangs[1], '["notepad.exe" "' .. reportFile .. '"]', 'from its own folder')
    -- Unsupported path
    st, sc = panel({ SKINSPATH = 'C:\\a"b\\' }); st.clear()
    check(not sc.ToggleDev(1), 'a quoted path is refused')
    eq(option(st, 'MeterDevStatus', 'Text'), 'This folder path is not supported.', 'with a reason')
    eq(st.has('!CommandMeasure|MeasureDevPanelRun'), nil, 'nothing launched')
    return passed
end

return suite
