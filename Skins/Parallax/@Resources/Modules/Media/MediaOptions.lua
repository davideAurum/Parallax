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

local function setExpanded(requested)
    local before = readExpanded()
    if not before then
        SKIN:Bang('!SetOption', 'MeterQueueStatus', 'ToolTipText', 'Cannot read Media settings. Check file access.')
        return false
    end
    local value = requested or (before == '1' and '0' or '1')
    if before == value then return false end
    SKIN:Bang('!WriteKeyValue', 'Variables', 'QueueExpanded', value, settingsPath)
    if readExpanded() ~= value then
        SKIN:Bang('!SetOption', 'MeterQueueStatus', 'ToolTipText', 'Could not save the queue display preference.')
        return false
    end
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

local function drawerFailed(message)
    SKIN:Bang('!SetOption', 'MeterVisualizerToggle', 'ToolTipText', message)
    SKIN:Bang('!UpdateMeter', 'MeterVisualizerToggle')
    return false
end

-- The tab: collapsed <-> open, from what is on screen. Hidden is chosen only in
-- Media settings (the tab does not show then).
function ToggleVisualizer()
    if not hosted() then return false end
    if not readDrawer() then return drawerFailed('Cannot read Media settings. Check file access.') end
    local value = loadedOpen() and '1' or '2'
    local lift = 0
    if value == '2' then
        lift = openLift()
        if not lift then return drawerFailed('Cannot place the spectrum drawer above Media.') end
    end
    SKIN:Bang('!WriteKeyValue', 'Variables', 'VisualizerDrawer', value, settingsPath)
    if readDrawer() ~= value then return drawerFailed('Could not save the spectrum drawer preference.') end
    placeAnchor(lift, false)
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
