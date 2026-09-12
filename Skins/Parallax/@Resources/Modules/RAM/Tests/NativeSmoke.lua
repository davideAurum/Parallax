-- Test-only: runs in a copied RAM skin owned by the isolated smoke instance.
-- API reference: https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html
local ticks, completed, checks = 0, false, 0

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function number(expression)
    return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(expression) .. ')')
end

local function meter(name)
    local value = SKIN:GetMeter(name)
    check(value ~= nil, 'Missing native meter: ' .. name)
    return value
end

local function equalOption(item, key, expected)
    check(item:GetOption(key) == expected, item:GetName() .. ' incorrect ' .. key)
end

local infoModel
local function checkHardware()
    local mode = SELF:GetOption('InfoMode')
    local provider = SKIN:GetMeasure('MeasureRAMInfo')
    local raw = mode == 'Fixture' and SELF:GetOption('InfoFixture', '', false) or provider:GetStringValue()
    local data = mode ~= 'Timeout' and provider:GetValue() == 1 and infoModel.Parse(raw) or nil
    local fields = infoModel.Format(data, SKIN:GetVariable('RAMUseMiB'), SKIN:GetVariable('RAMDecimals'))
    for _, key in ipairs({'Installed','Type','Speed','Devices','Form'}) do
        local item = meter('MeterRAMInfo'..key)
        equalOption(item, 'Text', fields[key].text)
        equalOption(item, 'ClipString', '1')
        equalOption(item, 'Group', 'RAMHardwareInfo')
        check(item:GetOption('Text') ~= 'Checking...', key..' did not settle')
        check(#item:GetOption('ToolTipText') > 20, key..' has no metadata explanation')
    end
    return string.format('%s:%s [%s; %s; %s; %s; %s]', mode:lower(), data and 'reported' or 'unavailable',
        fields.Installed.text, fields.Type.text, fields.Speed.text, fields.Devices.text, fields.Form.text)
end

local function run()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local columns = tonumber(SKIN:GetVariable('Columns'))
    local width = tonumber(SKIN:GetVariable('ColumnWidth'))
    check(scale == SELF:GetNumberOption('ExpectedScale'), 'Scale override lost')
    check(columns == SELF:GetNumberOption('ExpectedColumns'), 'Column override lost')
    check(width == SELF:GetNumberOption('ExpectedWidth'), 'Width override lost')
    local round = function(value) return math.floor(value + 0.5) end
    local gap = 2 * round(tonumber(SKIN:GetVariable('Gutter')) * scale / 2)
    local expectedW = columns * (round(width * scale) + gap)
    local expectedH = math.max(round(tonumber(SKIN:GetVariable('PanelHeight')) * scale),
        round((262 + tonumber(SKIN:GetVariable('GraphHeight'))) * scale)) + gap
    local inset = gap / 2
    check(SKIN:GetW() == expectedW, 'Native skin width ' .. SKIN:GetW() .. ' expected ' .. expectedW)
    check(SKIN:GetH() == expectedH, 'Native skin height ' .. SKIN:GetH() .. ' expected ' .. expectedH)
    local bounds = meter('MeterRAMBounds')
    check(bounds:GetW() == expectedW and bounds:GetH() == expectedH, 'Bounds meter does not preserve window')
    local visible = 0
    for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
        local item = meter(name)
        local x, y, w, h = item:GetX(true), item:GetY(true), item:GetW(), item:GetH()
        local hidden = number(item:GetOption('Hidden', '0')) ~= 0
        if not hidden then
            visible = visible + 1
            -- Lua GetX(true) resolves relative placement but keeps String anchors.
            local align = item:GetOption('StringAlign'):lower()
            if align:match('^right') then x = x - w end
            if align:match('^center') then x = x - w / 2 end
            if align:match('center$') then y = y - h / 2 end
            if align:match('bottom$') then y = y - h end
            check(w >= 0 and h >= 0, name .. ' negative native size')
            check(x >= -0.01 and y >= -0.01 and x + w <= expectedW + 0.01 and y + h <= expectedH + 0.01,
                string.format('%s exceeds window: %.2f,%.2f %.2fx%.2f', name, x, y, w, h))
            if name ~= 'MeterRAMBounds' then
                check(x >= inset - 0.01 and y >= inset - 0.01 and x + w <= expectedW - inset + 0.01 and y + h <= expectedH - inset + 0.01,
                    string.format('%s enters gutter: %.2f,%.2f %.2fx%.2f', name, x, y, w, h))
            end
        end
    end
    local used = assert(SKIN:GetMeasure('MeasureRAMUsed'))
    local available = assert(SKIN:GetMeasure('MeasureRAMAvailable'))
    local total = assert(SKIN:GetMeasure('MeasureRAMTotal'))
    for _, measure in ipairs({used, available, total}) do
        equalOption(measure, 'Measure', 'PhysicalMemory')
        check(measure:GetNumberOption('UpdateDivider') == 1, measure:GetName() .. ' changed cadence')
        check(measure:GetValue() >= 0 and measure:GetValue() <= total:GetValue(), measure:GetName() .. ' outside physical memory range')
    end
    check(total:GetValue() > 0, 'No native physical memory total')
    check(used:GetMaxValue() == total:GetValue(), 'Used range lost native total')
    check(used:GetMinValue() == 0, 'Used native range minimum changed')
    check(math.abs(used:GetRelativeValue() - used:GetValue() / total:GetValue()) < 0.000001, 'Native relative value is not used/total')
    equalOption(available, 'InvertMeasure', '1')
    equalOption(total, 'Total', '1')
    local percent = meter('MeterRAMPercent')
    equalOption(percent, 'MeasureName', 'MeasureRAMUsed')
    equalOption(percent, 'Percentual', '1')
    equalOption(percent, 'AutoScale', '0')
    equalOption(meter('MeterRAMBar'), 'MeasureName', 'MeasureRAMUsed')
    local history = meter('MeterRAMHistory')
    equalOption(history, 'MeasureName', 'MeasureRAMUsed')
    equalOption(history, 'AutoScale', '0')
    equalOption(history, 'GraphStart', 'Right')
    check(tonumber(history:GetOption('Scale')) == 1, 'History byte scale changed')
    local useMiB = tonumber(SKIN:GetVariable('RAMUseMiB'))
    for _, kind in ipairs({'Used', 'Available', 'Total'}) do
        for _, unit in ipairs({'GiB', 'MiB'}) do
            local item = meter('MeterRAM' .. kind .. unit)
            equalOption(item, 'MeasureName', 'MeasureRAM' .. kind)
            equalOption(item, 'AutoScale', '0')
            equalOption(item, 'Text', '%1 ' .. unit)
            check(tonumber(item:GetOption('Scale')) == (unit == 'GiB' and 1073741824 or 1048576), 'Byte divisor and suffix mismatch')
            local expectedHidden = (unit == 'GiB') and useMiB or (1 - useMiB)
            check(number(item:GetOption('Hidden')) == expectedHidden, 'Wrong unit meter visible')
            equalOption(item, 'ClipString', '1')
        end
    end
    equalOption(meter('MeterRAMTitle'), 'ClipString', '1')
    equalOption(meter('MeterRAMTitle'), 'FontColor', SKIN:GetVariable('TitleTextColor'))
    check(number(meter('MeterRAMTitle'):GetOption('FontSize')) == tonumber(SKIN:GetVariable('TitleFontSize'))*scale, 'Title font role lost')
    for _, name in ipairs({'MeterRAMInfoHeading', 'MeterRAMSubtitle', 'MeterRAMHistoryLabel'}) do
        equalOption(meter(name), 'FontColor', SKIN:GetVariable('HeaderTextColor'))
        check(number(meter(name):GetOption('FontSize')) == tonumber(SKIN:GetVariable('HeaderFontSize'))*scale, 'Header font role lost: '..name)
    end
    for _, name in ipairs({'MeterRAMUsedGiB', 'MeterRAMAvailableGiB', 'MeterRAMTotalGiB', 'MeterRAMInfoInstalled'}) do
        equalOption(meter(name), 'FontColor', SKIN:GetVariable('TextColor'))
        check(number(meter(name):GetOption('FontSize')) == tonumber(SKIN:GetVariable('FontSize'))*scale, 'Body font role lost: '..name)
    end
    local visibleBody = tonumber(SKIN:GetVariable('RAMUseMiB')) == 1 and 'MeterRAMUsedMiB' or 'MeterRAMUsedGiB'
    for _, pair in ipairs({{'Title','MeterRAMTitle'}, {'Header','MeterRAMSubtitle'}, {'Body',visibleBody}}) do
        local natural = meter('MeterRAMProbe'..pair[1]):GetH()
        local allocated = meter(pair[2]):GetH()
        check(natural > 0 and natural <= allocated, pair[1]..' natural font height '..natural..' exceeds allocated '..allocated)
    end
    check(#meter('MeterRAMTitle'):GetOption('Text') > 40, 'Long-title test override lost')
    local samples = assert(SKIN:GetMeasure('MeasureRAMHistorySamples')):GetValue()
    check(samples >= 1 and samples <= number('#ContentWidth#'), 'History sample count outside plot')
    local hardware = checkHardware()
    return string.format('PASS: width=%d columns=%d scale=%g window=%dx%d unit=%s; %d checks, %d visible meters; hover/leave restored; hardware=%s; native Lua %s',
        width, columns, scale, expectedW, expectedH, useMiB == 1 and 'MiB' or 'GiB', checks, visible, hardware, _VERSION)
end

local function checkHoverState(hovered)
    local options = meter('MeterRAMOptions')
    equalOption(options, 'Hidden', hovered and '0' or '1')
    equalOption(meter('MeterRAMPercent'), 'Hidden', hovered and '1' or '0')
    if hovered then
        equalOption(options, 'Meter', 'Shape')
        equalOption(options, 'MouseActionCursor', '1')
        local x, y, w, h = options:GetX(true), options:GetY(true), options:GetW(), options:GetH()
        local inset = number('#Inset#')
        check(w > 0 and h > 0, 'Shown gear has no native area')
        check(x >= inset and y >= inset and x + w <= SKIN:GetW() - inset and y + h <= SKIN:GetH() - inset,
            string.format('Shown gear enters gutter: %.2f,%.2f %.2fx%.2f', x, y, w, h))
    end
end

local beforeUnits, lastSamples
local utilityOpenings, utilityChecks, utilityFailed = 0, 0, false
function UtilityOpened(count)
    utilityOpenings = utilityOpenings + 1
    utilityChecks = utilityChecks + tonumber(count)
end
function UtilityVerified(count)
    utilityChecks = utilityChecks + tonumber(count)
end
function UtilityFailed() utilityFailed = true end

local function settings(command)
    SKIN:Bang('!CommandMeasure', 'MeasureRAMSettingsSmoke', command, SELF:GetOption('SettingsConfig'))
end

local function openSettings()
    local action = meter('MeterRAMOptions'):GetOption('LeftMouseUpAction', '', false)
    local expected = '[!ActivateConfig "' .. SELF:GetOption('SettingsConfig') .. '" "Settings.ini"]'
    check(action == expected, 'Gear does not open the copied dedicated settings utility')
    SKIN:Bang(action)
end

local function saved(key, expected)
    check(tonumber(SKIN:GetVariable(key)) == expected, key .. ' did not apply immediately')
    local path = SKIN:GetVariable('@') .. 'User\\RAM.inc'
    local file = assert(io.open(path, 'rb'))
    local text = assert(file:read('*a')); file:close()
    local persisted = ('\n' .. text):match('\n' .. key .. '=([^\r\n]+)')
    check(tonumber(persisted) == expected, key .. ' not persisted in the copied user file')
    check(tonumber(('\n'..text):match('\nColumns=([^\r\n]+)')) == SELF:GetNumberOption('ExpectedColumns'),
        'Utility overwrote the live meter column preference')
    check(tonumber(('\n'..text):match('\nPanelHeight=([^\r\n]+)')) == tonumber(SKIN:GetVariable('PanelHeight')),
        'Utility overwrote the live meter height preference')
    check(text:find('RAMTitle=RAM physical memory with a deliberately long clipped title', 1, true) ~= nil,
        'Saving utility preferences damaged unrelated settings')
end

local function step()
    local samples = SKIN:GetMeasure('MeasureRAMHistorySamples'):GetValue()
    check(not utilityFailed, 'Dedicated settings test failed; inspect its utility-failure.txt report')
    if lastSamples then check(samples == lastSamples + 1, 'Utility action reset or advanced history sample count') end
    lastSamples = samples
    -- Execute actual production actions. Their bangs run after Lua returns.
    if ticks == 3 then
        dofile(SELF:GetOption('ModelTestsPath'))(infoModel, check)
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        if SELF:GetOption('InfoMode') == 'Timeout' then equalOption(meter('MeterRAMInfoInstalled'),'Text','Checking...') end
        beforeUnits = tonumber(SKIN:GetVariable('RAMUseMiB'))
        check(utilityOpenings == 0, 'Settings utility unexpectedly active before clicking the gear')
        check(SKIN:GetMeter('MeterRAMSettingsTitle') == nil, 'Settings still overlays the live RAM skin')
        checkHoverState(false)
        SKIN:Bang(SELF:GetOption('HoverAction', '', false))
    elseif ticks == 4 then
        checkHoverState(true)
        openSettings()
    elseif ticks == 5 then
        check(utilityOpenings == 1, 'Gear failed to activate a separate settings config')
        settings("Verify('Units','RAMUseMiB',"..beforeUnits..",'"..(beforeUnits == 1 and 'MiB' or 'GiB').."')")
        SKIN:Bang(SELF:GetOption('LeaveAction', '', false))
        settings("Click('Units','RAMUseMiB')")
    elseif ticks == 6 then
        saved('RAMUseMiB', 1-beforeUnits)
        checkHoverState(false)
        settings("Verify('Units','RAMUseMiB',"..(1-beforeUnits)..",'"..(beforeUnits == 1 and 'GiB' or 'MiB').."')")
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        settings("Click('Decimals','RAMDecimals')")
    elseif ticks == 7 then
        saved('RAMDecimals', 0)
        settings("Verify('Decimals','RAMDecimals',0,'0')")
        equalOption(meter('MeterRAMUsedGiB'), 'NumOfDecimals', '0')
        if SELF:GetOption('InfoMode') == 'Fixture' then checkHardware() end
        settings("Click('PercentDecimals','RAMPercentDecimals')")
    elseif ticks == 8 then
        saved('RAMPercentDecimals', 0)
        settings("Verify('PercentDecimals','RAMPercentDecimals',0,'0')")
        equalOption(meter('MeterRAMPercent'), 'NumOfDecimals', '0')
        settings("Click('Bar','RAMShowBar')")
    elseif ticks == 9 then
        saved('RAMShowBar', 0)
        settings("Verify('Bar','RAMShowBar',0,'Off')")
        equalOption(meter('MeterRAMBar'), 'Hidden', '1')
        settings("Click('History','RAMShowHistory')")
    elseif ticks == 10 then
        saved('RAMShowHistory', 0)
        settings("Verify('History','RAMShowHistory',0,'Off')")
        for _,suffix in ipairs({'', 'Label', 'Range', 'Uncollected', 'Frame'}) do
            equalOption(meter('MeterRAMHistory'..suffix), 'Hidden', '1')
        end
        settings("Click('History','RAMShowHistory')")
    elseif ticks == 11 then
        saved('RAMShowHistory', 1)
        settings("Verify('History','RAMShowHistory',1,'On')")
        equalOption(meter('MeterRAMHistory'), 'Hidden', '0')
        settings("Click('Bar','RAMShowBar')")
    elseif ticks == 12 then
        saved('RAMShowBar', 1)
        settings("Verify('Bar','RAMShowBar',1,'On')")
        settings('Close()')
    elseif ticks == 13 then
        checkHoverState(false)
        SKIN:Bang(SELF:GetOption('HoverAction', '', false))
        openSettings()
    elseif ticks == 14 then
        check(utilityOpenings == 2, 'Settings did not close independently and initialize again on reopen')
        settings("Verify('Units','RAMUseMiB',"..(1-beforeUnits)..",'"..(beforeUnits == 1 and 'GiB' or 'MiB').."')")
        settings("Verify('Decimals','RAMDecimals',0,'0')")
        settings("Verify('PercentDecimals','RAMPercentDecimals',0,'0')")
        settings("Verify('Bar','RAMShowBar',1,'On')")
        settings("Verify('History','RAMShowHistory',1,'On')")
        settings('Close()')
    elseif ticks == 15 then
        checkHoverState(true)
        SKIN:Bang(SELF:GetOption('LeaveAction', '', false))
    elseif ticks == 16 then
        checkHoverState(false)
    elseif ticks == 20 then
        check(utilityChecks > 100, 'Dedicated settings geometry or preference checks did not complete')
        return run() .. string.format('; separate utility opened/closed twice, reopened preferences persisted, %d utility checks', utilityChecks)
    end
end

function Initialize()
    infoModel = dofile(SKIN:GetVariable('@')..'Modules\\RAM\\InfoModel.lua')
end
function Update()
    if completed then return 0 end
    ticks = ticks + 1
    -- At least two completed meter updates precede the assertions; no test-only
    -- !UpdateMeter calls can append graph samples or alter production cadence.
    if ticks < 3 then return 0 end
    local ok, result = pcall(step)
    if ok and result == nil then return 0 end
    completed = true
    local output = assert(io.open(SELF:GetOption('ResultPath'), 'wb'))
    assert(output:write((ok and result or ('FAIL: ' .. tostring(result))) .. '\n'))
    assert(output:close())
    return ok and 1 or -1
end
