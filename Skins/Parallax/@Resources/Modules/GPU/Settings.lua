-- Original independent GPU settings controller, Rainmeter Lua 5.1.
-- Event-driven: no timer writes, telemetry collection or recurring processes.
-- Only fixed controls write known keys. Registry data travels as encoded data,
-- never as command text. DiscoverExports.ps1.txt runs only after Browse / Rescan.
local state
local fields = { 'Temperature', 'Power', 'Clock' }
local defaults = {
    Columns = '1', PanelHeight = '288', GPUEnableSensors = '0',
    GPURegHKey = 'HKEY_CURRENT_USER', GPURegKey = 'SOFTWARE\\HWiNFO64\\VSB'
}
for _, field in ipairs(fields) do
    defaults['GPU' .. field .. 'Index'] = '-1'
    defaults['GPU' .. field .. 'Sensor'] = ''
    defaults['GPU' .. field .. 'Label'] = ''
end

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

local function display(value)
    return tostring(value or ''):gsub('[%c]', ' '):gsub('#', '')
        :gsub('%[', '('):gsub('%]', ')'):gsub('"', "'")
end

local function finite(value)
    return value and value == value and value ~= math.huge and value ~= -math.huge
end

local function knownField(field)
    for _, candidate in ipairs(fields) do if candidate == field then return true end end
    return false
end

local function safeIdentity(value)
    if type(value) ~= 'string' or #value > 2048 or trim(value) ~= value then return false end
    -- HWiNFO's exact ordinal marker is common in GPU names. This narrow literal
    -- exception cannot name a measure or an existing GPU variable. All other
    -- bracket/hash syntax stays forbidden, including arbitrary Rainmeter bangs.
    local checked = value:gsub('%[#%d+%]', '')
    return not checked:find('[%c#%[%]"\']')
end

local function utf8(code)
    if code < 128 then return string.char(code) end
    if code < 2048 then return string.char(192 + math.floor(code / 64), 128 + code % 64) end
    if code < 65536 then
        return string.char(224 + math.floor(code / 4096), 128 + math.floor(code / 64) % 64, 128 + code % 64)
    end
    return string.char(240 + math.floor(code / 262144), 128 + math.floor(code / 4096) % 64,
        128 + math.floor(code / 64) % 64, 128 + code % 64)
end

