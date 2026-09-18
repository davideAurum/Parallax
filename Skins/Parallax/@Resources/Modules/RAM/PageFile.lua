-- Original paging-file reader bridge. Two setup-time launches, then one
-- resident Windows API host; display/settings updates never launch a poller.
local model, state, interval, deadline, session, cached, reason, previous, measures
local lastSequence, lastEpoch, lastLease, lastWire, launched
local bootstrap, host = 'MeasureRAMPageBootstrap', 'MeasureRAMPageHost'
local targets = {'MeterRAMPageLabel', 'MeterRAMPageGiB', 'MeterRAMPageMiB', 'MeterRAMPageBar'}

local function measure(name)
    if not measures[name] then measures[name] = SKIN:GetMeasure(name) end
    return measures[name]
end
local function status(name) local item = measure(name); return item and item:GetValue() or 103 end
local function output(name) local item = measure(name); return item and tostring(item:GetStringValue() or '') or '' end
local function set(name, option, value)
    local key = name .. ':' .. option
    if previous[key] == value then return false end
    previous[key] = value
    SKIN:Bang('!SetOption', name, option, value)
    return true
end

function Display(immediate)
    local frame, detail = cached, reason
    if frame and frame.epoch and not model.Fresh(frame.epoch, os.time(), interval) then
        frame, detail = nil, 'The paging-file sample is stale. Refresh Memory Meter if readings do not resume.'
    end
    local dirty = false
    local useMB = tonumber(SKIN:GetVariable('RAMUseMiB')) == 1
    local decimals = tonumber(SKIN:GetVariable('RAMDecimals')) or 1
    local ratio = frame and frame.status == 'OK' and frame.total > 0 and frame.used / frame.total or nil
    if set('MeasureRAMPageRatio', 'Formula', string.format('%.15f', ratio or 0)) then
        SKIN:Bang('!UpdateMeasure', 'MeasureRAMPageRatio')
        dirty = true
    end
    local showBar = tonumber(SKIN:GetVariable('RAMShowPageBar')) == 1 and ratio ~= nil
    dirty = set('MeterRAMPageBar', 'Hidden', showBar and '0' or '1') or dirty
    for _, entry in ipairs({{'MeterRAMPageGiB', false}, {'MeterRAMPageMiB', true}}) do
        local formatted = model.Format(frame, entry[2], decimals)
        local tip = detail or formatted.tip
        dirty = set(entry[1], 'Text', formatted.text) or dirty
        dirty = set(entry[1], 'ToolTipText', tip) or dirty
        dirty = set(entry[1], 'Hidden', entry[2] == useMB and '0' or '1') or dirty
        if entry[2] == useMB then
            dirty = set('MeterRAMPageLabel', 'ToolTipText', tip) or dirty
            dirty = set('MeterRAMPageBar', 'ToolTipText', tip) or dirty
        end
    end
    if dirty and immediate ~= false then
        for _, name in ipairs(targets) do SKIN:Bang('!UpdateMeter', name) end
        SKIN:Bang('!Redraw')
    end
end

local function cleanup()
    if session then
        os.remove(session.lease)
        os.remove(session.path)
        os.remove(session.tmp)
        session = nil
    end
end

local function stopProcesses()
    for _, name in ipairs({bootstrap, host}) do
        if launched[name] then
            -- RunCommand runs at 0 and starts at -1; the skin may also expose
            -- an unlaunched cached 0. Track launches and refresh before deciding.
            SKIN:Bang('!UpdateMeasure', name)
            local current = status(name)
            launched[name] = nil
            if current == 0 then SKIN:Bang('!CommandMeasure', name, 'Kill') end
        end
    end
end

local function fail(detail)
    state, cached, reason = 'failed', nil, detail .. ' Refresh Memory Meter to retry.'
    stopProcesses()
    cleanup()
    Display()
end

local function launch(name, invocation)
    -- Only fixed methods and validated hex/integer arguments enter this command.
    local parameter = '-NoLogo -NoProfile -NonInteractive -Command "'
        .. "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; try { "
        .. "Add-Type -TypeDefinition ([IO.File]::ReadAllText('PageFileHost.cs.txt')); "
        .. invocation .. " } catch { [Console]::Write('RAM_PAGE_FAILED') }\""
    SKIN:Bang('!SetOption', name, 'Parameter', parameter)
    SKIN:Bang('!UpdateMeasure', name)
    launched[name] = true
    SKIN:Bang('!CommandMeasure', name, 'Run')
end

local function heartbeat(now)
    if now >= lastLease and now - lastLease < 5 then return true end
    local file = io.open(session.lease, 'wb')
    if not file then return false end
    local written = file:write(session.token .. '|' .. tostring(now))
    local closed = file:close()
    if not written or not closed then return false end
    lastLease = now
    return true
end

function Initialize()
    model = dofile(SKIN:GetVariable('@') .. 'Modules\\RAM\\PageFileModel.lua')
    state, session, cached, reason, previous, measures = 'idle', nil, {status = 'STARTING'}, nil, {}, {}
    lastSequence, lastEpoch, lastLease, lastWire = -1, 0, -1, nil
    launched = {}
    interval = tonumber(SKIN:GetVariable('MetricsInterval')) or 1000
    if interval ~= interval or interval == math.huge or interval == -math.huge then interval = 1000 end
    interval = math.max(1000, math.min(30000, math.floor(interval)))
end

function Start()
    if state ~= 'idle' then return end
    state, deadline = 'bootstrap', os.time() + 20
    launch(bootstrap, '[Console]::Write([ParallaxRamPageFile]::CreateSession(' .. interval .. '))')
    Display()
end

local function readFrame(now)
    local file = io.open(session.path, 'rb')
    if not file then
        cached = now < deadline and {status = 'STARTING'} or nil
        reason = now >= deadline and 'The paging-file reader has not published a sample.' or nil
        return
    end
    local wire = file:read(513)
    file:close()
    local frame, issue = model.Parse(wire, session.token, now, interval, lastSequence, lastEpoch)
    if not frame or (frame.sequence == lastSequence and lastWire and wire ~= lastWire) then
        cached = nil
        reason = issue == 'stale' and 'The paging-file sample is stale.' or 'The paging-file sample is invalid or out of sequence.'
        return
    end
    cached, reason, lastSequence, lastEpoch, lastWire = frame, nil, frame.sequence, frame.epoch, wire
end

function Update()
    local now = os.time()
    if state == 'bootstrap' then
        local current = status(bootstrap)
        if current == 1 then
            launched[bootstrap] = nil
            local roots = {}
            for _, key in ipairs({'TMP', 'TEMP'}) do
                local root = os.getenv(key)
                if root then roots[#roots + 1] = root end
            end
            session = model.ParseSession(output(bootstrap), roots)
            if not session then fail('The paging-file session response was invalid.'); return 0 end
            if not heartbeat(now) then fail('The paging-file session lease could not be written.'); return 0 end
            state, deadline = 'running', now + 20
            launch(host, "[ParallaxRamPageFile]::Run('" .. session.token .. "'," .. interval .. ')')
        elseif current >= 100 or now >= deadline then
            fail('The paging-file reader could not start.'); return 0
        end
    elseif state == 'running' then
        local current = status(host)
        if current == 1 or current >= 100 then fail('The paging-file reader stopped.'); return 0 end
        if not heartbeat(now) then fail('The paging-file session lease was lost.'); return 0 end
        readFrame(now)
    end
    if state ~= 'stopped' then Display(false) end
    return 0
end

function Stop()
    state = 'stopped'
    stopProcesses()
    cleanup()
end
