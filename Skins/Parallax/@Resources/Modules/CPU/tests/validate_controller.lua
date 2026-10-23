-- Offline CPU.lua controller suite, compatible with Rainmeter's Lua 5.1.
-- No telemetry, registry, process or user settings are read or changed. The
-- skin's own INI sources are parsed for meter groups, styles, dividers and
-- DynamicVariables; every reading is a synthetic fixture value.
--
-- The mock follows Rainmeter 4.5.28's skin cycle closely enough to check
-- paint and option re-read behaviour:
--   1. measures update in file order. A measure re-reads its options when it
--      has DynamicVariables=1 or a !SetOption flagged it, even while it is
--      disabled; a re-read of a UsageMonitor measure is a plugin Reload.
--   2. the controller's Update() runs. Bangs execute synchronously.
--   3. every meter whose UpdateDivider is not -1 updates, re-reading its
--      options when DynamicVariables=1 or a !SetOption flagged it.
--   4. the skin redraws once.
-- !UpdateMeter and !UpdateMeterGroup force an update, and any pending re-read,
-- even for UpdateDivider=-1 meters. A changed UpdateDivider takes effect at
-- the section's next re-read.
--
-- Invocation from an isolated Lua 5.1 harness:
--   local suite = assert(loadfile(testPath))()
--   local report = suite.Run(cpuLuaPath)
-- Run returns a readable report on success and raises the full report on failure.

local suite = {}

