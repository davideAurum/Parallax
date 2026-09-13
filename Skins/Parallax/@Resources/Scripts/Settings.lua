-- Event-driven settings; writes happen only on an explicit click.
local settingsPath
local themeMenuOpen = false
local editingKey
local ranges = {
    Scale = { low=0.75, high=2, meter='MeterScaleInput' },
    ColumnWidth = { low=180, high=320, integer=true, meter='MeterWidthInput' },
    Gutter = { low=0, high=16, integer=true, meter='MeterGapInput' },
    CornerRadius = { low=0, high=24, integer=true, meter='MeterRoundingInput' },
    TitleFontSize = { low=6, high=12, decimals=2, meter='MeterTitleSizeInput' },
    HeaderFontSize = { low=6, high=10, decimals=2, meter='MeterHeaderSizeInput' },
    FontSize = { low=6, high=10, decimals=2, meter='MeterBodySizeInput' },
    BackgroundTransparency = { low=0, high=100, decimals=2, meter='MeterBackgroundTransparencyInput' },
    BorderThickness = { low=0, high=4, decimals=2, meter='MeterBorderSizeInput' },
    DividerThickness = { low=0, high=4, decimals=2, meter='MeterDividerSizeInput' },
    TableHeaderBorderThickness = { low=0, high=4, decimals=2, meter='MeterTableHeaderBorderSizeInput' },
    DataBarThickness = { low=1, high=12, decimals=2, meter='MeterDataBarSizeInput' }
}
local steps = { Scale=0.01, ColumnWidth=1, Gutter=1, CornerRadius=1,
    TitleFontSize=0.25, HeaderFontSize=0.25, FontSize=0.25,
    BackgroundTransparency=1, BorderThickness=0.25, DividerThickness=0.25,
    TableHeaderBorderThickness=0.25, DataBarThickness=0.25 }
local colorTargets = {
    AccentColor='MeterAccentValue', AccentColor2='MeterAccent2Value',
    TitleTextColor='MeterTitleColorValue', HeaderTextColor='MeterHeaderColorValue', TextColor='MeterBodyColorValue',
    BackgroundColor='MeterBackgroundColorValue', BorderColor='MeterBorderColorValue', DividerColor='MeterDividerColorValue',
    TableHeaderBorderColor='MeterTableHeaderBorderColorValue'
}
local themes = {
    default = {
        Theme='default', FontFace='IBM Plex Sans', FontSize='9', TitleFontSize='10', HeaderFontSize='8', PanelPadding='6', CornerRadius='3',
        BackgroundColor='15,15,15,255', BorderColor='50,50,50,255', BorderThickness='1', DividerColor='50,50,50,255', DividerThickness='1', TrackColor='50,50,50,255',
        TableHeaderBorderColor='50,50,50,255', TableHeaderBorderThickness='1', DataBarThickness='6',
        GraphBackgroundColor='25,25,25,255', GridColor='50,50,50,180', GraphHeight='48',
        TextColor='220,220,220', TitleTextColor='220,220,220', HeaderTextColor='175,175,175', MutedColor='175,175,175', AccentColor='137,190,250', AccentColor2='181,161,226',
        GoodColor='100,230,90', WarningColor='240,225,40', DangerColor='235,55,75',
        CPUColor='235,55,75', RAMColor='105,205,255', GPUColor='120,205,45',
        DiskReadColor='100,230,90', DiskWriteColor='240,225,40',
        NetworkInColor='240,225,40', NetworkOutColor='100,230,90',
        MediaColor='137,190,250', ClockColor='137,190,250'
    }
}
local accents = { cyan='137,190,250', amber='224,178,101', lilac='181,161,226', green='125,195,160' }
local profiles = {
    balanced = { MetricsInterval='1000', SensorInterval='2000', CapacityInterval='30000', VisualizerInterval='50' },
    economy = { MetricsInterval='2000', SensorInterval='4000', CapacityInterval='60000', VisualizerInterval='100' }
}

local function currentProfile()
    for name, values in pairs(profiles) do
        local matches = true
        for key, value in pairs(values) do
            if tonumber(SKIN:GetVariable(key)) ~= tonumber(value) then matches = false; break end
        end
        if matches then return name end
    end
    return nil
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Settings.inc'
    themeMenuOpen = false
    editingKey = nil
end

local function showThemeMenu(open)
    if themeMenuOpen == open then return end
    themeMenuOpen = open
    SKIN:Bang(open and '!ShowMeterGroup' or '!HideMeterGroup', 'ThemeMenu')
    SKIN:Bang('!UpdateMeterGroup', 'ThemeMenu')
    SKIN:Bang('!Redraw')
end

function ToggleThemeMenu() showThemeMenu(not themeMenuOpen) end
function CloseThemeMenu() showThemeMenu(false) end

local function number(name, fallback)
    return tonumber(SKIN:GetVariable(name)) or fallback
