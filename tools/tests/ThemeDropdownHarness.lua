-- Test-only source-action driver for an isolated Rainmeter settings skin.
-- Reads requests from its private run directory; never addresses another instance.
local root, generation, lastSequence, ticks, pending
local names = { 'MeterThemeDismiss', 'MeterThemePopup', 'MeterThemeDefault' }

local function read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local value = file:read('*a'); file:close(); return value
end

local function write(path, value)
    local file = assert(io.open(path, 'wb'))
    file:write(value); file:close()
end

local function visible(name)
    local meter = assert(SKIN:GetMeter(name), 'Missing meter '..name)
    return meter:GetW() > 0 and meter:GetH() > 0
end

local function report(path, expectedOpen)
    local ok, result = pcall(function()
        local bounds = assert(SKIN:GetMeter('MeterBounds'))
        local width, height = bounds:GetW(), bounds:GetH()
        assert(width == tonumber(SELF:GetOption('ExpectedWidth')), 'Incorrect native width '..width)
        assert(height == tonumber(SELF:GetOption('ExpectedHeight')), 'Incorrect native height '..height)
        local lines = { 'PASS', 'Generation='..generation, 'Width='..width, 'Height='..height }
        for _, name in ipairs(names) do
            local meter = assert(SKIN:GetMeter(name))
            assert(visible(name) == expectedOpen, name..' visibility incorrect')
            assert(meter:GetX() >= 0 and meter:GetY() >= 0, name..' starts outside bounds')
            assert(meter:GetX()+meter:GetW() <= width+1 and meter:GetY()+meter:GetH() <= height+1, name..' extends beyond bounds')
            lines[#lines+1] = name..'='..table.concat({meter:GetX(),meter:GetY(),meter:GetW(),meter:GetH()}, ',')
        end
        lines[#lines+1] = 'Open='..tostring(expectedOpen)
        return table.concat(lines, '\n')..'\n'
    end)
    write(path, ok and result or ('FAIL\n'..tostring(result)..'\n'))
end

function Initialize()
    root = SELF:GetOption('ReportDirectory')
    assert(root ~= '', 'Missing isolated report directory')
    generation = (tonumber(read(root..'generation.txt')) or 0) + 1
    write(root..'generation.txt', tostring(generation))
    lastSequence = tonumber(read(root..'sequence.txt')) or 0
    ticks, pending = 0, nil
end

local function meterAction(name, required)
    local action = assert(SKIN:GetMeter(name)):GetOption('LeftMouseUpAction', '')
    assert(action:find(required, 1, true), name..' source action does not contain '..required)
    SKIN:Bang(action)
end

function Update()
    ticks = ticks + 1
    if ticks == 2 then report(root..'ready-'..generation..'.txt', false) end
    if ticks < 3 then return 0 end
    if pending then
        report(root..'result-'..pending.sequence..'.txt', pending.open)
        pending = nil
    end
    local request = read(root..'request.txt') or ''
    local sequence, action = request:match('^(%d+)|([%w_]+)')
    sequence = tonumber(sequence)
    if not sequence or sequence <= lastSequence then return 0 end
    lastSequence = sequence
    -- Record before dispatch: Default refreshes this skin and recreates the harness.
    write(root..'sequence.txt', tostring(sequence))
    local ok, err = pcall(function()
        local wasOpen = visible('MeterThemeDefault')
        if action == 'toggle' then
            meterAction('MeterThemeSelect', 'ToggleThemeMenu()')
            pending = { sequence=sequence, open=not wasOpen }
        elseif action == 'dismiss' then
            assert(wasOpen, 'Dismiss requires an open menu')
            meterAction('MeterThemeDismiss', 'CloseThemeMenu()')
            pending = { sequence=sequence, open=false }
        elseif action == 'leave' then
            assert(wasOpen, 'Mouse leave requires an open menu')
            local sourceAction = SELF:GetOption('SourceMouseLeaveAction', '')
            assert(sourceAction:find('CloseThemeMenu()',1,true), 'Missing source MouseLeaveAction')
            SKIN:Bang(sourceAction)
            pending = { sequence=sequence, open=false }
        elseif action == 'select' then
            assert(wasOpen, 'Default selection requires an open menu')
            meterAction('MeterThemeDefault', "Theme('default')")
            write(root..'selected-'..sequence..'.txt', 'PASS\nDefault source action dispatched\n')
        elseif action == 'audit_closed' then
            pending = { sequence=sequence, open=false }
        else error('Unsupported isolated test action '..action) end
    end)
    if not ok then write(root..'result-'..sequence..'.txt', 'FAIL\n'..tostring(err)..'\n') end
    return 0
end
