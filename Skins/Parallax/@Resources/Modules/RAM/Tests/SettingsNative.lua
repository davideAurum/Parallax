-- Test-only controller injected into a copied, initially inactive Settings config.
-- It uses actual utility meter actions; production Update=-1 remains unchanged.
local checks = 0
local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end
local function report(command)
    SKIN:Bang('!CommandMeasure', 'MeasureRAMNativeSmoke', command, SELF:GetOption('ParentConfig'))
end
local function safely(work, opened)
    local before = checks
    local ok, message = pcall(work)
    if ok then
        report((opened and 'UtilityOpened(' or 'UtilityVerified(') .. (checks-before) .. ')')
    else
        local output = assert(io.open(SELF:GetOption('FailurePath'), 'wb'))
        output:write(tostring(message)); output:close()
        report('UtilityFailed()')
    end
end
local function meter(name)
    local value = SKIN:GetMeter(name)
    check(value ~= nil, 'Missing settings meter: ' .. name)
    return value
end
local function number(expression)
    return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(expression) .. ')')
end

function Opened()
    safely(function()
        local scale = tonumber(SKIN:GetVariable('Scale'))
        local width = tonumber(SKIN:GetVariable('ColumnWidth'))
        check(scale == SELF:GetNumberOption('ExpectedScale'), 'Utility lost module scale')
        check(width == SELF:GetNumberOption('ExpectedWidth'), 'Utility lost module width')
        check(tonumber(SKIN:GetVariable('Columns')) == 2, 'Utility inherited live meter columns')
        check(tonumber(SKIN:GetVariable('PanelHeight')) == 248, 'Utility inherited live meter height')
        local round = function(value) return math.floor(value + 0.5) end
        local gap = 2 * round(tonumber(SKIN:GetVariable('Gutter')) * scale / 2)
        local expectedW = 2 * (round(width * scale) + gap)
        local expectedH = round(248 * scale) + gap
        local inset = gap / 2
        check(SKIN:GetW() == expectedW and SKIN:GetH() == expectedH,
            'Settings native dimensions do not match independent layout')
        for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
            local item = meter(name)
            check(number(item:GetOption('Hidden', '0')) == 0, 'Utility control still hidden: ' .. name)
            local x,y,w,h = item:GetX(true), item:GetY(true), item:GetW(), item:GetH()
            local align = item:GetOption('StringAlign'):lower()
            if align:match('^right') then x=x-w end
            if align:match('^center') then x=x-w/2 end
            if align:match('center$') then y=y-h/2 end
            if align:match('bottom$') then y=y-h end
            check(w > 0 and h > 0, 'Utility meter has no native area: ' .. name)
            check(x >= -0.01 and y >= -0.01 and x+w <= expectedW+0.01 and y+h <= expectedH+0.01,
                'Utility meter exceeds native window: ' .. name)
            if name ~= 'MeterRAMSettingsBounds' then
                check(x >= inset-0.01 and y >= inset-0.01 and x+w <= expectedW-inset+0.01 and y+h <= expectedH-inset+0.01,
                    'Utility meter enters gutter: ' .. name)
            end
        end
        check(SKIN:GetMeasure('MeasureRAMUsed') == nil, 'Utility collects physical memory unnecessarily')
        check(SKIN:GetMeasure('MeasureRAMInfo') == nil, 'Utility launches hardware metadata unnecessarily')
        check(SKIN:GetMeter('MeterRAMHistory') == nil, 'Utility duplicates the live history')
        for _, role in ipairs({
            {'Title','TitleTextColor','TitleFontSize'},
            {'Display','HeaderTextColor','HeaderFontSize'},
            {'Visibility','HeaderTextColor','HeaderFontSize'},
            {'UnitsLabel','TextColor','FontSize'},
            {'Units','AccentColor','FontSize'},
            {'Close','AccentColor2','FontSize'}
        }) do
            local item = meter('MeterRAMSettings'..role[1])
            check(item:GetOption('FontColor') == SKIN:GetVariable(role[2]), 'Wrong utility semantic color: '..role[1])
            check(number(item:GetOption('FontSize')) == tonumber(SKIN:GetVariable(role[3]))*scale, 'Wrong utility font role: '..role[1])
        end
        check(meter('MeterRAMSettingsClose'):GetOption('LeftMouseUpAction', '', false) == '[!DeactivateConfig]',
            'Close must deactivate only the utility itself')
    end, true)
end

function Click(name, key)
    safely(function()
        local action = meter('MeterRAMSettings'..name):GetOption('LeftMouseUpAction', '', false)
        check(action == '[!CommandMeasure MeasureRAMSettings "Cycle(\'' .. key .. '\')"]', 'Unexpected utility control action')
        -- Validate the label and row hit targets as well as the clicked value.
        check(meter('MeterRAMSettings'..name..'Label'):GetOption('LeftMouseUpAction', '', false) == action, 'Label action differs from value')
        check(meter('MeterRAMSettings'..name..'Row'):GetOption('LeftMouseUpAction', '', false) == action, 'Row action differs from value')
        SKIN:Bang(action)
    end)
end

function Verify(name, key, expected, text)
    safely(function()
        -- Read natural sizes after the first render; OnRefreshAction runs too
        -- early for an unconstrained native String meter to have drawn.
        for _, pair in ipairs({{'Title','Title'}, {'Header','Display'}, {'Body','UnitsLabel'}}) do
            local natural = meter('MeterRAMProbe'..pair[1]):GetH()
            local allocated = meter('MeterRAMSettings'..pair[2]):GetH()
            check(natural > 0 and natural <= allocated,
                'Utility '..pair[1]..' natural font height '..natural..' exceeds allocated '..allocated)
        end
        check(tonumber(SKIN:GetVariable(key)) == expected, 'Settings variable did not apply: ' .. key)
        check(meter('MeterRAMSettings'..name):GetOption('Text') == text, 'Settings label did not update: ' .. name)
        local file = assert(io.open(SKIN:GetVariable('@') .. 'User\\RAM.inc', 'rb'))
        local saved = file:read('*a'); file:close()
        check(tonumber(('\n' .. saved):match('\n'..key..'=([^\r\n]+)')) == expected, 'Utility did not save ' .. key)
    end)
end

function Close()
    safely(function()
        local action = meter('MeterRAMSettingsClose'):GetOption('LeftMouseUpAction', '', false)
        check(action == '[!DeactivateConfig]', 'Unexpected utility close action')
        SKIN:Bang(action)
    end)
end

function Update() return 0 end
