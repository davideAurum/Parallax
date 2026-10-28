-- Original Parallax connection presentation. No I/O, telemetry polling, or state writes.
-- Native SysInfo link rates are already bits per second; WiFiStatus rates only prove a connection.
local M = {}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

function M.configureWifi(enabledRaw, indexRaw)
    if enabledRaw ~= '0' and enabledRaw ~= '1' then
        return { enabled = false, index = 0, error = 'Wi-Fi enable must be 0 or 1.' }
    end
    local index = type(indexRaw) == 'string' and indexRaw:match('^%d+$') and tonumber(indexRaw)
    if not index or index < 0 or index > 63 or index ~= math.floor(index) then
        return { enabled = false, index = 0, error = 'Wi-Fi source must be a whole index from 0 to 63.' }
    end
    return { enabled = enabledRaw == '1', index = index }
end

local knownPhy = {
    ['802.11a'] = true, ['802.11ac'] = true, ['802.11ad'] = true,
    ['802.11ax'] = true, ['802.11be'] = true, ['802.11b'] = true,
    ['802.11g'] = true, ['802.11n'] = true,
    ['dsss'] = true, ['fhss'] = true, ['ir-band'] = true
}

-- Wi-Fi Alliance generation names. 802.11a/b/g/ad and the legacy PHYs have no
-- generation shown, and 6E is a band, not a PHY, so ax is always "Wi-Fi 6".
local generation = {
    ['802.11n'] = 'Wi-Fi 4', ['802.11ac'] = 'Wi-Fi 5', ['802.11ax'] = 'Wi-Fi 6', ['802.11be'] = 'Wi-Fi 7'
}

local function protocol(phy)
    local name = generation[phy:lower()]
    return name and (name .. ' (' .. phy .. ')') or phy
end

-- Band and channel of the interface connected to `ssid`, from `netsh wlan show
-- interfaces` output ("Band : 5 GHz" on Windows 11 24H2 and later, "Channel : 36"
-- on Windows 10 and 11; the labels are English-only). Returns band, channel (either
-- may be nil), or nothing when no block matches or it carries neither.
function M.parseBand(Core, output, ssid)
    ssid = trim(ssid)
    if ssid == '' then return nil end
    local blocks, current = {}, nil
    for line in tostring(output or ''):gmatch('[^\r\n]+') do
        local key, value = line:match('^%s*([%w ]-)%s*:%s*(.-)%s*$')
        if key == 'Name' then current = {}; blocks[#blocks + 1] = current end
        if current and key and current[key] == nil then current[key] = value end
    end
    for _, block in ipairs(blocks) do
        if block.SSID and (Core.safe(block.SSID)) == ssid then
            local band = block.Band and block.Band:match('^%d+%.?%d* GHz$')
            local channel = block.Channel and block.Channel:match('^%d+$')
            if band or channel then return band, channel end
        end
    end
end

function M.describe(Core, adapter, wifi, config)
    adapter, wifi = adapter or {}, wifi or {}
    config = config or M.configureWifi('0', '0')
    local result = {
        typeName = '--', name = 'Adapter unavailable',
        ip = '--', gateway = '--', receiveLink = '--', transmitLink = '--',
        -- Blank unless a Wi-Fi connection is reported (the panel has no channel: WiFiStatus offers none).
        ssid = '', signal = '--', radio = '', signalPercent = nil,
        signalColor = 'MutedColor'
    }
    local function positive(value)
        return Core.finite(value) and value > 0
    end
    local function link(value)
        return positive(value) and Core.rate(value, 'bits') or '--'
    end
    local function provided(value)
        value = trim(value)
        return value ~= '' and value ~= '-1' and value ~= '0' and value ~= '???'
    end
    local function address(value)
        local text = trim(value)
        if not provided(text) or text == '0.0.0.0' or text == '::' then return '--' end
        return text
    end

    -- The adapter's operational state is Network's traffic status line; here a down
    -- or disconnected NIC just shows no addresses or link rates.
    local identity = Core.identity(adapter)
    if identity then
        local alias, description = trim(adapter.alias), trim(adapter.description)
        result.name = provided(description) and description or provided(alias) and alias or 'Selected adapter'
        result.typeName = adapter.type == 6 and 'Ethernet' or adapter.type == 71 and 'Wi-Fi' or 'Other'
        if adapter.status == 1 and adapter.state ~= -1 then
            result.ip, result.gateway = address(adapter.ip), address(adapter.gateway)
            result.receiveLink, result.transmitLink = link(adapter.receiveSpeed), link(adapter.transmitSpeed)
        end
    else
        result.name = 'Selected: ' .. trim(adapter.selector)
    end

    local configIndexValid = Core.finite(config.index) and config.index >= 0 and config.index <= 63
        and config.index == math.floor(config.index)

    if config.error or not configIndexValid or type(config.enabled) ~= 'boolean' then
        result.ssid = 'Check Wi-Fi settings'
    elseif config.enabled then
        local ssid, phy = trim(wifi.ssid), trim(wifi.phy)
        local pending = ssid:lower():match('%(authorizing%.%.%.%)$') or ssid:lower():match('%(connecting%.%.%.%)$')
        local usablePhy = knownPhy[phy:lower()] == true
        local connectionKnown = provided(ssid) and (usablePhy or positive(wifi.receiveRate) or positive(wifi.transmitRate))
        if provided(ssid) and pending then
            result.ssid, result.signal, result.radio = ssid, 'Pending', 'Pending'
        elseif connectionKnown then
            result.ssid, result.connected = ssid, true
            result.radio = usablePhy and protocol(phy) or 'Protocol unavailable'
            if Core.finite(wifi.quality) and wifi.quality >= 0 and wifi.quality <= 100 then
                result.signalPercent = wifi.quality
                result.signal = string.format('%.0f%%', wifi.quality)
                result.signalColor = wifi.quality <= 25 and 'DangerColor' or wifi.quality <= 50 and 'WarningColor' or 'GoodColor'
            else
                result.signal = 'Unavailable'
            end
        end
    end

    -- Adapter names, addresses, and SSIDs are data, never Rainmeter action text.
    for key, value in pairs(result) do
        if type(value) == 'string' then result[key] = Core.safe(value) end
    end
    return result
end

return M
