-- Original, side-effect-free formatter for numeric Windows RAM inventory.
local M = {}
local types = {
    [3]='DRAM', [4]='EDRAM', [5]='VRAM', [6]='SRAM', [7]='RAM', [8]='ROM',
    [9]='Flash', [10]='EEPROM', [11]='FEPROM', [12]='EPROM', [13]='CDRAM',
    [14]='3DRAM', [15]='SDRAM', [16]='SGRAM', [17]='RDRAM',
    [18]='DDR', [19]='DDR2', [20]='DDR2 FB-DIMM',
    [24]='DDR3', [25]='FBD2', [26]='DDR4', [27]='LPDDR', [28]='LPDDR2',
    [29]='LPDDR3', [30]='LPDDR4', [31]='Logical NVM', [32]='HBM', [33]='HBM2',
    [34]='DDR5', [35]='LPDDR5', [36]='HBM3'
}
-- These are WMI FormFactor codes, NOT the raw SMBIOS form-factor enumeration.
local forms = {
    [2]='SIP', [3]='DIP', [4]='ZIP', [5]='SOJ', [6]='Proprietary', [7]='SIMM',
    [8]='DIMM', [9]='TSOP', [10]='PGA', [11]='RIMM', [12]='SODIMM',
    [13]='SRIMM', [14]='SMD', [15]='SSMP', [16]='QFP', [17]='TQFP',
    [18]='SOIC', [19]='LCC', [20]='PLCC', [21]='BGA', [22]='FPBGA', [23]='LGA'
}

local function integer(text, maximum)
    if not text or not text:match('^%d+$') then return nil end
    local n = tonumber(text)
    if not n or n > maximum then return nil end
    return n
end

function M.Parse(raw)
    if type(raw) ~= 'string' or #raw > 65536 then return nil end
    raw = raw:match('^%s*(.-)%s*$')
    local slotText, rows = raw:match('^RAMINFO1|(%d+)|(.+)$')
    local slots = integer(slotText, 65535)
    if not slots or rows:sub(-1) == ';' or rows:find(';;', 1, true) then return nil end
    local result = {slots=slots, devices={}}
    for row in rows:gmatch('[^;]+') do
        local c,t,r,f = row:match('^(%d+),(%d+),(%d+),(%d+)$')
        local capacity = integer(c, 9007199254740991)
        local kind, rate, form = integer(t, 65535), integer(r, 4294967295), integer(f, 65535)
        if not capacity or not kind or not rate or not form or #result.devices >= 512 then return nil end
        result.devices[#result.devices+1] = {capacity=capacity, type=kind, rate=rate, form=form}
    end
    if #result.devices == 0 then return nil end
    return result
end

local function field(text, tip) return {text=text, tip=tip} end

local function common(devices, key, names, suffix, explanation)
    local seen, values, missing = {}, {}, false
    for _, device in ipairs(devices) do
        local value = names and names[device[key]] or (not names and device[key] > 0 and tostring(device[key]) .. suffix)
        if not value then missing = true
        elseif not seen[value] then seen[value]=true; values[#values+1]=value end
    end
    table.sort(values)
    local text = #values == 0 and 'Unknown' or (#values > 1 and 'Mixed' or (missing and 'Partial' or values[1]))
    local detail = #values > 0 and table.concat(values, ', ') or 'none'
    if missing then detail = detail .. '; some or all records are unknown' end
    return field(text, explanation .. '#CRLF#Reported values: ' .. detail .. '.')
end

function M.Format(data, useMiB, decimals)
    if not data then
        local result = {}
        for _, key in ipairs({'Installed','Type','Speed','Devices','Form'}) do
            result[key] = field('Unavailable', 'Windows memory inventory is unavailable. Refresh the skin to retry. Live physical RAM readings below are independent.')
        end
        return result
    end
    local result, total, known = {}, 0, 0
    for _, device in ipairs(data.devices) do
        if device.capacity > 0 then total=total+device.capacity; known=known+1 end
    end
    local unit, divisor = 'GiB', 1073741824
    if tonumber(useMiB) == 1 then unit, divisor = 'MiB', 1048576 end
    decimals = tonumber(decimals) or 1
    if decimals ~= decimals or decimals == math.huge or decimals == -math.huge then decimals=1 end
    decimals = math.max(0, math.min(2, math.floor(decimals)))
    local complete = known == #data.devices and total <= 9007199254740991
    local installed = complete and string.format('%.'..decimals..'f %s', total/divisor, unit) or (known > 0 and 'Partial' or 'Unknown')
    result.Installed = field(installed, complete
        and ('Installed capacity reported by firmware: '..string.format('%.0f',total)..' bytes. Windows-usable Total below may be lower because of hardware reservations.')
        or 'One or more device capacities are missing or invalid. An incomplete sum is not shown as installed RAM.')
    result.Type = common(data.devices, 'type', types, '', 'Memory generation/type reported by SMBIOS.')
    result.Speed = common(data.devices, 'rate', nil, ' MT/s', 'Firmware-reported configured transfer rate, not a live clock. The Windows value is shown unchanged; older firmware/WMI documentation may call this MHz.')
    result.Form = common(data.devices, 'form', forms, '', 'Physical memory form factor reported by Windows.')
    local count = #data.devices
    local devices = complete and data.slots >= count and (count..' / '..data.slots) or (count..' reported')
    result.Devices = field(devices, 'Windows reports '..count..' memory device records. '
        .. (data.slots >= count and ('System-memory arrays report '..data.slots..' slots/sockets. ') or 'Total slots/sockets are unknown or inconsistent. ')
        .. 'This does not establish removable modules, free upgrade slots or memory channel mode.')
    return result
end

return M
