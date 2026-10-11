-- Read only UsageMonitor's cached ranks. No shell launches or file writes.
local model, samples, lastDisplay, waitUntil

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\ProcessModel.lua')
    samples, lastDisplay = {}, nil
    -- UsageMonitor's worker needs about a second after load before its first
    -- ranking; keep the startup label briefly rather than report no data.
    waitUntil = os.time() + 3
end

function Display(immediate)
    if not model then return end
    local result = model.Format(samples, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    if #result.rows == 0 and os.time() < waitUntil then result.state = 'Waiting for process data...' end
    -- Avoid unchanged meter updates while preserving periodic provider reads.
    local parts = {result.state, result.tip}
    for _, row in ipairs(result.rows) do
        parts[#parts+1], parts[#parts+2], parts[#parts+3] = row.name, row.text, row.tip
    end
    local signature = table.concat(parts, '\0')
    if signature == lastDisplay then return end
    lastDisplay = signature
    for rank=1,5 do
        local row = result.rows[rank]
        for _, kind in ipairs({'Name','Value'}) do
            local meter = 'MeterRAMProcess'..kind..rank
            SKIN:Bang(row and '!ShowMeter' or '!HideMeter', meter)
            SKIN:Bang('!SetOption', meter, 'Text', row and (kind == 'Name' and row.name or row.text) or '')
            SKIN:Bang('!SetOption', meter, 'ToolTipText', row and row.tip or '')
        end
    end
    SKIN:Bang(#result.rows == 0 and '!ShowMeter' or '!HideMeter', 'MeterRAMProcessesState')
    SKIN:Bang('!SetOption', 'MeterRAMProcessesState', 'Text', result.state)
    SKIN:Bang('!SetOption', 'MeterRAMProcessesState', 'ToolTipText', result.tip)
    SKIN:Bang('!SetOption', 'MeterRAMProcessesHeader', 'ToolTipText',
        'Five largest private working sets, highest first. '..result.tip)
    -- The table meters use UpdateDivider=-1, so changed options appear only
    -- after an explicit update. The periodic skin cycle redraws afterwards;
    -- out-of-cycle Settings calls must redraw themselves.
    SKIN:Bang('!UpdateMeter', 'MeterRAMProcessesHeader')
    SKIN:Bang('!UpdateMeterGroup', 'RAMProcesses')
    if immediate ~= false then SKIN:Bang('!Redraw') end
end

function Update()
    samples = {}
    for rank=1,5 do
        local measure = SKIN:GetMeasure('MeasureRAMProcess'..rank)
        if measure then
            samples[#samples+1] = {name=measure:GetStringValue(), bytes=measure:GetValue()}
        end
    end
    Display(false)
    return 0
end
