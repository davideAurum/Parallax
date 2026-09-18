-- Parallax original CPU presentation/controller. No provider or process polling.
-- Processor Utility measures precede this Script measure. Bangs are queued by Rainmeter.
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

local function utility(value)
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge or value < 0 or value > 1000 then return nil end
    return value
end

local function graphUtility(value)
    value = utility(value)
    return value and math.min(100, value) or nil
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

-- The first twelve colors are deliberately distinct for the common 12-thread
-- layout. Higher thread counts repeat the editable palette rather than
-- inventing a measurement-specific color at runtime.
local threadPalette = {
    '235,55,75', '255,145,77', '240,225,40', '166,219,91',
    '79,205,120', '60,200,194', '77,170,255', '122,139,255',
    '182,130,255', '238,111,196', '245,139,168', '190,190,190'
}

local function defaultThreadColor(index)
    return threadPalette[(index - 1) % #threadPalette + 1]
end

local function normalizeThreadColor(value, fallback)
    local text = tostring(value or ''):match('^%s*(.-)%s*$')
    local hex = text:gsub('^#', '')
    if (#hex == 6 or #hex == 8) and hex:match('^%x+$') then
        return table.concat({
            tostring(tonumber(hex:sub(1, 2), 16)),
            tostring(tonumber(hex:sub(3, 4), 16)),
            tostring(tonumber(hex:sub(5, 6), 16))
        }, ',')
    end
    local red, green, blue = text:match('^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
    red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
    if red and green and blue and red <= 255 and green <= 255 and blue <= 255 then
        return string.format('%d,%d,%d', red, green, blue)
    end
    return fallback
end

local function configuredThreadColor(index)
    local fallback = defaultThreadColor(index)
    return normalizeThreadColor(SKIN:GetVariable('CPUThreadColor' .. index, fallback), fallback)
end

local function syncThreadColors()
    state.threadColors = state.threadColors or {}
    local changed = false
    for index = 1, 64 do
        local color = configuredThreadColor(index)
        if state.threadColors[index] ~= color then
            state.threadColors[index] = color
            changed = true
        end
    end
    return changed
end

local function normalizeClock(frequency, unit)
    frequency = tonumber(frequency)
    if not frequency or frequency ~= frequency or math.abs(frequency) == math.huge then return nil end
    if unit and unit:lower() == 'm' then frequency = frequency / 1000 end
    if frequency <= 0 or frequency > 20 then return nil end
    return frequency, string.format('%.2f GHz', frequency)
end

local function configuredTurboClock()
    -- Rated turbo is intentionally explicit: the available Windows/HWiNFO paths only expose
    -- firmware limits or live clocks, neither of which is a portable advertised turbo spec.
    local frequency, unit = tostring(SKIN:GetVariable('CPUTurboClock') or '')
        :match('^%s*(%d+%.?%d*)%s*([GgMm])[Hh][Zz]%s*$')
    return normalizeClock(frequency, unit)
end

local graphTotalHeight = 62
local renderHistory

local function graphThreadRange()
    -- History collection is absolute-thread based, independent of table paging.
    return 1, state.count or 0
end

local function graphHeight()
    return graphTotalHeight
end

local function shapeName(index)
    return index == 1 and 'Shape' or ('Shape' .. index)
end

local function configureHistoryTrack()
    state.graphFirst, state.graphRows = graphThreadRange()
    state.graphHeight = graphHeight()
    set('MeterHistoryTrack', 'H', '(' .. state.graphHeight .. '*#Scale#)')
    set('MeterHistory', 'H', '(' .. state.graphHeight .. '*#Scale#)')

    local height = state.graphHeight
    local shapes = {
        'Rectangle 0.5,0.5,(#ContentWidth#-1),(' .. height .. '*#Scale#-1) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1'
    }
    for index = 1, 3 do
        local y = height * index / 4
        shapes[#shapes + 1] = 'Line 1,(' .. y .. '*#Scale#),(#ContentWidth#-1),(' .. y .. '*#Scale#) | Stroke Color #GridColor# | StrokeWidth 1'
    end
    local count = math.max(#shapes, state.trackShapeCount or 4)
    for index = 1, count do
        set('MeterHistoryTrack', shapeName(index), shapes[index] or '')
    end
    state.trackShapeCount = #shapes
end

local function layout()
    local cursor = 30
    local function y(meter, top)
        set(meter, 'Y', '(#Inset#+' .. top .. '*#Scale#)')
    end
    local function centeredBarY(meter, top)
        -- The shared thickness is already physical pixels. Center it in this
        -- 16-logical-pixel row so the full supported 1-12px range clears both
        -- adjacent rows at every suite scale.
        set(meter, 'Y', '(#Inset#+' .. top .. '*#Scale#+((16*#Scale#-#DataBarThicknessPx#)/2))')
    end
    SKIN:Bang(state.showInfo and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUInfo')
    if state.showInfo then
        local top = cursor
        local infoHeight = 34
        for meter, offset in pairs({ MeterProcessorPanel = 0,
            MeterProcessorName = 2, MeterProcessorDetails = 18 }) do y(meter, top + offset) end
        set('MeterProcessorPanel', 'H', '(' .. infoHeight .. '*#Scale#)')
        set('MeterProcessorPanel', 'Shape', 'Rectangle 0.5,0.5,(#ContentWidth#-1),(' .. infoHeight .. '*#Scale#-1),(2*#Scale#) | Fill Color #GraphBackgroundColor# | Stroke Color #BorderColor# | StrokeWidth 1')
        cursor = top + infoHeight + 8
        y('MeterCurrentClockLabel', cursor)
        y('MeterCurrentClockValue', cursor)
        cursor = cursor + 16
        SKIN:Bang(state.showFan and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUFan')
        if state.showFan then
            y('MeterCurrentFanLabel', cursor)
            y('MeterCurrentFanValue', cursor)
            cursor = cursor + 16
        else
            y('MeterCurrentFanLabel', 0)
            y('MeterCurrentFanValue', 0)
        end
        SKIN:Bang(state.showMotherboardFan and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUMotherboardFan')
        if state.showMotherboardFan then
            y('MeterMotherboardFanLabel', cursor)
            y('MeterMotherboardFanValue', cursor)
            cursor = cursor + 16
        else
            y('MeterMotherboardFanLabel', 0)
            y('MeterMotherboardFanValue', 0)
        end
        cursor = cursor + 8
    else
        y('MeterCurrentClockLabel', 0)
        y('MeterCurrentClockValue', 0)
        y('MeterCurrentFanLabel', 0)
        y('MeterCurrentFanValue', 0)
        y('MeterMotherboardFanLabel', 0)
        y('MeterMotherboardFanValue', 0)
    end
    SKIN:Bang(state.showCores and '!ShowMeterGroup' or '!HideMeterGroup', 'CPUTableFrame')
    visible('MeterCoreState', state.showCores and (state.count == 0 or state.warmup > 0))
    for _, meter in ipairs({'MeterPrevious', 'MeterPage', 'MeterNext'}) do y(meter, 0) end
    if state.showCores then
        for _, meter in ipairs({'MeterTableCoreHeader','MeterTableVoltageHeader','MeterTableTemperatureHeader','MeterTableUsageHeader'}) do y(meter, cursor) end
        y('MeterTableHeaderRule', cursor + 16)
        state.coreY = cursor + 20
        y('MeterCoreState', state.coreY)
        for slot = 1, 64 do
            local top = slot <= state.rows and state.coreY + (slot - 1) * 16 or 0
            y('MeterCoreLabel' .. slot, top)
            y('MeterCoreValue' .. slot, top)
            y('MeterCoreVoltage' .. slot, top)
            y('MeterCoreTemperature' .. slot, top)
            centeredBarY('MeterCoreBar' .. slot, top)
        end
        cursor = state.coreY + (state.count > 0 and state.rows or 2) * 16
        y('MeterTableFooterRule', cursor + 2)
        cursor = cursor + 10
        if state.pages > 1 then
            for _, meter in ipairs({'MeterPrevious', 'MeterPage', 'MeterNext'}) do y(meter, cursor) end
            cursor = cursor + 18
        end
    else
        for slot = 1, 64 do
            y('MeterCoreLabel' .. slot, 0)
            y('MeterCoreValue' .. slot, 0)
            y('MeterCoreVoltage' .. slot, 0)
            y('MeterCoreTemperature' .. slot, 0)
            y('MeterCoreBar' .. slot, 0)
        end
        for _, meter in ipairs({'MeterTableCoreHeader', 'MeterTableVoltageHeader', 'MeterTableTemperatureHeader', 'MeterTableUsageHeader',
            'MeterTableHeaderRule', 'MeterTableFooterRule', 'MeterCoreState'}) do y(meter, 0) end
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
        end
        cursor = state.processY + state.processCount * 16
        y('MeterProcessFooterRule', cursor + 2)
        cursor = cursor + 10
    end
    configureHistoryTrack()
    visible('MeterHistoryTrack', state.showHistory)
    if state.showHistory then
        y('MeterHistoryTrack', cursor)
        y('MeterHistory', cursor)
        cursor = cursor + state.graphHeight + 8
    end
    local height = math.max(state.minimumHeight, cursor + 20)
    y('MeterSensors', height - 20)
    visible('MeterSensors', true)
    SKIN:Bang('!SetVariable', 'PanelHeight', tostring(height))
    set('MeterBounds', 'H', '(Round(' .. height .. '*#Scale#)+#Gap#)')
    set('MeterPanel', 'Shape', 'Rectangle (#BorderThickness#*#Scale#/2),(#BorderThickness#*#Scale#/2),(#PanelWidth#-#BorderThickness#*#Scale#),(Round(' .. height .. '*#Scale#)-#BorderThickness#*#Scale#),(#CornerRadius#*#Scale#) | Fill Color #BackgroundColor# | Stroke Color #BorderColor# | StrokeWidth (#BorderThickness#*#Scale#)')
    if renderHistory then renderHistory() else visible('MeterHistory', false) end
    SKIN:Bang('!UpdateMeter', '*')
end

local function bindCores()
    state.active = 0
    local enabled = state.showCores and state.count > 0
    state.pages = state.count > 0 and math.ceil(state.count / state.rows) or 1
    state.page = math.max(1, math.min(state.page, state.pages))
    local first = (state.page - 1) * state.rows + 1
    local visibleSlots = enabled and math.max(0, math.min(state.rows, state.count - first + 1)) or 0
    -- Reuse the sensor reader's current values for this absolute thread page.
    SKIN:Bang('!CommandMeasure', 'MeasureCPUSensors', 'SetThreadPage(' .. first .. ',' .. visibleSlots .. ')')
    for slot = 1, 64 do
        local measure = 'MeasureCPU' .. slot
        local index = first + slot - 1
        SKIN:Bang('!HideMeterGroup', 'CPUCore' .. slot)
        SKIN:Bang('!DisableMeasure', measure)
        set(measure, 'Disabled', 1)
        -- 0,0 is a valid safe instance while this page-relative slot is disabled.
        set(measure, 'Name', '0,0')
        if enabled and slot <= state.rows and index <= state.count then
            state.active = state.active + 1
            set(measure, 'Name', '0,' .. (index - 1))
            set(measure, 'Disabled', 0)
            SKIN:Bang('!EnableMeasure', measure)
            set('MeterCoreLabel' .. slot, 'Text', tostring(index))
            set('MeterCoreLabel' .. slot, 'ToolTipText', 'Windows hardware thread ' .. index .. '. The bar and percentage show frequency-adjusted Processor Utility. Values above 100% indicate turbo; the bar is capped at 100%.')
            set('MeterCoreValue' .. slot, 'NumOfDecimals', state.decimals)
            set('MeterCoreValue' .. slot, 'Text', '...')
            set('MeterCoreBar' .. slot, 'BarColor', state.threadColors[index] or defaultThreadColor(index))
        else
            -- Hidden page-bank rows must not retain native tooltip controls.
            set('MeterCoreLabel' .. slot, 'ToolTipText', '')
        end
    end
    -- A changed UsageMonitor instance needs fresh samples. Discard its warmup.
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

local function updateThreadValues()
    for slot = 1, state.active do
        local value = utility(SKIN:GetMeasure('MeasureCPU' .. slot):GetValue())
        set('MeterCoreValue' .. slot, 'Text', value and string.format('%.' .. state.decimals .. 'f%%', value) or '-')
    end
end

local function applyThreadBarColors()
    local first = ((state.page or 1) - 1) * (state.rows or 1) + 1
    for slot = 1, math.min(state.rows or 0, 64) do
        local index = first + slot - 1
        if index <= (state.count or 0) then
            set('MeterCoreBar' .. slot, 'BarColor', state.threadColors[index] or defaultThreadColor(index))
        end
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

local function clearHistoryPath(index)
    set('MeterHistory', 'HistoryPath' .. index, '')
    set('MeterHistory', shapeName(index), 'Rectangle 0,0,0,0 | Fill Color 0,0,0,0 | StrokeWidth 0')
    state.renderedThreadPath[index] = false
end

local function clearHistoryShape()
    for index = 1, 64 do clearHistoryPath(index) end
end

local function clearHistory()
    state.totalHistory = {}
    state.threadHistory = {}
    clearHistoryShape()
    visible('MeterHistory', false)
    visible('MeterHistoryTrack', state.showHistory)
end

local function historyTooltip()
    local duration = (state.samples - 1) * state.interval / 1000
    local text
    if state.historySource == 1 then
        text = string.format('Per-thread Processor Utility: %d samples, approximately %.1f seconds between full-buffer endpoints. Every Windows logical processor is drawn as an overlaid trace on the shared 0-100%% scale and time axis, newest at right. Turbo values above 100%% are capped only in the graph. Each trace uses its matching Thread bar color. An invalid reading clears only that trace; unobserved history stays blank. Changing source, capacity, visibility or refreshing starts fresh history.', state.samples, duration)
    else
        text = string.format('Total Processor Utility: %d samples, approximately %.1f seconds between full-buffer endpoints. The trace is capped to 0-100%%, newest at right; the numeric total can show turbo values above 100%%. Unobserved history stays blank; changing source, capacity, visibility or refreshing starts fresh history.', state.samples, duration)
    end
    set('MeterHistory', 'ToolTipText', text)
    set('MeterHistoryTrack', 'ToolTipText', text)
end

local function graphDimensions()
    local width = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#ContentWidth#') .. ')')
    local height = (state.graphHeight or graphTotalHeight) * state.scale
    if not width or width <= 0 or not height or height <= 0 then return nil end
    return width, height
end

local function tracePoints(history, width, top, height)
    if #history < 2 then return nil end
    local inset = math.max(1, state.scale)
    local usableWidth = width - 2 * inset
    local usableHeight = height - 2 * inset
    if usableWidth <= 0 or usableHeight <= 0 then return nil end
    -- Retain every requested observation, but draw no more than one point per
    -- horizontal pixel. This bounds a 64-thread, 300-sample redraw.
    local maximum = math.max(2, math.floor(usableWidth) + 1)
    local stride = math.max(1, math.ceil(#history / maximum))
    local step = usableWidth / (state.samples - 1)
    local points = {}
    local function add(index)
        local sample = history[index]
        points[#points + 1] = {
            x = inset + (state.samples - #history + index - 1) * step,
            y = top + height - inset - sample / 100 * usableHeight
        }
    end
    for index = 1, #history, stride do add(index) end
    if (#history - 1) % stride ~= 0 then add(#history) end
    return #points >= 2 and points or nil
end

local function formatPoint(point)
    return string.format('%.3f,%.3f', point.x, point.y)
end

local function drawHistoryPath(index, path, color)
    if not path then return end
    set('MeterHistory', 'HistoryPath' .. index, path)
    set('MeterHistory', shapeName(index), 'Path HistoryPath' .. index .. ' | StrokeWidth ' .. math.max(1, state.scale)
        .. ' | Stroke Color ' .. color
        .. ' | Fill Color 0,0,0,0 | StrokeLineJoin Round')
end

local function totalHistoryPath()
    local width, height = graphDimensions()
    if not width then return nil end
    local points = tracePoints(state.totalHistory, width, 0, height)
    if not points then return nil end
    local path = {formatPoint(points[1])}
    for index = 2, #points do path[#path + 1] = 'LineTo ' .. formatPoint(points[index]) end
    path[#path + 1] = 'ClosePath 0'
    return table.concat(path, ' | ')
end

local function threadHistoryPath(index)
    local width, height = graphDimensions()
    if not width then return nil end
    local points = tracePoints(state.threadHistory[index] or {}, width, 0, height)
    if not points then return nil end
    local path = {formatPoint(points[1])}
    for point = 2, #points do path[#path + 1] = 'LineTo ' .. formatPoint(points[point]) end
    path[#path + 1] = 'ClosePath 0'
    return table.concat(path, ' | ')
end

renderHistory = function()
    if not state.showHistory then
        visible('MeterHistory', false)
        return
    end
    if state.historySource == 0 then
        local path = totalHistoryPath()
        if not path and state.renderedThreadPath[1] then clearHistoryPath(1) end
        drawHistoryPath(1, path, SKIN:GetVariable('CPUColor'))
        state.renderedThreadPath[1] = path ~= nil
        visible('MeterHistory', path ~= nil)
        return
    end
    local hasTrace = false
    for index = 1, state.count do
        local path = threadHistoryPath(index)
        if path then
            drawHistoryPath(index, path, state.threadColors[index] or defaultThreadColor(index))
            state.renderedThreadPath[index] = true
            hasTrace = true
        elseif state.renderedThreadPath[index] then
            clearHistoryPath(index)
        end
    end
    visible('MeterHistory', hasTrace)
end

local function appendSample(history, value)
    history[#history + 1] = value
    if #history > state.samples then table.remove(history, 1) end
end

local function appendTotalHistory(value)
    if not state.showHistory or state.historySource ~= 0 then return end
    appendSample(state.totalHistory, value)
    renderHistory()
end

local function appendThreadHistory()
    if not state.showHistory or state.historySource ~= 1 or state.historyWarmup > 0 then return end
    for index = 1, state.count do
        local value = graphUtility(SKIN:GetMeasure('MeasureCPUHistory' .. index):GetValue())
        if value then
            local history = state.threadHistory[index] or {}
            state.threadHistory[index] = history
            appendSample(history, value)
        else
            -- Do not draw an apparently continuous trace over a known-invalid sample.
            state.threadHistory[index] = {}
        end
    end
    renderHistory()
end

local function bindHistoryMeasures()
    local enabled = state.showHistory and state.historySource == 1 and state.count > 0
    for index = 1, 64 do
        local measure = 'MeasureCPUHistory' .. index
        local active = enabled and index <= state.count
        SKIN:Bang(active and '!EnableMeasure' or '!DisableMeasure', measure)
        set(measure, 'Disabled', active and 0 or 1)
    end
    -- Enabling a UsageMonitor instance requires fresh samples.
    state.historyWarmup = enabled and 2 or 0
end

function Initialize()
    state = { ready = false, totalHistory = {}, threadHistory = {}, threadColors = {}, renderedThreadPath = {}, trackShapeCount = 4 }
end

local function showProcessorName()
    local raw = SKIN:GetMeasure('MeasureCPUModel'):GetStringValue()
    -- Only an explicit nominal frequency in the brand string is used here.
    -- Current/maximum clock measures are not substitutes for the base clock.
    local frequency, unit = raw:match('@%s*(%d+%.?%d*)%s*([GgMm])[Hh][Zz]%s*$')
    state.baseClockGHz, state.baseClock = normalizeClock(frequency, unit)
    state.turboClockGHz, state.turboClock = configuredTurboClock()
    if not state.baseClockGHz or not state.turboClockGHz or state.turboClockGHz <= state.baseClockGHz then
        state.turboClockGHz, state.turboClock = nil, nil
    end
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
    if state.turboClock then
        summary = counts .. string.format(' @ %.2f (%.2f) GHz', state.baseClockGHz, state.turboClockGHz)
    end
    set('MeterProcessorDetails', 'Text', summary)
    local detail = valid and (physical .. ' physical cores; ' .. logical .. ' hardware threads (logical processors). ')
        or 'Windows processor topology unavailable. Refresh to retry. '
    detail = detail .. (state.baseClock and ('Base clock: ' .. state.baseClock .. ', from the primary processor model string; not a current reading.')
        or 'Base clock unavailable: the primary processor model does not report a nominal frequency.')
    detail = detail .. (state.turboClock and (' Configured turbo boost clock: ' .. state.turboClock
        .. '. This is an advertised limit supplied in CPU settings, not a live measurement or a guaranteed all-core frequency.')
        or ' Turbo boost clock is not configured with a valid value above the base clock.')
    set('MeterProcessorDetails', 'ToolTipText', detail)
    state.processorInfoDone = true
    layout()
    redraw()
end

function ApplyPreferences()
    if not state.ready then return end
    -- A settings event applies display changes without taking a telemetry sample.
    for key, spec in pairs({
        CPUShowInfo = {'showInfo', 1, 0, 1}, CPUShowFan = {'showFan', 1, 0, 1},
        CPUShowMotherboardFan = {'showMotherboardFan', 1, 0, 1}, CPUShowCores = {'showCores', 1, 0, 1},
        CPUShowProcesses = {'showProcesses', 1, 0, 1}, CPUShowHistory = {'showHistory', 1, 0, 1},
        CPUProcessCount = {'processCount', 5, 1, 10}, CPUHistorySource = {'historySource', 0, 0, 1},
        CPUHistorySamples = {'samples', 60, 10, 300},
        CPUDecimals = {'decimals', 0, 0, 1}
    }) do
        local current = state[spec[1]]
        if type(current) == 'boolean' then current = current and 1 or 0 end
        local desired = option(key, spec[2], spec[3], spec[4])
        if desired ~= current then ApplySetting(key, desired) end
    end
    if syncThreadColors() then
        applyThreadBarColors()
        renderHistory()
        redraw()
    end
end

function Update()
    if not state.ready then
        state.processorInfoDeadline = os.time() + 12
        showProcessorName()
        state.userFile = SKIN:GetVariable('@') .. 'User\\CPU.inc'
        state.minimumHeight = option('PanelHeight', 80, 50, 4096)
        state.showInfo = option('CPUShowInfo', 1, 0, 1) == 1
        state.showFan = option('CPUShowFan', 1, 0, 1) == 1
        state.showMotherboardFan = option('CPUShowMotherboardFan', 1, 0, 1) == 1
        state.showProcesses = option('CPUShowProcesses', 1, 0, 1) == 1
        state.processCount = option('CPUProcessCount', 5, 1, 10)
        state.rows = option('CPUCoresPerPage', 8, 1, 64)
        state.page = option('CPUPage', 1, 1, 64)
        state.decimals = option('CPUDecimals', 0, 0, 1)
        state.samples = option('CPUHistorySamples', 60, 10, 300)
        state.showCores = option('CPUShowCores', 1, 0, 1) == 1
        state.showHistory = option('CPUShowHistory', 1, 0, 1) == 1
        state.historySource = option('CPUHistorySource', 0, 0, 1)
        state.scale = tonumber(SKIN:GetVariable('Scale')) or 1
        state.interval = tonumber(SKIN:GetVariable('CPUUpdateInterval')) or 1000
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
        syncThreadColors()
        historyTooltip()
        bindCores()
        bindProcesses()
        bindHistoryMeasures()
        layout()
        clearHistory()
        state.ready = true
        redraw()
        return 0
    end

    ApplyProcessorInfo()
    updateProcesses()
    local value = utility(SKIN:GetMeasure('MeasureCPUTotal'):GetValue())
    if value then
        set('MeterTotal', 'Text', string.format('%.' .. state.decimals .. 'f%%', value))
    else
        set('MeterTotal', 'Text', 'Unavailable')
    end
    if state.historySource == 0 then
        local graphValue = graphUtility(value)
        if graphValue then
            appendTotalHistory(graphValue)
        else
            -- Do not bridge a known-invalid total sample with a continuous trace.
            clearHistory()
        end
    else
        if state.historyWarmup > 0 then state.historyWarmup = state.historyWarmup - 1 end
        appendThreadHistory()
    end
    updateThreadValues()
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
    elseif key == 'CPUShowFan' then
        state.showFan = value == 1
    elseif key == 'CPUShowMotherboardFan' then
        state.showMotherboardFan = value == 1
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
        bindHistoryMeasures()
        historyTooltip()
    elseif key == 'CPUHistorySource' then
        state.historySource = value
        clearHistory()
        bindHistoryMeasures()
        historyTooltip()
    elseif key == 'CPUHistorySamples' then
        state.samples = value
        clearHistory()
        historyTooltip()
    elseif key == 'CPUDecimals' then
        state.decimals = value
        for slot = 1, 64 do set('MeterCoreValue' .. slot, 'NumOfDecimals', value) end
        local total = utility(SKIN:GetMeasure('MeasureCPUTotal'):GetValue())
        if total then
            set('MeterTotal', 'Text', string.format('%.' .. value .. 'f%%', total))
        end
    else
        return
    end
    SKIN:Bang('!SetVariable', key, tostring(value))
    layout()
    redraw()
end
