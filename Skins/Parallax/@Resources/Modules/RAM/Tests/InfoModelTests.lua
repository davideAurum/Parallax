-- Test-only numeric inventories. These are never loaded by production skins.
return function(model, check)
    local function parsed(raw)
        local result = model.Parse(raw)
        check(result ~= nil, 'Valid hardware inventory rejected: '..raw)
        return result
    end
    local function text(fields, key, expected)
        check(fields[key].text == expected, key..' expected '..expected..', received '..tostring(fields[key].text))
        check(type(fields[key].tip) == 'string' and #fields[key].tip > 0, key..' has no explanatory tooltip')
    end
    check(model.Parse(nil) == nil, 'Missing inventory must be unavailable')
    check(model.Parse(1) == nil, 'Non-string inventory must be unavailable')
    for _, raw in ipairs({'', 'UNAVAILABLE', 'RAMINFO2|4|8,26,3200,8', 'RAMINFO1|4|',
        'RAMINFO1|-1|8,26,3200,8', 'RAMINFO1|65536|8,26,3200,8',
        'RAMINFO1|4|8,26,3200,8;', 'RAMINFO1|4|8,26,3200,8;;8,26,3200,8',
        'RAMINFO1|4|8,26,3200', 'RAMINFO1|4|8,26,3200,8,9',
        'RAMINFO1|4|-8,26,3200,8', 'RAMINFO1|4|8.5,26,3200,8',
        'RAMINFO1|4|8,26,3200,8|extra', 'RAMINFO1|4|8,26,4294967296,8',
        'RAMINFO1|4|9007199254740992,26,3200,8', 'RAMINFO1|4|8,65536,3200,8',
        'RAMINFO1|4|8,26,3200,65536'}) do
        check(model.Parse(raw) == nil, 'Malformed inventory accepted: '..raw)
    end
    check(model.Parse('RAMINFO1|4|'..string.rep('8,26,3200,8;',512)..'8,26,3200,8') == nil,
        'Excessive device count accepted')
    check(model.Parse(string.rep('x',65537)) == nil, 'Oversized protocol accepted')
    local standard = parsed(' \r\nRAMINFO1|4|8589934592,26,3200,8;8589934592,26,3200,8\r\n')
    local fields = model.Format(standard, 0, 2)
    text(fields, 'Installed', '16.00 GiB')
    text(fields, 'Type', 'DDR4')
    text(fields, 'Speed', '3200 MT/s')
    text(fields, 'Devices', '2 / 4')
    text(fields, 'Form', 'DIMM')
    text(model.Format(standard, 1, 0), 'Installed', '16384 MiB')
    text(model.Format(standard, 1, 1), 'Installed', '16384.0 MiB')
    text(model.Format(standard, 0, 99), 'Installed', '16.00 GiB')
    text(model.Format(standard, 0, -2), 'Installed', '16 GiB')
    text(model.Format(standard, 0, 0/0), 'Installed', '16.0 GiB')
    text(model.Format(standard, 0, math.huge), 'Installed', '16.0 GiB')
    local mixed = model.Format(parsed('RAMINFO1|4|8589934592,26,3200,8;8589934592,34,4800,12'), 0, 1)
    for _, key in ipairs({'Type','Speed','Form'}) do text(mixed,key,'Mixed') end
    text(mixed,'Installed','16.0 GiB')
    check(mixed.Speed.tip:find('3200 MT/s',1,true) ~= nil and mixed.Speed.tip:find('4800 MT/s',1,true) ~= nil,
        'Mixed rate tooltip lost reported values')
    local partial = model.Format(parsed('RAMINFO1|4|8589934592,26,3200,8;0,0,0,0'),0,1)
    for _, key in ipairs({'Installed','Type','Speed','Form'}) do text(partial,key,'Partial') end
    text(partial,'Devices','2 reported')
    local unknown = model.Format(parsed('RAMINFO1|0|0,0,0,0'),0,1)
    for _, key in ipairs({'Installed','Type','Speed','Form'}) do text(unknown,key,'Unknown') end
    text(unknown,'Devices','1 reported')
    local future = model.Format(parsed('RAMINFO1|0|8589934592,65535,0,65535'),0,1)
    for _, key in ipairs({'Type','Speed','Form'}) do text(future,key,'Unknown') end
    text(future,'Installed','8.0 GiB')
    text(future,'Devices','1 reported')
    local inconsistent = model.Format(parsed('RAMINFO1|1|8589934592,26,3200,8;8589934592,26,3200,8'),0,1)
    text(inconsistent,'Devices','2 reported')
    local overflow = model.Format(parsed('RAMINFO1|2|9007199254740991,26,3200,8;9007199254740991,26,3200,8'),0,1)
    text(overflow,'Installed','Partial')
    for _, case in ipairs({{18,'DDR'},{19,'DDR2'},{20,'DDR2 FB-DIMM'},{24,'DDR3'},{34,'DDR5'},{35,'LPDDR5'}}) do
        text(model.Format(parsed('RAMINFO1|1|8589934592,'..case[1]..',3200,12'),0,1),'Type',case[2])
    end
    text(model.Format(parsed('RAMINFO1|1|8589934592,35,6400,21'),0,1),'Form','BGA')
    local unavailable = model.Format(nil,0,1)
    for _, key in ipairs({'Installed','Type','Speed','Devices','Form'}) do text(unavailable,key,'Unavailable') end
end
