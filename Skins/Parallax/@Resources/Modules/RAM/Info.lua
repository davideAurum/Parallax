-- Cached, refresh-only module inventory. Display/layout never query hardware.
local model, data, settled, deadline, layoutPasses, lastHeight

local function layout()
    local summary = SKIN:GetMeter('MeterRAMInfoSummary')
    local scale = tonumber(SKIN:GetVariable('Scale')) or 1
    if not summary or scale <= 0 then return end
    -- Native String wrapping honors the actual font and available column width.
    local height = math.ceil(math.max(18*scale, summary:GetH()))/scale + 8
    if lastHeight and math.abs(lastHeight-height) < 0.001 then return end
    lastHeight = height
    SKIN:Bang('!SetVariable', 'RAMInfoHeight', tostring(height))
    -- This group deliberately excludes the Line meter: moving the graph must
    -- not append a sample outside its normal update cadence.
    SKIN:Bang('!UpdateMeterGroup', 'RAMLayout')
    local history = SKIN:GetMeter('MeterRAMHistory')
    if history then
        local inset = SKIN:ParseFormula(SKIN:ReplaceVariables('#Inset#'))
        local barExtra = math.max(0, (tonumber(SKIN:GetVariable('DataBarThickness')) or 6)-6)
        SKIN:Bang('!MoveMeter', tostring(history:GetX(true)),
            tostring(inset+(height+236+2*barExtra)*scale), 'MeterRAMHistory')
    end
    SKIN:Bang('!Redraw')
end

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\InfoModel.lua')
    data, settled, deadline = nil, false, os.time()+15
    layoutPasses, lastHeight = 0, nil
end

function Display()
    if not settled then return end
    local result = model.Format(data, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    SKIN:Bang('!SetOption', 'MeterRAMInfoSummary', 'Text', result.Summary.text)
    SKIN:Bang('!SetOption', 'MeterRAMInfoSummary', 'ToolTipText', result.Summary.tip)
    SKIN:Bang('!UpdateMeter', 'MeterRAMInfoSummary')
    layout()
    -- Font metrics can settle after the first draw. Recheck the cached view
    -- briefly, then disable it again; this never reruns the provider.
    layoutPasses = 2
    SKIN:Bang('!EnableMeasure', 'MeasureRAMInfoView')
    SKIN:Bang('!Redraw')
end

function Complete()
    if settled then return end
    local measure = SKIN:GetMeasure('MeasureRAMInfo')
    data = measure and measure:GetValue() == 1 and model.Parse(measure:GetStringValue()) or nil
    settled = true
    Display()
end

function Update()
    if settled then
        if layoutPasses > 0 then layout(); layoutPasses = layoutPasses-1 end
        if layoutPasses == 0 then SKIN:Bang('!DisableMeasure', 'MeasureRAMInfoView') end
        return 0
    end
    local measure = SKIN:GetMeasure('MeasureRAMInfo')
    local status = measure and measure:GetValue() or -1
    if status == 1 or status >= 100 or os.time() >= deadline then Complete() end
    return 0
end
