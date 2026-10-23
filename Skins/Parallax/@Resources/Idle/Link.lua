-- Parallax idle link: the consumer side of the Parallax\Idle coordinator, and
-- the bounded file readers the coordinator shares. Loaded with dofile() by a
-- consumer script, so it sees only the standard libraries of that script's
-- Lua state: the caller passes its own SKIN to Link.new(). It never polls,
-- launches a process or writes a file. docs/ARCHITECTURE.md describes the
-- protocol; the coordinator is @Resources\Idle\Coordinator.lua.
--
-- Joining (once per consumer load, plus one re-join per 10 minutes):
--   * nothing at all if Idle\Idle.ini is missing (an !ActivateConfig for a
--     missing file would open a modal) or Rainmeter.ini cannot be read;
--   * a silent group request (!UpdateMeasureGroup ParallaxIdleSyncRequest *)
--     when Rainmeter.ini already records the coordinator active: only the
--     coordinator has a measure in that group, and a group update with no
--     members logs nothing;
--   * otherwise !ActivateConfig "<root>\Idle" "Idle.ini". The coordinator's
--     Start() then broadcasts from its OnRefreshAction, inside this call.
-- A consumer never sends !CommandMeasure into Parallax\Idle: when that config
-- exists but is not active, Rainmeter logs a warning.
--
-- Call join() only after the load's own first update: from the delayed
-- [!Delay 100][!UpdateMeasureGroup ParallaxIdleJoin] in OnRefreshAction or a
-- later regular update. During Rainmeter's startup walk a consumer that loads
-- before Parallax\Idle would otherwise activate it, and the walk would then
-- activate it again (an "already active" warning), or ask a coordinator
-- that does not exist yet.

local Link = {}

Link.REJOIN_SECONDS = 600
Link.SETTINGS_LIMIT = 4194304

-- Bounded ASCII view of a text file, or nil when it cannot be read or is
-- larger than limit. UTF-16 (either byte order) and a UTF-8 BOM are accepted;
-- non-ASCII code units read as '?', which no section, key or value looked for
-- here contains. Rainmeter writes Rainmeter.ini as UTF-16LE.
function Link.readText(path, limit)
    if type(path) ~= 'string' or path == '' then return nil end
    local ok, file = pcall(io.open, path, 'rb')
    if not ok or not file then return nil end
    local readOk, contents = pcall(file.read, file, limit + 1)
    pcall(file.close, file)
    if not readOk or type(contents) ~= 'string' or #contents > limit then return nil end
    local bom = contents:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        local ascii, little = {}, bom == '\255\254'
        for at = 3, #contents - 1, 2 do
            local a, b = contents:byte(at, at + 1)
            local code = little and a + 256 * b or b + 256 * a
            ascii[#ascii + 1] = code < 128 and string.char(code) or '?'
        end
        return table.concat(ascii)
    end
    return (contents:gsub('^\239\187\191', ''))
end

-- Whether a file exists and can be opened for reading.
function Link.exists(path)
    if type(path) ~= 'string' or path == '' then return false end
    local ok, file = pcall(io.open, path, 'rb')
    if not ok or not file then return false end
    pcall(file.close, file)
    return true
end

-- The wanted keys (lower-case names) of one section: values, sectionFound.
-- nil when the file cannot be read. A repeated wanted key keeps the first.
function Link.readSection(path, limit, name, wanted)
    local contents = Link.readText(path, limit)
    if not contents then return nil end
    local values, inSection, found = {}, false, false
    name = name:lower()
    for line in (contents .. '\n'):gmatch('([^\r\n]*)[\r\n]+') do
        local section = line:match('^%s*%[([^%]]+)%]%s*$')
        if section then
            inSection = section:lower() == name
            found = found or inSection
        elseif inSection then
            local key, value = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            key = key and key:lower()
            if key and wanted[key] and values[key] == nil then values[key] = value end
        end
    end
    return values, found
end

-- A config's recorded Active value in Rainmeter.ini: a number (0 when the
-- section or key is missing), or nil when the file cannot be read.
function Link.activeOf(settingsFile, config)
    local values = Link.readSection(settingsFile, Link.SETTINGS_LIMIT, config, { active = true })
    if not values then return nil end
    return tonumber(values.active) or 0
end

function Link.new(skin)
    local self = {}
    local lastJoin = nil

    local function root() return skin:GetVariable('ROOTCONFIG', 'Parallax') end
    function self.settingsFile() return (skin:GetVariable('SETTINGSPATH', '') or '') .. 'Rainmeter.ini' end
    function self.idleConfig() return root() .. '\\Idle' end

    -- Joins the coordinator, or returns false without acting (missing
    -- coordinator, unreadable settings, or rate-limited). now: os.time().
    function self.join(now)
        now = now or os.time()
        if lastJoin ~= nil and now - lastJoin >= 0 and now - lastJoin < Link.REJOIN_SECONDS then return false end
        lastJoin = now
        local ini = (skin:GetVariable('SKINSPATH', '') or '') .. self.idleConfig() .. '\\Idle.ini'
        if not Link.exists(ini) then return false end
        local active = Link.activeOf(self.settingsFile(), self.idleConfig())
        if active == nil then return false end
        if active == 1 then
            skin:Bang('!UpdateMeasureGroup', 'ParallaxIdleSyncRequest', '*')
        else
            skin:Bang('!ActivateConfig', self.idleConfig(), 'Idle.ini')
        end
        return true
    end

    -- Asks a loaded coordinator to re-check whether anything still needs it,
    -- at its next regular tick. Silent when it is not loaded.
    function self.requestReevaluate()
        skin:Bang('!UpdateMeasureGroup', 'ParallaxIdleReevaluateRequest', '*')
        return true
    end

    return self
end

return Link
