-- Original shared Disk Meter naming helpers, Lua 5.1. No files or telemetry
-- queries are performed here. Format reads cached measures; Query is explicit.
local Names = {}
local modes = { letters = true, volume = true, model = true, both = true }
local maximumNameBytes, maximumPacketBytes = 512, 14000
-- One in-memory packet per loaded library. Public Parse stays pure; repeated
-- per-drive formatting shares this result until the provider string changes.
local packetRaw, packetModels, packetStatus

-- Walk complete UTF-8 characters where available. Rainmeter's ordinary Lua
-- bridge uses system ANSI; UTF-16-script callers use UTF-8. Keep both as data.
local function characters(value)
    local result, position = {}, 1
    while position <= #value do
        local first = value:byte(position)
        local length, code
        if first < 128 then length, code = 1, first
        elseif first >= 194 and first <= 223 then length, code = 2, first - 192
        elseif first >= 224 and first <= 239 then length, code = 3, first - 224
        elseif first >= 240 and first <= 244 then length, code = 4, first - 240
        else return nil end
        if position + length - 1 > #value then return nil end
        for offset = 1, length - 1 do
            local byte = value:byte(position + offset)
            if byte < 128 or byte > 191 then return nil end
            code = code * 64 + byte - 128
        end
        if (length == 3 and code < 2048) or (length == 4 and code < 65536)
            or (code >= 55296 and code <= 57343) or code > 1114111 then return nil end
        result[#result + 1] = { value:sub(position, position + length - 1), code }
        position = position + length
    end
    return result
end

local function clean(value)
    if type(value) ~= 'string' or #value > maximumPacketBytes then return '' end
    local units = characters(value)
    if not units then
        -- The local ANSI code page can be multibyte. Preserve its existing bytes
        -- but reject overlong values instead of cutting an unknown character.
        if #value > maximumNameBytes then return '' end
        return value:gsub('[%c#%%%[%]|]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    end
    local result, bytes = {}, 0
    for _, unit in ipairs(units) do
        local text, code = unit[1], unit[2]
        -- Neutralize option expansion, protocol separators, controls and common
        -- Unicode line/direction controls before Text or ToolTipText assignment.
        if code < 32 or (code >= 127 and code <= 159) or code == 35 or code == 37
            or code == 91 or code == 93 or code == 124 or code == 8206 or code == 8207
            or (code >= 8232 and code <= 8238) or (code >= 8294 and code <= 8297) then text = ' ' end
        if bytes + #text > maximumNameBytes then break end
        result[#result + 1], bytes = text, bytes + #text
    end
    return table.concat(result):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end

function Names.Parse(raw)
    if raw == nil or raw == '' then return {}, 'unavailable' end
    if type(raw) ~= 'string' or #raw > maximumPacketBytes then return {}, 'invalid' end
    raw = raw:gsub('\r\n', '\n')
    if raw:find('\r', 1, true) then return {}, 'invalid' end
    if raw:sub(-1) == '\n' then raw = raw:sub(1, -2) end
    local lines = {}
    for line in (raw .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = line end
    if lines[1] ~= 'IO_MODELS_V1' then return {}, 'invalid' end
    if lines[2] == 'UNAVAILABLE' and #lines == 2 then return {}, 'unavailable' end
    if lines[2] ~= 'OK' or #lines > 28 then return {}, 'invalid' end
    local models = {}
    for index = 3, #lines do
        local letter, model = lines[index]:match('^([A-Z])|(.*)$')
        if not letter or model == '' or #model > maximumNameBytes or models[letter]
            or clean(model) ~= model then return {}, 'invalid' end
        models[letter] = model
    end
    return models, 'ok'
end

local function measured(skin, name, method)
    local ok, value = pcall(function()
        local measure = skin:GetMeasure(name)
        return measure and measure[method](measure) or nil
    end)
    return ok and value or nil
end

function Names.Format(skin, letter, mode)
    if type(letter) ~= 'string' or not letter:match('^[A-Z]$') then return '', 'Drive unavailable.' end
    if not modes[mode] then mode = 'volume' end
    local kind = measured(skin, 'MeasureIOType' .. letter, 'GetValue')
    local present = type(kind) == 'number' and kind >= 3 and kind <= 7 and kind % 1 == 0
    if mode == 'letters' then return '', present and 'Drive letter only.' or 'Drive unavailable.' end
    local label = present and clean(measured(skin, 'MeasureIOName' .. letter, 'GetStringValue')) or ''
    local volumeStatus = label ~= '' and ('Volume label: ' .. label .. '.') or 'No label / unavailable.'
    if mode == 'volume' then return label ~= '' and label or 'No label / unavailable', volumeStatus end
    local raw = measured(skin, 'MeasureIOModelQuery', 'GetStringValue')
    if packetModels == nil or raw ~= packetRaw then
        packetModels, packetStatus = Names.Parse(raw)
        packetRaw = raw
    end
    local models, status = packetModels, packetStatus
    local model = present and models[letter] or nil
    local modelStatus = model and ('Windows device model/name: ' .. model .. '.') or 'Model unavailable.'
    if status == 'invalid' then modelStatus = modelStatus .. ' Invalid inventory response.' end
    modelStatus = modelStatus .. ' Cached on demand; refresh drives to update. Virtual/network volumes may not identify underlying hardware.'
    if mode == 'model' then return model or 'Model unavailable', modelStatus end
    if label ~= '' and model then return label .. ' / ' .. model, volumeStatus .. ' ' .. modelStatus end
    return label ~= '' and label or model or 'No label / unavailable; Model unavailable', volumeStatus .. ' ' .. modelStatus
end

function Names.Query(skin, mode)
    if mode ~= 'model' and mode ~= 'both' then return false end
    skin:Bang('!CommandMeasure', 'MeasureIOModelQuery', 'Run')
    return true
end

return Names
