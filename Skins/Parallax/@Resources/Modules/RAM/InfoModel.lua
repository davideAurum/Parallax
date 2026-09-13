-- Original, side-effect-free formatter for cached Windows memory inventory.
-- RAMINFO2|capacity,type,configuredRate,makerSource,manufacturerHex;...
local M = {}
local MAX_INTEGER, MAX_DEVICES, MAX_WIRE = 9007199254740991, 512, 160000
local types = {
    [3]='DRAM', [4]='EDRAM', [5]='VRAM', [6]='SRAM', [7]='RAM', [8]='ROM',
    [9]='Flash', [10]='EEPROM', [11]='FEPROM', [12]='EPROM', [13]='CDRAM',
    [14]='3DRAM', [15]='SDRAM', [16]='SGRAM', [17]='RDRAM',
    [18]='DDR SDRAM', [19]='DDR2 SDRAM', [20]='DDR2 FB-DIMM SDRAM',
    [24]='DDR3 SDRAM', [25]='FBD2 SDRAM', [26]='DDR4 SDRAM',
    [27]='LPDDR SDRAM', [28]='LPDDR2 SDRAM', [29]='LPDDR3 SDRAM',
    [30]='LPDDR4 SDRAM', [31]='Logical NVM', [32]='HBM', [33]='HBM2',
    [34]='DDR5 SDRAM', [35]='LPDDR5 SDRAM', [36]='HBM3', [37]='MRDIMM'
}
-- CIM does not establish LPDDR/HBM clock ratios; retain their reported MT/s.
local doubleRate = {
    [18]=true, [19]=true, [20]=true, [24]=true, [25]=true, [26]=true, [34]=true
}
-- Standard DDR4 speed bins, not a device profile or a measured live clock.
-- Samsung DDR4 SDRAM timing tables and DMTF SMBIOS 7.18.4 document the basis.
local ddr4Bins = {1600, 5600/3, 6400/3, 2400, 8000/3, 8800/3, 3200}
local aliases = {
    ['hynix']='SK Hynix', ['hynix semiconductor']='SK Hynix',
    ['hynix semiconductor inc']='SK Hynix', ['hynix semiconductor inc.']='SK Hynix',
    ['sk hynix']='SK Hynix', ['sk hynix inc']='SK Hynix', ['sk hynix inc.']='SK Hynix',
    ['skhynix']='SK Hynix', ['samsung']='Samsung',
    ['samsung electronics']='Samsung', ['samsung electronics co., ltd.']='Samsung',
    ['micron']='Micron', ['micron technology']='Micron', ['micron technology inc.']='Micron',
    ['kingston']='Kingston', ['kingston technology']='Kingston',
    ['crucial']='Crucial', ['corsair']='Corsair'
}
local placeholders = {
    ['']=true, ['unknown']=true, ['unknown manufacturer']=true, ['unspecified']=true,
    ['not specified']=true, ['not available']=true, ['none']=true, ['n/a']=true, ['undefined']=true,
    ['other']=true, ['default string']=true, ['to be filled by o.e.m.']=true,
    ['to be filled by oem']=true, ['manufacturer']=true
}
local forbidden = {['#']=true, ['[']=true, [']']=true, ['%']=true,
    ['"']=true, ["'"]=true, ['!']=true, ['\\']=true}

local function integer(text, maximum)
    if not text or not text:match('^%d+$') then return nil end
    local n = tonumber(text)
    if not n or n > maximum then return nil end
    return n
end

