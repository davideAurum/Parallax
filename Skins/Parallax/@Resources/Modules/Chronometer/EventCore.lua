-- Original Parallax fixed-instant event codec. Lua 5.1; no OS, UI or file access.
-- Persisted input is data only. It is never passed to a Lua or Rainmeter evaluator.
local Core = { MAX_BYTES = 2048, MAX_NAME_BYTES = 320, MAX_NAME_UNITS = 80, MAX_DEADLINE = 4102531199 }
local HEADER = 'PARALLAX-EVENT-1'

local function checksum(body)
    local value = 0
    for i = 1, #body do value = (value * 31 + body:byte(i)) % 65521 end
    return value
end

local function decimal(text, limit)
    if type(text) ~= 'string' or not text:match('^%d+$') or (#text > 1 and text:sub(1, 1) == '0') then return nil end
    local number = tonumber(text)
    if not number or number < 0 or number > limit or number ~= math.floor(number) then return nil end
    return number
end

-- Reject malformed sequences, overlong encodings, surrogate code points and values
-- above U+10FFFF. C0 and C1 Unicode control characters are forbidden in saved names.
local function utf8(value, allowControls)
    local i, units, hasText = 1, 0, false
    while i <= #value do
        local first, length, code = value:byte(i), 1, nil
        if first <= 127 then code = first
        elseif first >= 194 and first <= 223 then length, code = 2, first - 192
        elseif first >= 224 and first <= 239 then length, code = 3, first - 224
        elseif first >= 240 and first <= 244 then length, code = 4, first - 240
        else return false end
        for offset = 1, length - 1 do
            local nextByte = value:byte(i + offset)
            if not nextByte or nextByte < 128 or nextByte > 191 then return false end
            code = code * 64 + nextByte - 128
        end
        if (length == 2 and code < 128) or (length == 3 and code < 2048) or
            (length == 4 and code < 65536) or (code >= 55296 and code <= 57343) or code > 1114111 then return false end
        if not allowControls and (code < 32 or (code >= 127 and code <= 159)) then return false end
        units = units + (code > 65535 and 2 or 1)
        -- Unicode White_Space matches the editor's String.IsNullOrWhiteSpace check.
        if not (code == 32 or (code >= 9 and code <= 13) or code == 133 or code == 160 or code == 5760 or
            (code >= 8192 and code <= 8202) or code == 8232 or code == 8233 or code == 8239 or code == 8287 or code == 12288) then hasText = true end
        i = i + length
    end
    return true, units, hasText
end

local function validDate(value)
    if type(value) ~= 'string' then return false end
    local year, month, day, hour, minute, second = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
    if not year or year < 2000 or year > 2099 or month < 1 or month > 12 or
        hour > 23 or minute > 59 or second > 59 then return false end
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then days[2] = 29 end
    return day >= 1 and day <= days[month]
end

local function state(deadline, name, localDate)
    if deadline == 0 then
        if name ~= '' or localDate ~= '' then return nil, 'Cleared event must have empty name and local date' end
        return { deadline = 0, name = '', localDate = '', enabled = false }
    end
    local valid, units, hasText = utf8(name, false)
    if #name < 1 or #name > Core.MAX_NAME_BYTES or not valid or units > Core.MAX_NAME_UNITS or not hasText then
        return nil, 'Event name must be valid UTF-8, at most 80 UTF-16 units and 320 bytes, without controls or whitespace-only content'
    end
    if not validDate(localDate) then return nil, 'Original local date must be a valid date in 2000..2099' end
    return { deadline = deadline, name = name, localDate = localDate, enabled = true }
end

function Core.decode(text)
    if type(text) ~= 'string' or #text > Core.MAX_BYTES then return nil, 'Event file is missing or exceeds 2048 bytes' end
    local body, checkText = text:match('^(.*\n)END|(%d+)\n$')
    if not body or #checkText > 5 or decimal(checkText, 65520) ~= checksum(body) then return nil, 'Event file is incomplete or checksum is invalid' end
    local deadlineText, hexName, localDate = body:match('^PARALLAX%-EVENT%-1\n(%d+)\n([0-9a-f]*)\n([^\n]*)\n$')
    if not deadlineText then return nil, 'Event file format is invalid' end
    local deadline = decimal(deadlineText, Core.MAX_DEADLINE)
    if not deadline or #deadlineText > 10 then return nil, 'Event deadline is outside the supported range' end
    if #hexName % 2 ~= 0 or #hexName > Core.MAX_NAME_BYTES * 2 then return nil, 'Event name encoding is invalid' end
    local name = hexName:gsub('..', function(pair) return string.char(tonumber(pair, 16)) end)
    return state(deadline, name, localDate)
end

-- Optional export/testing counterpart. Disabled state must use the exact empty shape.
function Core.encode(value)
    if type(value) ~= 'table' or type(value.deadline) ~= 'number' or value.deadline ~= value.deadline or
        value.deadline < 0 or value.deadline > Core.MAX_DEADLINE or value.deadline ~= math.floor(value.deadline) or
        type(value.name) ~= 'string' or type(value.localDate) ~= 'string' then return nil, 'Event state is invalid' end
    local validated, err = state(value.deadline, value.name, value.localDate)
    if not validated then return nil, err end
    if value.enabled ~= validated.enabled then return nil, 'Event enabled flag does not match its deadline' end
    local hexName = value.name:gsub('.', function(byte) return string.format('%02x', byte:byte()) end)
    local body = HEADER .. '\n' .. string.format('%.0f', value.deadline) .. '\n' .. hexName .. '\n' .. value.localDate .. '\n'
    return body .. 'END|' .. checksum(body) .. '\n'
end

function Core.remaining(value, now)
    if not value or not value.enabled or type(now) ~= 'number' or now ~= now or math.abs(now) == math.huge then return 0 end
    return math.max(0, math.floor(value.deadline - now))
end

function Core.format(seconds)
    if type(seconds) ~= 'number' or seconds ~= seconds or math.abs(seconds) == math.huge then seconds = 0 end
    seconds = math.max(0, math.floor(seconds))
    local days = math.floor(seconds / 86400)
    local hours, minutes, secs = math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60, seconds % 60
    return string.format('%.0fd %dh %dm %ds', days, hours, minutes, secs)
end

function Core.displayName(name)
    if type(name) ~= 'string' or #name > Core.MAX_NAME_BYTES then return 'Event' end
    local valid, units, hasText = utf8(name, true)
    if not valid or units > Core.MAX_NAME_UNITS or not hasText then return 'Event' end
    name = name:gsub('[%c#%%%[%]]', ' '):gsub('\194[\128-\159]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or 'Event'
end

return Core
