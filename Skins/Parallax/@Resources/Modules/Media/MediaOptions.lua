-- Media accordion and spectrum drawer. Explicit toggles and confirmed-empty
-- collapse write fixed scalar preferences; the queue reader deduplicates
-- automatic empty transitions. The spectrum drawer opens UPWARD, so it also
-- keeps this config's AnchorY in Rainmeter.ini equal to the open drawer's lift:
-- Rainmeter keeps the anchor point at the saved WindowY, so the panel holds its
-- screen position while the window grows above it.
local settingsPath

-- Bounded ASCII view of an INI file. Both UTF-16 byte orders and a UTF-8 BOM
-- are accepted; non-ASCII code units read as '?', which no key, value or
-- section this script looks for contains.
local function readAscii(path, limit)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local contents = file:read(limit + 1)
    file:close()
    if not contents or #contents > limit then return nil end
    local bom = contents:sub(1, 2)
    if bom == '\255\254' or bom == '\254\255' then
        if #contents % 2 ~= 0 then return nil end
        local ascii, little = {}, bom == '\255\254'
        for at = 3, #contents, 2 do
            local a, b = contents:byte(at, at+1)
            local code = little and a+256*b or b+256*a
            ascii[#ascii+1] = code < 128 and string.char(code) or '?'
        end
        return table.concat(ascii)
    end
    return (contents:gsub('^\239\187\191', ''))
end

-- The wanted keys (lower case) of one section, and whether the section exists.
-- An unreadable file or a repeated wanted key fails closed with nil.
local function readSection(path, limit, name, wanted)
    local contents = readAscii(path, limit)
    if not contents then return nil end
    local values, inSection, found = {}, false, false
    name = name:lower()
    for line in (contents .. '\n'):gmatch('([^\r\n]*)[\r\n]+') do
        local section = line:match('^%s*%[([^%]]+)%]%s*$')
        if section then
            inSection = section:lower() == name
            found = found or inSection
        elseif inSection then
            local key, scalar = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            key = key and key:lower()
            if key and wanted[key] then
                if values[key] ~= nil then return nil end
                values[key] = scalar
            end
        end
    end
    return values, found
end

-- One saved Media preference, or nil when User\Media.inc cannot be read.
local function readMedia(key, default)
    local values = readSection(settingsPath, 262144, 'Variables', { [key:lower()] = true })
    if not values then return nil end
    return values[key:lower()] or default
end

local function readExpanded()
    local value = readMedia('QueueExpanded', '0')
    if not value then return nil end
    return value == '1' and '1' or '0'
end

function Initialize()
    settingsPath = SKIN:GetVariable('@') .. 'User\\Media.inc'
end

function Update() return 'Queue' end

-- An unreadable or unsaved preference leaves the queue display unchanged.
local function setExpanded(requested)
    local before = readExpanded()
    if not before then return false end
    local value = requested or (before == '1' and '0' or '1')
    if before == value then return false end
    SKIN:Bang('!WriteKeyValue', 'Variables', 'QueueExpanded', value, settingsPath)
    if readExpanded() ~= value then return false end
    -- Keep an already-open settings panel in sync with a footer toggle.
    SKIN:Bang('!Refresh', 'Parallax\\Media\\Settings')
    SKIN:Bang('!Refresh')
    return true
end

function ToggleQueue() return setExpanded(nil) end

-- Called only by the inline reader after a fresh, fully validated empty queue.
function CollapseEmptyQueue() return setExpanded('0') end

-- Spectrum drawer ---------------------------------------------------------
-- The saved VisualizerDrawer as Media shows it: 0 hidden, 1 collapsed (tab
-- only) or 2 open. Only the literal digits name its drawer includes, so another
-- number equal to 1 or 2 (such as '02') shows just the tab, and any other text
-- hides it. Media settings reads it the same way.
local function readDrawer()
    local value = readMedia('VisualizerDrawer', '1')
    if not value then return nil end
    if value == '0' or value == '1' or value == '2' then return value end
    local number = tonumber(value)
    return (number == 1 or number == 2) and '1' or '0'
end

-- Setup.ini sets MediaVisualizerHost=0: no drawer there, so its anchor is 0.
local function hosted()
    return SKIN:GetVariable('MediaVisualizerHost', '0') == '1'
end

-- What is on screen: MediaVisualizerOpen is 1 only when VisualizerDrawer2.inc,
-- the open drawer itself, loaded.
local function loadedOpen()
    return hosted() and SKIN:GetVariable('MediaVisualizerOpen', '0') == '1'
end

-- The open drawer's lift in whole pixels, as the skin's own Calc resolved it.
local function openLift()
    local measure = SKIN:GetMeasure('MeasureMediaVisualizerLift')
    local value = measure and tonumber(measure:GetValue())
    if not value or value ~= value or value < 1 or value > 4096 then return nil end
    return math.floor(value + 0.5)
end

local function rainmeterIni()
    return SKIN:GetVariable('SETTINGSPATH') .. 'Rainmeter.ini'
end

-- Recorded beside the anchor in this config's own Rainmeter.ini section: the
-- AnchorY this drawer last wrote. Layouts copy the section, so the record
-- travels with the anchor it describes.
local marker = 'ParallaxDrawerAnchorY'

-- This config's saved AnchorX, AnchorY and drawer record as raw text, or nil
-- when Rainmeter.ini cannot be read or has no section for it. A missing or
-- empty anchor key is Rainmeter's 0.
local function readAnchor()
    local values, found = readSection(rainmeterIni(), 4194304, SKIN:GetVariable('CURRENTCONFIG'),
        { anchorx = true, anchory = true, [marker:lower()] = true })
    if not values or not found then return nil end
    local x, y = values.anchorx, values.anchory
    return (x == nil or x == '') and '0' or x, (y == nil or y == '') and '0' or y, values[marker:lower()]
end

local function isPixel(value)
    return value:match('^%d+$') ~= nil or value:match('^%d*%.%d+$') ~= nil
end

-- Make AnchorY equal the expected lift, but only an anchor this drawer owns:
-- Rainmeter's default 0, or the value it last recorded writing. Any other saved
-- anchor - a custom pixel, percentage or bottom-relative value - is the user's
-- own and is left alone; the panel then moves when the drawer opens. Before a
-- refresh (live=false) AnchorY is written straight to Rainmeter.ini, which the
-- refresh reads, so the new layout appears once at its final position. During
-- a load (live=true) only a readable mismatch acts, through !SetAnchor, which
-- moves the window at once and rewrites AnchorX with its existing value.
local function placeAnchor(expected, live)
    local anchorX, anchorY, written = readAnchor()
    if anchorY then
        if not isPixel(anchorY) then return false end
        local owned = tonumber(anchorY) == 0 or (written ~= nil and tonumber(written) == tonumber(anchorY))
        if not owned then return false end
        if tonumber(anchorY) == expected then return true end
    elseif live then
        return false
    end
    local config, text = SKIN:GetVariable('CURRENTCONFIG'), tostring(expected)
    if not live and anchorY then
        SKIN:Bang('!WriteKeyValue', config, 'AnchorY', text, rainmeterIni())
        local _, readBack = readAnchor()
        if not readBack or tonumber(readBack) ~= expected then SKIN:Bang('!SetAnchor', anchorX, text) end
    else
        SKIN:Bang('!SetAnchor', anchorX or '0', text)
    end
    SKIN:Bang('!WriteKeyValue', config, marker, text, rainmeterIni())
    return true
end

-- Capture lease -------------------------------------------------------------
-- Modules\Media\CaptureState.inc holds the drawer's runtime capture state:
-- MediaDrawerCapture 0 live, 1 capture paused, 2 deferred to the standalone
-- Audio Visualizer, and MediaStandby. ApplyLease is the only writer. A lease
-- change (park, unpark, defer, reclaim, standby or fail-live) also stamps the
-- reload it causes, so MediaLifecycle skips the provider resume for it
-- (MEDIA-08), and reloads this skin once per load at most; several changes
-- before that posted reload coalesce into it. A 'toggle' change (the tab or
-- Media settings) writes the state only: the toggle's own reload carries it.
local LEASE_REASONS = { park = true, unpark = true, defer = true, reclaim = true, standby = true, ['fail-live'] = true }
local leaseRefreshed = false

local function statePath()
    return SKIN:GetVariable('@') .. 'Modules\\Media\\CaptureState.inc'
end

-- The saved capture and standby values, or nil when the file cannot be read
-- or has no single value for each key.
local function readLease()
    local values, found = readSection(statePath(), 65536, 'Variables', { mediadrawercapture = true, mediastandby = true })
    if not values or not found then return nil end
    return values.mediadrawercapture or '0', values.mediastandby or '0'
end

-- capture: 0, 1, 2 or nil to keep; standby: 0, 1 or nil to keep; reason: one
-- of LEASE_REASONS, or 'toggle'. Returns true when the state changed and
-- reads back as written.
function ApplyLease(capture, standby, reason)
    local savedCapture, savedStandby = readLease()
    if not savedCapture then return false end
    local wantCapture = capture == nil and savedCapture or tostring(capture)
    local wantStandby = standby == nil and savedStandby or tostring(standby)
    if wantCapture ~= '0' and wantCapture ~= '1' and wantCapture ~= '2' then return false end
    if wantStandby ~= '0' and wantStandby ~= '1' then return false end
    if wantCapture == savedCapture and wantStandby == savedStandby then return false end
    local path = statePath()
    if wantCapture ~= savedCapture then SKIN:Bang('!WriteKeyValue', 'Variables', 'MediaDrawerCapture', wantCapture, path) end
    if wantStandby ~= savedStandby then SKIN:Bang('!WriteKeyValue', 'Variables', 'MediaStandby', wantStandby, path) end
    local lease = LEASE_REASONS[reason] == true
    if lease then
        SKIN:Bang('!WriteKeyValue', 'Variables', 'MediaLeaseRefreshAt', string.format('%d', os.time()), path)
        SKIN:Bang('!WriteKeyValue', 'Variables', 'MediaLeaseRefreshClock', string.format('%d', math.floor(os.clock())), path)
    end
    local backCapture, backStandby = readLease()
    if backCapture ~= wantCapture or backStandby ~= wantStandby then return false end
    if lease and not leaseRefreshed then
        leaseRefreshed = true
        SKIN:Bang('!Refresh')
    end
    return true
end

-- One capture at a time (XMOD-02): an opening drawer starts deferred while
-- Rainmeter.ini records the standalone Audio Visualizer loaded (Active=1, its
-- only skin file), and live otherwise; the lease re-checks after each load.
local function openingCapture()
    local values = readSection(rainmeterIni(), 4194304, SKIN:GetVariable('ROOTCONFIG', 'Parallax') .. '\\Visualizer', { active = true })
    return values and values.active == '1' and 2 or 0
end

-- Collapsing or hiding the drawer: ask a loaded Parallax\Idle coordinator to
-- re-check whether anything still needs it (@Resources\Idle\Link.lua). A
-- silent group request; nothing happens when the coordinator is not loaded
-- or the link file is missing.
local function requestReevaluate()
    -- Rainmeter's dofile logs an error for a missing file, so look first.
    local path = SKIN:GetVariable('@') .. 'Idle\\Link.lua'
    local file = io.open(path, 'rb')
    if not file then return end
    file:close()
    local ok, link = pcall(function() return dofile(path).new(SKIN) end)
    if ok and type(link) == 'table' then link.requestReevaluate() end
end

-- The tab: collapsed <-> open, from what is on screen. Hidden is chosen only in
-- Media settings (the tab does not show then). An unreadable or unsaved
-- preference, or no usable lift, leaves the drawer as it is.
function ToggleVisualizer()
    if not hosted() then return false end
    if not readDrawer() then return false end
    local value = loadedOpen() and '1' or '2'
    local lift = 0
    if value == '2' then
        lift = openLift()
        if not lift then return false end
    end
    SKIN:Bang('!WriteKeyValue', 'Variables', 'VisualizerDrawer', value, settingsPath)
    if readDrawer() ~= value then return false end
    -- Opening or collapsing starts the drawer live, or deferred to a loaded
    -- standalone Audio Visualizer.
    ApplyLease(openingCapture(), nil, 'toggle')
    placeAnchor(lift, false)
    if value ~= '2' then requestReevaluate() end
    -- Keep an already-open settings panel in sync with the tab.
    SKIN:Bang('!Refresh', 'Parallax\\Media\\Settings')
    SKIN:Bang('!Refresh')
    return true
end

-- Once per load (MeasureMediaVisualizerLift): the anchor the loaded state needs.
function CheckAnchor()
    local expected = 0
    if loadedOpen() then
        expected = openLift()
        if not expected then return false end
    end
    return placeAnchor(expected, true)
end

-- Media settings saved VisualizerDrawer: place the anchor, then reload. With
-- no usable lift the anchor is left for the next load's CheckAnchor.
function ApplyVisualizerPreference()
    local state = readDrawer()
    if state and hosted() then
        local lift = 0
        if state == '2' then lift = openLift() end
        if lift then placeAnchor(lift, false) end
        ApplyLease(openingCapture(), nil, 'toggle')
        if state ~= '2' then requestReevaluate() end
    end
    SKIN:Bang('!Refresh')
    return true
end

-- Audio settings (or the standalone Visualizer's menu) saved a Visualizer key:
-- reload only an open drawer. A changed height re-places the anchor on that
-- load (CheckAnchor), which can show one displaced frame.
function RefreshVisualizerDrawer()
    if not loadedOpen() then return false end
    SKIN:Bang('!Refresh')
    return true
end
