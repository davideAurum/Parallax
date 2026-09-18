-- Parallax Welcome: the suite loader panel shown after installation.
-- Load state is read from Rainmeter's own settings file on explicit events only.
-- Nothing is polled, no provider is sampled, and the only writes are Rainmeter's
-- own config activation, performed through !ActivateConfig / !DeactivateConfig.

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

function Initialize()
    -- Rainmeter's own built-in path, read the same way Chronometer reads it.
    -- A user variable indirection is not used: it is not expanded for scripts.
    local path = SKIN:GetVariable('SETTINGSPATH')
    settingsFile = (path ~= nil and path ~= '' and path .. 'Rainmeter.ini') or nil
    rendered = false
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
function Render(optimistic)
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
    SKIN:Bang('!SetOption', 'MeterWelcomeStatus', 'Text', status)
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
