-- Original Parallax connection presentation. No I/O, telemetry polling, or state writes.
-- Native SysInfo and installed WiFiStatus link-rate values are already bits per second.
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

function M.describe(Core, adapter, wifi, config)
    adapter, wifi = adapter or {}, wifi or {}
    config = config or M.configureWifi('0', '0')
    local result = {
        adapter = 'Adapter unavailable', description = '--', status = 'Adapter unavailable',
        internet = 'Unknown', ip = '--', gateway = '--', receiveLink = '--', transmitLink = '--',
        wifiName = 'Wi-Fi unavailable', signal = '--', radio = 'Radio unavailable',
        wifiTooltip = '', signalTooltip = '', signalPercent = nil,
        statusColor = 'WarningColor', internetColor = 'MutedColor', signalColor = 'MutedColor'
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

    -- Internet connectivity is an independent PC-wide Windows report, even if this NIC is down.
    if adapter.internet == 1 then
        result.internet, result.internetColor = 'Detected', 'GoodColor'
    elseif adapter.internet == -1 then
        result.internet, result.internetColor = 'Not reported', 'WarningColor'
    end

    local identity, identityError = Core.identity(adapter)
    if identity then
        local alias, description = trim(adapter.alias), trim(adapter.description)
        result.adapter = provided(alias) and alias or provided(description) and description or 'Selected adapter'
        result.description = provided(description) and description or '--'
        local typeName = adapter.type == 6 and 'Ethernet' or adapter.type == 71 and 'Wi-Fi' or 'Other'
        local states = { [-3] = 'Not present', [-2] = 'Lower layer down', [-1] = 'Down',
            [0] = 'Status unknown', [1] = 'Up', [2] = 'Dormant', [3] = 'Testing' }
        local state = adapter.state == -1 and 'Disconnected' or states[adapter.status] or 'Unavailable'
        result.status = typeName .. ' / ' .. state
        if adapter.status == 1 and adapter.state ~= -1 then
            result.statusColor = 'GoodColor'
            result.ip, result.gateway = address(adapter.ip), address(adapter.gateway)
            result.receiveLink, result.transmitLink = link(adapter.receiveSpeed), link(adapter.transmitSpeed)
        end
    else
        local shortErrors = {
            ['Configured adapter not found'] = 'Selected NIC not found',
            ['Select one adapter; index 0 unsupported'] = 'Select one adapter'
        }
        result.adapter = 'Selected: ' .. trim(adapter.selector)
        result.status = shortErrors[identityError] or identityError or 'Adapter unavailable'
    end

    local configIndexValid = Core.finite(config.index) and config.index >= 0 and config.index <= 63
        and config.index == math.floor(config.index)
    local sourceIndex = configIndexValid and config.index or 0
    local source = 'Wi-Fi source: WLAN index ' .. sourceIndex .. ', separate from the selected adapter. '
        .. 'Native WiFiStatus cannot verify this index or match it to Net; an unavailable index may fall back to 0. '
    result.signalTooltip = 'Windows Wi-Fi signal quality from 0 to 100%; not network throughput. '
        .. 'A confirmed connection can have a valid 0% signal. Each Wi-Fi field is queried separately.'

    if config.error or not configIndexValid or type(config.enabled) ~= 'boolean' then
        result.wifiName = 'Check Wi-Fi settings'
        result.wifiTooltip = tostring(config.error or 'Wi-Fi configuration is invalid.') .. ' Wi-Fi querying is disabled.'
    elseif not config.enabled then
        result.wifiName = 'Wi-Fi off in module'
        result.wifiTooltip = 'Wi-Fi querying is disabled in this module. ' .. source
    else
        local ssid, phy = trim(wifi.ssid), trim(wifi.phy)
        local pending = ssid:lower():match('%(authorizing%.%.%.%)$') or ssid:lower():match('%(connecting%.%.%.%)$')
        local usablePhy = knownPhy[phy:lower()] == true
        local connectionKnown = provided(ssid) and (usablePhy or positive(wifi.receiveRate) or positive(wifi.transmitRate))
        if provided(ssid) and pending then
            result.wifiName, result.signal, result.radio = 'Wi-Fi: ' .. ssid, 'Pending', 'Radio: Pending'
            result.wifiTooltip = source .. 'Native connection state: ' .. ssid .. '. Signal is withheld while connecting.'
        elseif connectionKnown then
            result.wifiName = 'Wi-Fi: ' .. ssid
            result.radio = usablePhy and 'Radio: ' .. phy or 'Radio unavailable'
            result.wifiTooltip = source .. 'SSID: ' .. ssid .. '. Wi-Fi link RX: ' .. link(wifi.receiveRate)
                .. '; TX: ' .. link(wifi.transmitRate) .. '. Link rates are not measured throughput. '
                .. 'PHY identifies the Wi-Fi standard; channel and frequency band are not exposed.'
            if Core.finite(wifi.quality) and wifi.quality >= 0 and wifi.quality <= 100 then
                result.signalPercent = wifi.quality
                result.signal = string.format('%.0f%%', wifi.quality)
                result.signalColor = wifi.quality <= 25 and 'DangerColor' or wifi.quality <= 50 and 'WarningColor' or 'GoodColor'
            else
                result.signal = 'Unavailable'
                result.signalTooltip = result.signalTooltip .. ' The current quality value is unavailable.'
            end
        else
            result.wifiTooltip = source .. 'Current Wi-Fi data is unavailable. Native error values cannot distinguish '
                .. 'no adapter, disconnected Wi-Fi, radio off, or denied Windows Location access. '
                .. 'Check Wi-Fi and Settings / Privacy & security / Location. Reload Wi-Fi skins after adapter or service changes.'
        end
    end

    -- Adapter names, addresses, SSIDs, and tooltips are data, never Rainmeter action text.
    for key, value in pairs(result) do
        if type(value) == 'string' then result[key] = Core.safe(value) end
    end
    return result
end

return M
