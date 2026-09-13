-- Test-only replacement for the copied PageFile view. No provider or file IO.
-- Parse a fixed wire once, then exercise the production model's cached format.
local model, frame, parses, displayed

function Initialize()
    model = dofile(SKIN:GetVariable('@')..'Modules\\RAM\\PageFileModel.lua')
    frame = model.Parse(SELF:GetOption('FixtureWire', '', false),
        SELF:GetOption('FixtureToken'), SELF:GetNumberOption('FixtureNow'), 1000)
    parses = 1
    displayed = false
end

function Display()
    displayed = true
    local decimals = SKIN:GetVariable('RAMDecimals')
    local ratio = frame and frame.status == 'OK' and frame.total > 0 and frame.used/frame.total or nil
    SKIN:Bang('!SetOption','MeasureRAMPageRatio','Formula',string.format('%.15f',ratio or 0))
    SKIN:Bang('!UpdateMeasure','MeasureRAMPageRatio')
    SKIN:Bang('!SetOption','MeterRAMPageBar','Hidden',ratio ~= nil and tonumber(SKIN:GetVariable('RAMShowPageBar')) == 1 and '0' or '1')
    SKIN:Bang('!UpdateMeter','MeterRAMPageBar')
    for _, pair in ipairs({{'GiB',0}, {'MiB',1}}) do
        local value = model.Format(frame, pair[2], decimals)
        local name = 'MeterRAMPage'..pair[1]
        SKIN:Bang('!SetOption', name, 'Text', value.text)
        SKIN:Bang('!SetOption', name, 'ToolTipText', value.tip)
        SKIN:Bang('!UpdateMeter', name)
    end
    SKIN:Bang('!SetOption', 'MeterRAMPageLabel', 'ToolTipText', model.Format(frame,0,decimals).tip)
    SKIN:Bang('!UpdateMeter', 'MeterRAMPageLabel')
end

function Update() if not displayed then Display() end; return parses end
function Start() error('Fixture must not launch the PAGE provider') end
function Stop() end
