-- Interactive QA orchestration, appended only to an isolated copied skin.
-- Interactive mode uses an operator; AutomatedForm substitutes a test-only entrypoint
-- that invokes the unshown production form controller without OS input.
local ticks, checks, stopped, sawRunning = 0, 0, false, false
local completedAt, Core, statePath

local function check(condition, message)
    if not condition then error(message, 2) end
    checks = checks + 1
end

local function text(name)
    local meter = SKIN:GetMeter(name)
    check(meter ~= nil, 'Missing production meter: ' .. name)
    return meter:GetOption('Text', '', true)
end

local function finish(ok, message)
    stopped = true
    local file = assert(io.open(SELF:GetOption('ResultPath'), 'wb'))
    assert(file:write((ok and 'PASS: ' or 'FAIL: ') .. message .. '\nSUMMARY: ' .. checks ..
        ' checks, ' .. (ok and '0' or '1') .. ' failed\n'))
    assert(file:close())
    SKIN:Bang('!Quit')
end

local function savedState()
    local file = io.open(statePath, 'rb')
    if not file then return nil end
    local contents = file:read(2049)
    file:close()
    local state, err = Core.decode(contents)
    check(state ~= nil, 'Editor saved a valid event envelope: ' .. tostring(err))
    return state
end

function Initialize()
    Core = dofile(SKIN:GetVariable('@') .. 'Modules\\Chronometer\\EventCore.lua')
    statePath = SKIN:GetVariable('SETTINGSPATH') .. 'Parallax-Chronometer-event-v1.state'
end

function Update()
    if stopped then return 0 end
    ticks = ticks + 1
    if ticks < 2 then return 0 end
    local ok, err = pcall(function()
        local editor = SKIN:GetMeasure('MeasureEventEditor')
        check(editor ~= nil, 'Production RunCommand measure exists')
        local code = editor:GetValue()
        if ticks == 2 then
            check(savedState() == nil, 'Isolated editor starts with no event state')
            check(text('MeterEventName') == 'No event set', 'Adapter starts with its unset display')
            check(code == -1, 'Production editor has not already run')
            local executable = SELF:GetOption('EditorExecutable')
            check(editor:GetOption('Program'):find(executable, 1, true) ~= nil, 'RunCommand targets the copied editor executable')
            check(editor:GetOption('Parameter'):find(statePath, 1, true) ~= nil, 'Editor writes only the isolated event path')
            SKIN:Bang('!CommandMeasure', 'MeasureEventCountdown', 'OpenEditor()')
            if editor:GetValue() == 0 then sawRunning = true end
        else
            check(code < 100, 'Production RunCommand failed with code ' .. code)
            if code == 0 then sawRunning = true end
            if code == 1 and not completedAt then completedAt = ticks end
            if completedAt and ticks > completedAt then
                if SELF:GetOption('AutomatedForm') ~= '1' then
                    check(sawRunning, 'Production RunCommand was observed running the interactive editor')
                end
                check(editor:GetStringValue():match('^%s*(.-)%s*$') == 'SAVED', 'Editor completion returned SAVED through RunCommand')
                local state = savedState()
                check(state ~= nil and state.enabled, 'Actual editor Save created an enabled event')
                check(state.name == 'Release party', 'Actual form saved the requested synthetic name')
                check(state.deadline > os.time(), 'Actual form saved a future deadline')
                -- No test Reload, EditorFinished, refresh or meter write is issued.
                -- The production FinishAction alone must publish the saved event.
                check(text('MeterEventName') == 'Countdown to Release party:', 'Production FinishAction refreshed the event label')
                check(SKIN:GetMeter('MeterEventCountdown'):GetOption('ToolTipText'):find(os.date('%Y-%m-%d %H:%M', state.deadline), 1, true) ~= nil,
                    'Production FinishAction refreshed the target date in the event tooltip')
                local days, hours, minutes, seconds = text('MeterEventCountdown'):match('^(%d+)d (%d+)h (%d+)m (%d+)s$')
                check(days ~= nil, 'Production FinishAction rendered a future countdown')
                local remaining = tonumber(days) * 86400 + tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)
                check(remaining > 0 and math.abs(remaining - (state.deadline - os.time())) <= 2, 'Displayed countdown agrees with the form deadline')
                finish(true, SELF:GetOption('AutomatedForm') == '1'
                    and 'Test-only entrypoint invoked production form Save; actual RunCommand FinishAction updated the event without GUI input'
                    or 'Production OpenEditor launched the form; actual Save and RunCommand FinishAction updated the event')
            end
            check(ticks < SELF:GetNumberOption('TimeoutSeconds') - 2, 'Interactive editor QA timed out waiting for Release party Save')
        end
    end)
    if not ok then finish(false, tostring(err)) end
    return 0
end
