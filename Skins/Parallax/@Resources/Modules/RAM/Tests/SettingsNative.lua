-- Test-only controller injected into a copied, initially inactive Settings config.
-- It uses actual utility meter actions; production Update=-1 remains unchanged.
local checks = 0
local windowBounds, formatBeforeVisibility
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
local function controlAction(key)
    local method = (key == 'RAMDecimals' or key == 'RAMPercentDecimals') and 'Edit' or 'Cycle'
    return '[!CommandMeasure MeasureRAMSettings "'..method..'(\''..key..'\')"]'
end
local function rect(item)
    local x,y,w,h = item:GetX(true),item:GetY(true),item:GetW(),item:GetH()
    if item:GetOption('StringAlign'):lower():match('^center') then x=x-w/2 end
    return x,y,w,h
end

function Opened()
    safely(function()
        local scale = tonumber(SKIN:GetVariable('Scale'))
        local width = tonumber(SKIN:GetVariable('ColumnWidth'))
        check(scale == SELF:GetNumberOption('ExpectedScale'), 'Utility lost module scale')
        check(width == SELF:GetNumberOption('ExpectedWidth'), 'Utility lost module width')
        check(tonumber(SKIN:GetVariable('Columns')) == 2, 'Utility inherited live meter columns')
        check(tonumber(SKIN:GetVariable('PanelHeight')) == 340, 'Utility inherited live meter height')
        local round = function(value) return math.floor(value + 0.5) end
        local gap = 2 * round(tonumber(SKIN:GetVariable('Gutter')) * scale / 2)
        local expectedW = 2 * (round(width * scale) + gap)
        local expectedH = round(340 * scale) + gap
        local inset = gap / 2
        check(SKIN:GetW() == expectedW and SKIN:GetH() == expectedH,
            'Settings native dimensions do not match independent layout')
        windowBounds = {w=expectedW, h=expectedH}
        for name in SELF:GetOption('MeterNames'):gmatch('[^|]+') do
            local item = meter(name)
            check(number(item:GetOption('Hidden', '0')) == 0, 'Utility control still hidden: ' .. name)
            local x,y,w,h = item:GetX(true), item:GetY(true), item:GetW(), item:GetH()
            local align = item:GetOption('StringAlign'):lower()
            if align:match('^right') then x=x-w end
            if align:match('^center') then x=x-w/2 end
            if align:match('center$') then y=y-h/2 end
            if align:match('bottom$') then y=y-h end
            local separator = name == 'MeterRAMSettingsDisplayRule' or name == 'MeterRAMSettingsVisibilityRule'
            if separator and tonumber(SKIN:GetVariable('DividerThickness')) == 0 then
                check(w >= 0 and h >= 0, 'Disabled utility divider has invalid native bounds')
            else
                check(w > 0 and h > 0, 'Utility meter has no native area: ' .. name)
            end
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
        check(SKIN:GetMeasure('MeasureRAMSettingsInput'):GetOption('Measure') == 'Calc', 'Native Settings must keep numeric input inert')
        for _, section in ipairs({{'Display',74,95}, {'Visibility',188,209}}) do
            local item = meter('MeterRAMSettings'..section[1])
            check(item:GetOption('MeterStyle'):gsub('%s+','') == 'StyleUtilitySettingsSection|StyleRAMSettingsUI', 'Utility section lost shared style inheritance')
            check(math.abs(item:GetY(true)-(inset+section[2]*scale)) <= 1.01, 'Utility section has the wrong position')
            local rule = meter('MeterRAMSettings'..section[1]..'Rule')
            check(rule:GetOption('MeterStyle'):gsub('%s+','') == 'StyleRule|StyleRAMSettingsUI', 'Utility semantic section must use a divider rule')
            check(math.abs(rule:GetY(true)-(inset+section[3]*scale)) <= 1.01, 'Utility divider has the wrong position')
        end
        for _, control in ipairs({{'Units',100}, {'Decimals',128}, {'PercentDecimals',156}, {'Bar',214}, {'PageBar',242}, {'History',270}}) do
            check(SKIN:GetMeter('MeterRAMSettings'..control[1]..'Row') == nil, 'Utility still uses a shaded full-row hit target')
            local label = meter('MeterRAMSettings'..control[1]..'Label')
            local value = meter('MeterRAMSettings'..control[1])
            check(label:GetOption('MeterStyle'):gsub('%s+','') == 'StyleUtilitySettingsLabel|StyleRAMSettingsLabel', 'Utility label lost shared style inheritance')
            local stepper = control[1] == 'Units' or control[1] == 'Decimals' or control[1] == 'PercentDecimals'
            if stepper then
                local frame = meter('MeterRAMSettings'..control[1]..'Frame')
                local prev,nextItem = meter('MeterRAMSettings'..control[1]..'Prev'),meter('MeterRAMSettings'..control[1]..'Next')
                check(frame:GetOption('MeterStyle'):gsub('%s+','') == 'StyleSettingsStepperFrame|StyleRAMSettingsStepperFrame', 'Stepper frame lost shared style')
                check(value:GetOption('MeterStyle'):gsub('%s+','') == 'StyleSettingsStepperValue|StyleRAMSettingsStepperValue', 'Stepper value lost shared style')
                check(math.abs(frame:GetY(true)-(inset+control[2]*scale)) <= 1.01 and number(frame:GetOption('H')) == 20*scale, 'Stepper frame lost section pitch or height')
                local vx,vy,vw,vh = rect(value)
                check(math.abs(vx-frame:GetX(true)) <= 1.01 and math.abs(vw-frame:GetW()) <= 1.01 and number(value:GetOption('W')) == 56*scale, 'Stepper value must align with its 56px frame')
                check(math.abs(vy-frame:GetY(true)-scale) <= 1.01 and math.abs(label:GetY(true)-frame:GetY(true)-2*scale) <= 1.01, 'Stepper text must center vertically inside its frame')
                check(value:GetOption('StringAlign'):lower() == 'center' and value:GetOption('Padding') == '0,0,0,0', 'Stepper value must use centered unpadded text')
                for index,arrow in ipairs({prev,nextItem}) do
                    check(arrow:GetOption('MeterStyle'):gsub('%s+','') == 'StyleSettingsStepperButton|StyleRAMSettingsStepper'..(index == 1 and 'Prev' or 'Next'), 'Stepper arrow lost shared style')
                    check(arrow:GetOption('FontColor') == SKIN:GetVariable('AccentColor') and number(arrow:GetOption('FontSize')) == tonumber(SKIN:GetVariable('FontSize'))*scale, 'Stepper arrows lost accent/body typography')
                    check(number(arrow:GetOption('W')) == 18*scale and number(arrow:GetOption('H')) == 18*scale and math.abs(arrow:GetY(true)-vy) <= 1.01, 'Stepper arrow dimensions or alignment changed')
                end
                local px,py,pw = rect(prev)
                local nx = rect(nextItem)
                check(label:GetX(true)+label:GetW() <= px+0.01 and math.abs(px-number('#ContentX#')-138*scale) <= 1.01, 'Stepper group overlaps its label or loses column alignment')
                check(math.abs(frame:GetX(true)-px-pw-2*scale) <= 1.01 and math.abs(nx-frame:GetX(true)-frame:GetW()-2*scale) <= 1.01, 'Stepper arrows lost their frame gaps')
                local key = control[1] == 'Units' and 'RAMUseMiB' or ('RAM'..control[1])
                local centerAction = controlAction(key)
                check(value:GetOption('LeftMouseUpAction','',false) == centerAction and frame:GetOption('LeftMouseUpAction','',false) == centerAction
                    and label:GetOption('LeftMouseUpAction','',false) == centerAction, 'Stepper frame/value/label actions disagree')
                local method = control[1] == 'Units' and 'Cycle' or 'Adjust'
                for _,direction in ipairs({{'Prev',-1},{'Next',1}}) do
                    check(meter('MeterRAMSettings'..control[1]..direction[1]):GetOption('LeftMouseUpAction','',false)
                        == '[!CommandMeasure MeasureRAMSettings "'..method..'(\''..key..'\','..direction[2]..')"]', 'Stepper direction action is incorrect')
                end
            else
                check(value:GetOption('MeterStyle'):gsub('%s+','') == 'StyleUtilitySettingsValue|StyleRAMSettingsValue', 'Utility field lost shared style inheritance')
                check(math.abs(value:GetY(true)-(inset+control[2]*scale)) <= 1.01, 'Utility fields lost their 28px pitch')
                check(math.abs(label:GetY(true)-value:GetY(true)-2*scale) <= 1.01, 'Utility label lost alignment with its field')
                check(label:GetX(true)+label:GetW() <= value:GetX(true)+0.01, 'Utility label overlaps its value field')
                check(value:GetOption('StringAlign'):lower() == 'left' and value:GetOption('SolidColor') == SKIN:GetVariable('GraphBackgroundColor'), 'Utility value lost its left-aligned shaded field')
                local padding = {}
                for part in value:GetOption('Padding'):gmatch('[^,]+') do padding[#padding+1] = number(part) end
                check(#padding == 4 and padding[1] == 3*scale and padding[2] == scale and padding[3] == 3*scale and padding[4] == scale,
                    'Utility field lost shared padding')
            end
            check(number(value:GetOption('H')) == 18*scale, 'Utility field lost its text height')
        end
        check(meter('MeterUtilitySettingsGlobalLink'):GetOption('LeftMouseUpAction','',false) == '[!ActivateConfig "Parallax\\Settings" "Settings.ini"]',
            'Utility global-navigation target changed')
        for _, role in ipairs({
            {'Title','TitleTextColor','TitleFontSize'},
            {'Display','AccentColor','HeaderFontSize'},
            {'Visibility','AccentColor','HeaderFontSize'},
            {'UnitsLabel','TextColor','FontSize'},
            {'Units','TextColor','FontSize'},
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
        check(action == controlAction(key), 'Unexpected utility control action')
        -- The field and its label remain the two matching click targets.
        check(meter('MeterRAMSettings'..name..'Label'):GetOption('LeftMouseUpAction', '', false) == action, 'Label action differs from value')
        check(SKIN:GetMeter('MeterRAMSettings'..name..'Row') == nil, 'Superseded full-row hit target remains')
        if (key == 'RAMShowBar' or key == 'RAMShowPageBar' or key == 'RAMShowHistory') and not formatBeforeVisibility then
            formatBeforeVisibility = {}
            for _, option in ipairs({'RAMUseMiB','RAMDecimals','RAMPercentDecimals'}) do
                formatBeforeVisibility[option] = tonumber(SKIN:GetVariable(option))
            end
        end
        if key == 'RAMDecimals' or key == 'RAMPercentDecimals' then
            check(meter('MeterRAMSettings'..name..'Frame'):GetOption('LeftMouseUpAction','',false) == action, 'Numeric frame and center must open the same input action')
            local previous = meter('MeterRAMSettings'..name..'Prev'):GetOption('LeftMouseUpAction','',false)
            check(previous == '[!CommandMeasure MeasureRAMSettings "Adjust(\''..key..'\',-1)"]', 'Unexpected numeric decrement action')
            check(tonumber(SKIN:GetVariable(key)) == 2, 'Native numeric control fixture must begin at its upper limit')
            -- Exercise real decrement actions; typed center behavior is tested
            -- in the mocked controller so no native popup/helper can launch.
            SKIN:Bang(previous); SKIN:Bang(previous)
        else SKIN:Bang(action) end
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
        if key == 'RAMShowBar' or key == 'RAMShowPageBar' or key == 'RAMShowHistory' then
            -- RAM has no dependent settings rows: these toggles control only
            -- the monitor's visuals. All six settings remain useful/accessible.
            check(SKIN:GetW() == windowBounds.w and SKIN:GetH() == windowBounds.h, 'Visibility toggle resized the fixed RAM settings utility')
            for _, control in ipairs({{'Units','RAMUseMiB'}, {'Decimals','RAMDecimals'}, {'PercentDecimals','RAMPercentDecimals'}, {'Bar','RAMShowBar'}, {'PageBar','RAMShowPageBar'}, {'History','RAMShowHistory'}}) do
                local current = tonumber(SKIN:GetVariable(control[2]))
                local label = meter('MeterRAMSettings'..control[1]..'Label')
                local field = meter('MeterRAMSettings'..control[1])
                local action = controlAction(control[2])
                local components = {{label,action},{field,action}}
                if control[1] == 'Units' or control[1] == 'Decimals' or control[1] == 'PercentDecimals' then
                    components[#components+1] = {meter('MeterRAMSettings'..control[1]..'Frame'),action}
                    local method = control[1] == 'Units' and 'Cycle' or 'Adjust'
                    for _,direction in ipairs({{'Prev',-1},{'Next',1}}) do
                        components[#components+1] = {meter('MeterRAMSettings'..control[1]..direction[1]),
                            '[!CommandMeasure MeasureRAMSettings "'..method..'(\''..control[2]..'\','..direction[2]..')"]'}
                    end
                end
                for _, component in ipairs(components) do
                    local item = component[1]
                    check(number(item:GetOption('Hidden','0')) == 0 and item:GetW() > 0 and item:GetH() > 0, 'Visibility toggle hid an applicable RAM setting')
                    local x,y,w,h = rect(item)
                    check(x >= 0 and y >= 0 and x+w <= windowBounds.w+0.01 and y+h <= windowBounds.h+0.01, 'Applicable RAM setting left the utility window')
                    check(item:GetOption('LeftMouseUpAction','',false) == component[2], 'Visibility toggle disabled an applicable RAM setting action')
                end
                local expectedText = tostring(current)
                if control[2] == 'RAMUseMiB' then expectedText = current == 1 and 'MB' or 'GB'
                elseif control[2] == 'RAMShowBar' or control[2] == 'RAMShowPageBar' or control[2] == 'RAMShowHistory' then expectedText = current == 1 and 'On' or 'Off' end
                check(field:GetOption('Text') == expectedText, 'Visibility toggle lost a displayed settings value')
                check(tonumber(('\n'..saved):match('\n'..control[2]..'=([^\r\n]+)')) == current, 'Visibility toggle lost a saved settings value')
            end
            for option, value in pairs(formatBeforeVisibility or {}) do
                check(tonumber(SKIN:GetVariable(option)) == value, 'Visibility toggle changed an independent formatting preference')
            end
        end
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
