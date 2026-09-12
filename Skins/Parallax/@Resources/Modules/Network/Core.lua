-- Original Parallax pure presentation/state logic. Input rates are native bits/s.
local M = { HISTORY = 60 }

function M.finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

function M.safe(s)
    -- Adapter labels are data, never executable Rainmeter variable/action text.
    return tostring(s or ''):gsub('[%c#%[%]]', ' ')
end

local function trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$')
end

function M.ceiling(s)
    local n = tonumber(s)
    if M.finite(n) and n > 0 and M.finite(n * 1000000) then return n * 1000000 end
end

function M.rate(bits, units)
    if not M.finite(bits) or bits < 0 then return '--' end
    local n, base, labels = bits, 1000, {'bit/s', 'kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'}
    if units == 'bytes' then
        n, base, labels = bits / 8, 1024, {'B/s', 'KiB/s', 'MiB/s', 'GiB/s', 'TiB/s'}
    elseif units ~= 'bits' then
        return 'Check units'
    end
    local i = 1
    while n >= base and i < #labels do n, i = n / base, i + 1 end
    return string.format('%.1f %s', n, labels[i])
end

local function validGuid(guid)
    local g = trim(guid)
    if g:sub(1, 1) == '{' and g:sub(-1) == '}' then g = g:sub(2, -2) end
    if not g:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then return false end
    return g:gsub('[0%-]', '') ~= ''
end

function M.identity(input)
    local selector = trim(input.selector)
    local n = tonumber(selector)
    if selector == '' or (n and (not selector:match('^%d+$')
        or n <= 0 or n ~= math.floor(n) or n > 2147483647)) then
        return nil, 'Select one adapter; index 0 unsupported'
    end
    if not validGuid(input.guid) then return nil, 'Adapter unavailable' end
    -- Invalid names can silently select Best or ALL, depending on native measure/version.
    if selector:lower() ~= 'best' and not n
        and selector:lower() ~= trim(input.alias):lower()
        and selector:lower() ~= trim(input.description):lower() then
        return nil, 'Configured adapter not found'
    end
    return selector .. '|' .. input.guid:lower()
end

function M.new()
    return { identity = nil, ready = false, warmup = 2, history = {}, lastTime = nil }
end

function M.step(model, input, now)
    local identity, errorText = M.identity(input)
    local gap = model.lastTime and (now - model.lastTime > 3 or now <= model.lastTime)
    model.lastTime = now
    if identity ~= model.identity or gap then
        model.identity, model.ready, model.warmup, model.history = identity, false, 2, {}
    end
    local state, valid = errorText, false
    if identity then
        if input.state == -1 then
            state = 'Adapter disconnected'
        elseif input.status ~= 1 then
            local states = { [-3] = 'Adapter not present', [-2] = 'Lower layer down',
                [-1] = 'Adapter down', [0] = 'Adapter status unknown',
                [2] = 'Adapter dormant', [3] = 'Adapter testing' }
            state = states[input.status] or 'Adapter unavailable'
        elseif not model.ready or model.warmup > 0 then
            -- A selector change does not reset native Net counter baselines.
            -- Discard two ticks after startup/change/reconnect or a detected clock gap.
            model.ready = true
            model.warmup = math.max(0, model.warmup - 1)
            state = 'Adapter up / sampling...'
        elseif not M.finite(input.inbound) or not M.finite(input.outbound)
            or input.inbound < 0 or input.outbound < 0 then
            state = 'Sample unavailable'
        else
            valid, state = true, 'Adapter up / 1 s samples'
        end
    end
    if not identity or input.state == -1 or input.status ~= 1 then
        model.ready, model.warmup = false, 2
    end
    if valid then
        table.insert(model.history, { input.inbound, input.outbound })
        if #model.history > M.HISTORY then table.remove(model.history, 1) end
    else
        -- Clearing is explicit: unknown samples are never represented as measured zeros.
        model.history = {}
    end
    return { valid = valid, state = state, identity = identity }
end

function M.path(history, direction, ceiling, width, height, scale)
    if not ceiling or #history == 0 then return '1,1 | LineTo 1,1', false end
    local inset = 2 * scale
    local w, h = math.max(0, width - 2 * inset), math.max(0, height - 2 * inset)
    local path, clipped = {}, false
    for i, sample in ipairs(history) do
        local n = sample[direction]
        clipped = clipped or n > ceiling
        local x = inset + w * (M.HISTORY - #history + i - 1) / (M.HISTORY - 1)
        local y = inset + h * (1 - math.min(1, math.max(0, n / ceiling)))
        table.insert(path, string.format(i == 1 and '%.3f,%.3f' or 'LineTo %.3f,%.3f', x, y))
    end
    -- A single sample has no invented predecessor; a zero-length path draws no line.
    if #history == 1 then table.insert(path, 'LineTo ' .. path[1]) end
    return table.concat(path, ' | '), clipped
end

return M
