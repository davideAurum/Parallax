-- Original, side-effect-free display model for cached UsageMonitor RAM rankings.
-- Alias=RAM, Rollup=1 supplies private working-set bytes grouped by process name.
local M = {}
local MAX_ROWS, MAX_NAME_BYTES, MAX_INTEGER = 5, 1024, 9007199254740991
local forbidden = {['#']=true, ['[']=true, [']']=true, ['%']=true,
    ['"']=true, ["'"]=true, ['!']=true, ['\\']=true}
local metricTip = 'Private working set is resident process memory excluding shared pages. '
    ..'Processes with the same counter name are combined. These rankings do not account for all physical RAM in use.'
local freshnessTip = 'UsageMonitor samples the Process category about once per second and exposes no separate freshness signal. '
    ..'Missing rankings can mean no active samples or unavailable counters; they are not measured zero.'

-- Rainmeter uses Lua 5.1. Validate UTF-8 and remove option/measure expansion syntax
-- before sending external process names to literal Text or ToolTipText options.
local function literalName(raw)
    if type(raw) ~= 'string' or #raw == 0 or #raw > MAX_NAME_BYTES then return nil end
    local out, i = {}, 1
    while i <= #raw do
        local first = raw:byte(i)
        local count, point, minimum
        if first < 128 then count, point, minimum = 1, first, 0
        elseif first >= 194 and first <= 223 then count, point, minimum = 2, first-192, 128
        elseif first >= 224 and first <= 239 then count, point, minimum = 3, first-224, 2048
        elseif first >= 240 and first <= 244 then count, point, minimum = 4, first-240, 65536
        else return nil end
        if i+count-1 > #raw then return nil end
        for j = 1, count-1 do
            local continuation = raw:byte(i+j)
            if continuation < 128 or continuation > 191 then return nil end
            point = point*64 + continuation-128
        end
        if point < minimum or point > 1114111 or (point >= 55296 and point <= 57343) then return nil end
        local character = raw:sub(i, i+count-1)
        local control = point < 32 or (point >= 127 and point <= 159)
            or (point >= 8203 and point <= 8207) or (point >= 8232 and point <= 8238)
            or (point >= 8294 and point <= 8297) or point == 65279
        out[#out+1] = (control or forbidden[character]) and ' ' or character
        i = i+count
    end
    local clean = table.concat(out):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if clean == '' or clean:lower() == '_total' or clean:lower() == 'idle' then return nil end
    return clean
end

local function validBytes(bytes)
    return type(bytes) == 'number' and bytes == bytes and bytes > 0
        and bytes <= MAX_INTEGER and bytes == math.floor(bytes)
end

function M.Format(samples, useMB, decimals)
    local unit, divisor = 'GB', 1000000000
    if tonumber(useMB) == 1 then unit, divisor = 'MB', 1000000 end
    decimals = tonumber(decimals) or 1
    if decimals ~= decimals or decimals == math.huge or decimals == -math.huge then decimals = 1 end
    decimals = math.max(0, math.min(2, math.floor(decimals)))
    local numberFormat = '%.'..decimals..'f'
    local result = {rows={}, state='', tip=''}
    if type(samples) == 'table' then
        -- Preserve the provider's descending rank order; never sum or re-rank
        -- separately read measures, which do not expose a common sample timestamp.
        for rank = 1, MAX_ROWS do
            local sample = samples[rank]
            if type(sample) == 'table' and validBytes(sample.bytes) then
                local name = literalName(sample.name)
                if name then
                    local value = sample.bytes/divisor
                    local text = string.format(numberFormat,value)
                    -- A positive reading below the selected display precision
                    -- must not look like an actual zero-byte measurement.
                    if text == string.format(numberFormat,0) then
                        text = '<'..string.format(numberFormat,10^(-decimals))
                    end
                    text = text..' '..unit
                    result.rows[#result.rows+1] = {
                        name=name, text=text,
                        tip=name..': '..text..' private working set ('
                            ..string.format('%.0f',sample.bytes)..(sample.bytes == 1 and ' byte). ' or ' bytes). ')..metricTip
                    }
                end
            end
        end
    end
    if #result.rows == 0 then result.state = 'No process data' end
    result.tip = metricTip..' '..freshnessTip..' '
        ..#result.rows..' of '..MAX_ROWS..' ranked entries are available. '
        ..'Decimal units: 1 '..unit..' = '..string.format('%.0f',divisor)..' bytes.'
    return result
end

return M
