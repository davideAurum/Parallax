-- Rainmeter adapter. User labels never become Lua commands or executable state.
local Core, Store, state, store
local names, labels, cache = {}, {}, {}
local dirty, failed, retryTicks, recovery = false, false, 0, nil
local defaults = { 1500, 300, 900, 600, 240, 600, 1200, 1800, 60, 300, 600, 3600 }
local defaultLabels = { 'Deep work', 'Short break', 'Long break', 'Review', 'Tea', 'Stretch',
    'Walk', 'Reading', 'Timer one', 'Timer two', 'Timer three', 'Timer four' }
local defaultNames = { 'Focus', 'Daily', 'Custom' }

local function label(value, fallback)
    -- Rainmeter variable/section delimiters are reserved, not a label expression language.
    value = tostring(value or ''):gsub('[%c#%%%[%]]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value ~= '' and value or fallback
end

local function option(meter, key, value)
    value = tostring(value)
    local id = meter .. ':' .. key
    if cache[id] ~= value then
        cache[id] = value
        SKIN:Bang('!SetOption', meter, key, value)
    end
end

local function save()
    if not dirty then return end
    local ok, result = pcall(function() return store and Store.save(store, state) end)
    if ok and result then
        dirty, failed = false, false
    else
        if not failed then
            SKIN:Bang('!Log', 'Parallax Chronometer: state could not be saved. Check write access to Rainmeter settings directory.', 'Error')
        end
        failed = true
    end
    retryTicks = 0
end

local function paint(now, immediate)
    option('MeterList', 'Text', state.selected .. '/3  ' .. names[state.selected])
    local active, done, invalid = 0, 0, 0
    for _, timer in ipairs(state.timers) do
        if timer.status == 'running' then active = active + 1 end
        if timer.status == 'done' then done = done + 1 end
        if timer.status == 'disabled' then invalid = invalid + 1 end
    end
    for row = 1, Core.ROWS do
        local index = (state.selected - 1) * Core.ROWS + row
        local timer = state.timers[index]
        local status = timer.status
        option('MeterLabel' .. row, 'Text', labels[index])
        option('MeterState' .. row, 'Text', status == 'disabled' and 'Fix duration' or
            status == 'idle' and 'Ready' or status == 'running' and 'Running' or
            status == 'paused' and 'Paused' or 'Done')
        option('MeterState' .. row, 'FontColor', SKIN:GetVariable(status == 'done' and 'GoodColor' or
            status == 'disabled' and 'DangerColor' or status == 'running' and 'AccentColor' or 'MutedColor'))
        option('MeterTime' .. row, 'Text', status == 'disabled' and '--:--:--' or Core.format(Core.remaining(timer, now)))
        option('MeterToggle' .. row, 'Text', status == 'running' and 'Pause' or
            status == 'paused' and 'Resume' or status == 'done' and 'Again' or
            status == 'disabled' and '--' or 'Start')
    end
    local footer
    if failed then footer = 'NOT SAVED - see Rainmeter log'
    elseif recovery then footer = recovery
    elseif invalid > 0 then footer = invalid .. ' invalid duration(s) - edit lists'
    else footer = 'All lists: ' .. active .. ' running / ' .. done .. ' done' end
    option('MeterPersistence', 'Text', footer)
    option('MeterPersistence', 'FontColor', SKIN:GetVariable((failed or recovery or invalid > 0) and 'WarningColor' or 'MutedColor'))
    -- A normal Rainmeter update refreshes meters and redraws once after all
    -- measures finish. Only event-driven calls need an immediate extra pass.
    if immediate ~= false then
        SKIN:Bang('!UpdateMeterGroup', 'ChronometerData')
        SKIN:Bang('!Redraw')
    end
end

function Initialize()
    local root = SKIN:GetVariable('@') .. 'Modules\\Chronometer\\'
    Core, Store = dofile(root .. 'Core.lua'), dofile(root .. 'Store.lua')
    names, labels, cache = {}, {}, {}
    dirty, failed, retryTicks, recovery = false, false, 0, nil
    local durations = {}
    for list = 1, Core.LISTS do
        names[list] = label(SKIN:GetVariable('ChronometerList' .. list .. 'Name'), defaultNames[list])
        for row = 1, Core.ROWS do
            local i = (list - 1) * Core.ROWS + row
            local key = 'ChronometerList' .. list .. 'Timer' .. row
            labels[i] = label(SKIN:GetVariable(key .. 'Label'), defaultLabels[i])
            durations[i] = SKIN:GetVariable(key .. 'Seconds', tostring(defaults[i]))
        end
    end
    local path = SKIN:GetVariable('SETTINGSPATH')
    local saved, damaged
    if path and path ~= '' then
        store, saved, damaged = Store.open(path .. 'Parallax-Chronometer-v1', Core)
    else
        store = nil
    end
    state, dirty = Core.reconcile(saved, durations)
    if damaged then
        recovery = saved and 'Backup recovered - check timers' or 'State unreadable - timers reset'
        SKIN:Bang('!Log', 'Parallax Chronometer: ' .. recovery .. '. Runtime snapshots use a/b state files in the Rainmeter settings directory.', 'Warning')
    end
    if Core.tick(state, os.time()) then dirty = true end
    if not store then dirty = true end
    save()
    -- Meters may not exist during Initialize. The first Update paints them.
end

function Update()
    local now = os.time()
    local completed = Core.tick(state, now)
    if completed then dirty = true end
    if dirty then
        retryTicks = retryTicks + 1
        if completed or retryTicks >= 60 then save() end
    end
    paint(now, false)
    return 0
end

function Toggle(row)
    if type(row) ~= 'number' or row < 1 or row > Core.ROWS or row ~= math.floor(row) then return end
    if Core.toggle(state, (state.selected - 1) * Core.ROWS + row, os.time()) then
        dirty = true
        save()
        paint(os.time())
    end
end

function Reset(row)
    if type(row) ~= 'number' or row < 1 or row > Core.ROWS or row ~= math.floor(row) then return end
    if Core.reset(state, (state.selected - 1) * Core.ROWS + row) then
        dirty = true
        save()
        paint(os.time())
    end
end

function SelectList(step)
    if step ~= -1 and step ~= 1 then return end
    Core.select(state, step)
    dirty = true
    save()
    paint(os.time())
end
