-- Independent RAM settings utility. No telemetry or periodic work.
local values, userFile
local choices = {
    RAMUseMiB = {default=0, count=2, meter='MeterRAMSettingsUnits'},
    RAMDecimals = {default=1, count=3, meter='MeterRAMSettingsDecimals'},
    RAMPercentDecimals = {default=0, count=3, meter='MeterRAMSettingsPercentDecimals'},
    RAMShowBar = {default=1, count=2, meter='MeterRAMSettingsBar'},
    RAMShowHistory = {default=1, count=2, meter='MeterRAMSettingsHistory'}
}

local function render()
    for key, spec in pairs(choices) do
        local label = tostring(values[key])
        if key == 'RAMUseMiB' then label = values[key] == 1 and 'MiB' or 'GiB'
        elseif key == 'RAMShowBar' or key == 'RAMShowHistory' then label = values[key] == 1 and 'On' or 'Off' end
        SKIN:Bang('!SetOption', spec.meter, 'Text', label)
    end
    SKIN:Bang('!UpdateMeterGroup', 'RAMSettingsUI')
    SKIN:Bang('!Redraw')
end

function Initialize()
    values = {}
    userFile = SKIN:GetVariable('@') .. 'User\\RAM.inc'
    for key, spec in pairs(choices) do
        local value = tonumber(SKIN:GetVariable(key))
        if not value or value ~= value or value == math.huge or value == -math.huge then value=spec.default end
        values[key] = math.max(0, math.min(spec.count-1, math.floor(value)))
    end
end

function Update()
    render()
    return 0
end

function Cycle(key)
    local spec = choices[key]
    if not spec then return end
    local value = (values[key]+1) % spec.count
    values[key] = value
    SKIN:Bang('!SetVariable', key, tostring(value))
    SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), userFile)
    -- Apply only to loaded RAM meters. If RAM is unloaded, its next load reads
    -- the saved value. The settings utility never starts/stops the RAM meter.
    SKIN:Bang('!SetVariableGroup', key, tostring(value), 'ParallaxRAM')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxRAMApply', '*')
    render()
end
