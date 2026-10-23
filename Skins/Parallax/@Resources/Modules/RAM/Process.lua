-- Read only UsageMonitor's cached ranks. No shell launches or file writes.
local model, samples, lastDisplay, waitUntil, shown, texts

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\ProcessModel.lua')
    samples, lastDisplay = {}, nil
    -- Last visibility and text sent to each table meter, so a changed ranking
    -- touches only the rows whose name, value or visibility changed.
    shown, texts = {}, {}
    -- UsageMonitor's worker needs about a second after load before its first
    -- ranking; keep the startup label briefly rather than report no data.
    waitUntil = os.time() + 3
end

local function apply(meter, visible, text, changed)
    if shown[meter] ~= visible then
        SKIN:Bang(visible and '!ShowMeter' or '!HideMeter', meter)
        shown[meter] = visible
    end
    if texts[meter] ~= text then
        SKIN:Bang('!SetOption', meter, 'Text', text)
        texts[meter] = text
        changed[#changed + 1] = meter
    end
end

function Display(immediate)
    if not model then return end
    local result = model.Format(samples, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    if #result.rows == 0 and os.time() < waitUntil then result.state = 'Waiting for process data...' end
    -- Avoid unchanged meter updates while preserving periodic provider reads.
    local parts = {result.state}
    for _, row in ipairs(result.rows) do
        parts[#parts+1], parts[#parts+2] = row.name, row.text
    end
    local signature = table.concat(parts, '\0')
    if signature == lastDisplay then return end
    lastDisplay = signature
    local changed = {}
    for rank=1,5 do
        local row = result.rows[rank]
        for _, kind in ipairs({'Name','Value'}) do
            apply('MeterRAMProcess'..kind..rank, row ~= nil, row and (kind == 'Name' and row.name or row.text) or '', changed)
        end
    end
    apply('MeterRAMProcessesState', #result.rows == 0, result.state, changed)
    -- The table meters use UpdateDivider=-1, so a changed Text appears only
    -- after an explicit update; force just those meters. Show/Hide applies
    -- at once and needs none. The periodic skin cycle redraws afterwards;
    -- out-of-cycle Settings calls must redraw themselves.
    for _, meter in ipairs(changed) do SKIN:Bang('!UpdateMeter', meter) end
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
