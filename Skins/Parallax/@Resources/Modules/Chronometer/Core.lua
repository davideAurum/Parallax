-- Original Parallax countdown engine. Lua 5.1; no Rainmeter or filesystem dependency.
local Core = { LISTS = 3, ROWS = 4, MAX_DURATION = 604800 }
local LIMIT = 9007199254740991

local function integer(value, low, high)
    if type(value) == 'string' and not value:match('^%d+$') then return nil end
    local n = tonumber(value)
    if not n or n ~= n or n < low or n > high or n ~= math.floor(n) then return nil end
    return n
end

function Core.duration(value)
    return integer(value, 1, Core.MAX_DURATION)
end

function Core.new(durations)
    local state = { selected = 1, generation = 0, timers = {} }
    for i = 1, Core.LISTS * Core.ROWS do
        local duration = Core.duration(durations[i]) or 0
        state.timers[i] = { duration = duration, status = duration > 0 and 'idle' or 'disabled',
            remaining = duration, deadline = 0 }
    end
    return state
end

function Core.remaining(timer, now)
    if timer.status == 'running' then return math.max(0, timer.deadline - now) end
    return timer.remaining
end

function Core.tick(state, now)
    local changed = false
    for _, timer in ipairs(state.timers) do
        if timer.status == 'running' and timer.deadline <= now then
            timer.status, timer.remaining, timer.deadline = 'done', 0, 0
            changed = true
        end
    end
    return changed
end

function Core.toggle(state, index, now)
    local timer = state.timers[index]
    if not timer or timer.status == 'disabled' then return false end
    if timer.status == 'running' then
        timer.remaining = Core.remaining(timer, now)
        timer.status = timer.remaining > 0 and 'paused' or 'done'
        timer.deadline = 0
    else
        if timer.status == 'done' then timer.remaining = timer.duration end
        timer.status, timer.deadline = 'running', now + timer.remaining
    end
    return true
end

function Core.reset(state, index)
    local timer = state.timers[index]
    if not timer or timer.status == 'disabled' then return false end
    timer.status, timer.remaining, timer.deadline = 'idle', timer.duration, 0
    return true
end

function Core.select(state, step)
    state.selected = ((state.selected - 1 + step) % Core.LISTS) + 1
end

-- Slot identity is list/row. Label edits retain state; duration edits reset that slot only.
function Core.reconcile(saved, durations)
    local current, changed = Core.new(durations), false
    if not saved then return current, false end
    current.selected, current.generation = saved.selected, saved.generation
    for i, timer in ipairs(current.timers) do
        if saved.timers[i].duration == timer.duration then
            local old = saved.timers[i]
            current.timers[i] = { duration = old.duration, status = old.status,
                remaining = old.remaining, deadline = old.deadline }
        else
            changed = true
        end
    end
    return current, changed
end

function Core.format(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds / 3600) % 24
    local minutes = math.floor(seconds / 60) % 60
    local secs = seconds % 60
    if days > 0 then return string.format('%.0fd %02d:%02d:%02d', days, hours, minutes, secs) end
    return string.format('%02d:%02d:%02d', hours, minutes, secs)
end

local function checksum(data)
    local sum = 0
    for i = 1, #data do sum = (sum * 31 + data:byte(i)) % 65521 end
    return sum
end

function Core.encode(state, generation)
    local lines = { 'PARALLAX_CHRONOMETER_V1', string.format('%.0f|%d', generation, state.selected) }
    for i, timer in ipairs(state.timers) do
        lines[#lines + 1] = string.format('%d|%d|%s|%.0f|%.0f', i, timer.duration,
            timer.status, timer.remaining, timer.deadline)
    end
    local body = table.concat(lines, '\n') .. '\n'
    return body .. 'END|' .. checksum(body) .. '\n'
end

-- Persisted state is a bounded text format, never loadfile/dofile/loadstring input.
-- Checksum detects truncation/accidental damage; it is not an authentication scheme.
function Core.decode(text)
    if type(text) ~= 'string' or #text > 8192 then return nil end
    local body, check = text:match('^(.*\n)END|(%d+)\n$')
    if not body or integer(check, 0, 65520) ~= checksum(body) then return nil end
    local lines = {}
    for line in body:gmatch('([^\n]*)\n') do lines[#lines + 1] = line end
    if #lines ~= 14 or lines[1] ~= 'PARALLAX_CHRONOMETER_V1' then return nil end
    local generation, selected = lines[2]:match('^(%d+)|(%d+)$')
    generation, selected = integer(generation, 1, LIMIT - 1), integer(selected, 1, Core.LISTS)
    if not generation or not selected then return nil end
    local state = { generation = generation, selected = selected, timers = {} }
    for i = 1, Core.LISTS * Core.ROWS do
        local id, duration, status, remaining, deadline = lines[i + 2]:match('^(%d+)|(%d+)|(%a+)|(%d+)|(%d+)$')
        id, duration = integer(id, i, i), integer(duration, 0, Core.MAX_DURATION)
        remaining, deadline = integer(remaining, 0, LIMIT), integer(deadline, 0, LIMIT)
        if not id or not duration or not remaining or not deadline then return nil end
        if status == 'disabled' then
            if duration ~= 0 or remaining ~= 0 or deadline ~= 0 then return nil end
        elseif duration == 0 then return nil
        elseif status == 'idle' then
            if remaining ~= duration or deadline ~= 0 then return nil end
        elseif status == 'paused' then
            if remaining == 0 or deadline ~= 0 then return nil end
        elseif status == 'running' then
            if remaining == 0 or deadline == 0 then return nil end
        elseif status == 'done' then
            if remaining ~= 0 or deadline ~= 0 then return nil end
        else return nil end
        state.timers[i] = { duration = duration, status = status, remaining = remaining, deadline = deadline }
    end
    return state
end

return Core