-- Validate UTF-8 ourselves for Rainmeter's Lua 5.1; keep firmware data literal.
local function literalUTF8(raw)
    local out, i = {}, 1
    while i <= #raw do
        local first = raw:byte(i)
        local count, point, minimum
        if first < 128 then count, point, minimum = 1, first, 0
        elseif first >= 194 and first <= 223 then count, point, minimum = 2, first-192, 128
        elseif first >= 224 and first <= 239 then count, point, minimum = 3, first-224, 2048
        elseif first >= 240 and first <= 244 then count, point, minimum = 4, first-240, 65536
        else return nil end
        if i+count-1 > #raw then return nil end
        for j = 1, count-1 do
            local continuation = raw:byte(i+j)
            if continuation < 128 or continuation > 191 then return nil end
            point = point*64 + continuation-128
        end
        if point < minimum or point > 1114111 or (point >= 55296 and point <= 57343) then return nil end
        local character = raw:sub(i, i+count-1)
        local control = point < 32 or (point >= 127 and point <= 159)
            or (point >= 8203 and point <= 8207) or (point >= 8232 and point <= 8238)
            or (point >= 8294 and point <= 8297) or point == 65279
        out[#out+1] = (control or forbidden[character]) and ' ' or character
        i = i+count
    end
    return table.concat(out):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end

local function manufacturer(raw)
    local clean = literalUTF8(raw)
    if not clean then return nil end
    local lower = clean:lower()
    local opaque = clean:match('^%d+$') or (#clean >= 4 and #clean%2 == 0 and clean:match('^%x+$'))
        or clean:match('^0[xX]%x+$')
    if placeholders[lower] or opaque then
        return {text='Unknown manufacturer', identity='unknown:'..raw, literal=clean, unknown=true}
    end
    -- Only explicit aliases are renamed; never search for a vendor substring.
    local name = aliases[lower] or clean
    return {text=name, identity='name:'..name, literal=clean, unknown=false}
end

function M.Parse(raw)
    if type(raw) ~= 'string' or #raw > MAX_WIRE then return nil end
    raw = raw:match('^%s*(.-)%s*$')
    local rows = raw:match('^RAMINFO2|(.+)$')
    if not rows or rows:sub(1,1) == ';' or rows:sub(-1) == ';' or rows:find(';;',1,true) then return nil end
    local result = {devices={}}
    for row in rows:gmatch('[^;]+') do
        local c,t,r,s,h = row:match('^(%d+),(%d+),(%d+),(%d+),(%x*)$')
        local capacity = integer(c, MAX_INTEGER)
        local kind, rate, source = integer(t, 65535), integer(r, 4294967295), integer(s, 1)
        if not capacity or not kind or not rate or not source or not h
            or #h > 256 or #h%2 ~= 0 or #result.devices >= MAX_DEVICES then return nil end
        local name = h:gsub('%x%x', function(pair) return string.char(tonumber(pair,16)) end)
        local maker = manufacturer(name)
        if not maker or (source == 1 and maker.text ~= 'SK Hynix') then return nil end
        result.devices[#result.devices+1] = {
            capacity=capacity, type=kind, rate=rate, makerSource=source,
            manufacturer=name, maker=maker
        }
    end
    if #result.devices == 0 then return nil end
    return result
end

local function field(text, tip) return {text=text, tip=tip} end

local function clock(kind, rate)
    local raw = string.format('%.0f',rate)
    if rate == 0 or rate == 65535 or rate == 4294967295 then
        return 'rate unknown', 'Configured transfer rate is unavailable or unresolved (firmware value '..raw..').'
    end
    if kind == 26 then
        for _, bin in ipairs(ddr4Bins) do
            if math.abs(rate-bin) <= 1 then
                return string.format('%.1f MHz nominal',bin/2),
                    'Nominal clock inferred from a standard DDR4 speed bin within 1 MT/s of the firmware-reported '
                    ..raw..' MT/s; not a measured live clock. Integer firmware data does not supply fractional clock precision.'
            end
        end
    end
    if doubleRate[kind] then
        return string.format('~%.0f MHz derived',rate/2),
            'Approximate DDR I/O clock derived from firmware-reported '..raw..' MT/s divided by two; not a measured live clock.'
    end
    return raw..' MT/s', 'Configured transfer rate reported by firmware: '..raw..' MT/s; not a measured live clock.'
end

function M.Format(data, useMiB, decimals)
    if type(data) ~= 'table' or type(data.devices) ~= 'table' or #data.devices == 0 then
        return {Summary=field('Unavailable', 'Windows memory inventory is unavailable. Refresh the skin to retry. Live physical RAM readings below are independent.'), groups={}}
    end
    -- Keep the legacy preference flag, while using decimal capacity units.
    local unit, divisor = 'GB', 1000000000
    if tonumber(useMiB) == 1 then unit, divisor = 'MB', 1000000 end
    decimals = tonumber(decimals) or 1
    if decimals ~= decimals or decimals == math.huge or decimals == -math.huge then decimals=1 end
    decimals = math.max(0, math.min(2, math.floor(decimals)))
    local groups, indexed = {}, {}
    for _, device in ipairs(data.devices) do
        local maker = device.maker
        local key = #maker.identity..':'..maker.identity..':'..string.format('%.0f',device.capacity)
            ..':'..device.type..':'..device.rate
        local group = indexed[key]
        if not group then
            group = {manufacturer=maker.text, identity=maker.identity, capacity=device.capacity,
                type=device.type, rate=device.rate, count=0, labels={}, inferred=0, unknown=maker.unknown}
            indexed[key], groups[#groups+1] = group, group
        end
        group.count = group.count+1
        if device.makerSource == 1 then group.inferred=group.inferred+1
        else group.labels[maker.literal] = true end
    end
    table.sort(groups, function(a,b)
        if a.identity ~= b.identity then return a.identity < b.identity end
        if a.capacity ~= b.capacity then return a.capacity < b.capacity end
        if a.type ~= b.type then return a.type < b.type end
        return a.rate < b.rate
    end)
    local texts, tips = {}, {}
    for _, group in ipairs(groups) do
        local capacity = group.capacity > 0 and string.format('%.'..decimals..'f %s',group.capacity/divisor,unit) or 'capacity unknown'
        local kind = types[group.type] or 'Unknown type'
        local speed, speedTip = clock(group.type,group.rate)
        group.text = group.manufacturer..' '..capacity..' '..kind..' @ '..speed
            ..' x '..group.count..(group.count == 1 and ' module' or ' modules')
        local labels = {}
        for label in pairs(group.labels) do labels[#labels+1] = label ~= '' and label or '(empty)' end
        table.sort(labels)
        local makerTip = #labels > 0 and ('Firmware manufacturer label(s): '..table.concat(labels, ', ')..'. ') or ''
        if group.inferred > 0 then
            makerTip = makerTip..'Manufacturer for '..group.inferred..' record(s) identified from the firmware-reported part number using SK Hynix published DDR4 module naming scheme. '
        end
        if group.unknown then makerTip=makerTip..'The manufacturer label could not be resolved. ' end
        group.tip = group.text..'\n'..makerTip
            ..(group.capacity > 0 and ('Each record reports '..string.format('%.0f',group.capacity)..' bytes. ') or 'Per-record capacity is unknown. ')
            ..'SMBIOS memory type code: '..group.type..'. '..speedTip
        texts[#texts+1], tips[#tips+1] = group.text, group.tip
    end
    tips[#tips+1] = 'Groups use manufacturer, exact per-record capacity, memory type and raw configured rate. '
        ..'Counts reflect Windows memory-device records; soldered devices may be included. '
        ..'This inventory does not establish free upgrade slots or memory channel mode.'
    return {Summary=field(table.concat(texts,'\n'),table.concat(tips,'\n\n')), groups=groups}
end

return M
