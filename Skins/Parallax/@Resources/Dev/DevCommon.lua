-- Developer copy: the parts DevStatus.lua (the icon in each dev utility) and
-- DevPanel.lua (Global Settings > Developer) share. Pure functions, no SKIN calls,
-- so the offline suite (tests/DevSuite.lua) runs them as they are.
local M = {}

M.MONITORS = { 'Chronometer', 'CPU', 'GPU', 'IO', 'Media', 'Network', 'RAM', 'Visualizer' }

local monitorSet = {}
for _, name in ipairs(M.MONITORS) do monitorSet[name] = true end

-- @Resources\Dev\Status.inc -> { key = number }. Only DevComparedAt, DevReleaseVersion
-- and the DevDiff* counts are read; everything else is ignored. nil for no text.
function M.parseStatus(text)
    if type(text) ~= 'string' then return nil end
    local values = {}
    for key, value in text:gmatch('([%w_]+)=([^\r\n]*)') do
        if key == 'DevReleaseVersion' or key == 'DevBaseVersion' then
            values[key] = value:gsub('^%s+', ''):gsub('%s+$', '')
        elseif key:match('^Dev') then
            values[key] = tonumber(value)
        end
    end
    return values
end

-- 'differ', 'same' or 'unknown' for one utility. A shared file counts for every
-- utility; a copy that was never compared, or whose counts are missing, is unknown
-- rather than a green icon.
function M.stateFor(status, module)
    if type(status) ~= 'table' then return 'unknown' end
    if (status.DevComparedAt or 0) <= 0 then return 'unknown' end
    local own, shared = status['DevDiff' .. tostring(module)], status.DevDiffShared
    if own == nil or shared == nil then return 'unknown' end
    if own > 0 or shared > 0 then return 'differ' end
    return 'same'
end

-- How many utilities differ (own or shared changes), for the settings status line.
function M.differingUtilities(status)
    if type(status) ~= 'table' or (status.DevComparedAt or 0) <= 0 then return nil end
    local shared = status.DevDiffShared or 0
    local count = 0
    for _, name in ipairs(M.MONITORS) do
        local own = status['DevDiff' .. name]
        if own == nil then return nil end
        if own > 0 or shared > 0 then count = count + 1 end
    end
    return count
end

-- 'ParallaxDev' -> 'Parallax'; anything else is returned as it is.
function M.releaseName(rootConfig)
    local base = tostring(rootConfig or ''):match('^(.+)Dev$')
    return base or tostring(rootConfig or '')
end

-- Output of DevMode.ps1 (read as data): the RESULT line and any CONFIG lines. A
-- CONFIG entry is accepted only when it names one of the suite's utilities inside
-- the copy's own root config and a plain .ini file; coordinates are integers or '-'.
function M.parseResult(output, devRoot)
    local result = { ok = false, configs = {} }
    local seen = false
    for line in tostring(output or ''):gmatch('[^\r\n]+') do
        local fields = {}
        for field in (line .. '|'):gmatch('([^|]*)|') do fields[#fields + 1] = field end
        if fields[1] == 'RESULT' and (fields[2] == 'OK' or fields[2] == 'ERR') then
            seen = true
            if fields[2] == 'OK' then
                result.ok, result.action = true, fields[3]
                result.changed, result.differing, result.detail = tonumber(fields[4]), tonumber(fields[5]), fields[6] or ''
            else
                result.ok, result.code, result.message = false, fields[3] or 'Failed', fields[4] or ''
            end
        elseif fields[1] == 'CONFIG' and #fields == 5 then
            local config, file, x, y = fields[2], fields[3], fields[4], fields[5]
            local root, name = config:match('^(%w+)\\(%a+)$')
            if root and root == devRoot and monitorSet[name] and file:match('^[%w_%-]+%.ini$')
                and (x == '-' or x:match('^%-?%d+$')) and (y == '-' or y:match('^%-?%d+$')) then
                result.configs[#result.configs + 1] = {
                    config = config, file = file, x = tonumber(x), y = tonumber(y), module = name }
            end
        end
    end
    if not seen then result.ok, result.code, result.message = false, 'NoResult', 'The helper reported nothing.' end
    return result
end

-- The RunCommand parameter string. Paths are rejected when they hold a quote; the
-- Skins path gets a trailing '.' so a quoted argument never ends in a backslash.
function M.commandArguments(root, skinsPath, release, action, settingsPath, extra)
    for _, value in ipairs({ root, skinsPath, release, action, settingsPath or '' }) do
        if tostring(value):find('"', 1, true) then return nil end
    end
    if not tostring(action):match('^%a+$') or not tostring(release):match('^[%w%._ %-]+$') then return nil end
    local args = string.format(
        '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sDev\\DevMode.ps1" -Action %s -SkinsPath "%s." -Release "%s"',
        root, action, skinsPath, release)
    if settingsPath and settingsPath ~= '' then args = args .. string.format(' -SettingsPath "%s."', settingsPath) end
    return args .. (extra and (' ' .. extra) or '')
end

-- The helper's progress file: one line, "<phase>|<done>|<total>". Nil for anything else.
function M.parseProgress(text)
    if type(text) ~= 'string' then return nil end
    local phase, done, total = text:match('^%s*(%a+)|(%d+)|(%d+)')
    if not phase then return nil end
    return phase, tonumber(done), tonumber(total)
end

-- How far through its own work the helper is, 0 to 1, from the phase it last reported: the
-- clone counts files; the later phases are markers, not measurements.
function M.helperFraction(phase, done, total)
    if phase == 'build' and total and total > 0 then return 0.05 + 0.75 * math.min(1, done / total) end
    if phase == 'compare' then return 0.85 end
    if phase == 'list' then return 0.95 end
    return 0
end

-- One bar for a whole action. Each flow is its stages in order with a share of the bar each;
-- the stage in progress reports a fraction of its own share.
M.FLOWS = {
    enable = { { 'helper', 0.6 }, { 'load', 0.4 } },
    disable = { { 'helper', 0.4 }, { 'unload', 0.6 } },
    resetOn = { { 'unload', 0.2 }, { 'helper', 0.6 }, { 'load', 0.2 } },
    reset = { { 'helper', 1 } },
    compare = { { 'helper', 1 } },
}

function M.overall(flow, stage, fraction)
    local stages = M.FLOWS[flow]
    if not stages then return 0 end
    fraction = math.max(0, math.min(1, fraction or 0))
    local before = 0
    for _, entry in ipairs(stages) do
        if entry[1] == stage then return before + entry[2] * fraction end
        before = before + entry[2]
    end
    return 0
end

-- Clock text for the status line, from a unix time.
function M.clock(stamp, format)
    if not stamp or stamp <= 0 then return nil end
    return os.date(format or '%H:%M', stamp)
end

return M
