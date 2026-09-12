-- Parallax original CPU presentation/controller. No provider or process polling.
-- Native CPU measures precede this Script measure. Bangs are queued by Rainmeter.
local state

local function integer(value, fallback, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then
        return fallback
    end
    return math.max(minimum, math.min(maximum, math.floor(number)))
end

local function option(name, fallback, minimum, maximum)
    return integer(SKIN:GetVariable(name), fallback, minimum, maximum)
end

local function set(meter, key, value)
    SKIN:Bang('!SetOption', meter, key, tostring(value))
end

local function visible(meter, show)
    SKIN:Bang(show and '!ShowMeter' or '!HideMeter', meter)
end

local function redraw()
    -- Updating a Shape only redraws the stored path; it never adds a sample.
    SKIN:Bang('!UpdateMeterGroup', 'CPUUI')
    SKIN:Bang('!Redraw')
end

local function save(key, value)
    SKIN:Bang('!SetVariable', key, tostring(value))
    SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), state.userFile)
end

local function layout()
    local cursor = 30
    local function y(meter, top)
        set(meter, 'Y', '(#Inset#+' .. top .. '*#Scale#)')
    end
    SKIN:Bang(state.showInfo and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUInfo')
    visible('MeterProcessorClock', state.showInfo and state.infoWrap)
    if state.showInfo then
        local top = cursor
        local infoHeight = state.infoWrap and 50 or 34
        for meter, offset in pairs({ MeterProcessorPanel = 0,
            MeterProcessorName = 2, MeterProcessorDetails = 18, MeterProcessorClock = 34 }) do y(meter, top + offset) end
        set('MeterProcessorPanel', 'H', '(' .. infoHeight .. '*#Scale#)')
        set('MeterProcessorPanel', 'Shape', 'Rectangle 0.5,0.5,(#ContentWidth#-1),(' .. infoHeight .. '*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1')
        cursor = top + infoHeight + 8
    end
    SKIN:Bang(state.showCores and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUTableFrame')
    visible('MeterCoreState', state.showCores and (state.count == 0 or state.warmup > 0))
    if state.showCores then
        for _, meter in ipairs({'MeterTableCoreHeader','MeterTableVoltageHeader','MeterTableTemperatureHeader','MeterTableUsageHeader'}) do y(meter, cursor) end
        y('MeterTableHeaderRule', cursor + 16)
        state.coreY = cursor + 20
        y('MeterCoreState', state.coreY)
        for slot = 1, 64 do
            local top = slot <= state.rows and state.coreY + (slot - 1) * 16 or 0
            y('MeterCoreLabel' .. slot, top)
            y('MeterCoreValue' .. slot, top)
            y('MeterCoreBar' .. slot, top + 7)
            y('MeterCoreVoltage' .. slot, top)
            y('MeterCoreTemperature' .. slot, top)
        end
        cursor = state.coreY + (state.count > 0 and state.rows or 2) * 16
        y('MeterTableFooterRule', cursor + 2)
        cursor = cursor + 10
        if state.pages > 1 then
            for _, meter in ipairs({'MeterPrevious', 'MeterPage', 'MeterNext'}) do y(meter, cursor) end
            cursor = cursor + 18
        end
    end
    SKIN:Bang(state.showProcesses and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUProcessFrame')
    if state.showProcesses then
        y('MeterProcessesHeading', cursor)
        y('MeterProcessUsageHeader', cursor)
        y('MeterProcessHeaderRule', cursor + 16)
        state.processY = cursor + 20
        y('MeterProcessesState', state.processY)
        for slot = 1, 10 do
            local top = slot <= state.processCount and state.processY + (slot - 1) * 16 or 0
            y('MeterProcessName' .. slot, top)
            y('MeterProcessValue' .. slot, top)
            y('MeterProcessBar' .. slot, top + 7)
        end
        cursor = state.processY + state.processCount * 16
        y('MeterProcessFooterRule', cursor + 2)
        cursor = cursor + 10
    end
    visible('MeterHistoryLabel', state.showHistory)
    visible('MeterHistoryTrack', state.showHistory)
    visible('MeterHistory', state.showHistory and #state.history >= 2)
    if state.showHistory then
        y('MeterHistoryLabel', cursor)
        y('MeterHistoryTrack', cursor + 16)
        y('MeterHistory', cursor + 16)
        cursor = cursor + 70
    end
    local height = math.max(state.minimumHeight, cursor + 20)
    y('MeterSensors', height - 20)
    visible('MeterSensors', true)
    SKIN:Bang('!SetVariable', 'PanelHeight', tostring(height))
    set('MeterBounds', 'H', '(Round(' .. height .. '*#Scale#)+#Gap#)')
    set('MeterPanel', 'Shape', 'Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(Round(' .. height .. '*#Scale#)-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)')
    SKIN:Bang('!UpdateMeter', '*')
end

local function bindCores()
    state.active = 0
    local enabled = state.showCores and state.count > 0
    state.pages = state.count > 0 and math.ceil(state.count / state.rows) or 1
    state.page = math.max(1, math.min(state.page, state.pages))
    local first = (state.page - 1) * state.rows + 1
    for slot = 1, 64 do
        local measure = 'MeasureCPU' .. slot
        local index = first + slot - 1
        SKIN:Bang('!HideMeterGroup', 'CPUCore' .. slot)
        SKIN:Bang('!DisableMeasure', measure)
        set(measure, 'Disabled', 1)
        -- Processor=0 is safe even when no logical-processor count is known.
        set(measure, 'Processor', 0)
        if enabled and slot <= state.rows and index <= state.count then
            state.active = state.active + 1
            set(measure, 'Processor', index)
            set(measure, 'Disabled', 0)
            SKIN:Bang('!EnableMeasure', measure)
            set('MeterCoreLabel' .. slot, 'Text', 'LP ' .. index)
            set('MeterCoreLabel' .. slot, 'ToolTipText', 'Logical processor ' .. index .. '; not a physical-core identifier.')
            set('MeterCoreValue' .. slot, 'NumOfDecimals', state.decimals)
        end
    end
    -- A changed Processor resets native timing. Discard its first sample.
    state.warmup = 2
    visible('MeterCoreState', state.showCores)
    visible('MeterPrevious', enabled and state.page > 1)
    visible('MeterNext', enabled and state.page < state.pages)
    visible('MeterPage', enabled and state.pages > 1)
    set('MeterPage', 'Text', enabled and state.pages > 1 and ('Page ' .. state.page .. ' / ' .. state.pages) or '')
    if enabled then
        set('MeterCoreState', 'Text', 'Sampling logical CPUs...')
    else
        set('MeterCoreState', 'Text', state.showCores and state.countError or 'Core display off')
    end
end

local function bindProcesses()
    state.processWarmup = 2
    for slot = 1, 10 do
        local enabled = state.showProcesses and slot <= state.processCount
        local measure = 'MeasureCPUProcess' .. slot
        SKIN:Bang(enabled and '!EnableMeasure' or '!DisableMeasure', measure)
        set(measure, 'Disabled', enabled and 0 or 1)
        SKIN:Bang('!HideMeterGroup', 'CPUProcess' .. slot)
    end
    visible('MeterProcessesState', state.showProcesses)
    set('MeterProcessesState', 'Text', 'Waiting for process data...')
end

local function updateProcesses()
    if not state.showProcesses then return end
    if state.processWarmup > 0 then state.processWarmup = state.processWarmup - 1; return end
    local populated = 0
    for slot = 1, state.processCount do
        local measure = SKIN:GetMeasure('MeasureCPUProcess' .. slot)
        local name, value = measure:GetStringValue(), measure:GetValue()
        local valid = name ~= '' and name ~= '0' and value == value and value > 0 and value <= 100
        SKIN:Bang(valid and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUProcess' .. slot)
        if valid then
            populated = populated + 1
            set('MeterProcessName' .. slot, 'Text', name)
            set('MeterProcessName' .. slot, 'ToolTipText', name .. ': ' .. string.format('%.1f%% of total CPU; same-name instances grouped.', value))
            set('MeterProcessValue' .. slot, 'Text', string.format('%.' .. state.decimals .. 'f%%', value))
        end
    end
    visible('MeterProcessesState', populated == 0)
    set('MeterProcessesState', 'Text', 'No active process data')
end

local function clearHistory()
    state.history = {}
    visible('MeterHistory', false)
    visible('MeterHistoryTrack', state.showHistory)
    set('MeterHistoryLabel', 'Text', state.showHistory and 'Graph | warming up' or '')
end

local function historyTooltip()
    set('MeterHistory', 'ToolTipText', string.format('%d samples, approximately %.1f seconds between full-buffer endpoints. 0-100%%, newest at right. Unobserved history stays blank; refresh clears it.', state.samples, (state.samples - 1) * state.interval / 1000))
end

local function appendHistory(value)
    if not state.showHistory then return end
    local history = state.history
    history[#history + 1] = value
    if #history > state.samples then table.remove(history, 1) end
    set('MeterHistoryLabel', 'Text', string.format('Graph | %d/%d | 0-100%%', #history, state.samples))
    if #history < 2 then return end
    local meter = SKIN:GetMeter('MeterHistory')
    -- GetW/GetH return zero for a hidden meter; use declared dimensions while
    -- preparing the first path after startup or a visibility toggle.
    local width = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(meter:GetOption('W')) .. ')')
    local height = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(meter:GetOption('H')) .. ')')
    -- Keep the stroke inside the declared meter, including at exactly 0/100%.
    local inset = math.max(1, state.scale)
    local step = math.max(0, width - 2 * inset) / (state.samples - 1)
    local path = {}
    for index, sample in ipairs(history) do
        local x = inset + (state.samples - #history + index - 1) * step
        local y = height - inset - sample / 100 * math.max(0, height - 2 * inset)
        path[#path + 1] = (index == 1 and '' or 'LineTo ') .. string.format('%.3f,%.3f', x, y)
    end
    path[#path + 1] = 'ClosePath 0'
    set('MeterHistory', 'HistoryPath', table.concat(path, ' | '))
    set('MeterHistory', 'Shape', 'Path HistoryPath | StrokeWidth ' .. state.scale .. ' | Stroke Color ' .. SKIN:GetVariable('CPUColor') .. ' | Fill Color 0,0,0,0')
    visible('MeterHistory', true)
end

function Initialize()
    state = { ready = false, history = {} }
end

local function showProcessorName()
    local raw = SKIN:GetMeasure('MeasureCPUModel'):GetStringValue()
    -- Only an explicit nominal frequency in the brand string is used here.
    -- Current/maximum clock measures are not substitutes for the base clock.
    local frequency, unit = raw:match('@%s*(%d+%.?%d*)%s*([GgMm])[Hh][Zz]%s*$')
    frequency = tonumber(frequency)
    if frequency and unit:lower() == 'm' then frequency = frequency / 1000 end
    state.baseClock = frequency and frequency > 0 and frequency <= 20
        and string.format('%.2f GHz', frequency) or nil
    local name = raw:gsub('%([Rr]%)', ''):gsub('%([Tt][Mm]%)', '')
    name = name:gsub('%s+[Cc][Pp][Uu]%s*@%s*[%d%.]+%s*[GgMm][Hh][Zz]%s*$', '')
    name = name:gsub('%s*@%s*[%d%.]+%s*[GgMm][Hh][Zz]%s*$', '')
    name = name:gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if name == '' or tonumber(name) == 0 then name = 'Unavailable' end
    set('MeterProcessorName', 'Text', name)
    set('MeterProcessorName', 'ToolTipText', name == 'Unavailable' and 'Windows processor name unavailable.' or raw)
end

function ApplyProcessorInfo()
    if not state.ready or state.processorInfoDone then return end
    local measure = SKIN:GetMeasure('MeasureCPUInfo')
    local status = measure:GetValue()
    if status ~= 1 and status < 100 and os.time() < state.processorInfoDeadline then return end
    local physical, logical = measure:GetStringValue():match('^%s*OK|(%d+)|(%d+)%s*$')
    physical, logical = tonumber(physical), tonumber(logical)
    local valid = status == 1 and physical and logical and physical >= 1 and logical >= 1
        and physical < math.huge and logical < math.huge
    local counts = valid and (physical .. '-cores (' .. logical .. '-threads)') or '?-cores (?-threads)'
    local clock = state.baseClock or 'Unavailable'
    local summary = counts .. ' @ ' .. clock
    local width = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#ContentWidth#') .. ')') / state.scale - 8
    -- Reflow at a conservative text-width threshold; never shrink the selected
    -- body font. Breaking before @ keeps the clock and unit together.
    state.infoWrap = #summary * (tonumber(SKIN:GetVariable('FontSize')) or 9) * 0.72 > width
    set('MeterProcessorDetails', 'Text', state.infoWrap and counts or summary)
    set('MeterProcessorClock', 'Text', '@ ' .. clock)
    local detail = valid and (physical .. ' physical cores; ' .. logical .. ' hardware threads (logical processors). ')
        or 'Windows processor topology unavailable. Refresh to retry. '
    detail = detail .. (state.baseClock and ('Base clock: ' .. state.baseClock .. ', from the primary processor model string; not current or turbo frequency.')
        or 'Base clock unavailable: the primary processor model does not report a nominal frequency.')
    set('MeterProcessorDetails', 'ToolTipText', detail)
    set('MeterProcessorClock', 'ToolTipText', detail)
    state.processorInfoDone = true
    layout()
    redraw()
end

function ApplyPreferences()
    if not state.ready then return end
    -- A settings event applies display changes without taking a telemetry sample.
    for key, spec in pairs({
        CPUShowInfo = {'showInfo', 1, 0, 1}, CPUShowCores = {'showCores', 1, 0, 1},
        CPUShowProcesses = {'showProcesses', 1, 0, 1}, CPUShowHistory = {'showHistory', 1, 0, 1},
        CPUProcessCount = {'processCount', 5, 1, 10}, CPUHistorySamples = {'samples', 60, 10, 300},
        CPUDecimals = {'decimals', 0, 0, 1}
    }) do
        local current = state[spec[1]]
        if type(current) == 'boolean' then current = current and 1 or 0 end
        local desired = option(key, spec[2], spec[3], spec[4])
        if desired ~= current then ApplySetting(key, desired) end
    end
end

function Update()
    if not state.ready then
        state.processorInfoDeadline = os.time() + 12
        showProcessorName()
        state.userFile = SKIN:GetVariable('@') .. 'User\\CPU.inc'
        state.minimumHeight = option('PanelHeight', 80, 50, 4096)
        state.showInfo = option('CPUShowInfo', 1, 0, 1) == 1
        state.showProcesses = option('CPUShowProcesses', 1, 0, 1) == 1
        state.processCount = option('CPUProcessCount', 5, 1, 10)
        state.rows = option('CPUCoresPerPage', 8, 1, 64)
        state.page = option('CPUPage', 1, 1, 64)
        state.decimals = option('CPUDecimals', 0, 0, 1)
        state.samples = option('CPUHistorySamples', 60, 10, 300)
        state.showCores = option('CPUShowCores', 1, 0, 1) == 1
        state.showHistory = option('CPUShowHistory', 1, 0, 1) == 1
        state.scale = tonumber(SKIN:GetVariable('Scale')) or 1
        state.interval = tonumber(SKIN:GetVariable('MetricsInterval')) or 1000
        state.count = 0
        state.countError = 'Core count unavailable'
        local detected = tonumber(SELF:GetOption('DetectedCount', ''))
        if detected and detected == detected and detected == math.floor(detected) and detected >= 1 and detected <= 64 then
            state.count = detected
            local limit = option('CPUCoreLimit', 0, 0, 64)
            if limit > 0 then state.count = math.min(state.count, limit) end
        elseif detected and detected > 64 then
            state.countError = 'Above 64 LPs: unsupported'
        end
        if option('CPUAutoRows', 1, 0, 1) == 1 then
            state.rows = state.count > 0 and state.count or 8
            state.page = 1
        end
        historyTooltip()
        bindCores()
        bindProcesses()
        layout()
        clearHistory()
        state.ready = true
        redraw()
        return 0
    end

    ApplyProcessorInfo()
    updateProcesses()
    -- The first overall sample was intentionally skipped during setup.
    local value = SKIN:GetMeasure('MeasureCPUTotal'):GetValue()
    if value == value and value >= 0 and value <= 100 then
        set('MeterTotal', 'Text', string.format('%.' .. state.decimals .. 'f%%', value))
        appendHistory(value)
    else
        set('MeterTotal', 'Text', 'Unavailable')
        -- Do not bridge a known-invalid sample with an apparently continuous trace.
        clearHistory()
    end
    if state.active > 0 and state.warmup > 0 then
        state.warmup = state.warmup - 1
        if state.warmup == 0 then
            visible('MeterCoreState', false)
            for slot = 1, state.active do
                SKIN:Bang('!ShowMeterGroup', 'CPUCore' .. slot)
            end
        end
    end
    redraw()
    return value
end

function Page(direction)
    if not state.ready or not state.showCores or state.count == 0 then return end
    local page = math.max(1, math.min(state.pages, state.page + (direction < 0 and -1 or 1)))
    if page == state.page then return end
    state.page = page
    save('CPUPage', state.page)
    bindCores()
    layout()
    redraw()
end

-- The independent settings utility saves preferences, then applies them here.
-- No refresh is required, so unrelated history and processor metadata survive.
function ApplySetting(key, value)
    if not state.ready then return end
    local maximum = key == 'CPUHistorySamples' and 300 or (key == 'CPUProcessCount' and 10 or 1)
    local minimum = key == 'CPUHistorySamples' and 10 or (key == 'CPUProcessCount' and 1 or 0)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < minimum or value > maximum then return end
    if key == 'CPUShowInfo' then
        state.showInfo = value == 1
    elseif key == 'CPUShowProcesses' then
        state.showProcesses = value == 1
        bindProcesses()
    elseif key == 'CPUProcessCount' then
        state.processCount = value
        bindProcesses()
    elseif key == 'CPUShowCores' then
        state.showCores = value == 1
        bindCores()
    elseif key == 'CPUShowHistory' then
        state.showHistory = value == 1
        clearHistory()
    elseif key == 'CPUHistorySamples' then
        state.samples = value
        clearHistory()
        historyTooltip()
    elseif key == 'CPUDecimals' then
        state.decimals = value
        for slot = 1, 64 do set('MeterCoreValue' .. slot, 'NumOfDecimals', value) end
        local total = SKIN:GetMeasure('MeasureCPUTotal'):GetValue()
        if total == total and total >= 0 and total <= 100 then
            set('MeterTotal', 'Text', string.format('%.' .. value .. 'f%%', total))
        end
    else
        return
    end
    SKIN:Bang('!SetVariable', key, tostring(value))
    layout()
    redraw()
end
