-- Test-only synthetic inventories. Never loaded by production skins.
return function(model, check)
    local function hex(value)
        return (value:gsub('.',function(c) return string.format('%02X',string.byte(c)) end))
    end
    local function row(capacity,kind,rate,name,source)
        return string.format('%.0f,%d,%.0f,%d,%s',capacity,kind,rate,source or 0,hex(name or ''))
    end
    local function parsed(rows)
        local result = model.Parse('RAMINFO2|'..rows)
        check(result ~= nil, 'Valid hardware inventory rejected')
        return result
    end
    local function summary(data,units,decimals)
        local result = model.Format(data,units or 0,decimals)
        check(type(result.Summary.text)=='string' and type(result.Summary.tip)=='string' and #result.Summary.tip>0,
            'Summary must include literal text and explanatory tooltip')
        check(type(result.groups)=='table', 'Missing grouped summary data')
        return result
    end
    local function contains(value,needle,message)
        check(value:find(needle,1,true) ~= nil,message or ('Missing '..needle))
    end
    local function excludes(value,needle,message)
        check(value:find(needle,1,true) == nil,message or ('Unexpected '..needle))
    end
    local sample = row(8589934592,26,2666,'SK Hynix',1)
    check(model.Parse(nil)==nil and model.Parse(1)==nil, 'Non-string inventory accepted')
    for _,raw in ipairs({'','UNAVAILABLE','RAMINFO1|4|8,26,3200,8','RAMINFO2|',
        'RAMINFO2|;'..sample,'RAMINFO2|'..sample..';','RAMINFO2|'..sample..';;'..sample,
        'RAMINFO2|-8,26,2666,0,','RAMINFO2|8.5,26,2666,0,','RAMINFO2|8,26,2666,2,',
        'RAMINFO2|9007199254740992,26,2666,0,','RAMINFO2|8,65536,2666,0,',
        'RAMINFO2|8,26,4294967296,0,','RAMINFO2|8,26,2666,-1,',
        'RAMINFO2|8,26,2666,0,0','RAMINFO2|8,26,2666,0,GG',
        'RAMINFO2|8,26,2666,0,4142,extra','RAMINFO2|8,26,2666,0,4142|extra',
        'RAMINFO2|8,26,2666,0,'..string.rep('41',129),
        'RAMINFO2|8,26,2666,1,'..hex('Samsung')}) do
        check(model.Parse(raw)==nil,'Malformed inventory accepted: '..raw)
    end
    for _,badUTF8 in ipairs({'80','C0AF','C1BF','C2','C241','EDA080','F0808080','F4908080','F5808080','FF'}) do
        check(model.Parse('RAMINFO2|8,26,2666,0,'..badUTF8)==nil,'Invalid UTF-8 accepted: '..badUTF8)
    end
    check(model.Parse('RAMINFO2|'..string.rep(sample..';',512)..sample)==nil,'More than 512 records accepted')
    check(model.Parse(string.rep('x',160001))==nil,'Oversized protocol accepted')
    check(model.Parse(' \r\nRAMINFO2|'..sample..'\r\n')~=nil,'Outer whitespace rejected')
    local maximum = parsed(row(9007199254740991,65535,4294967295,string.rep('Z',128)))
    check(maximum.devices[1].capacity==9007199254740991,'Exact maximum capacity lost')
    check(#maximum.devices[1].manufacturer==128,'128-byte manufacturer rejected or truncated')

    local duplicate = parsed(table.concat({sample,sample,sample,sample},';'))
    local result = summary(duplicate,0,1)
    check(#result.groups==1 and result.groups[1].count==4,'Identical records must group')
    check(result.Summary.text=='SK Hynix 8.6 GB DDR4 SDRAM @ 1333.3 MHz nominal x 4 modules','Incorrect nominal DDR4 summary')
    contains(result.Summary.tip,'2666 MT/s','Tooltip lost queried rate')
    contains(result.Summary.tip,'not a measured live clock','Clock inference not explained')
    contains(result.Summary.tip,'published DDR4 module naming scheme','Part-family provenance missing')
    excludes(result.Summary.tip,'HMA','Part numbers must never appear in the model protocol or output')
    contains(summary(duplicate,1,0).Summary.text,'8590 MB')
    contains(summary(duplicate,1,1).Summary.text,'8589.9 MB')
    contains(summary(duplicate,0,2).Summary.text,'8.59 GB')
    contains(summary(duplicate,0,99).Summary.text,'8.59 GB')
    contains(summary(duplicate,0,-2).Summary.text,'9 GB')
    for _,decimals in ipairs({0/0,math.huge,-math.huge,'invalid'}) do
        contains(summary(duplicate,0,decimals).Summary.text,'8.6 GB')
    end
    contains(summary(duplicate,0,1.9).Summary.text,'8.6 GB')
    check(duplicate.devices[1].capacity==8589934592 and duplicate.devices[1].rate==2666,'Formatting mutated inventory')

    local alias = summary(parsed(row(8589934592,26,2666,'Hynix')..';'..row(8589934592,26,2666,' sk hynix inc. ',1)),0,1)
    check(#alias.groups==1 and alias.groups[1].count==2,'Explicit manufacturer aliases should group')
    contains(alias.Summary.tip,'Firmware manufacturer label(s): Hynix')
    contains(alias.Summary.tip,'Manufacturer for 1 record(s) identified','Mixed manufacturer provenance lost')
    local mixed = summary(parsed(table.concat({sample,
        row(17179869184,26,2666,'SK Hynix'),row(8589934592,24,2666,'SK Hynix'),
        row(8589934592,26,3200,'SK Hynix'),row(8589934592,26,2666,'Samsung')},';')),0,1)
    check(#mixed.groups==5,'Different capacities/types/rates/vendors collapsed')
    local _,newlines=mixed.Summary.text:gsub('\n','')
    check(newlines==4,'Each group needs its own line')
    excludes(mixed.Summary.text,'Mixed','Distinct groups must not collapse to Mixed')
    for _,group in ipairs(mixed.groups) do contains(group.text,'x 1 module'); excludes(group.text,'x 1 modules') end
    local nearSizes = summary(parsed(row(8589934592,26,2666,'Acme')..';'..row(8589934593,26,2666,'Acme')),0,0)
    check(#nearSizes.groups==2,'Rounded displayed capacity merged different exact capacities')
    contains(nearSizes.Summary.tip,'8589934592 bytes')
    contains(nearSizes.Summary.tip,'8589934593 bytes')
    local nearRates = summary(parsed(row(8589934592,26,2666,'Acme')..';'..row(8589934592,26,2667,'Acme')),0,1)
    check(#nearRates.groups==2,'Nominal bin formatting merged distinct raw rates')

    local unknowns = summary(parsed(table.concat({row(0,0,0,''),row(8589934592,26,2666,'0000AD010000'),
        row(8589934592,26,2666,'0000CE010000'),row(8589934592,26,2666,'0000AD010000')},';')),0,1)
    check(#unknowns.groups==3,'Distinct opaque identities merged or identical identities split')
    contains(unknowns.Summary.text,'Unknown manufacturer')
    contains(unknowns.Summary.text,'capacity unknown Unknown type @ rate unknown')
    excludes(unknowns.Summary.text,'SK Hynix','Opaque code alone must not identify manufacturer')
    contains(unknowns.Summary.tip,'0000AD010000')
    contains(unknowns.Summary.tip,'0000CE010000')
    contains(unknowns.Summary.text,'x 2 modules')
    for _,name in ipairs({'0','123','0xAD','N/A','To Be Filled By O.E.M.','Undefined',' undefined '}) do
        contains(summary(parsed(row(1,26,2666,name)),0,1).Summary.text,'Unknown manufacturer',
            'Numeric code or firmware placeholder displayed as a manufacturer')
    end
    local partial = summary(parsed(sample..';'..row(0,26,0,'Acme')),0,1)
    check(#partial.groups==2,'Partial record discarded')
    contains(partial.Summary.text,'capacity unknown')
    contains(partial.Summary.text,'rate unknown')
    local future = summary(maximum,0,1)
    contains(future.Summary.text,'Unknown type')
    contains(future.Summary.text,'rate unknown')
    local unavailable = summary(nil,0,1)
    check(unavailable.Summary.text=='Unavailable' and #unavailable.groups==0,'Unavailable inventory fabricated groups')

    for _,case in ipairs({{1600,'800.0'},{1866,'933.3'},{1867,'933.3'},{2133,'1066.7'},
        {2134,'1066.7'},{2400,'1200.0'},{2666,'1333.3'},{2667,'1333.3'},
        {2933,'1466.7'},{2934,'1466.7'},{3200,'1600.0'},{1599,'800.0'},{1601,'800.0'}}) do
        contains(summary(parsed(row(1,26,case[1],'Acme')),0,1).Summary.text,case[2]..' MHz nominal')
    end
    local unusual = summary(parsed(row(1,26,2600,'Acme')),0,1)
    contains(unusual.Summary.text,'~1300 MHz derived')
    excludes(unusual.Summary.text,'nominal')
    for _,case in ipairs({{18,'DDR SDRAM'},{19,'DDR2 SDRAM'},{20,'DDR2 FB-DIMM SDRAM'},
        {24,'DDR3 SDRAM'},{34,'DDR5 SDRAM'}}) do
        local formatted=summary(parsed(row(1,case[1],3200,'Acme')),0,1)
        contains(formatted.Summary.text,case[2])
        contains(formatted.Summary.text,'~1600 MHz derived')
    end
    for _,kind in ipairs({0,15,27,28,29,30,32,33,35,36}) do
        local formatted=summary(parsed(row(1,kind,6400,'Acme')),0,1)
        contains(formatted.Summary.text,'6400 MT/s')
        excludes(formatted.Summary.text,'MHz','Unknown/non-DDR/LPDDR/HBM clock domain must not be inferred')
    end
    contains(summary(parsed(row(1,26,65535,'Acme')),0,1).Summary.text,'rate unknown')

    local attack = '#RAMColor#[!Execute] %1 "quoted" \'single\' \\path\nnext\r\t'..string.char(0,127)
    local sanitized = summary(parsed(row(1,26,2666,attack)),0,1)
    for _,bad in ipairs({'#','[',']','%','"',"'","!",'\\','\r','\t',string.char(0),string.char(127)}) do
        excludes(sanitized.Summary.text,bad,'Unsafe manufacturer content reached Text')
        excludes(sanitized.Summary.tip,bad,'Unsafe manufacturer content reached ToolTipText')
    end
    local _,injectedLines=sanitized.Summary.text:gsub('\n','')
    check(injectedLines==0,'Manufacturer introduced extra summary lines')
    local utf8Name = 'M'..string.char(195,188)..'ller & Co.'
    contains(summary(parsed(row(1,26,2666,utf8Name)),0,1).Summary.text,utf8Name,'Legitimate UTF-8 name lost')
    local bidi = summary(parsed(row(1,26,2666,'A'..string.char(226,128,174)..'B')),0,1)
    excludes(bidi.Summary.text,string.char(226,128,174),'Bidirectional control survived sanitization')
    local noSubstring = summary(parsed(row(1,26,2666,'Not SK Hynix')),0,1)
    contains(noSubstring.Summary.text,'Not SK Hynix','Manufacturer substring was treated as alias')
    local sanitizedUnknowns = summary(parsed(row(1,0,0,'#')..';'..row(1,0,0,'!')),0,1)
    check(#sanitizedUnknowns.groups==2,'Distinct unknown raw identities merged after sanitization')

    local many = {}
    for i=1,512 do many[i]=row(i,26,2666,'Acme') end
    local bounded = summary(parsed(table.concat(many,';')),0,1)
    check(#bounded.groups==512,'Maximum supported group count rejected')
    local longRows = {}
    for i=1,512 do longRows[i]=row(9007199254740991,65535,4294967295,string.rep('Z',128)) end
    check(model.Parse('RAMINFO2|'..table.concat(longRows,';'))~=nil,'Maximum records with maximum names exceeded wire bound')
end
