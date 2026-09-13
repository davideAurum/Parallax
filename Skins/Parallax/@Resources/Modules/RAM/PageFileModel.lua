-- Original paging-file wire validation and decimal display formatting.
-- Values come from EnumPageFiles, never from commit accounting minus RAM.
local M = {}
local maxInteger, maxEpoch = 9007199254740991, 253402300799

local function integer(value, maximum)
    if type(value) ~= 'string' or #value == 0 or #value > 16
        or not value:match('^%d+$') or (#value > 1 and value:sub(1, 1) == '0') then return nil end
    local number = tonumber(value)
    if not number or number < 0 or number > maximum or number ~= math.floor(number) then return nil end
    return number
end

local function split(value)
    local result = {}
    for part in (value .. '|'):gmatch('(.-)|') do result[#result + 1] = part end
    return result
end

local function token(value)
    return type(value) == 'string' and #value == 32 and not value:find('[^0-9a-f]')
end

local function unhex(value)
    if type(value) ~= 'string' or #value == 0 or #value > 4096
        or #value % 2 ~= 0 or value:find('[^%x]') then return nil end
    local decoded = value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end)
    local offset = 1
    while offset <= #decoded do
        local first = decoded:byte(offset)
        local length, point, minimum
        if first < 128 then length, point, minimum = 1, first, 0
        elseif first >= 194 and first <= 223 then length, point, minimum = 2, first - 192, 128
        elseif first >= 224 and first <= 239 then length, point, minimum = 3, first - 224, 2048
        elseif first >= 240 and first <= 244 then length, point, minimum = 4, first - 240, 65536
        else return nil end
        for index = 1, length - 1 do
            local byte = decoded:byte(offset + index)
            if not byte or byte < 128 or byte > 191 then return nil end
            point = point * 64 + byte - 128
        end
        if point < minimum or point > 1114111 or (point >= 55296 and point <= 57343)
            or point < 32 or (point >= 127 and point <= 159) then return nil end
        offset = offset + length
    end
    return decoded
end

local function normalize(path) return path:gsub('/', '\\'):gsub('\\+$', ''):lower() end

function M.ParseSession(output, roots)
    if type(output) ~= 'string' or #output > 4200 then return nil end
    local fields = split(output)
    if #fields ~= 4 or fields[1] ~= 'RAM_PAGE_SESSION' or fields[2] ~= '1' or not token(fields[3]) then return nil end
    local path = unhex(fields[4])
    if not path or not path:match('^%a:[\\/]') then return nil end
    local expected = '\\Parallax-RAM-Page-' .. fields[3] .. '.dat'
    local matched = false
    for _, root in ipairs(roots or {}) do
        if type(root) == 'string' and root:match('^%a:[\\/]')
            and normalize(path) == normalize(normalize(root) .. expected) then matched = true end
    end
    if not matched then return nil end
    local base = path:sub(1, -5)
    return {token = fields[3], path = path, lease = base .. '.lease', tmp = base .. '.tmp'}
end

function M.Fresh(epoch, now, intervalMs)
    if type(epoch) ~= 'number' or type(now) ~= 'number' or type(intervalMs) ~= 'number'
        or epoch < 0 or epoch > maxEpoch or now < 0 or now > maxEpoch
        or epoch ~= math.floor(epoch) or now ~= math.floor(now)
        or intervalMs < 1000 or intervalMs > 30000 or intervalMs ~= math.floor(intervalMs) then return false end
    return epoch <= now + 5 and now - epoch <= math.max(8, math.ceil(3 * intervalMs / 1000) + 2)
end

function M.Parse(output, expectedToken, now, intervalMs, lastSequence, lastEpoch)
    if type(output) ~= 'string' or #output > 512 or not token(expectedToken) then return nil, 'invalid' end
    local fields = split(output)
    if #fields ~= 9 or fields[1] ~= 'RAM_PAGE' or fields[2] ~= '1' or fields[3] ~= expectedToken then return nil, 'invalid' end
    local sequence, epoch = integer(fields[4], maxInteger), integer(fields[5], maxEpoch)
    if not sequence or not epoch then return nil, 'invalid' end
    if not M.Fresh(epoch, now, intervalMs) then return nil, 'stale' end
    lastSequence, lastEpoch = lastSequence or -1, lastEpoch or 0
    if sequence < lastSequence or epoch < lastEpoch or (sequence == lastSequence and epoch ~= lastEpoch) then return nil, 'regressed' end
    local status = fields[6]
    local frame = {status = status, sequence = sequence, epoch = epoch}
    if status == 'OK' or status == 'NONE' then
        frame.used, frame.total, frame.count = integer(fields[7], maxInteger), integer(fields[8], maxInteger), integer(fields[9], 512)
        if not frame.used or not frame.total or not frame.count or frame.used > frame.total then return nil, 'invalid' end
        if status == 'NONE' then
            if frame.used ~= 0 or frame.total ~= 0 or frame.count ~= 0 then return nil, 'invalid' end
        elseif frame.count == 0 then return nil, 'invalid' end
    elseif status == 'STARTING' or status == 'UNAVAILABLE' or status == 'UNSUPPORTED' then
        if fields[7] ~= '?' or fields[8] ~= '?' or fields[9] ~= '?' then return nil, 'invalid' end
    else return nil, 'invalid' end
    return frame
end

function M.Format(frame, useMB, decimals)
    local status = frame and frame.status or 'UNAVAILABLE'
    if status == 'NONE' then
        return {text = 'No paging file', tip = 'Windows reports no installed paging files. Physical RAM and system commit accounting are separate.'}
    elseif status == 'STARTING' then
        return {text = 'Checking...', tip = 'Waiting for the Windows paging-file usage and allocated-capacity reading.'}
    elseif status == 'UNSUPPORTED' then
        return {text = 'Unsupported', tip = 'Windows paging-file enumeration is not supported in this environment.'}
    elseif status ~= 'OK' then
        return {text = 'Unavailable', tip = 'Windows paging-file usage and allocated capacity could not be read.'}
    end
    decimals = tonumber(decimals) or 1
    if decimals ~= decimals or decimals == math.huge or decimals == -math.huge then decimals = 1 end
    decimals = math.max(0, math.min(2, math.floor(decimals)))
    local mb = useMB == true or tonumber(useMB) == 1
    local divisor, unit = mb and 1000000 or 1000000000, mb and 'MB' or 'GB'
    local format = '%.' .. decimals .. 'f/%.' .. decimals .. 'f %s'
    return {
        text = string.format(format, frame.used / divisor, frame.total / divisor, unit),
        tip = string.format('Paging-file space in use / current allocated capacity across %d paging file%s. Used: %.0f bytes; allocated: %.0f bytes. Excludes physical RAM and system commit accounting. Allocated capacity can grow automatically.',
            frame.count, frame.count == 1 and '' or 's', frame.used, frame.total)
    }
end

return M
