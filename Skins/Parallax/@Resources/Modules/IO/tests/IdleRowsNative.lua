-- Test-only: runs in a copied Disk Meter owned by Test-IOIdleRows.ps1, with
-- every provider replaced by constant Calc fixtures and a fast test cadence.
-- It walks the drive selection through none, C, all, an All-mode removal and
-- return of D (applied by the fixture type measure on its own inventory
-- update, as a real hotplug is), and back. Role=New asserts that shown rows
-- update every tick while hidden rows idle; Role=Old (an optional pre-change
-- copy) performs the same steps so the runner can compare captured windows.
-- It writes only its own phase, report and progress files.
local ticks, done, checks, phase = 0, false, 0, 0
local role, phaseTicks, captureTick
local letters = {}
for code = 65, 90 do letters[#letters + 1] = string.char(code) end
local prefixes = {'MeterIODrive', 'MeterIOCapacity', 'MeterIOUsed', 'MeterIODiskReadLabel',
    'MeterIODiskWriteLabel', 'MeterIODiskRead', 'MeterIODiskWrite', 'MeterIOLegend'}
-- Each phase: a label, an action at its first tick, and the rows expected shown.
local phases = {
    {'C,D,G overlay', nil, 'CDG'},
    {'none', function() SKIN:Bang('!SetVariable', 'IODiskDrives', 'none') end, ''},
    {'C', function() SKIN:Bang('!SetVariable', 'IODiskDrives', 'C') end, 'C'},
    {'all', function() SKIN:Bang('!SetVariable', 'IODiskDrives', 'all') end, 'CDEG'},
    {'all, D removed', function() SKIN:Bang('!SetOption', 'MeasureIOTypeD', 'Formula', '1') end, 'CEG'},
    {'all, D returned', function() SKIN:Bang('!SetOption', 'MeasureIOTypeD', 'Formula', '4') end, 'CDEG'},
    {'C,D,G', function() SKIN:Bang('!SetVariable', 'IODiskDrives', 'C,D,G') end, 'CDG'},
}
local notes = {}

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function write(path, text)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(text)); assert(file:close())
end

local function hidden(meter)
    local text = meter:GetOption('Hidden', '0')
    return (tonumber(text) or SKIN:ParseFormula('(' .. text .. ')')) ~= 0
end

local function verify(spec)
    local summary = {}
    for _, letter in ipairs(letters) do
        local expected = spec[3]:find(letter, 1, true) ~= nil
        local drive = SKIN:GetMeter('MeterIODrive' .. letter)
        check(hidden(drive) == not expected, phase .. ' ' .. spec[1] .. ': row ' .. letter .. ' visibility')
        if expected then check(drive:GetY() > 0, letter .. ' shown row was not placed') end
        if role == 'New' then
            for _, prefix in ipairs(prefixes) do
                local meter = SKIN:GetMeter(prefix .. letter)
                local divider = tonumber(meter:GetOption('UpdateDivider', '1'))
                check(divider == (expected and 1 or -1), prefix .. letter .. ' divider ' .. tostring(divider)
                    .. (expected and ': a shown row must update every tick' or ': a hidden row must idle'))
                if not expected then check(meter:GetY() == 0, prefix .. letter .. ' hidden row left Y=0') end
            end
        end
        if expected then summary[#summary + 1] = letter end
    end
    notes[#notes + 1] = string.format('%s: rows %s', spec[1], #summary > 0 and table.concat(summary) or 'none')
end

local function step()
    local index = math.floor((ticks - 1) / phaseTicks) + 1
    local within = (ticks - 1) % phaseTicks
    if index > #phases then
        return string.format('PASS role=%s: %d checks; %s', role, checks, table.concat(notes, '; '))
    end
    if index ~= phase then
        phase = index
        if phases[phase][2] then phases[phase][2]() end
        write(SELF:GetOption('PhasePath'), 'phase=' .. phase .. ' start\n')
    elseif within == captureTick then
        -- Settled: selection, inventory and a refilled history graph.
        verify(phases[phase])
        write(SELF:GetOption('PhasePath'), 'phase=' .. phase .. ' capture\n')
    end
end

function Initialize()
    role = SELF:GetOption('Role', 'New')
    phaseTicks = SELF:GetNumberOption('PhaseTicks', 130)
    captureTick = SELF:GetNumberOption('CaptureTick', 105)
end

function Update()
    if done then return 0 end
    ticks = ticks + 1
    local ok, result = pcall(step)
    if ok and result == nil then return 0 end
    done = true
    write(SELF:GetOption('ResultPath'), (ok and result or ('FAIL role=' .. tostring(role) .. ' tick ' .. ticks .. ' phase ' .. phase .. ': ' .. tostring(result))) .. '\n')
    return ok and 1 or -1
end
