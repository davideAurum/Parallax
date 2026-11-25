-- Test-only: runs inside a staged settings panel (Test-PanelScroll.ps1) or inside the
-- driver skin that carries its commands. The panel keeps its production Update=-1; every
-- call arrives as a bang from the driver, so nothing here redraws or updates on a timer.
local root, role, names, armed, sequence

local function read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local text = file:read('*a')
    file:close()
    return text
end

local function write(name, lines)
    -- Written whole, then renamed: the runner polls for the final name.
    local path = root .. name
    local file = assert(io.open(path .. '.tmp', 'wb'))
    file:write(table.concat(lines, '\n'), '\nEND\n')
    file:close()
    assert(os.rename(path .. '.tmp', path))
end

function Initialize()
    root, role = SELF:GetOption('RunRoot'), SELF:GetOption('Role')
    armed, sequence = {}, 0
    names = {}
    for name in SELF:GetOption('Meters', ''):gmatch('[^|]+') do names[#names + 1] = name end
end

-- The driver skin only (Update=50): the next command is "<seq>|<config>|<call>".
function Update()
    if role ~= 'driver' then return 0 end
    local seq, config, call = (read(root .. 'command.txt') or ''):match('^(%d+)|([^|]*)|(.-)%s*$')
    seq = tonumber(seq)
    if not seq or seq <= sequence then return 0 end
    sequence = seq
    if call:find('^%[') then SKIN:Bang(call)
    else SKIN:Bang('!CommandMeasure', 'MeasurePanelScrollTest', call, config) end
    return 0
end

local function number(name) return SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#' .. name .. '#') .. ')') end

local function snapshot()
    local result = {}
    for _, name in ipairs(names) do
        local meter = SKIN:GetMeter(name)
        if meter then
            result[#result + 1] = { name = name, x = meter:GetX(), y = meter:GetY(), w = meter:GetW(), h = meter:GetH(),
                contained = meter:GetOption('Container', '') ~= '' }
        end
    end
    return result
end

local function describe(lines)
    local bounds = SKIN:GetMeter('MeterBounds')
    for _, name in ipairs({ 'PanelHeight', 'PanelHeightPx', 'WindowHeight', 'WindowWidth', 'Gap', 'Inset', 'Scale', 'PanelScrollY',
            'PanelScrollTopPx', 'PanelScrollView', 'PanelScrollHidden', 'PanelScrollThumbY', 'PanelScrollThumbH', 'WORKAREAY' }) do
        lines[#lines + 1] = string.format('V|%s|%s', name, tostring(number(name)))
    end
    lines[#lines + 1] = string.format('W|%d|%d|%d|%d|%d|%d', SKIN:GetX(), SKIN:GetY(), SKIN:GetW(), SKIN:GetH(), bounds:GetW(), bounds:GetH())
end

-- Wheel or arrow to both ends, noting where every meter sits at each stop.
-- method: the source's own wheel action strings, or the arrows' own actions.
function Audit(tag, down, up)
    local lines = {}
    local function stop()
        lines[#lines + 1] = 'S|' .. number('PanelScrollY')
        for _, m in ipairs(snapshot()) do
            lines[#lines + 1] = string.format('M|%s|%s|%s|%s|%s|%d', m.name, m.x, m.y, m.w, m.h, m.contained and 1 or 0)
        end
    end
    for _ = 1, 200 do
        local before = number('PanelScrollY')
        SKIN:Bang(up)
        if number('PanelScrollY') == before then break end
    end
    describe(lines)
    stop()
    for _ = 1, 200 do
        local before = number('PanelScrollY')
        SKIN:Bang(down)
        if number('PanelScrollY') == before then break end
        stop()
    end
    write(tag .. '.txt', lines)
end

function State(tag)
    local lines = {}
    describe(lines)
    write(tag .. '.txt', lines)
end

function Do(action) SKIN:Bang(action) end

-- The panel's own actions, replaced by a recorder so no click can change anything.
function Arm(tag)
    local lines = {}
    for _, name in ipairs(names) do
        local meter = SKIN:GetMeter(name)
        local action = meter and meter:GetOption('LeftMouseUpAction', '') or ''
        if action ~= '' then
            lines[#lines + 1] = 'A|' .. name .. '|' .. action
            SKIN:Bang('!SetOption', name, 'LeftMouseUpAction', "[!CommandMeasure MeasurePanelScrollTest \"Hit('" .. name .. "')\"]")
            SKIN:Bang('!UpdateMeter', name)
        end
    end
    write(tag .. '.txt', lines)
end

function Hit(name) armed[#armed + 1] = name end

function Hits(tag)
    write(tag .. '.txt', armed)
    armed = {}
end

-- Scrolls to a stop the wheel reaches, from the top.
function Go(stops, down, up)
    for _ = 1, 200 do
        local before = number('PanelScrollY')
        SKIN:Bang(up)
        if number('PanelScrollY') == before then break end
    end
    for _ = 1, stops do SKIN:Bang(down) end
end
