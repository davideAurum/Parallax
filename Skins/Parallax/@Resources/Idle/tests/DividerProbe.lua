-- Staged-only divider and value probe for Test-IdleStandDown.ps1. The harness
-- appends it to a staged copy of a utility entrypoint (never to a shipped
-- file) as [MeasureParallaxDividerProbe], UpdateDivider=1, in no group, so it
-- runs every tick while the skin is paused. Options:
--   ProbeMeters    file: one meter name per line (static extraction of every
--                  meter in the resolved entrypoint)
--   ProbeMeasures  file: one measure name per line (ParallaxIdlePause members)
--   ProbeLog       file appended with one record per line:
--     L|clock|load                         this load started
--     Y|clock|sync                         first ParallaxIdleSync=1 of the load
--     H|clock|0 or 1                       MeterParallaxPaused Hidden changed
--     S|clock|tag|meter|divider            snapshot: each meter's effective
--                                          UpdateDivider (own option, then its
--                                          MeterStyle, else the skin default)
--     V|clock|hidden|digest|changed        measure values each tick: a digest
--                                          of every listed measure's string
--                                          value, and how many changed
--   ProbeDefault   formula for the skin's DefaultUpdateDivider (default 1)
-- Snapshot(tag) can also be called with !CommandMeasure.
local meters, measures, logPath, defaultDivider
local lastHidden, synced, last

local function lines(path)
    local list = {}
    local file = path ~= '' and io.open(path, 'rb') or nil
    if not file then return list end
    for line in (file:read('*a') or ''):gmatch('[^\r\n]+') do list[#list + 1] = line end
    file:close()
    return list
end

local function log(text)
    local file = io.open(logPath, 'ab')
    if not file then return end
    file:write(string.format('%s|%.3f|%s\n', text:sub(1, 1), os.clock(), text:sub(3)))
    file:close()
end

local function effective(meter)
    local value = meter:GetOption('UpdateDivider', '')
    if value == '' then return defaultDivider end
    local number = tonumber(value) or SKIN:ParseFormula(value)
    return tonumber(number) or value
end

function Snapshot(tag)
    local out = {}
    for _, name in ipairs(meters) do
        local meter = SKIN:GetMeter(name)
        out[#out + 1] = string.format('S|%.3f|%s|%s|%s', os.clock(), tag, name, meter and tostring(effective(meter)) or 'missing')
    end
    local file = io.open(logPath, 'ab')
    if file then file:write(table.concat(out, '\n') .. '\n'); file:close() end
end

function Initialize()
    meters = lines(SELF:GetOption('ProbeMeters', ''))
    measures = lines(SELF:GetOption('ProbeMeasures', ''))
    logPath = SELF:GetOption('ProbeLog', '')
    defaultDivider = tonumber(SKIN:ParseFormula(SELF:GetOption('ProbeDefault', '1'))) or 1
    lastHidden, synced, last = nil, false, {}
    log('L|load')
end

function Update()
    if not synced and SKIN:GetVariable('ParallaxIdleSync', '0') == '1' then
        synced = true
        log('Y|sync')
    end
    local paused = SKIN:GetMeter('MeterParallaxPaused')
    local hidden = paused and paused:GetOption('Hidden', '1') or 'none'
    if hidden ~= lastHidden then
        lastHidden = hidden
        log('H|' .. hidden)
        Snapshot(hidden == '0' and 'enter' or 'live')
    end
    local digest, changed = 0, 0
    for index, name in ipairs(measures) do
        local measure = SKIN:GetMeasure(name)
        local value = measure and measure:GetStringValue() or ''
        if last[index] ~= nil and last[index] ~= value then changed = changed + 1 end
        last[index] = value
        for at = 1, #value do digest = (digest * 31 + value:byte(at)) % 2147483647 end
    end
    log(string.format('V|%s|%d|%d', hidden, digest, changed))
    return 0
end