end

local function colorChannels(value)
    value = tostring(value or ''):match('^%s*(.-)%s*$')
    local literal = value:gsub('^#','')
    local channels = {}
    if (#literal == 6 or #literal == 8) and literal:match('^%x+$') then
        for pair in literal:gmatch('%x%x') do channels[#channels+1] = tonumber(pair,16) end
        return channels
    end
    if not value:match('^%d+%s*,%s*%d+%s*,%s*%d+$') and not value:match('^%d+%s*,%s*%d+%s*,%s*%d+%s*,%s*%d+$') then return nil end
    for channel in value:gmatch('%d+') do
        local n = tonumber(channel)
        if n > 255 then return nil end
        channels[#channels+1] = n
    end
    if #channels ~= 3 and #channels ~= 4 then return nil end
    return channels
end

local function accentHex(value)
    local channels = colorChannels(value)
    if not channels then return 'Unavailable' end
    for i, value in ipairs(channels) do channels[i] = string.format('%02X',value) end
    return '#'..table.concat(channels)
end

local function transparency()
    local channels = colorChannels(SKIN:GetVariable('BackgroundColor'))
    return channels and tonumber(string.format('%.2f',100 * (1 - (channels[4] or 255)/255))) or nil
end

function Update()
    local scale = number('Scale', 1)
    local single = math.floor(number('ColumnWidth', 220) * scale + 0.5)
    local gap = 2 * math.floor(number('Gutter', 8) * scale / 2 + 0.5)
    SKIN:Bang('!SetOption', 'MeterGeometry', 'Text', string.format('Panels: %d / %d px   Gap: %d px   Scale: %g%%', single, single * 2 + gap, gap, scale * 100))
    SKIN:Bang('!SetOption', 'MeterCadence', 'Text', string.format('Metrics %gs  Sensors %gs  Disk %gs  Spectrum ~%g FPS', number('MetricsInterval',1000)/1000, number('SensorInterval',2000)/1000, number('CapacityInterval',30000)/1000, math.floor(1000/math.max(1,number('VisualizerInterval',50)) + 0.5)))
    local profile = currentProfile()
    SKIN:Bang('!SetOption', 'MeterRefreshValue', 'Text', profile == 'balanced' and 'Balanced' or profile == 'economy' and 'Economy' or 'Custom')
    SKIN:Bang('!SetOption', 'MeterScaleInput', 'Text', string.format('%g%%', scale * 100))
    SKIN:Bang('!SetOption', 'MeterWidthInput', 'Text', string.format('%g px', number('ColumnWidth',220)))
    SKIN:Bang('!SetOption', 'MeterGapInput', 'Text', string.format('%g px', number('Gutter',8)))
    SKIN:Bang('!SetOption', 'MeterRoundingInput', 'Text', string.format('%g px', number('CornerRadius',3)))
    for key, meter in pairs(colorTargets) do
        SKIN:Bang('!SetOption', meter, 'Text', accentHex(SKIN:GetVariable(key)))
    end
    for key, fallback in pairs({TitleFontSize=10, HeaderFontSize=8, FontSize=9}) do
        SKIN:Bang('!SetOption', ranges[key].meter, 'Text', string.format('%g pt', number(key,fallback)))
    end
    SKIN:Bang('!SetOption', 'MeterBackgroundTransparencyInput', 'Text', transparency() and string.format('%g%%',transparency()) or 'Unavailable')
    for key, fallback in pairs({BorderThickness=1, DividerThickness=1, TableHeaderBorderThickness=1, DataBarThickness=6}) do
        SKIN:Bang('!SetOption', ranges[key].meter, 'Text', string.format('%g px', number(key,fallback)))
    end
    return 0
end

local function save(values)
    if not values or not settingsPath then return false end
    -- Values are static theme/profile values or strictly validated numeric data.
    for key, value in pairs(values) do
        SKIN:Bang('!WriteKeyValue', 'Variables', key, value, settingsPath)
    end
    SKIN:Bang('!RefreshGroup', 'Parallax')
    return true
end

function Set(key, value)
    value = tostring(value)
    local range, numeric = ranges[key], tonumber(value)
    if not range or not value:match('^%d+%.?%d*$') or not numeric or numeric ~= numeric then return false end
    local fraction = value:match('%.(%d*)$')
    if range.decimals and fraction and #fraction > range.decimals then return false end
    if numeric < range.low or numeric > range.high or (range.integer and numeric % 1 ~= 0) then return false end
    if key == 'BackgroundTransparency' then
        local channels = colorChannels(SKIN:GetVariable('BackgroundColor'))
        if not channels then return false end
        local alpha = math.floor(255 * (1 - numeric/100) + 0.5)
        return save({BackgroundColor=string.format('%d,%d,%d,%d',channels[1],channels[2],channels[3],alpha)})
    end
    return save({ [key] = string.format('%.4f', numeric):gsub('0+$',''):gsub('%.$','') })
end

function Adjust(key, direction)
    local range = ranges[key]
    if editingKey or not range or (direction ~= -1 and direction ~= 1) then return false end
    local raw = key == 'BackgroundTransparency' and transparency() or SKIN:GetVariable(key)
    if raw == nil then return false end
    local literal = tostring(raw)
    if not literal:match('^%d+%.?%d*$') then return false end
    local value = tonumber(literal)
    if not value or value ~= value or value < range.low or value > range.high
        or (range.integer and value % 1 ~= 0) then return false end
    local fraction = literal:match('%.(%d*)$')
    if range.decimals and fraction and #fraction > range.decimals then return false end
    local nextValue = math.max(range.low, math.min(range.high, value + direction * steps[key]))
    if nextValue == value then return false end
    CloseThemeMenu()
    return Set(key, string.format(key == 'Scale' and '%.4f' or '%.2f', nextValue):gsub('0+$',''):gsub('%.$',''))
end

function CycleTheme(direction)
    -- Default is currently the only choice; disabled arrows never reapply it.
    if editingKey or (direction ~= -1 and direction ~= 1) then return false end
    return false
end

local function inputStatus(message, error)
    SKIN:Bang('!SetOption', 'MeterInputStatus', 'Text', message)
    SKIN:Bang('!SetOption', 'MeterInputStatus', 'FontColor', SKIN:GetVariable(error and 'DangerColor' or 'MutedColor'))
    SKIN:Bang('!UpdateMeter', 'MeterInputStatus')
    SKIN:Bang('!Redraw')
end

function BeginEdit(key)
    if editingKey or not ranges[key] then return false end
    local range = ranges[key]
    local meter = SKIN:GetMeter(range.meter:gsub('Input$', 'Frame')) or SKIN:GetMeter(range.meter)
    if not meter then return false end
    local value
    if key == 'BackgroundTransparency' then value = transparency() else value = number(key, range.low) end
    if not value then return false end
    value = math.max(range.low, math.min(range.high, value))
    if key == 'Scale' then value = value * 100 end
    if range.integer then value = math.floor(value) end
    local initial = string.format('%.2f', value):gsub('0+$',''):gsub('%.$','')
    CloseThemeMenu()
    editingKey = key
    inputStatus('Enter to apply. Esc to cancel.', false)
    -- Only fixed names, a quoted installed path and canonical numbers enter this command.
    -- User input returns through RunCommand stdout as data, never as a Rainmeter action.
    local args = string.format('-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sScripts\\SettingsInput.ps1" -Key %s -Initial "%s" -X %d -Y %d -Width %d -Height %d -Scale %.4f',
        SKIN:GetVariable('@'), key, initial, math.floor(SKIN:GetX()+meter:GetX()), math.floor(SKIN:GetY()+meter:GetY()),
        math.max(40, math.floor(meter:GetW())), math.max(20, math.floor(meter:GetH())), number('Scale',1))
    SKIN:Bang('!SetOption', 'MeasureSettingsInput', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureSettingsInput')
    SKIN:Bang('!CommandMeasure', 'MeasureSettingsInput', 'Run')
    return true
end

function CommitInput()
    if not editingKey then return false end
    local key = editingKey
    editingKey = nil
    local measure = SKIN:GetMeasure('MeasureSettingsInput')
    local output = measure and measure:GetStringValue() or ''
    output = output:gsub('[\r\n]+$', '')
    if output == 'PARALLAX_INPUT_V1|cancel|' then return false end
    local value = output:match('^PARALLAX_INPUT_V1|ok|(%d+%.?%d*)$')
    if value then
        if key == 'Scale' then value = string.format('%.4f', tonumber(value)/100) end
        if Set(key, value) then return true end
    end
    inputStatus('Value was not applied. Click the field to try again.', true)
    return false
end

function Theme(name) return save(themes[name]) end
function OpenColor(key)
    if editingKey or not colorTargets[key] then return false end
    CloseThemeMenu()
    SKIN:Bang('!ActivateConfig', 'Parallax\\ColorPicker', 'ColorPicker.ini')
    SKIN:Bang('!CommandMeasure', 'MeasureColorPicker', "OpenTarget('"..key.."')", 'Parallax\\ColorPicker')
    return true
end
function Accent(name)
    if not accents[name] then return false end
    return save({ AccentColor=accents[name] })
end
function Profile(name)
    if editingKey then return false end
    return save(profiles[name])
end
function CycleProfile(direction)
    if editingKey or (direction ~= -1 and direction ~= 1) then return false end
    local current = currentProfile()
    local nextProfile = current == 'balanced' and 'economy' or current == 'economy' and 'balanced'
        or (direction == -1 and 'economy' or 'balanced')
    CloseThemeMenu()
    return Profile(nextProfile)
end
