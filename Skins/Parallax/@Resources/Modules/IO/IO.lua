-- Original Parallax presentation controller. Native measures own all telemetry.
-- The optional model-name query runs once at initialization, never for telemetry.
local cache, history, lastObservationTime, shapeCount
local selected, selectedKey, graphMode, graphDrives, selectionKind, selectionWarning
local capacityEnabled, ratesEnabled, layoutKey
local Names
local letters = {}
for code = 65, 90 do letters[#letters + 1] = string.char(code) end
local historySlots = 60
local MiB = 1048576

local function variable(key, default)
    return SKIN:GetVariable(key, default)
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge
        and value ~= -math.huge
end

local function number(key)
    local measure = SKIN:GetMeasure(key)
    local value = measure and measure:GetValue() or nil
    if finite(value) then return value end
    return nil
end

-- Keep external labels as display text, never Rainmeter variable/action syntax.
local function safe(text)
    return tostring(text or ''):gsub('[%c#%[%]]', ' ')
end

local function option(meter, key, value)
    local id = meter .. ':' .. key
    value = tostring(value)
    if cache[id] ~= value then
        SKIN:Bang('!SetOption', meter, key, value)
        cache[id] = value
        return true
    end
    return false
end

local function text(meter, value)
    return option(meter, 'Text', safe(value))
end

local function visible(meter, show)
    local id = meter .. ':visible'
    if cache[id] ~= show then
        SKIN:Bang(show and '!ShowMeter' or '!HideMeter', meter)
        cache[id] = show
    end
end

local function scaled(value, base, units)
    if not finite(value) or value < 0 then return '--' end
    local unit = 1
    while value >= base and unit < #units do
        value = value / base
        unit = unit + 1
    end
    return string.format('%.1f %s', value, units[unit])
end

local function bytes(value)
    return scaled(value, 1000, {'B', 'KB', 'MB', 'GB', 'TB', 'PB'})
end

local function capacityBytes(value)
    return scaled(value, 1000, {'B', 'KB', 'MB', 'GB', 'TB', 'PB'})
end

local function compactCapacity(freeText, totalText)
    local freeValue, freeUnit = freeText:match('^(.-) ([^ ]+)$')
    local _, totalUnit = totalText:match('^(.-) ([^ ]+)$')
    return (freeUnit == totalUnit and freeValue or freeText) .. '/' .. totalText
end

local function diskRate(value)
    local units = variable('IODiskUnits', 'bytes'):lower()
    if units == 'bits' then
        return scaled(value * 8, 1000, {'bit/s', 'kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'})
    elseif units == 'bytes' then
        return bytes(value) .. '/s'
    end
    return 'Check IO units'
end

local function positiveSetting(key)
    local value = tonumber(variable(key, ''))
    return finite(value) and value > 0 and value or nil
end

local function numericVariable(key)
    local raw = variable(key, '')
    local value = tonumber(raw)
    if not value and raw ~= '' then
        value = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(raw) .. ')')
    end
    return finite(value) and value or nil
end

local function present(kind)
    return kind == 3 or kind == 4 or kind == 5 or kind == 6 or kind == 7
end

local function capacityType(kind)
    return kind == 3 or kind == 4 or kind == 5 or kind == 7
end

