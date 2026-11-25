-- Parallax Welcome: the suite loader panel shown after installation.
-- Load state is read from Rainmeter's own settings file on explicit events only.
-- Nothing is polled, no provider is sampled, and the only writes are Rainmeter's
-- own config activation, performed through !ActivateConfig / !DeactivateConfig,
-- and the panel positions Rainmeter records when Arrange or Undo moves them.

local settingsFile
local rendered = false

-- Each entry names a shipped config, the skin file inside it, and that file's
-- 1-based position among the .ini files in the config folder. Rainmeter records
-- the loaded file as Active=<position> under a [<config>] section in its
-- settings file. Media.ini is the first of Media's two skin files (Media.ini,
-- Setup.ini); every other config here ships a single .ini. Adding an
-- alphabetically earlier .ini to any of these folders changes its position and
-- must be reflected here.
local components = {
    { key = 'Chronometer', config = 'Parallax\\Chronometer', file = 'Chronometer.ini', position = 1 },
    { key = 'CPU',         config = 'Parallax\\CPU',         file = 'CPU.ini',         position = 1 },
    { key = 'RAM',         config = 'Parallax\\RAM',         file = 'RAM.ini',         position = 1 },
    { key = 'GPU',         config = 'Parallax\\GPU',         file = 'GPU.ini',         position = 1 },
    { key = 'IO',          config = 'Parallax\\IO',          file = 'IO-Disk.ini',     position = 1 },
    { key = 'Network',     config = 'Parallax\\Network',     file = 'Network.ini',     position = 1 },
    { key = 'Media',       config = 'Parallax\\Media',       file = 'Media.ini',       position = 1 },
    { key = 'Visualizer',  config = 'Parallax\\Visualizer',  file = 'Visualizer.ini',  position = 1 },
    { key = 'Settings',    config = 'Parallax\\Settings',    file = 'Settings.ini',    position = 1 }
}

local byKey = {}
for slot, entry in ipairs(components) do
    entry.slot = slot
    byKey[entry.key] = entry
end

-- Arrange uses the first placement's columns (Geometry.inc), from the right,
-- with the panels' real sizes: more threads, drives or an open queue make a
-- panel larger than the first placement allows for.
local columnOrder = {
    { 'CPU' }, { 'GPU', 'IO', 'Chronometer' }, { 'Network', 'RAM' },
    { 'Visualizer', 'Media', 'Welcome' }, { 'Settings' }
}
local CROWDED_STEP = 30
local answers -- while Arrange asks: key -> { x, y, w, h }
local before  -- what Undo puts back: key -> { x, y }

function Initialize()
    -- Rainmeter's own built-in path, read the same way Chronometer reads it.
    -- A user variable indirection is not used: it is not expanded for scripts.
    local path = SKIN:GetVariable('SETTINGSPATH')
    settingsFile = (path ~= nil and path ~= '' and path .. 'Rainmeter.ini') or nil
    rendered = false
    answers, before = nil, nil
end

-- Rainmeter writes its settings file as UTF-16LE; generated test profiles are
-- UTF-8. Only ASCII section names and keys are matched, so non-ASCII characters
-- become a placeholder byte instead of being decoded.
local function decode(data)
    if data:sub(1, 2) == '\255\254' then
        local out, count = {}, 0
        for i = 3, #data - 1, 2 do
            local low, high = data:byte(i), data:byte(i + 1)
            count = count + 1
            out[count] = (high == 0 and low < 128) and string.char(low) or '\1'
        end
        return table.concat(out)
    end
    if data:sub(1, 3) == '\239\187\191' then return data:sub(4) end
    return data
end

-- Returns config name (lowercase) -> Active value, or nil when the settings
-- file is missing or unreadable. A missing Active key counts as inactive.
local function readActive()
    if not settingsFile then return nil end
    local file = io.open(settingsFile, 'rb')
    if not file then return nil end
    local data = file:read(4 * 1024 * 1024)
    file:close()
    if not data or data == '' then return nil end
    local active, section = {}, nil
    for line in decode(data):gmatch('[^\r\n]+') do
        local name = line:match('^%s*%[(.-)%]%s*$')
        if name then
            section = name:lower()
        elseif section then
            local key, value = line:match('^%s*([^=]-)%s*=%s*(.-)%s*$')
            if key and key:lower() == 'active' then active[section] = tonumber(value) or 0 end
        end
    end
    return active
