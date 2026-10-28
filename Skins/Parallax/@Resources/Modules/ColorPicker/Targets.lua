-- Every color variable the suite lets a user pick, in dropdown order. The
-- picker and the launcher both validate keys here, so no unlisted name is
-- ever written or interpolated into a bang.
--
-- Entry fields: key, label, group, file (User\<file>.inc that stores the
-- value; Settings by default), alpha (keep the saved alpha byte; otherwise
-- the value is saved as opaque R,G,B), default (used when the key is unset).
-- A new shared color in Defaults.inc needs one line here; TargetTests.lua
-- fails until it has one.
local M = {}

local threadPalette = {
    '235,55,75', '255,145,77', '240,225,40', '166,219,91',
    '79,205,120', '60,200,194', '77,170,255', '122,139,255',
    '182,130,255', '238,111,196', '245,139,168', '190,190,190'
}
M.ThreadPalette = threadPalette
M.MaxThreads = 64
-- ColorPicker.ini's ColumnWidth and PanelHeight, which Launcher.lua needs to
-- place the window. TargetTests.lua fails if the two files disagree.
M.PickerColumnWidth = 280
M.PickerPanelHeight = 262

local groups = {
    { name = 'Text and accents', items = {
        { 'AccentColor', 'Accent Color 1' },
        { 'AccentColor2', 'Accent Color 2' },
        { 'TitleTextColor', 'Title Text Color' },
        { 'HeaderTextColor', 'Header Text Color' },
        { 'TextColor', 'Body Text Color' },
        { 'MutedColor', 'Muted Color' } } },
    { name = 'Surfaces', items = {
        { 'BackgroundColor', 'Background Color', alpha = true },
        { 'BorderColor', 'Border Color' },
        { 'DividerColor', 'Divider Color' },
        { 'TableHeaderBorderColor', 'Table header border', default = '50,50,50,255' },
        { 'TrackColor', 'Track Color' },
        { 'GraphBackgroundColor', 'Graph Background', alpha = true },
        { 'GridColor', 'Graph Grid', alpha = true } } },
    { name = 'Status', items = {
        { 'GoodColor', 'Good Color' },
        { 'WarningColor', 'Warning Color' },
        { 'DangerColor', 'Danger Color' } } },
    { name = 'Utilities', items = {
        { 'CPUColor', 'CPU Color' },
        { 'RAMColor', 'RAM Color' },
        { 'GPUColor', 'GPU Color' },
        { 'DiskReadColor', 'Disk Read Color' },
        { 'DiskWriteColor', 'Disk Write Color' },
        { 'NetworkInColor', 'Network In Color' },
        { 'NetworkOutColor', 'Network Out Color' },
        { 'MediaColor', 'Media Color' },
        { 'ClockColor', 'Clock Color' },
        { 'RAMHistoryEmptyColor', 'Memory History Cover', file = 'RAM', default = '25,25,25', refresh = 'ParallaxRAM' } } }
}

local byKey = {}
for _, group in ipairs(groups) do
    for _, item in ipairs(group.items) do
        local entry = { key = item[1], label = item[2], group = group.name, file = item.file or 'Settings',
            alpha = item.alpha == true, default = item.default, refresh = item.refresh or 'Parallax' }
        byKey[entry.key] = entry
    end
end
M.Groups = groups

-- CPUThreadColor1..64 live in User\CPU.inc and apply without reloading the CPU
-- meter (see ColorPicker.Apply), as the Thread Colors panel always did.
local function threadEntry(index)
    return { key = 'CPUThreadColor' .. index, label = 'CPU Thread ' .. index, group = 'CPU threads', file = 'CPU',
        alpha = false, default = threadPalette[(index - 1) % #threadPalette + 1], thread = index }
end

-- Returns the entry for an exact, case-sensitive key, or nil.
function M.Find(key)
    if type(key) ~= 'string' then return nil end
    if byKey[key] then return byKey[key] end
    local digits = key:match('^CPUThreadColor(%d+)$')
    local index = digits and tonumber(digits)
    if index and index >= 1 and index <= M.MaxThreads and tostring(index) == digits then return threadEntry(index) end
    return nil
end

-- Flat dropdown list: group heading rows and selectable rows. threadCount is
-- the number of logical threads the CPU meter shows (0 omits the group).
function M.Menu(threadCount)
    local menu = {}
    for _, group in ipairs(groups) do
        menu[#menu + 1] = { kind = 'group', label = group.name }
        for _, item in ipairs(group.items) do menu[#menu + 1] = { kind = 'target', key = item[1], label = item[2] } end
    end
    threadCount = math.max(0, math.min(M.MaxThreads, math.floor(tonumber(threadCount) or 0)))
    if threadCount > 0 then
        menu[#menu + 1] = { kind = 'group', label = 'CPU threads' }
        for index = 1, threadCount do menu[#menu + 1] = { kind = 'target', key = 'CPUThreadColor' .. index, label = 'CPU Thread ' .. index } end
    end
    return menu
end

return M