local function names(drives)
    local result = {}
    for _, letter in ipairs(drives) do result[#result + 1] = letter .. ':' end
    return #result > 0 and table.concat(result, ', ') or 'none'
end

local function compactRate(value)
    -- Reuse the already-rounded value; only remove redundant display spacing
    -- and a trailing .0. The tooltip retains the original formatted rate.
    local amount, unit = value:match('^(%d+%.%d+) ([^ ]+)$')
    return amount and (amount:gsub('%.0$', '') .. unit) or value
end

local function nameMode()
    local mode = variable('IODriveNames', 'volume')
    if mode ~= 'letters' and mode ~= 'model' and mode ~= 'both' then return 'volume' end
    return mode
end

local function parseSelection()
    local raw = variable('IODiskDrives', 'C')
    local found, kind, warning = {}, raw, ''
    if raw == 'all' then
        for _, letter in ipairs(letters) do
            if present(number('MeasureIOType' .. letter)) then found[letter] = true end
        end
    elseif raw ~= 'none' then
        local valid = type(raw) == 'string' and raw:match('^[A-Z][A-Z,]*$') ~= nil
        local previous = ''
        if valid then
            for token in (raw .. ','):gmatch('(.-),') do
                if not token:match('^[A-Z]$') or token <= previous then valid = false; break end
                found[token], previous = true, token
            end
        end
        if not valid then
            found, kind = { C = true }, 'C'
            warning = 'Invalid drive selection; using C:. '
        end
    end
    local result = {}
    if found.C then result[1] = 'C' end
    for _, letter in ipairs(letters) do
        if letter ~= 'C' and found[letter] then result[#result + 1] = letter end
    end
    return result, kind, warning
end

local function updateBanks()
    local wantCapacity, wantRates = {}, {}
    for _, letter in ipairs(selected) do
        local kind = number('MeasureIOType' .. letter)
        wantCapacity[letter] = capacityType(kind)
        wantRates[letter] = present(kind)
    end
    if graphMode == 'c' then wantRates.C = present(number('MeasureIOTypeC')) end
    local banks = {{prefix = 'IOCapacity', wanted = wantCapacity, active = capacityEnabled},
        {prefix = 'IORates', wanted = wantRates, active = ratesEnabled}}
    for _, letter in ipairs(letters) do
        for _, bank in ipairs(banks) do
            local wanted, active = bank.wanted[letter] == true, bank.active[letter] == true
            if wanted ~= active then
                local group = bank.prefix .. letter
                SKIN:Bang(wanted and '!EnableMeasureGroup' or '!DisableMeasureGroup', group)
                if wanted then SKIN:Bang('!UpdateMeasureGroup', group) end
                bank.active[letter] = wanted
            end
        end
    end
end

local function syncSelection()
    local drives, kind, warning = parseSelection()
    local key = table.concat(drives, ',')
    local mode = variable('IOGraphMode', 'combined')
    if mode ~= 'c' and mode ~= 'overlay' and mode ~= 'split' then mode = 'combined' end
    if key ~= selectedKey or mode ~= graphMode then
        history, lastObservationTime = {}, nil
    end
    selected, selectedKey, graphMode = drives, key, mode
    selectionKind, selectionWarning = kind, warning
    graphDrives = mode == 'c' and {'C'} or selected
    updateBanks()
end

-- A letter always has the same overlay color, regardless of selection order.
local function driveColor(letter)
    local hue = ((string.byte(letter) - 65) * 0.61803398875 % 1) * 6
    local sector, fraction = math.floor(hue), hue - math.floor(hue)
    local value, saturation = 0.95, 0.65
    local p, q, t = value * (1 - saturation), value * (1 - saturation * fraction), value * (1 - saturation * (1 - fraction))
    local channels = {{value,t,p},{q,value,p},{p,value,t},{p,q,value},{t,p,value},{value,p,q}}
    local color = channels[sector + 1]
    return string.format('%d,%d,%d', math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function layout()
    local scale = numericVariable('Scale') or 1
    if scale <= 0 then scale = 1 end
    local inset = numericVariable('Inset') or 0
    local gap = numericVariable('Gap') or 0
    local width = numericVariable('ContentWidth') or 0
    local x = numericVariable('ContentX') or inset
    local cellGap = 4 * scale
    local cellWidth = math.max(0, width - 2 * cellGap)
    local rateWidth, capacityWidth = cellWidth * 0.28, cellWidth * 0.44
    local bar = numericVariable('DataBarThicknessPx')
        or math.max(1, math.floor((numericVariable('DataBarThickness') or 6) * scale + 0.5))
    local extra = #selected > 0 and math.max(0, bar / scale - 6) or 0
    local pitch = 50 + extra
    local legendColumns = math.max(1, math.floor(width / (26 * scale)))
    local legendRows = graphMode == 'overlay' and math.ceil(#selected / legendColumns) or 0
    local savedHeight = numericVariable('PanelHeight') or 157
    local key = table.concat({selectedKey, graphMode, selectionKind, scale, inset, gap, width, x, bar, savedHeight}, '|')
    if layoutKey == key then return false end
    layoutKey = key
    local positions = {}
    for index, letter in ipairs(selected) do positions[letter] = index - 1 end
    local graphBase = 89 + extra + math.max(0, #selected - 1) * pitch
    for _, letter in ipairs(letters) do
        local index = positions[letter]
        local shown = index ~= nil
        local row = shown and (42 + index * pitch) or 0
        local barY = shown and (inset + (60 + index * pitch) * scale + math.max(0, (6 * scale - bar) / 2)) or 0
        local rateY = shown and (inset + (68 + extra + index * pitch) * scale) or 0
        for _, prefix in ipairs({'MeterIODrive', 'MeterIOCapacity'}) do
            local capacityRow = prefix == 'MeterIOCapacity'
            option(prefix .. letter, 'Y', shown and (capacityRow and rateY or (inset + row * scale)) or 0)
            option(prefix .. letter, 'X', capacityRow and (x + width) or x)
            option(prefix .. letter, 'W', capacityRow and capacityWidth or width)
            visible(prefix .. letter, shown)
        end
        option('MeterIOUsed' .. letter, 'Y', barY)
        if not shown then visible('MeterIOUsed' .. letter, false) end
        for _, direction in ipairs({'Read', 'Write'}) do
            local cellX = x + (direction == 'Write' and (rateWidth + cellGap) or 0)
            for _, suffix in ipairs({'', 'Label'}) do
                local meter = 'MeterIODisk' .. direction .. suffix .. letter
                option(meter, 'Y', shown and (rateY + (suffix == 'Label' and 2 * scale or 0)) or 0)
                option(meter, 'X', cellX + (suffix == 'Label' and 0 or 11 * scale))
                option(meter, 'W', suffix == 'Label' and 10 * scale or math.max(1, rateWidth - 11 * scale))
                visible(meter, shown)
            end
        end
        local legend = 'MeterIOLegend' .. letter
        if shown and graphMode == 'overlay' then
            text(legend, letter .. ':')
            option(legend, 'X', x + (index % legendColumns) * 26 * scale)
            option(legend, 'Y', inset + (graphBase + math.floor(index / legendColumns) * 18) * scale)
            option(legend, 'FontColor', driveColor(letter))
            visible(legend, true)
        else
            option(legend, 'Y', 0)
            visible(legend, false)
        end
    end
    text('MeterIOEmpty', selectionKind == 'all' and 'No drives found' or 'No drives selected')
    option('MeterIOEmpty', 'Y', inset + 42 * scale)
    visible('MeterIOEmpty', #selected == 0)
    local graphY = inset + (graphBase + legendRows * 18) * scale
    option('MeterIODiskGraphTrack', 'Y', graphY)
    option('MeterIODiskGraph', 'Y', graphY)
    option('MeterIODiskGraphTrack', 'Shape3',
        'Line 1,(#IOGraphHeight#*#Scale#/2),(#ContentWidth#-1),(#IOGraphHeight#*#Scale#/2) | Stroke Color #'
        .. (graphMode == 'split' and 'MutedColor' or 'GridColor') .. '# | StrokeWidth 1')
    for index, suffix in ipairs({'Positive', 'Zero', 'Negative'}) do
        local meter = 'MeterIOGraph' .. suffix
        text(meter, ({'+', '0', '-'})[index])
        option(meter, 'X', x + width - 2 * scale)
        -- Top anchors keep hidden Y=0 inside the skin. The 14px text boxes
        -- center at 7/31/55px, with zero exactly on the declared frame midpoint.
        option(meter, 'Y', graphMode == 'split' and (graphY + (index - 1) * 24 * scale) or 0)
        option(meter, 'W', 12 * scale)
        option(meter, 'H', 14 * scale)
        visible(meter, graphMode == 'split')
        SKIN:Bang('!UpdateMeter', meter)
    end
    SKIN:Bang('!UpdateMeter', 'MeterIODiskGraphTrack')
    local minimum = 157 + extra + math.max(0, #selected - 1) * pitch + legendRows * 18
    local height = math.floor(math.max(savedHeight, minimum) * scale + 0.5)
    local id = 'variable:PanelHeightPx'
    local resize = cache[id] ~= height or cache['MeterIOBounds:H'] ~= tostring(height + gap)
    if cache[id] ~= height then
        SKIN:Bang('!SetVariable', 'PanelHeightPx', tostring(height))
        cache[id] = height
    end
    option('MeterIOBounds', 'H', height + gap)
    if resize then
        SKIN:Bang('!UpdateMeter', 'MeterIOPanel')
        SKIN:Bang('!UpdateMeter', 'MeterIOBounds')
    end
    return true
end

local function renderNames(immediate)
    local mode, changed = nameMode(), false
    for _, letter in ipairs(selected) do
        local display, tooltip = Names.Format(SKIN, letter, mode)
        local meter = 'MeterIODrive' .. letter
        local dirty = text(meter, letter .. ':' .. (display ~= '' and (' ' .. display) or ''))
        dirty = option(meter, 'ToolTipText', safe(letter .. ': ' .. tooltip)) or dirty
        if immediate and dirty then SKIN:Bang('!UpdateMeter', meter) end
        changed = dirty or changed
        if graphMode == 'overlay' then
            local legend = 'MeterIOLegend' .. letter
            local detail = letter .. ': read is solid; write is dashed. Both use this drive color.'
            if tooltip ~= '' then detail = detail .. ' ' .. tooltip end
            dirty = option(legend, 'ToolTipText', safe(detail))
            if immediate and dirty then SKIN:Bang('!UpdateMeter', legend) end
            changed = dirty or changed
        end
    end
    if immediate and changed then SKIN:Bang('!Redraw') end
end

local function appendObservation(sample)
    history[#history + 1] = sample
    if #history > historySlots then table.remove(history, 1) end
end

local function observe(sample)
    -- This clock detects interruptions in our observations, not provider sample
    -- timestamps. Equal successive reports still occupy successive slots.
    local now = os.time()
    if lastObservationTime then
        local elapsed = now - lastObservationTime
        if elapsed < 0 then
            history = {}
        elseif elapsed > 1 then
            for _ = 1, math.min(historySlots - 1, elapsed - 1) do
                appendObservation({})
            end
        end
    end
    lastObservationTime = now
    appendObservation(sample)
end

local function graph()
    local series = {}
    if graphMode == 'overlay' then
        for _, letter in ipairs(graphDrives) do
            for _, direction in ipairs({'Read', 'Write'}) do
                series[#series + 1] = {letter = letter, direction = direction, color = driveColor(letter),
                    dashed = direction == 'Write'}
            end
        end
    elseif #graphDrives > 0 then
        for _, direction in ipairs({'Read', 'Write'}) do
            series[#series + 1] = {direction = direction,
                color = variable('Disk' .. direction .. 'Color', '220,220,220')}
        end
    end
    local function valueFor(sample, trace)
        if trace.letter then
            local drive = sample.Drives and sample.Drives[trace.letter]
            return drive and drive[trace.direction] or nil
        end
        return sample[trace.direction]
    end
    local ceilingMiBs = positiveSetting('IODiskMaxMiBs')
    local ceiling = ceilingMiBs and ceilingMiBs * MiB or nil
    if not finite(ceiling) then ceiling = nil end
    local scale = numericVariable('Scale')
    local width = numericVariable('ContentWidth')
    -- Split's zero must coincide with the declared frame midpoint even at
    -- fractional scales. Preserve the existing geometry of the other modes.
    local height = scale and (graphMode == 'split' and 62 * scale or math.floor(62 * scale)) or 0
    local inset = scale and math.max(2, 2 * scale) or 2
    local geometryValid = scale and scale > 0 and width and width > 2 * inset and height > 2 * inset
    local shapes, paths = {}, {}
    local peak = 0
    for _, sample in ipairs(history) do
        for _, trace in ipairs(series) do peak = math.max(peak, valueFor(sample, trace) or 0) end
    end
    local top = ceiling and math.min(ceiling, math.max(65536, math.min(peak, ceiling) * 1.15)) or nil
    local detail = not ceiling and 'Check graph limit. Traces hidden.'
        or not geometryValid and 'Graph dimensions unavailable. Traces hidden.'
        or (graphMode == 'split'
            and string.format('Displayed range: -%g to +%g MB/s; symmetric autoscale, cap %g MB/s per direction.',
                top / 1000000, top / 1000000, ceiling / 1000000)
            or string.format('Displayed range: 0-%g MB/s; autoscaled, cap %g MB/s.', top / 1000000, ceiling / 1000000))
    local modeText = graphMode == 'c' and 'C: only'
        or graphMode == 'overlay' and ('Individual overlay: ' .. names(graphDrives))
        or graphMode == 'split' and ('Split + / -; combined selected drives: ' .. names(graphDrives))
        or ('Combined selected drives: ' .. names(graphDrives))
    local tooltip = selectionWarning .. modeText .. '. Read/write observation history. ' .. detail
        .. (graphMode == 'overlay' and ' Each drive has a stable color; read is solid and write is dashed.' or '')
        .. (graphMode == 'split' and ' Read is positive above zero; write is negative below zero. Signs are a display convention; physical transfer rates remain nonnegative.' or '')
        .. ' 60 nominal one-second slots, newest at right. Current unavailable or nonpositive readings plot as zero; zero can mean idle or unavailable.'
        .. ' Retained observations connect by straight-line interpolation across missed intervals. History before the first observation stays blank.'
        .. ' Provider sample freshness is unknown; unchanged reports may be stale. Refresh, drive membership or graph mode changes clear history.'
    option('MeterIODiskGraphTrack', 'ToolTipText', tooltip)
    option('MeterIODiskGraph', 'ToolTipText', tooltip)
    if ceiling and geometryValid then
        width = math.floor(width)
        local step = (width - 2 * inset) / (historySlots - 1)
        local stroke = math.max(1, scale)
        local radius = math.max(1, scale)
        for _, trace in ipairs(series) do
            local points = {}
            for index, sample in ipairs(history) do
                local value = valueFor(sample, trace)
                if value ~= nil then
                    local ratio = math.min(value / top, 1)
                    local y = height - inset - ratio * (height - 2 * inset)
                    if graphMode == 'split' then
                        y = height / 2 + (trace.direction == 'Read' and -1 or 1)
                            * ratio * (height / 2 - inset)
                    end
                    points[#points + 1] = {
                        x = inset + (historySlots - #history + index - 1) * step,
                        y = y
                    }
                end
            end
            local index = #shapes + 1
            if #points == 1 then
                shapes[index] = string.format('Ellipse %.3f,%.3f,%.3f,%.3f | Fill Color %s | StrokeWidth 0',
                    points[1].x, points[1].y, radius, radius, trace.color)
            elseif #points > 1 then
                local parts = {}
                for i, point in ipairs(points) do
                    parts[i] = (i == 1 and '' or 'LineTo ') .. string.format('%.3f,%.3f', point.x, point.y)
                end
                parts[#parts + 1] = 'ClosePath 0'
                local key = 'IOHistoryPath' .. index
                paths[key] = table.concat(parts, ' | ')
                shapes[index] = 'Path ' .. key .. ' | Fill Color 0,0,0,0 | Stroke Color ' .. trace.color
                    .. ' | StrokeWidth ' .. stroke .. ' | StrokeLineJoin Round'
                    .. (trace.dashed and ' | StrokeDashes 4,3' or '')
            end
        end
    end
    for key, value in pairs(paths) do option('MeterIODiskGraph', key, value) end
    local count = #shapes
    for index = 1, math.max(count, shapeCount, 1) do
        local key = index == 1 and 'Shape' or ('Shape' .. index)
        option('MeterIODiskGraph', key, shapes[index] or (index == 1
            and 'Rectangle 0,0,0,0 | Fill Color 0,0,0,0 | StrokeWidth 0' or ''))
    end
    shapeCount = count
    visible('MeterIODiskGraph', count > 0)
end

local function capacity(letter)
    local total = capacityEnabled[letter] and number('MeasureIOTotal' .. letter) or nil
    local free = capacityEnabled[letter] and number('MeasureIOFree' .. letter) or nil
    local kind = number('MeasureIOType' .. letter)
    local valid = false
    local detail, display
    if kind == 6 then
        detail = 'Optical unsupported'
    elseif not capacityType(kind) then
        detail = 'Missing / unavailable'
    elseif not finite(total) or not finite(free) or total <= 0 or free < 0 or free > total then
        detail = 'Unavailable'
    else
        valid = true
        local freeText, totalText = capacityBytes(free), capacityBytes(total)
        detail = freeText .. ' / ' .. totalText
        display = compactCapacity(freeText, totalText)
    end
    text('MeterIOCapacity' .. letter, display or detail)
    option('MeterIOCapacity' .. letter, 'FontColor', valid
        and variable('TextColor', '220,220,220') or variable('MutedColor', '175,175,175'))
    option('MeterIOCapacity' .. letter, 'ToolTipText', letter .. ': ' .. detail .. (valid and ' (free / total)' or ''))
    visible('MeterIOUsed' .. letter, valid)
    if valid then
        option('MeterIOUsed' .. letter, 'ToolTipText', string.format('%.1f%% used', 100 * (1 - free / total)))
    end
    return valid, total, free
end

local function updateCapacities()
    local allValid, total, free = #selected > 0, 0, 0
    for _, letter in ipairs(selected) do
        local valid, driveTotal, driveFree = capacity(letter)
        allValid = allValid and valid
        if valid then total, free = total + driveTotal, free + driveFree end
    end
    allValid = allValid and finite(total) and finite(free) and total > 0
    local percent = allValid and 100 * (1 - free / total) or nil
    text('MeterIOTotal', percent and string.format('%.0f%%', percent) or '--')
    local tooltip = #selected == 0 and 'No selected drive capacity.'
        or allValid and string.format('Selected %s; %.1f%% used, weighted by total capacity.', names(selected), percent)
        or ('Selected ' .. names(selected) .. '; used percentage unavailable until every selected drive has valid capacity.')
    option('MeterIOTotal', 'ToolTipText', selectionWarning .. tooltip)
end

local function disk()
    local current = {}
    local function read(letter)
        if current[letter] then return current[letter] end
        local sample = {}
        for _, direction in ipairs({'Read', 'Write'}) do
            local value = ratesEnabled[letter] and number('MeasureIODisk' .. direction .. letter) or nil
            sample[direction] = finite(value) and value > 0 and value or 0
        end
        current[letter] = sample
        return sample
    end
    for _, letter in ipairs(selected) do
        local sample = read(letter)
        for _, direction in ipairs({'Read', 'Write'}) do
            local value = sample[direction]
            local meter = 'MeterIODisk' .. direction .. letter
            local formatted = value > 0 and diskRate(value) or '--'
            text(meter, compactRate(formatted))
            option(meter, 'ToolTipText', value > 0
                and (letter .. ': ' .. direction .. ': ' .. formatted .. '. Provider-reported; sample freshness is unknown.')
                or (letter .. ': ' .. direction .. ': no positive rate; idle, missing counter, unavailable provider, or initial sample.'))
        end
    end
    if #graphDrives > 0 then
        local readTotal, writeTotal = 0, 0
        for _, letter in ipairs(graphDrives) do
            local sample = read(letter)
            readTotal, writeTotal = readTotal + sample.Read, writeTotal + sample.Write
        end
        -- The graph's current-unknown convention also covers an unrepresentable sum.
        observe({ Read = finite(readTotal) and readTotal or 0, Write = finite(writeTotal) and writeTotal or 0,
            Drives = current })
    end
    graph()
end

function Initialize()
    cache = {}
    history, lastObservationTime, shapeCount = {}, nil, 0
    selected, selectedKey, graphMode, graphDrives, selectionKind, selectionWarning = {}, nil, nil, {}, 'C', ''
    capacityEnabled, ratesEnabled, layoutKey = {}, {}, nil
    Names = dofile(variable('@', '') .. 'Modules\\IO\\Names.lua')
    Names.Query(SKIN, nameMode())
    local interval = tonumber(variable('CapacityInterval', '30000')) or 30000
    option('MeterIOCapacityHeading', 'ToolTipText', string.format(
        'Native capacity sampled every %d seconds. Bars show used percentage.',
        math.max(5, math.ceil(interval / 1000))))
end

function NamesReady()
    -- A metadata completion must not query again, sample rates, or alter history.
    if Names then renderNames(true) end
    return 0
end

local function repaintNameLayout()
    local moved = layout()
    renderNames(not moved)
    if moved then
        -- Rebuild from retained observations only; a settings action is not a
        -- new rate observation and must not advance the graph's clock.
        graph()
        for _, letter in ipairs(selected) do
            for _, prefix in ipairs({'MeterIODrive', 'MeterIOCapacity', 'MeterIOUsed',
                'MeterIODiskRead', 'MeterIODiskWrite', 'MeterIODiskReadLabel', 'MeterIODiskWriteLabel'}) do
                SKIN:Bang('!UpdateMeter', prefix .. letter)
            end
            if graphMode == 'overlay' then SKIN:Bang('!UpdateMeter', 'MeterIOLegend' .. letter) end
        end
        SKIN:Bang('!UpdateMeter', 'MeterIOEmpty')
        SKIN:Bang('!UpdateMeter', 'MeterIODiskGraph')
        SKIN:Bang('!Redraw')
    end
end

function ApplyNamesMode()
    if not Names then return 0 end
    Names.Query(SKIN, nameMode())
    repaintNameLayout()
    return 0
end

function RefreshNamesInventory()
    if not Names then return 0 end
    SKIN:Bang('!UpdateMeasureGroup', 'IOInventory')
    Names.Query(SKIN, nameMode())
    -- Inventory names can refresh immediately. Selected membership and its
    -- telemetry/history scope are reconciled by the next normal Update only.
    repaintNameLayout()
    return 0
end

function Update()
    syncSelection()
    layout()
    renderNames(false)
    updateCapacities()
    disk()
    return 0
end