end

local function loadedSet()
    local active = readActive()
    if not active then return nil end
    local loaded = {}
    for _, entry in ipairs(components) do
        loaded[entry.key] = active[entry.config:lower()] == entry.position
    end
    return loaded
end

-- optimistic is an optional key -> boolean table applied to this render only.
-- It shows the intent of a click immediately; the next event shows the state
-- Rainmeter actually recorded, so a failed activation cannot stay on screen.
-- message replaces the status line for this render in the same way.
function Render(optimistic, message)
    rendered = true
    local loaded = loadedSet()
    local count = 0
    for _, entry in ipairs(components) do
        local on = loaded ~= nil and loaded[entry.key] or false
        if optimistic ~= nil and optimistic[entry.key] ~= nil then on = optimistic[entry.key] end
        if on then count = count + 1 end
        SKIN:Bang(on and '!ShowMeter' or '!HideMeter', 'MeterWelcomeCheck' .. entry.slot)
        SKIN:Bang('!SetOption', 'MeterWelcomeName' .. entry.slot, 'FontColor',
            SKIN:GetVariable(on and 'TextColor' or 'MutedColor'))
    end
    local status
    if loaded ~= nil then
        status = string.format('%d of %d components loaded.', count, #components)
    else
        status = 'Rainmeter settings are not readable; check marks show clicks only.'
    end
    SKIN:Bang('!SetOption', 'MeterWelcomeStatus', 'Text', message or status)
    SKIN:Bang('!UpdateMeterGroup', 'WelcomeRows')
    SKIN:Bang('!UpdateMeter', 'MeterWelcomeStatus')
    SKIN:Bang('!Redraw')
    return true
end

-- Update=-1 skins still receive one measure update when loaded or refreshed.
-- OnRefreshAction renders as well; this only guarantees a first paint.
function Update()
    if not rendered then Render() end
    return 0
end

function Toggle(key)
    local entry = byKey[key]
    if not entry then return false end
    local loaded = loadedSet()
    local on = loaded ~= nil and loaded[entry.key] or false
    if on then
        SKIN:Bang('!DeactivateConfig', entry.config)
    else
        SKIN:Bang('!ActivateConfig', entry.config, entry.file)
    end
    return Render({ [entry.key] = not on })
end

function LoadAll()
    local loaded = loadedSet()
    local optimistic = {}
    for _, entry in ipairs(components) do
        -- With no readable state every config is activated; Rainmeter reloads an
        -- already-loaded config rather than reporting an error.
        if loaded == nil or not loaded[entry.key] then
            SKIN:Bang('!ActivateConfig', entry.config, entry.file)
        end
        optimistic[entry.key] = true
    end
    return Render(optimistic)
end

function UnloadAll()
    local loaded = loadedSet()
    -- Deactivating a config that is not loaded logs an error, so an unknown
    -- state unloads nothing and leaves the status line to explain why.
    if loaded == nil then return Render() end
    local optimistic = {}
    for _, entry in ipairs(components) do
        if loaded[entry.key] then SKIN:Bang('!DeactivateConfig', entry.config) end
        optimistic[entry.key] = false
    end
    return Render(optimistic)
end

-- A panel's answer to ask(), sent by its MeasureParallaxPlace (Geometry.inc).
function Placed(slot, x, y, w, h)
    local entry = components[slot]
    if answers and entry and w > 0 and h > 0 then
        answers[entry.key] = { x = x, y = y, w = w, h = h }
    end
end

local function running(active, entry)
    return (active[entry.config:lower()] or 0) > 0
end

-- Where every loaded panel is and how large. Rainmeter runs each answer before
-- its !UpdateMeasure returns. A panel that gives none is left where it is.
local function ask(active)
    answers = {}
    for slot, entry in ipairs(components) do
        if running(active, entry) then
            for _, value in ipairs({ tostring(slot), '0' }) do
                SKIN:Bang('!SetVariable', 'ParallaxPlaceAsked', value, entry.config)
                SKIN:Bang('!UpdateMeasure', 'MeasureParallaxPlace', entry.config)
            end
        end
    end
    local panels = answers
    answers = nil
    panels.Welcome = { x = SKIN:GetX(), y = SKIN:GetY(), w = SKIN:GetW(), h = SKIN:GetH() }
    return panels
end

-- The work area of the screen the middle of this panel is on, else the primary.
local function workArea(panel)
    local function area(name, screen)
        local x, y = tonumber(SKIN:GetVariable(name .. 'X' .. screen)), tonumber(SKIN:GetVariable(name .. 'Y' .. screen))
        local w, h = tonumber(SKIN:GetVariable(name .. 'WIDTH' .. screen)), tonumber(SKIN:GetVariable(name .. 'HEIGHT' .. screen))
        return x and y and w and h and { x = x, y = y, w = w, h = h } or nil
    end
    local middleX, middleY = panel.x + panel.w / 2, panel.y + panel.h / 2
    for number = 1, 32 do
        local screen = area('WORKAREA', '@' .. number)
        if not screen then break end
        if middleX >= screen.x and middleX < screen.x + screen.w
            and middleY >= screen.y and middleY < screen.y + screen.h then return screen end
    end
    return area('PWORKAREA', '')
end

-- key -> { x, y }, and how many panels the screen has no room for. Those step
-- down from its top left, where they overlap others but keep their titles visible.
local function layout(panels, screen)
    local edge, bottom = screen.x + screen.w, screen.y + screen.h
    local opened, later, places, crowded = {}, {}, {}, 0
    local function open(width)
        local column = { right = edge, width = width, next = screen.y }
        edge = edge - width
        opened[#opened + 1] = column
        return column
    end
    local function stack(column, key)
        places[key] = { x = column.right - panels[key].w, y = column.next }
        column.next = column.next + panels[key].h
    end
    local function fits(column, key)
        return column.next == screen.y or column.next + panels[key].h <= bottom
    end
    for _, keys in ipairs(columnOrder) do
        local width = 0
        for _, key in ipairs(keys) do
            if panels[key] then width = math.max(width, panels[key].w) end
        end
        local column = width > 0 and edge - width >= screen.x and open(width) or nil
        for _, key in ipairs(keys) do
            if panels[key] then
                if column and fits(column, key) then stack(column, key) else later[#later + 1] = key end
            end
        end
    end
    for _, key in ipairs(later) do
        local found
        for _, column in ipairs(opened) do
            if not found and column.width >= panels[key].w and fits(column, key) then found = column end
        end
        if not found and edge - panels[key].w >= screen.x then found = open(panels[key].w) end
        if found then
            stack(found, key)
        else
            places[key] = { x = screen.x + crowded * CROWDED_STEP, y = screen.y + crowded * CROWDED_STEP }
            crowded = crowded + 1
        end
    end
    return places, crowded
end

local function move(key, place)
    local x, y = string.format('%d', place.x), string.format('%d', place.y)
    if key == 'Welcome' then SKIN:Bang('!Move', x, y) else SKIN:Bang('!Move', x, y, byKey[key].config) end
end

-- Moves every loaded panel to its column on this panel's screen.
function Arrange()
    local active = readActive()
    if not active then return Render() end
    local panels = ask(active)
    local screen = workArea(panels.Welcome)
    if not screen then return Render(nil, 'The screen size is not readable; nothing was moved.') end
    local places, crowded = layout(panels, screen)
    local count = 0
    before = {}
    for key, place in pairs(places) do
        before[key] = { x = panels[key].x, y = panels[key].y }
        move(key, place)
        count = count + 1
    end
    SKIN:Bang('!ShowMeter', 'MeterWelcomeUndo')
    local message = string.format('%d panels arranged. Undo puts them back.', count)
    if crowded > 0 then message = string.format('%d panels arranged, %d overlapping: the screen is full.', count, crowded) end
    return Render(nil, message)
end

-- Puts back every panel Arrange moved that is still loaded.
function Undo()
    local active = readActive()
    if not before or not active then return Render() end
    local count = 0
    for key, place in pairs(before) do
        if key == 'Welcome' or running(active, byKey[key]) then
            move(key, place)
            count = count + 1
        end
    end
    before = nil
    SKIN:Bang('!HideMeter', 'MeterWelcomeUndo')
    return Render(nil, string.format('%d panels put back.', count))
end
