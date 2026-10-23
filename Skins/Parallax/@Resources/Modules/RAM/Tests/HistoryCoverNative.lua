-- Test-only: runs in a copied RAM skin owned by Test-RAMHistoryCover.ps1.
-- It follows the startup history cover from load past a full plot at a fast
-- test cadence. Role=New asserts the production retirement; Role=Old (an
-- optional pre-change copy) performs the same actions so both windows can be
-- compared pixel for pixel. It writes only its own report and progress files.
local ticks, done, checks = 0, false, 0
local role, width, fullTick, probe
local coverName, countName = 'MeterRAMHistoryUncollected', 'MeasureRAMHistorySamples'
local historyMeters = {'MeterRAMHistoryLabel', 'MeterRAMHistoryRange', 'MeterRAMHistory', coverName, 'MeterRAMHistoryFrame'}
local log = {}

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function strict(condition, message)
    -- Production assertions apply to the current copy only.
    if role == 'New' then check(condition, message) end
end

local function hidden(name)
    -- Options can still hold their formula text, for example (1-1).
    local text = SKIN:GetMeter(name):GetOption('Hidden', '0')
    return (tonumber(text) or SKIN:ParseFormula('(' .. text .. ')')) ~= 0
end

local function divider(section, isMeasure)
    local item = isMeasure and SKIN:GetMeasure(section) or SKIN:GetMeter(section)
    return tonumber(item:GetOption('UpdateDivider', '1'))
end

local function samples() return SKIN:GetMeasure(countName):GetValue() end

local function setHistory(value)
    -- Same path as a Settings broadcast: variable, then the event-only display bridge.
    SKIN:Bang('!SetVariable', 'RAMShowHistory', tostring(value))
    SKIN:Bang('!UpdateMeasure', 'MeasureRAMSettings')
end

local function note(text) log[#log + 1] = string.format('tick %d: %s', ticks, text) end

local function write(path, text)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(text)); assert(file:close())
end

local function step()
    local count = samples()
    if ticks == 3 then
        width = SKIN:ParseFormula('(' .. SKIN:ReplaceVariables('#ContentWidth#') .. ')')
        check(width and width > 20, 'ContentWidth did not resolve')
        check(count >= 1 and count < width, 'Startup count outside the uncollected range: ' .. count)
        check(not hidden(coverName) and divider(coverName) == 1, 'Startup cover must be visible and updating')
        check(SKIN:GetMeter(coverName):GetW() > 0, 'Startup cover has no width over uncollected samples')
        note('startup count ' .. count .. ' of ' .. width .. '; cover visible, width ' .. SKIN:GetMeter(coverName):GetW())
    elseif ticks == 5 then
        setHistory(0)
        for _, name in ipairs(historyMeters) do check(hidden(name), 'History off left ' .. name .. ' visible') end
    elseif ticks == 6 then
        setHistory(1)
        for _, name in ipairs(historyMeters) do check(not hidden(name), 'History on before a full plot must show ' .. name) end
        check(divider(coverName) == 1 and divider(countName, true) == 1, 'Cover retired before the plot was full')
        note('history toggled off/on before full; cover re-shown')
    elseif ticks > 6 and not fullTick then
        if count >= width then
            fullTick = ticks
            note('count reached ' .. count .. ' (ContentWidth ' .. width .. ')')
            strict(hidden(coverName), 'Full plot did not hide the cover in the same update')
            strict(divider(coverName) == -1, 'Full plot did not idle the cover Shape (UpdateDivider -1)')
            strict(divider(countName, true) == -1, 'Full plot did not stop the sample count')
            if role == 'Old' then check(not hidden(coverName) and divider(coverName) == 1, 'Old copy changed cover semantics') end
        else
            check(not hidden(coverName) and divider(coverName) == 1, 'Cover retired early at count ' .. count)
        end
    elseif fullTick then
        local after = ticks - fullTick
        check(count == width, 'Full sample count changed after retirement: ' .. count)
        if role == 'New' then
            check(hidden(coverName) and divider(coverName) == -1 and divider(countName, true) == -1, 'Retired cover or count resumed')
        end
        if after == 3 and role == 'New' then
            -- An UpdateDivider=-1 meter ignores !SetOption until forced; a
            -- moved X that never applies shows the cover no longer updates.
            local meter = SKIN:GetMeter(coverName)
            probe = {x = meter:GetX(), option = meter:GetOption('X')}
            SKIN:Bang('!SetOption', coverName, 'X', tostring(probe.x + 7))
        elseif after == 6 and role == 'New' then
            check(SKIN:GetMeter(coverName):GetX() == probe.x, 'Retired cover still re-reads options every update')
            SKIN:Bang('!SetOption', coverName, 'X', probe.option)
            note('retired cover ignored a test X change for 3 updates (idle meter)')
        elseif after == 8 then
            setHistory(0)
            for _, name in ipairs(historyMeters) do check(hidden(name), 'History off after full left ' .. name .. ' visible') end
        elseif after == 9 then
            setHistory(1)
            for _, name in ipairs(historyMeters) do
                if name == coverName then strict(hidden(name), 'Showing history re-showed a retired cover')
                else check(not hidden(name), 'History on after full must show ' .. name) end
            end
            note('history toggled off/on after full; retired cover stayed hidden: ' .. tostring(hidden(coverName)))
        elseif after == 14 then
            local report = string.format('PASS role=%s: %d checks; ContentWidth=%g; full at tick %d; %s',
                role, checks, width, fullTick, table.concat(log, '; '))
            return report
        end
    end
end

function Initialize()
    role = SELF:GetOption('Role', 'New')
end

function Update()
    if done then return 0 end
    ticks = ticks + 1
    local ok, result = pcall(step)
    if ok and result == nil then
        if ticks % 10 == 0 then write(SELF:GetOption('ProgressPath'), tostring(ticks)) end
        return 0
    end
    done = true
    write(SELF:GetOption('ResultPath'), (ok and result or ('FAIL role=' .. tostring(role) .. ' tick ' .. ticks .. ': ' .. tostring(result))) .. '\n')
    return ok and 1 or -1
end
