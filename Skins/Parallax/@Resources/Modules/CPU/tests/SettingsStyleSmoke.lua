-- Test-only isolated native settings controller/layout checks; no CPU/provider measures.
local tick, phase, assertions, done = 0, 0, 0, false
local function check(okay, label)
    assertions = assertions + 1
    assert(okay, label)
end
local function write(name, text)
    local file = assert(io.open(SELF:GetOption('ReportRoot') .. name, 'wb'))
    file:write(text); file:close()
end
local function action(name)
    local meter = assert(SKIN:GetMeter(name), name)
    local command = meter:GetOption('LeftMouseUpAction')
    check(command ~= '', name .. ' has action')
    SKIN:Bang(command)
end
local function variable(name)
    local value = SKIN:GetVariable(name)
    return tonumber(value) or SKIN:ParseFormula(value)
end
local function geometry(expectedHeight)
    check(variable('PanelHeight') == expectedHeight, 'logical panel height')
    local scale = variable('Scale')
    local expected = math.floor(expectedHeight * scale + 0.5) + variable('Gap')
    check(SKIN:GetH() == expected, 'physical settings height: ' .. SKIN:GetH() .. ' expected ' .. expected)
    local source = assert(io.open(SKIN:GetVariable('@') .. 'Modules\\CPU\\SettingsMeters.inc', 'rb'))
    local text = source:read('*a'); source:close()
    for name in text:gmatch('%[([%w]+)%]') do
        local meter = SKIN:GetMeter(name)
        if meter then
            local hidden = tonumber(meter:GetOption('Hidden','0')) == 1
            if hidden then
                check(meter:GetY() == 0 and meter:GetW() == 0 and meter:GetH() == 0, name .. ' hidden bounds')
            else
                check(meter:GetX() >= -1 and meter:GetX() + meter:GetW() <= SKIN:GetW()+1, name .. ' horizontal bounds')
                check(meter:GetY() >= 0 and meter:GetY() + meter:GetH() <= SKIN:GetH()+1, name .. ' vertical bounds')
            end
        end
    end
    for _, name in ipairs({'Appearance','Processes','Graph','Rates','Sensors'}) do
        local meter = SKIN:GetMeter('MeterSettings' .. name .. 'Section')
        check(meter:GetOption('FontColor') == SKIN:GetVariable('AccentColor'), name .. ' Accent 1')
    end
end
function Initialize()
    local marker = io.open(SELF:GetOption('ReportRoot') .. 'pre-refresh-count.txt','rb')
    if marker then assertions=tonumber(marker:read('*a')) or 0; marker:close(); phase=8; return end
    local okay, result = pcall(function()
        local suite = assert(loadfile(SELF:GetOption('SuitePath')))()
        return suite.Run(SELF:GetOption('ControllerPath'))
    end)
    write('controller.txt', tostring(result))
    if not okay then done=true; write('failed.txt', tostring(result)) end
end
function Update()
    if done then return 0 end
    tick = tick + 1
    if tick % 5 ~= 0 then return 0 end
    local okay, failure = pcall(function()
        if phase == 0 then
            geometry(1000)
            write('capture-ready.txt','expanded')
        elseif phase == 1 then
            -- Allow the runner to capture the expanded window before exercising collapse.
            local captured = io.open(SELF:GetOption('ReportRoot') .. 'capture-complete-expanded.txt','rb')
            if not captured then return end
            captured:close()
        elseif phase == 2 then
            for _, name in ipairs({'Info','Cores','Processes','History'}) do action('MeterSettings' .. name .. 'Value') end
        elseif phase == 3 then
            geometry(888)
            check(SKIN:GetMeter('MeterSettingsProcessCountValue'):GetOption('Text') == '5', 'collapsed value retained')
            for _, name in ipairs({'Info','Cores','Processes','History'}) do
                check(SKIN:GetMeter('MeterSettings' .. name .. 'Value'):GetH() > 0, 'reenable control ' .. name)
            end
            write('capture-ready.txt','collapsed')
        elseif phase == 4 then
            local captured = io.open(SELF:GetOption('ReportRoot') .. 'capture-complete-collapsed.txt','rb')
            if not captured then return end
            captured:close()
        elseif phase == 5 then
            for _, name in ipairs({'Info','Cores','Processes','History'}) do action('MeterSettings' .. name .. 'Value') end
        elseif phase == 6 then
            geometry(1000)
            action('MeterSettingsProcessCountIncrease')
            action('MeterSettingsSamplesDecrease')
            action('MeterSettingsDecimalsIncrease')
        elseif phase == 7 then
            check(SKIN:GetMeter('MeterSettingsProcessCountValue'):GetOption('Text') == '6', 'count arrow applied')
            check(SKIN:GetMeter('MeterSettingsSamplesValue'):GetOption('Text') == '50', 'history decrement applied')
            check(SKIN:GetMeter('MeterSettingsDecimalsValue'):GetOption('Text') == '1', 'decimal arrow applied')
            check(SKIN:GetMeter('MeterSettingsDecimalsIncrease'):GetOption('LeftMouseUpAction') == '', 'max arrow disabled')
            -- Refresh this isolated settings config; production OnRefreshAction was removed only in the fixture.
            write('pre-refresh-count.txt', tostring(assertions))
            SKIN:Bang('!Refresh')
        elseif phase == 8 then
            geometry(1000)
            check(SKIN:GetMeter('MeterSettingsProcessCountValue'):GetOption('Text') == '6', 'count persisted on reload')
            check(SKIN:GetMeter('MeterSettingsSamplesValue'):GetOption('Text') == '50', 'history persisted on reload')
            write('passed.txt', tostring(assertions) .. ' native assertions; provider/discovery launches suppressed in fixture.')
            action('MeterSettingsClose')
            done = true
        end
        phase = phase + 1
    end)
    if not okay then done=true; write('failed.txt', tostring(failure)) end
    return 0
end
