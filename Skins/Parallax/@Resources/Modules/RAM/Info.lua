-- Cached, refresh-only hardware inventory. Updating this view never runs WMI.
local model, data, settled, deadline

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\InfoModel.lua')
    data, settled, deadline = nil, false, os.time()+15
end

function Display()
    if not settled then return end
    local fields = model.Format(data, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    for key, value in pairs(fields) do
        SKIN:Bang('!SetOption', 'MeterRAMInfo'..key, 'Text', value.text)
        SKIN:Bang('!SetOption', 'MeterRAMInfo'..key, 'ToolTipText', value.tip)
    end
    -- Do not append native graph samples outside the usual update cadence.
    SKIN:Bang('!UpdateMeterGroup', 'RAMHardwareInfo')
    SKIN:Bang('!Redraw')
end

function Complete()
    if settled then return end
    local measure = SKIN:GetMeasure('MeasureRAMInfo')
    data = measure and measure:GetValue() == 1 and model.Parse(measure:GetStringValue()) or nil
    settled = true
    Display()
    SKIN:Bang('!DisableMeasure', 'MeasureRAMInfoView')
end

function Update()
    if settled then return 0 end
    local measure = SKIN:GetMeasure('MeasureRAMInfo')
    local status = measure and measure:GetValue() or -1
    if status == 1 or status >= 100 or os.time() >= deadline then Complete() end
    return 0
end