local function decodeFile(bytes)
    if bytes:sub(1, 3) == '\239\187\191' then return bytes:sub(4) end
    if bytes:sub(1, 2) ~= '\255\254' then
        if bytes:find('\0', 1, true) then return nil end
        return bytes
    end
    if #bytes % 2 ~= 0 then return nil end
    local text, position = {}, 3
    local function word(at) return bytes:byte(at) + bytes:byte(at + 1) * 256 end
    while position <= #bytes do
        local code = word(position)
        position = position + 2
        if code >= 55296 and code <= 56319 then
            if position > #bytes then return nil end
            local low = word(position)
            if low < 56320 or low > 57343 then return nil end
            code = 65536 + (code - 55296) * 1024 + low - 56320
            position = position + 2
        elseif code >= 56320 and code <= 57343 then return nil end
        if code == 0 then return nil end
        text[#text + 1] = utf8(code)
    end
    return table.concat(text)
end

local function readValues()
    local file = io.open(state.userFile, 'rb')
    if not file then return nil end
    local bytes = file:read(65537) or ''
    file:close()
    if #bytes > 65536 then return nil end
    local text = decodeFile(bytes)
    if not text then return nil end
    local values, section = {}, ''
    for key, value in pairs(defaults) do values[key] = value end
    local known = {}
    for key in pairs(defaults) do known[key:lower()] = key end
    for line in (text .. '\n'):gmatch('(.-)\r?\n') do
        local heading = line:match('^%s*%[([^%]]+)%]%s*;?.*$')
        if heading then section = heading:lower()
        elseif section == 'variables' then
            local key, value = line:match('^%s*([^;=%s]+)%s*=(.*)$')
            key = key and known[key:lower()]
            if key then values[key] = trim(value) end
        end
    end
    return values
end

local function set(meter, option, value)
    local text = display(value)
    SKIN:Bang('!SetOption', meter, option, text)
end

local function render()
    if not state then return end
    local v = state.values
    set('MeterSettingsColumnsValue', 'Text', v.Columns == '1' and '1 column' or v.Columns == '2' and '2 columns' or 'Custom')
    set('MeterSettingsColumnsValue', 'ToolTipText', 'GPU monitor columns: ' .. v.Columns .. '. Click to choose one or two columns.')
    set('MeterSettingsHeightValue', 'Text', v.PanelHeight .. ' px / Fit')
    set('MeterSettingsHeightValue', 'ToolTipText', 'GPU monitor height: ' .. v.PanelHeight .. ' logical pixels. Fit sets the current content height to 288.')
    set('MeterSettingsSensorsValue', 'Text', v.GPUEnableSensors == '1' and 'On' or v.GPUEnableSensors == '0' and 'Off' or 'Custom')
    set('MeterSettingsHiveValue', 'Text', v.GPURegHKey == 'HKEY_CURRENT_USER' and 'Current user'
        or v.GPURegHKey == 'HKEY_LOCAL_MACHINE' and 'Local machine' or 'Custom')
    set('MeterSettingsHiveValue', 'ToolTipText', v.GPURegHKey .. '. Changes only the registry hive; existing exact mappings remain unchanged.')
    set('MeterSettingsKeyValue', 'Text', v.GPURegKey)
    set('MeterSettingsKeyValue', 'ToolTipText', 'Read-only registry source: ' .. v.GPURegHKey .. '\\' .. v.GPURegKey .. '. Advanced file opens custom settings.')
    for _, field in ipairs(fields) do
        local prefix = 'GPU' .. field
        local mapped = v[prefix .. 'Index']:match('^%d+$') and v[prefix .. 'Sensor'] ~= '' and v[prefix .. 'Label'] ~= ''
        set('MeterSettings' .. field .. 'Value', 'Text', mapped and v[prefix .. 'Label'] or 'Unmapped / choose')
        set('MeterSettings' .. field .. 'Value', 'ToolTipText', mapped and
            ('Index ' .. v[prefix .. 'Index'] .. ': ' .. v[prefix .. 'Sensor'] .. ' / ' .. v[prefix .. 'Label'])
            or ('Choose the exported ' .. field:lower() .. ' measurement for your GPU.'))
    end
    set('MeterSettingsNotice', 'Text', state.notice)
    set('MeterSettingsNotice', 'ToolTipText', state.detail or state.notice)
    set('MeterSettingsPickerTitle', 'Text', state.busy and 'Reading exported sensors...'
        or state.target and ('Choose ' .. state.target:lower() .. ' export') or 'Choose a sensor row above')
    local pages = math.max(1, math.ceil(#state.items / 5))
    state.page = math.max(1, math.min(pages, state.page))
    set('MeterSettingsPage', 'Text', #state.items == 0 and '--' or (state.page .. ' / ' .. pages))
    for slot = 1, 5 do
        local item = state.items[(state.page - 1) * 5 + slot]
        local meter = 'MeterSettingsPick' .. slot
        local placeholder = ''
        if #state.items == 0 and slot == 1 then
            placeholder = state.busy and 'Reading exported sensors...'
                or state.target and 'No readings available. Check Guide or Rescan.'
                or 'Choose Temperature, Power or Clock above.'
        end
        set(meter, 'Text', item and (item.index .. ': ' .. item.label .. ' / ' .. item.formatted) or placeholder)
        set(meter, 'FontColor', SKIN:GetVariable(item and 'AccentColor' or 'MutedColor', '175,175,175'))
        set(meter, 'ToolTipText', item and (item.sensor .. ' / ' .. item.label .. ': ' .. item.formatted
            .. '. Registry snapshot; age unknown. Confirm this is your GPU and the selected measurement.'
            .. (item.safe and '' or ' This identity cannot be saved safely in Rainmeter.')) or placeholder)
        set(meter, 'MouseActionCursor', item and item.safe and '1' or '0')
    end
    SKIN:Bang('!UpdateMeterGroup', 'GPUSettingsUI')
    SKIN:Bang('!UpdateMeterGroup', 'GPUSettingsPicker')
    SKIN:Bang('!Redraw')
end

local function notice(text, detail)
    state.notice, state.detail = text, detail
    render()
end

local function refreshValues()
    local values = readValues()
    if not values then
        notice('Cannot read GPU settings.', 'GPU.inc is missing, unreadable, too large, or has an unsupported encoding. No settings were changed.')
        return false
    end
    state.values = values
    return true
end

local function valid(key, value)
    if not defaults[key] or type(value) ~= 'string' then return false end
    if key == 'Columns' then return value == '1' or value == '2' end
    if key == 'PanelHeight' then return value == '288' end
    if key == 'GPUEnableSensors' then return value == '0' or value == '1' end
    if key == 'GPURegHKey' then return value == 'HKEY_CURRENT_USER' or value == 'HKEY_LOCAL_MACHINE' end
    if key == 'GPURegKey' then return false end
    for _, field in ipairs(fields) do
        if key == 'GPU' .. field .. 'Index' then
            return value == '-1' or (value:match('^%d+$') and tonumber(value) <= 99999 and tostring(tonumber(value)) == value)
        end
        if key == 'GPU' .. field .. 'Sensor' or key == 'GPU' .. field .. 'Label' then return safeIdentity(value) end
    end
    return false
end

local function save(changes)
    if not refreshValues() then return false end
    local keys = {}
    for key, value in pairs(changes) do
        if not valid(key, value) then notice('This setting cannot be saved safely.'); return false end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local changed = false
    for _, key in ipairs(keys) do
        if state.values[key] ~= changes[key] then
            changed = true
            SKIN:Bang('!WriteKeyValue', 'Variables', key, changes[key], state.userFile)
            state.values[key] = changes[key]
        end
    end
    if changed then SKIN:Bang('!RefreshGroup', 'ParallaxGPU') end
    notice(changed and 'Saved. GPU refreshes independently.' or 'Already set; no changes needed.')
    return true
end

local function unhex(value)
    if type(value) ~= 'string' or #value > 8192 or #value % 2 ~= 0 or value:find('[^%x]') then return nil end
    return (value:gsub('%x%x', function(pair) return string.char(tonumber(pair, 16)) end))
end

function Initialize()
    state = { userFile = SKIN:GetVariable('@') .. 'User\\GPU.inc', values = {}, items = {},
        page = 1, busy = false, notice = 'Changes save immediately; only GPU refreshes.' }
    for key, value in pairs(defaults) do state.values[key] = SKIN:GetVariable(key, value) end
    local values = readValues()
    if values then state.values = values
    else state.notice = 'Cannot read GPU settings; check Advanced file.' end
end

function Update() render(); return 0 end

function ToggleSensors()
    if not refreshValues() then return false end
    return save({GPUEnableSensors = state.values.GPUEnableSensors == '1' and '0' or '1'})
end

function CycleColumns()
    if not refreshValues() then return false end
    return save({Columns = state.values.Columns == '1' and '2' or '1'})
end

function FitHeight() return save({PanelHeight = '288'}) end

function CycleHive()
    if not refreshValues() then return false end
    state.items, state.page, state.sourceHive, state.sourceKey = {}, 1, nil, nil
    return save({GPURegHKey = state.values.GPURegHKey == 'HKEY_CURRENT_USER' and 'HKEY_LOCAL_MACHINE' or 'HKEY_CURRENT_USER'})
end

function Browse(field)
    if not knownField(field) then return false end
    if state.busy then notice('Still reading exports; wait for this scan.'); return false end
    if not refreshValues() then return false end
    local source = SKIN:GetMeasure('MeasureGPUDiscover')
    if not source then notice('Sensor discovery is unavailable.'); return false end
    state.target, state.items, state.page = field, {}, 1
    state.sourceHive, state.sourceKey = state.values.GPURegHKey, state.values.GPURegKey
    state.busy = true
    notice('Reading HWiNFO exports once...', 'Only the configured registry source is read. Existing exports may be retained after HWiNFO stops; sample age is unknown.')
    SKIN:Bang('!CommandMeasure', 'MeasureGPUDiscover', 'Run')
    return true
end

function Rescan()
    if not state.target then notice('Choose a sensor row first.'); return false end
    return Browse(state.target)
end

function FinishDiscovery()
    if not state.busy then return false end
    state.busy = false
    local source = SKIN:GetMeasure('MeasureGPUDiscover')
    local output = source and source:GetStringValue() or ''
    if not source or source:GetValue() ~= 1 or type(output) ~= 'string' or #output > 1048576 then
        notice('Could not read HWiNFO exports.', 'The one-shot helper failed or timed out. Verify the configured registry source, then Rescan.'); return false
    end
    if not refreshValues() then return false end
    local header, body = output:match('^([^\r\n]+)[\r\n]*(.*)$')
    local status, encodedHive, encodedKey, skipped, limited
    if header then
        status, encodedHive, encodedKey, skipped, limited = header:match('^GPU_EXPORTS|1|([A-Z_]+)|(%x*)|(%x*)|(%d+)|([01])$')
    end
    if not status then notice('Invalid sensor discovery response.'); return false end
    local hive, key = unhex(encodedHive), unhex(encodedKey)
    if status == 'INVALID_CONFIG' then
        notice('Check the registry source.', 'GPU.inc must contain an HKCU or HKLM hive and a literal registry path. Open Advanced file to review custom settings.'); return false
    end
    if hive ~= state.sourceHive or key ~= state.sourceKey or hive ~= state.values.GPURegHKey or key ~= state.values.GPURegKey then
        state.items = {}
        notice('Registry source changed; Rescan first.'); return false
    end
    local statusText = { EMPTY = 'No complete sensor exports found.', MISSING = 'HWiNFO export key was not found.',
        UNAVAILABLE = 'HWiNFO exports could not be read.', TOO_MANY = 'Too many registry values to browse safely.' }
    if status ~= 'OK' then
        notice(statusText[status] or 'Invalid sensor discovery response.',
            'Enable the desired HWiNFO Gadget exports, check the configured hive/key, then Rescan. Complete Sensor, Label, Value and numeric ValueRaw fields are required. No provider is installed or started by this utility.'); return false
    end
    local items, seen = {}, {}
    for line in body:gmatch('[^\r\n]+') do
        local index, sensorHex, labelHex, formattedHex, rawHex = line:match('^ITEM|(%d+)|(%x+)|(%x+)|(%x+)|(%x+)$')
        local sensor, label, formatted, raw = unhex(sensorHex), unhex(labelHex), unhex(formattedHex), unhex(rawHex)
        if not index or #items >= 256 or seen[index] or tonumber(index) > 99999 or tostring(tonumber(index)) ~= index
            or not sensor or not label or not formatted or not raw or #sensor > 2048 or #label > 2048
            or #formatted > 2048 or #raw > 2048 or trim(sensor) == '' or trim(label) == ''
            or not finite(tonumber(raw)) or tonumber(formatted) or not formatted:find('%d') then
            notice('Invalid sensor discovery response.'); return false
        end
        seen[index] = true
        items[#items + 1] = { index = index, sensor = sensor, label = label, formatted = formatted,
            safe = safeIdentity(sensor) and safeIdentity(label) }
    end
    if #items == 0 then notice('No complete sensor exports found.'); return false end
    state.items = items
    local detail = 'Choose the exact measurement for your discrete GPU; the list does not infer GPU identity or metric type. Values are registry snapshots with unknown age.'
    if tonumber(skipped) > 0 then detail = detail .. ' Skipped ' .. skipped .. ' incomplete or unusable exports.' end
    if limited == '1' then detail = detail .. ' The bounded list omits additional exports.' end
    notice('Select an export for ' .. state.target:lower() .. '.', detail)
    return true
end

function PrevPage()
    state.page = math.max(1, state.page - 1)
    render()
end

function NextPage()
    state.page = math.min(math.max(1, math.ceil(#state.items / 5)), state.page + 1)
    render()
end

function Select(slot)
    slot = tonumber(slot)
    if not slot or slot ~= math.floor(slot) or slot < 1 or slot > 5 or state.busy or not knownField(state.target) then return false end
    local item = state.items[(state.page - 1) * 5 + slot]
    if not item then return false end
    if not item.safe then
        notice('This export name cannot be saved safely.', 'Rename unsafe custom sensor/label text in HWiNFO, then Rescan. Exact ordinal markers such as GPU [#0] are supported; other Rainmeter syntax, quotes and control characters are not.'); return false
    end
    if not refreshValues() then return false end
    if state.sourceHive ~= state.values.GPURegHKey or state.sourceKey ~= state.values.GPURegKey then
        state.items = {}
        notice('Registry source changed; Rescan first.'); return false
    end
    local prefix = 'GPU' .. state.target
    return save({[prefix .. 'Index'] = item.index, [prefix .. 'Sensor'] = item.sensor, [prefix .. 'Label'] = item.label})
end

function Clear(field)
    if not knownField(field) then return false end
    local prefix = 'GPU' .. field
    return save({[prefix .. 'Index'] = '-1', [prefix .. 'Sensor'] = '', [prefix .. 'Label'] = ''})
end

function RefreshGPU()
    SKIN:Bang('!RefreshGroup', 'ParallaxGPU')
    notice('GPU refresh requested.', 'Only loaded GPU monitor configs refresh. GPU Settings remains open.')
end

function Close() SKIN:Bang('!DeactivateConfig', 'Parallax\\GPU\\Settings') end