local function equal(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function trim(value)
    return (tostring(value):match('^%s*(.-)%s*$'))
end

local function readIni(path, sections, order)
    local file = assert(io.open(path, 'rb'), 'Cannot read ' .. path)
    local text = file:read('*a')
    file:close()
    local section
    for line in text:gmatch('[^\r\n]+') do
        local trimmed = trim(line)
        if trimmed ~= '' and trimmed:sub(1, 1) ~= ';' then
            local name = trimmed:match('^%[(.+)%]$')
            if name then
                section = sections[name]
                if not section then
                    section = {name=name, keys={}}
                    sections[name] = section
                    order[#order + 1] = section
                end
            elseif section then
                local key, value = trimmed:match('^([^=]+)=(.*)$')
                if key then section.keys[trim(key):lower()] = value end
            end
        end
    end
end

-- Later styles in a MeterStyle list override earlier ones; a section's own
-- key overrides every style.
local function iniOption(sections, section, key, depth)
    depth = depth or 0
    assert(depth < 10, 'MeterStyle recursion in ' .. section.name)
    local value = section.keys[key]
    if value ~= nil then return value end
    local found
    for style in (section.keys.meterstyle or ''):gmatch('[^|]+') do
        local parent = sections[trim(style)]
        if parent then
            local candidate = iniOption(sections, parent, key, depth + 1)
            if candidate ~= nil then found = candidate end
        end
    end
    return found
end

local function loadSkin(cpuPath)
    local moduleDir = cpuPath:gsub('[^/\\]+$', '')
    local resources = moduleDir:gsub('[Mm]odules[/\\]CPU[/\\]$', '')
    local skinRoot = resources:gsub('@Resources[/\\]$', '')
    local sections, order = {}, {}
    for _, path in ipairs({resources .. 'Styles.inc', skinRoot .. 'CPU/CPU.ini',
            moduleDir .. 'CoreMeters.inc', moduleDir .. 'ProcessMeters.inc', moduleDir .. 'Measures.inc'}) do
        readIni(path, sections, order)
    end
    local userSections, userOrder = {}, {}
    readIni(resources .. 'User/CPU.inc', userSections, userOrder)
    return sections, order, userSections.Variables.keys
end

-- Deterministic fixture readings. These are test inputs, never telemetry.
local function threadReading(thread, tick)
    return ((thread * 37 + tick * 11) % 1000) / 10
end

local function newMock(cpuPath, options)
    options = options or {}
    local sections, order, userVariables = loadSkin(cpuPath)
    local context = {meters={}, meterList={}, measures={}, measureList={}, groups={},
        variables={}, now=5000, tick=0, threads=options.threads or 12, info=options.info or 'OK|6|12',
        infoStatus=options.infoStatus or 1, processes=options.processes,
        reloads=0, redraws=0, controllerBangs={}, eventBangs={}, writes={}, commands={},
        phase='load', violations={}}
    -- Rainmeter variable names are case-insensitive.
    local function setVariable(key, value) context.variables[key:lower()] = tostring(value) end
    for key, value in pairs(userVariables) do setVariable(key, value) end
    setVariable('Scale', '1')
    setVariable('CPUColor', '235,55,75')
    setVariable('@', 'X:\\Fixture\\@Resources\\')
    setVariable('ContentWidth', '208')
    for key, value in pairs(options.variables or {}) do setVariable(key, value) end
    if not context.processes then
        context.processes = {
            {name='alpha.exe', value=12.5}, {name='beta.exe', value=6.25}, {name='gamma.exe', value=3},
            {name='delta.exe', value=1.5}, {name='epsilon.exe', value=0.75}
        }
    end

    for _, section in ipairs(order) do
        local keys = section.keys
        if keys.meter then
            local groups = {}
            for group in (iniOption(sections, section, 'group') or ''):gmatch('[^|]+') do
                groups[trim(group):upper()] = true
            end
            local meter = {name=section.name, section=section, groups=groups,
                iniDivider=tonumber(iniOption(sections, section, 'updatedivider') or '1') or 1,
                dynamic=(iniOption(sections, section, 'dynamicvariables') or '0') == '1',
                hidden=(iniOption(sections, section, 'hidden') or '0') == '1',
                parser={}, applied={}, pending=false, rereads=0, updates=0}
            meter.divider = meter.iniDivider
            context.meters[section.name] = meter
            context.meterList[#context.meterList + 1] = meter
            for group in pairs(groups) do
                context.groups[group] = context.groups[group] or {}
                table.insert(context.groups[group], meter)
            end
        elseif keys.measure and section.name ~= 'MeasureCPUController' then
            local measure = {name=section.name, section=section, plugin=(keys.plugin or ''):lower(),
                divider=tonumber(keys.updatedivider or '1') or 1,
                dynamic=(keys.dynamicvariables or '0') == '1',
                disabled=(keys.disabled or '0') == '1',
                parser={}, pending=false, rereads=0, value=0, string=''}
            measure.appliedName = keys.name
            measure.appliedIndex = keys.index
            context.measures[section.name] = measure
            context.measureList[#context.measureList + 1] = measure
        end
    end
    assert(context.meters.MeterHistory and context.measures.MeasureCPU1 and context.measures.MeasureCPUProcess1,
        'CPU INI sources did not parse')

    local function sectionOption(item, key)
        local lower = key:lower()
        local value = item.parser[lower]
        if value ~= nil then return value or '' end
        return iniOption(sections, item.section, lower) or ''
    end
    function context:meterOption(name, key)
        return sectionOption(assert(self.meters[name], 'Unknown meter ' .. name), key)
    end
    -- What the last meter re-read applied, which is what the skin draws.
    function context:appliedOption(name, key)
        local meter = assert(self.meters[name], 'Unknown meter ' .. name)
        local value = meter.applied[key:lower()]
        if value ~= nil then return value or '' end
        return iniOption(sections, meter.section, key:lower()) or ''
    end
    function context:measureOption(name, key)
        return sectionOption(assert(self.measures[name], 'Unknown measure ' .. name), key)
    end

    local function reread(meter)
        meter.pending = false
        meter.rereads = meter.rereads + 1
        local applied = {}
        for key, value in pairs(meter.parser) do applied[key] = value end
        meter.applied = applied
        local divider = tonumber(sectionOption(meter, 'UpdateDivider'))
        meter.divider = divider or 1
    end
    local function updateMeter(meter, force)
        if meter.divider < 0 and not force then return end
        if meter.pending or meter.dynamic then reread(meter) end
        meter.updates = meter.updates + 1
    end

    local function provide(measure)
        local name = measure.name
        if name == 'MeasureCPUTotal' then
            local sum = 0
            for thread = 1, context.threads do sum = sum + threadReading(thread, context.tick) end
            measure.value = sum / context.threads
        elseif name:match('^MeasureCPU%d+$') or name:match('^MeasureCPUHistory%d+$') then
            local index = tonumber((measure.appliedName or ''):match('^0,(%d+)$'))
            measure.value = index and index < context.threads and threadReading(index + 1, context.tick) or 0
        elseif name:match('^MeasureCPUProcess%d+$') then
            local entry = context.processes[tonumber(measure.appliedIndex)]
            measure.string = entry and entry.name or ''
            measure.value = entry and entry.value or 0
        elseif name == 'MeasureCPUModel' then
            measure.string = 'Intel(R) Core(TM) i7-8700 CPU @ 3.20GHz'
        elseif name == 'MeasureCPUInfo' then
            measure.value, measure.string = context.infoStatus, context.info
        end
    end
    local function updateMeasure(measure, force)
        if measure.divider < 0 and not force then return end
        if measure.pending or measure.dynamic then
            measure.pending = false
            measure.rereads = measure.rereads + 1
            if measure.plugin == 'usagemonitor' then context.reloads = context.reloads + 1 end
            measure.appliedName = sectionOption(measure, 'Name')
            measure.appliedIndex = sectionOption(measure, 'Index')
            measure.disabled = sectionOption(measure, 'Disabled') == '1'
            measure.divider = tonumber(sectionOption(measure, 'UpdateDivider')) or 1
        end
        if not measure.disabled then provide(measure) end
    end

    local function members(group)
        return context.groups[group:upper()] or {}
    end
    local function bang(...)
        local args = {...}
        local name, target = args[1], args[2]
        local log = context.phase == 'controller' and context.controllerBangs or context.eventBangs
        log[#log + 1] = args
        if name == '!SetOption' then
            local item = context.meters[target] or context.measures[target]
            assert(item, '!SetOption on unknown section ' .. tostring(target))
            local value = tostring(args[4])
            -- Rainmeter deletes the key for an empty value.
            item.parser[args[3]:lower()] = value ~= '' and value or false
            item.pending = true
        elseif name == '!ShowMeter' or name == '!HideMeter' then
            assert(context.meters[target], name .. ' on unknown meter ' .. tostring(target)).hidden = name == '!HideMeter'
        elseif name == '!ShowMeterGroup' or name == '!HideMeterGroup' then
            for _, meter in ipairs(members(target)) do meter.hidden = name == '!HideMeterGroup' end
        elseif name == '!UpdateMeter' then
            if target == '*' then
                for _, meter in ipairs(context.meterList) do updateMeter(meter, true) end
            else
                updateMeter(assert(context.meters[target], 'Unknown meter ' .. tostring(target)), true)
            end
        elseif name == '!UpdateMeterGroup' then
            for _, meter in ipairs(members(target)) do updateMeter(meter, true) end
        elseif name == '!Redraw' then
            context.redraws = context.redraws + 1
        elseif name == '!EnableMeasure' or name == '!DisableMeasure' then
            local measure = assert(context.measures[target], name .. ' on unknown measure ' .. tostring(target))
            measure.disabled = name == '!DisableMeasure'
            -- Measure::Enable/Disable also write the parser value in 4.5.28.
            measure.parser.disabled = measure.disabled and '1' or '0'
        elseif name == '!UpdateMeasure' then
            updateMeasure(assert(context.measures[target], 'Unknown measure ' .. tostring(target)), true)
        elseif name == '!CommandMeasure' then
            equal(target, 'MeasureCPUSensors', 'command target')
            context.commands[#context.commands + 1] = args[3]
            if context.onSensorCommand then context.onSensorCommand(args[3]) end
        elseif name == '!SetVariable' then
            setVariable(target, args[3])
        elseif name == '!WriteKeyValue' then
            equal(target, 'Variables', 'written section')
            equal(args[5], 'X:\\Fixture\\@Resources\\User\\CPU.inc', 'written file')
            context.writes[#context.writes + 1] = {key=args[3], value=args[4]}
        else
            error('Unexpected production bang in offline test: ' .. tostring(name))
        end
    end
    context.bang = bang

    local skin = {}
    function skin:GetVariable(key, fallback)
        local value = context.variables[tostring(key):lower()]
        if value == nil then return fallback end
        return value
    end
    function skin:GetMeasure(name)
        local measure = assert(context.measures[name], 'Unknown mocked measure: ' .. tostring(name))
        return {GetValue=function() return measure.value end, GetStringValue=function() return measure.string end}
    end
    function skin:Bang(...) bang(...) end
    function skin:ReplaceVariables(text)
        return (text:gsub('#([^#]+)#', function(key) return context.variables[key:lower()] or ('#' .. key .. '#') end))
    end
    function skin:ParseFormula(text)
        assert(text:match('^[%d%.%(%)%+%-%*/%s]+$'), 'Unsupported fixture formula ' .. text)
        return assert(loadstring('return ' .. text))()
    end
    local self = {}
    function self:GetOption(key, fallback)
        if key == 'DetectedCount' then return tostring(options.detected or context.threads) end
        return fallback
    end
    local environment = {SKIN=skin, SELF=self, os={time=function() return context.now end}}
    environment._G = environment
    setmetatable(environment, {__index=_G})
    local chunk = assert(loadfile(cpuPath))
    setfenv(chunk, environment)
    chunk()
    context.environment = environment
    environment.Initialize()

    -- Rainmeter updates every measure and meter once when the skin loads,
    -- including UpdateDivider=-1 sections.
    for _, measure in ipairs(context.measureList) do updateMeasure(measure, true) end
    for _, meter in ipairs(context.meterList) do updateMeter(meter, true) end

    function context:checkDrawn(label)
        -- A visible meter with an unapplied !SetOption draws a stale value.
        for _, meter in ipairs(self.meterList) do
            if not meter.hidden and meter.pending then
                self.violations[#self.violations + 1] = label .. ': ' .. meter.name .. ' is visible with an unapplied option'
            end
        end
        assert(#self.violations == 0, table.concat(self.violations, '\n'))
    end
    function context:cycle()
        self.tick = self.tick + 1
        self.now = self.now + 1
        self.controllerBangs = {}
        self.eventBangs = {}
        self.phase = 'measures'
        local reloadsBefore, redrawsBefore = self.reloads, self.redraws
        local rereadsBefore = {}
        for _, meter in ipairs(self.meterList) do rereadsBefore[meter.name] = meter.rereads end
        for _, measure in ipairs(self.measureList) do updateMeasure(measure, false) end
        if self.beforeController then self.beforeController(self) end
        self.phase = 'controller'
        self.environment.Update()
        self.phase = 'meters'
        for _, meter in ipairs(self.meterList) do updateMeter(meter, false) end
        self.redraws = self.redraws + 1
        self.phase = 'idle'
        local stats = {reloads=self.reloads - reloadsBefore, redraws=self.redraws - redrawsBefore,
            bangs=#self.controllerBangs, rereads={}}
        for _, meter in ipairs(self.meterList) do stats.rereads[meter.name] = meter.rereads - rereadsBefore[meter.name] end
        self.last = stats
        self:checkDrawn('tick ' .. self.tick)
        return stats
    end
    function context:run(count)
        local stats
        for _ = 1, count do stats = self:cycle() end
        return stats
    end
    -- Settings clicks, paging and FinishActions run between skin cycles.
    function context:event(name, ...)
        self.eventBangs = {}
        self.phase = 'event'
        local redrawsBefore = self.redraws
        local result = assert(self.environment[name], 'Missing function ' .. name)(...)
        self.phase = 'idle'
        self.lastEventRedraws = self.redraws - redrawsBefore
        -- An event that paints must paint applied options, not stale ones.
        if self.lastEventRedraws > 0 then self:checkDrawn('event ' .. name) end
        return result
    end
    function context:count(log, name, target)
        local total = 0
        for _, args in ipairs(log) do
            if args[1] == name and (target == nil or args[2] == target) then total = total + 1 end
        end
        return total
    end
    function context:visible(name)
        return not assert(self.meters[name], 'Unknown meter ' .. name).hidden
    end
    function context:text(name)
        return self:appliedOption(name, 'Text')
    end
    function context:shapeCount(name, applied)
        local count = 0
        while true do
            local key = count == 0 and 'Shape' or ('Shape' .. (count + 1))
            local value = applied and self:appliedOption(name, key) or self:meterOption(name, key)
            if value == '' then return count end
            count = count + 1
        end
    end
    return context
end

local function percent(value, decimals)
    return string.format('%.' .. decimals .. 'f%%', value)
end

-- Every active Thread row shows its own logical processor's current reading.
local function threadRows(context, first, rows, decimals)
    for slot = 1, rows do
        local thread = first + slot - 1
        local value = threadReading(thread, context.tick)
        assert(context:visible('MeterCoreValue' .. slot), 'Thread row ' .. slot .. ' visible')
        equal(context:text('MeterCoreLabel' .. slot), tostring(thread), 'Thread label ' .. slot)
        equal(context:text('MeterCoreValue' .. slot), percent(value, decimals), 'Thread value ' .. slot)
        equal(context.measures['MeasureCPU' .. slot].appliedName, '0,' .. (thread - 1), 'Thread measure ' .. slot)
    end
end

function suite.Run(cpuPath)
    assert(type(cpuPath) == 'string' and cpuPath ~= '', 'Pass the absolute CPU.lua path')
    local results = {passed=0, failed=0, total=0}
    local report = {'Offline CPU.lua controller suite: parsed skin sources, mocked cycle, fixture readings; no hardware access.'}
    local function test(name, action)
        results.total = results.total + 1
        local ok, failure = pcall(action)
        if ok then
            results.passed = results.passed + 1
            report[#report + 1] = 'PASS ' .. name
        else
            results.failed = results.failed + 1
            report[#report + 1] = 'FAIL ' .. name .. ': ' .. tostring(failure)
        end
    end

    test('automatic rows show every logical processor after warmup', function()
        local context = newMock(cpuPath)
        context:run(1)
        for slot = 1, 12 do assert(not context:visible('MeterCoreValue' .. slot), 'warming row ' .. slot .. ' hidden') end
        context:run(2)
        threadRows(context, 1, 12, 1)
        for slot = 13, 64 do
            assert(not context:visible('MeterCoreValue' .. slot), 'unused slot ' .. slot .. ' hidden')
            assert(not context:visible('MeterCoreTemperature' .. slot), 'unused sensor slot ' .. slot .. ' hidden')
        end
        context:run(5)
        threadRows(context, 1, 12, 1)
    end)
    test('header total follows the current busy-time sample', function()
        local context = newMock(cpuPath)
        context:run(4)
        equal(context:text('MeterTotal'), percent(context.measures.MeasureCPUTotal.value, 1))
        assert(context:visible('MeterTotal'), 'total visible')
    end)
    test('process rows follow the ranking and hide empty ranks', function()
        local context = newMock(cpuPath, {processes={{name='alpha.exe', value=40}, {name='beta.exe', value=2.5}}})
        context:run(4)
        equal(context:text('MeterProcessName1'), 'alpha.exe')
        equal(context:text('MeterProcessValue1'), '40.0%')
        equal(context:text('MeterProcessName2'), 'beta.exe')
        assert(context:visible('MeterProcessName2') and not context:visible('MeterProcessName3'), 'two ranked rows')
        assert(not context:visible('MeterProcessesState'), 'state hidden while rows exist')
        context.processes = {}
        context:run(1)
        assert(not context:visible('MeterProcessName1'), 'empty rank hidden')
        assert(context:visible('MeterProcessesState'), 'state shown without rows')
        equal(context:text('MeterProcessesState'), 'No active process data')
        context.processes = {{name='gamma.exe', value=7}}
        context:run(1)
        equal(context:text('MeterProcessName1'), 'gamma.exe')
        assert(context:visible('MeterProcessName1') and not context:visible('MeterProcessesState'), 'row restored')
    end)
    test('per-thread history draws one coloured trace per logical processor', function()
        local context = newMock(cpuPath)
        context:run(6)
        assert(context:visible('MeterHistory'), 'history visible')
        for thread = 1, 12 do
            local shape = context:appliedOption('MeterHistory', thread == 1 and 'Shape' or ('Shape' .. thread))
            assert(shape:find('^Path HistoryPath' .. thread .. ' '), 'trace ' .. thread .. ' is a path: ' .. shape)
            assert(context:appliedOption('MeterHistory', 'HistoryPath' .. thread):find('LineTo', 1, true), 'trace ' .. thread .. ' has points')
        end
    end)
    test('total history source draws one CPUColor trace', function()
        local context = newMock(cpuPath, {variables={CPUHistorySource='0'}})
        context:run(4)
        local shape = context:appliedOption('MeterHistory', 'Shape')
        assert(shape:find('Stroke Color 235,55,75', 1, true), 'total trace colour: ' .. shape)
        assert(context:visible('MeterHistory'), 'total history visible')
    end)
    test('manual paging binds absolute threads and keeps values current', function()
        local context = newMock(cpuPath, {variables={CPUAutoRows='0', CPUCoresPerPage='4'}})
        context:run(3)
        threadRows(context, 1, 4, 1)
        assert(context:visible('MeterNext') and not context:visible('MeterPrevious'), 'first page controls')
        context:event('Page', 1)
        equal(context.commands[#context.commands], 'SetThreadPage(5)', 'sensor page')
        equal(context.writes[#context.writes].key, 'CPUPage', 'saved page')
        context:run(2)
        threadRows(context, 5, 4, 1)
        equal(context:text('MeterPage'), 'Page 2 / 3')
        context:event('Page', -1)
        context:run(2)
        threadRows(context, 1, 4, 1)
    end)
    test('hiding and showing the Thread table rebinds measures', function()
        local context = newMock(cpuPath)
        context:run(3)
        context:event('ApplySetting', 'CPUShowCores', 0)
        context:run(1)
        for slot = 1, 64 do
            assert(not context:visible('MeterCoreValue' .. slot), 'hidden row ' .. slot)
            assert(context.measures['MeasureCPU' .. slot].disabled, 'disabled slot ' .. slot)
        end
        context:event('ApplySetting', 'CPUShowCores', 1)
        context:run(2)
        threadRows(context, 1, 12, 1)
    end)
    test('switching history source restarts the graph in the new mode', function()
        local context = newMock(cpuPath)
        context:run(5)
        context:event('ApplySetting', 'CPUHistorySource', 0)
        assert(not context:visible('MeterHistory'), 'cleared graph hidden until two samples')
        context:run(3)
        assert(context:appliedOption('MeterHistory', 'Shape'):find('Stroke Color 235,55,75', 1, true), 'total trace')
        for index = 1, 64 do assert(context.measures['MeasureCPUHistory' .. index].disabled, 'history measure ' .. index .. ' disabled') end
        context:event('ApplySetting', 'CPUHistorySource', 1)
        context:run(5)
        assert(context:appliedOption('MeterHistory', 'Shape12'):find('^Path HistoryPath12 '), 'thread traces return')
    end)
    test('decimal and thread-colour preferences apply without a sample', function()
        local context = newMock(cpuPath)
        context:run(4)
        context.variables.cpudecimals = '0'
        context.variables.cputhreadcolor3 = '#102030'
        local tick = context.tick
        context:event('ApplyPreferences')
        equal(context.tick, tick, 'no sample taken')
        equal(context:meterOption('MeterCoreBar3', 'BarColor'), '16,32,48', 'thread bar colour')
        context:run(1)
        threadRows(context, 1, 12, 0)
        equal(context:appliedOption('MeterCoreBar3', 'BarColor'), '16,32,48', 'drawn bar colour')
        assert(context:appliedOption('MeterHistory', 'Shape3'):find('Stroke Color 16,32,48', 1, true), 'trace colour')
    end)
    test('processor details finish from a deferred topology result', function()
        local context = newMock(cpuPath, {infoStatus=0, info=''})
        context:run(3)
        equal(context:meterOption('MeterProcessorDetails', 'Text'), 'Checking...', 'pending details')
        context.measures.MeasureCPUInfo.value, context.measures.MeasureCPUInfo.string = 1, 'OK|6|12'
        context.infoStatus, context.info = 1, 'OK|6|12'
        context:event('ApplyProcessorInfo')
        equal(context:appliedOption('MeterProcessorDetails', 'Text'), '6-cores (12-threads) @ 3.20 (4.60) GHz')
        context:run(1)
    end)
    test('unsupported processor counts disable every Thread slot honestly', function()
        local context = newMock(cpuPath, {detected=65})
        context:run(3)
        equal(context:text('MeterCoreState'), 'Above 64 LPs: unsupported')
        assert(context:visible('MeterCoreState'), 'state visible')
        for slot = 1, 64 do assert(context.measures['MeasureCPU' .. slot].disabled, 'slot ' .. slot .. ' disabled') end
    end)
    test('steady-state cycles paint once, from the skin cycle', function()
        -- CPU-01 / XMOD-04: Update() sets options only. The skin's own meter
        -- pass applies them and redraws; no forced CPUUI pass, no extra frame.
        local context = newMock(cpuPath)
        context:run(4)
        for _ = 1, 6 do
            local stats = context:cycle()
            equal(stats.redraws, 1, 'redraws per cycle')
            equal(context:count(context.controllerBangs, '!Redraw'), 0, 'controller !Redraw')
            equal(context:count(context.controllerBangs, '!UpdateMeterGroup'), 0, 'controller !UpdateMeterGroup')
            equal(context:count(context.controllerBangs, '!UpdateMeter'), 0, 'controller !UpdateMeter')
            equal(stats.rereads.MeterHistory, 1, 'MeterHistory re-reads per cycle')
            equal(stats.rereads.MeterTotal, 1, 'MeterTotal re-reads per cycle')
            threadRows(context, 1, 12, 1)
        end
    end)
    test('settings, paging and deferred results still repaint immediately', function()
        local context = newMock(cpuPath, {infoStatus=0, info='', variables={CPUAutoRows='0', CPUCoresPerPage='4'}})
        context:run(3)
        context:event('Page', 1)
        assert(context.lastEventRedraws >= 1, 'Page repaints')
        context:event('ApplySetting', 'CPUShowProcesses', 0)
        assert(context.lastEventRedraws >= 1, 'ApplySetting repaints')
        context.variables.cputhreadcolor2 = '1,2,3'
        context:event('ApplyPreferences')
        assert(context.lastEventRedraws >= 1, 'thread colour change repaints')
        context.measures.MeasureCPUInfo.value, context.measures.MeasureCPUInfo.string = 1, 'OK|6|12'
        context.infoStatus, context.info = 1, 'OK|6|12'
        context:event('ApplyProcessorInfo')
        assert(context.lastEventRedraws >= 1, 'deferred processor details repaint')
        context:event('ApplyPreferences')
        equal(context.lastEventRedraws, 0, 'unchanged preferences do not repaint')
    end)
    test('no UsageMonitor slot reloads on a steady tick', function()
        -- CPU-02 / ENGINE-05: without DynamicVariables a slot re-reads only
        -- after !SetOption, so 74 per-tick plugin Reloads become none.
        local context = newMock(cpuPath)
        for _, measure in ipairs(context.measureList) do
            if measure.plugin == 'usagemonitor' then
                assert(not measure.dynamic, measure.name .. ' has DynamicVariables')
            end
        end
        context:run(4)
        for _ = 1, 5 do equal(context:cycle().reloads, 0, 'UsageMonitor reloads per steady cycle') end
        threadRows(context, 1, 12, 1)
    end)
    test('binding re-points only slots whose instance or state changed', function()
        local context = newMock(cpuPath, {variables={CPUAutoRows='0', CPUCoresPerPage='4'}})
        context:run(4)
        context:event('Page', 1)
        equal(context:count(context.eventBangs, '!EnableMeasure'), 0, 'page change re-enables nothing')
        equal(context:count(context.eventBangs, '!DisableMeasure'), 0, 'page change disables nothing')
        equal(context:cycle().reloads, 4, 'page change reloads the four re-pointed slots')
        equal(context:cycle().reloads, 0, 'then steady')
        context:event('ApplySetting', 'CPUShowCores', 0)
        equal(context:cycle().reloads, 4, 'hiding the table reloads its four slots once')
        context:event('ApplySetting', 'CPUShowCores', 1)
        equal(context:cycle().reloads, 4, 'showing it reloads them once')
        context:run(1)
        threadRows(context, 5, 4, 1)
        context:event('ApplySetting', 'CPUProcessCount', 3)
        equal(context:cycle().reloads, 2, 'two fewer process slots')
        context:event('ApplySetting', 'CPUHistorySource', 0)
        equal(context:cycle().reloads, 12, 'total source disables twelve history slots')
        context:event('ApplySetting', 'CPUHistorySamples', 30)
        equal(context:cycle().reloads, 0, 'capacity change leaves measures alone')
    end)
    test('steady ticks resend no unchanged option or visibility', function()
        -- CPU-04: unchanged process rows, state text and visibility send nothing.
        local context = newMock(cpuPath)
        context:run(5)
        for _ = 1, 4 do
            context:cycle()
            local log = context.controllerBangs
            for _, name in ipairs({'!ShowMeterGroup', '!HideMeterGroup', '!ShowMeter', '!HideMeter'}) do
                equal(context:count(log, name), 0, name .. ' per steady cycle')
            end
            for slot = 1, 5 do
                equal(context:count(log, '!SetOption', 'MeterProcessName' .. slot), 0, 'unchanged process name ' .. slot)
                equal(context:count(log, '!SetOption', 'MeterProcessValue' .. slot), 0, 'unchanged process value ' .. slot)
            end
            equal(context:count(log, '!SetOption', 'MeterProcessesState'), 0, 'hidden state text')
            local seen = {}
            for _, args in ipairs(log) do
                if args[1] == '!SetOption' then
                    local key = args[2] .. '|' .. args[3]
                    assert(not seen[key], 'option sent twice in one cycle: ' .. key)
                    seen[key] = true
                end
            end
            threadRows(context, 1, 12, 1)
        end
    end)
    test('process rows bang only when a row appears or disappears', function()
        local context = newMock(cpuPath)
        context:run(5)
        context.processes = {{name='alpha.exe', value=12.5}, {name='beta.exe', value=6.25}, {name='gamma.exe', value=3}}
        context:cycle()
        equal(context:count(context.controllerBangs, '!HideMeterGroup'), 2, 'two ranks vanished')
        equal(context:count(context.controllerBangs, '!ShowMeterGroup'), 0, 'no row appeared')
        assert(not context:visible('MeterProcessName4') and context:visible('MeterProcessName3'), 'rows follow ranks')
        context.processes = {{name='beta.exe', value=9}, {name='alpha.exe', value=8}}
        context:cycle()
        equal(context:count(context.controllerBangs, '!HideMeterGroup'), 1, 'third rank vanished')
        equal(context:count(context.controllerBangs, '!SetOption', 'MeterProcessName1'), 1, 'reranked name')
        equal(context:text('MeterProcessName1'), 'beta.exe')
        equal(context:text('MeterProcessValue2'), '8.0%')
        context.processes = {}
        context:cycle()
        equal(context:text('MeterProcessesState'), 'No active process data')
        assert(context:visible('MeterProcessesState'), 'empty state shown')
        context:event('ApplySetting', 'CPUShowProcesses', 0)
        context:event('ApplySetting', 'CPUShowProcesses', 1)
        equal(context:meterOption('MeterProcessesState', 'Text'), 'Waiting for process data...', 'rebinding waits again')
        context.processes = {{name='delta.exe', value=4}}
        context:run(3)
        equal(context:text('MeterProcessName1'), 'delta.exe')
        assert(context:visible('MeterProcessName1') and not context:visible('MeterProcessesState'), 'row after rebinding')
    end)
    -- Like Sensors.lua: before the controller on every tick, and at once on a
    -- page change, set V/T text for all 64 slots from absolute thread numbers.
    local function sensorStub(context)
        local first = 1
        local function render()
            for slot = 1, 64 do
                local thread = first + slot - 1
                context.bang('!SetOption', 'MeterCoreTemperature' .. slot, 'Text', 'T' .. thread .. '@' .. context.tick)
                context.bang('!SetOption', 'MeterCoreVoltage' .. slot, 'Text', 'V' .. thread .. '@' .. context.tick)
            end
        end
        context.beforeController = render
        context.onSensorCommand = function(command)
            first = tonumber(command:match('^SetThreadPage%((%d+)%)$')) or first
            render()
        end
    end
    local function sensorRows(context, first, rows)
        for slot = 1, rows do
            local thread = first + slot - 1
            assert(context:visible('MeterCoreTemperature' .. slot), 'sensor cell ' .. slot .. ' visible')
            equal(context:text('MeterCoreTemperature' .. slot), 'T' .. thread .. '@' .. context.tick, 'temperature cell ' .. slot)
            equal(context:text('MeterCoreVoltage' .. slot), 'V' .. thread .. '@' .. context.tick, 'voltage cell ' .. slot)
        end
    end
    local slotPrefixes = {'MeterCoreLabel', 'MeterCoreBar', 'MeterCoreValue', 'MeterCoreVoltage', 'MeterCoreTemperature'}
    test('idle Thread slots skip the meter pass', function()
        -- CPU-04: the 52 unused slots (260 hidden meters) are not updated per tick.
        local context = newMock(cpuPath)
        sensorStub(context)
        context:run(4)
        local before = {}
        for slot = 1, 64 do
            for _, prefix in ipairs(slotPrefixes) do
                local meter = context.meters[prefix .. slot]
                equal(meter.divider, slot <= 12 and 1 or -1, prefix .. slot .. ' divider')
                before[meter.name] = meter.updates
            end
        end
        context:run(3)
        for slot = 1, 64 do
            for _, prefix in ipairs(slotPrefixes) do
                local meter = context.meters[prefix .. slot]
                equal(meter.updates - before[meter.name], slot <= 12 and 3 or 0, prefix .. slot .. ' updates in 3 cycles')
            end
        end
        threadRows(context, 1, 12, 1)
        sensorRows(context, 1, 12)
    end)
    test('binding a slot applies values set while it was idle', function()
        local context = newMock(cpuPath, {threads=10, variables={CPUAutoRows='0', CPUCoresPerPage='4'}})
        sensorStub(context)
        context:run(3)
        threadRows(context, 1, 4, 1)
        sensorRows(context, 1, 4)
        context:event('ApplySetting', 'CPUShowCores', 0)
        context:run(1)
        for slot = 1, 64 do equal(context.meters['MeterCoreTemperature' .. slot].divider, -1, 'idle slot ' .. slot) end
        context:run(2)
        context:event('ApplySetting', 'CPUShowCores', 1)
        context:run(2)
        threadRows(context, 1, 4, 1)
        sensorRows(context, 1, 4)
        context:event('Page', 1)
        context:event('Page', 1)
        context:run(2)
        threadRows(context, 9, 2, 1)
        sensorRows(context, 9, 2)
        for slot = 3, 4 do
            assert(not context:visible('MeterCoreValue' .. slot), 'short last page hides slot ' .. slot)
            equal(context.meters['MeterCoreValue' .. slot].divider, -1, 'short last page idles slot ' .. slot)
        end
        context:event('Page', -1)
        context:run(2)
        threadRows(context, 5, 4, 1)
        sensorRows(context, 5, 4)
    end)
    test('controller never assigns tooltips', function()
        local context = newMock(cpuPath, {variables={CPUAutoRows='0', CPUCoresPerPage='4'}})
        context:run(4)
        context:event('Page', 1)
        context:run(3)
        for _, meter in ipairs(context.meterList) do
            for key in pairs(meter.parser) do assert(not key:find('^tooltip'), meter.name .. ' sets ' .. key) end
        end
    end)

    report[#report + 1] = string.format('%d passed, %d failed, %d total.', results.passed, results.failed, results.total)
    results.report = table.concat(report, '\n')
    assert(results.failed == 0, results.report)
    return results.report
end

return suite
