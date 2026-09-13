-- Test-only paging-file frames. Never loaded by production skins or helpers.
return function(model, check)
    local token = string.rep('a',32)
    local otherToken = string.rep('b',32)
    local now = 1700000000
    local function wire(changes)
        local fields = {'RAM_PAGE','1',token,'17',tostring(now),'OK','2600000000','10000000000','2'}
        for index,value in pairs(changes or {}) do fields[index] = value end
        return table.concat(fields,'|')
    end
    local function parse(output, interval, lastSequence, lastEpoch, at)
        return model.Parse(output,token,at or now,interval or 1000,lastSequence,lastEpoch)
    end
    local function accepted(output, message, interval, lastSequence, lastEpoch, at)
        local frame = parse(output,interval,lastSequence,lastEpoch,at)
        check(type(frame)=='table',message or 'Valid paging-file frame rejected')
        return frame
    end
    local function rejected(output, message, interval, lastSequence, lastEpoch, at)
        local frame,reason = parse(output,interval,lastSequence,lastEpoch,at)
        check(frame==nil,message or 'Invalid paging-file frame accepted')
        check(type(reason)=='string' and #reason>0,'Rejected paging-file frame needs an explanatory reason')
    end
    local function formatted(frame, units, decimals, expected)
        local result = model.Format(frame,units,decimals)
        check(type(result)=='table' and type(result.text)=='string' and type(result.tip)=='string',
            'Paging-file display must supply literal text and tooltip')
        check(#result.tip>0,'Paging-file display lost its explanatory tooltip')
        if expected then check(result.text==expected,'Unexpected paging-file display: '..result.text) end
        return result
    end
    local function hex(value)
        return (value:gsub('.',function(c) return string.format('%02X',string.byte(c)) end))
    end

    local sample = accepted(wire())
    check(sample.status=='OK' and sample.used==2600000000 and sample.total==10000000000 and sample.count==2,
        'Parsed paging-file values changed')
    check(sample.sequence==17 and sample.epoch==now,'Parsed paging-file ordering metadata changed')
    for _,units in ipairs({0,1}) do
        for decimals=0,2 do
            local expectations = units==1 and {'2600/10000 MB','2600.0/10000.0 MB','2600.00/10000.00 MB'}
                or {'3/10 GB','2.6/10.0 GB','2.60/10.00 GB'}
            formatted(sample,units,decimals,expectations[decimals+1])
        end
    end
    local precise = accepted(wire({[7]='123456789',[8]='1987654321',[9]='1'}))
    formatted(precise,0,2,'0.12/1.99 GB')
    formatted(precise,1,2,'123.46/1987.65 MB')
    local zero = accepted(wire({[7]='0',[8]='8000000000',[9]='1'}))
    formatted(zero,0,1,'0.0/8.0 GB')
    formatted(zero,1,0,'0/8000 MB')
    local emptyAllocation = accepted(wire({[7]='0',[8]='0',[9]='1'}))
    formatted(emptyAllocation,0,2,'0.00/0.00 GB')
    local maximum = accepted(wire({[7]='9007199254740991',[8]='9007199254740991',[9]='512'}))
    check(maximum.used==9007199254740991 and maximum.total==9007199254740991 and maximum.count==512,
        'Exact maximum supported paging-file values lost')
    local usedTip = formatted(precise,0,2).tip
    check(usedTip:find('123456789 bytes',1,true) and usedTip:find('1987654321 bytes',1,true),
        'Paging-file tooltip lost exact used or allocated bytes')
    check(usedTip:find('1 paging file.',1,true),'Single paging-file tooltip is grammatically incorrect')
    local scopeTip = formatted(sample,0,1).tip
    check(scopeTip:find('2 paging files.',1,true),'Paging-file count missing from tooltip')
    check(scopeTip:find('Excludes physical RAM and system commit accounting.',1,true),
        'Paging-file scope is not distinguished from RAM and system commit')
    check(scopeTip:find('Allocated capacity can grow automatically.',1,true),
        'Paging-file allocated capacity was represented as a fixed maximum')
    formatted(sample,0,99,'2.60/10.00 GB')
    formatted(sample,0,-2,'3/10 GB')
    formatted(sample,0,1.9,'2.6/10.0 GB')
    formatted(sample,true,1,'2600.0/10000.0 MB')
    formatted(sample,'1',1,'2600.0/10000.0 MB')
    for _,badDecimals in ipairs({0/0,math.huge,-math.huge,'invalid'}) do
        formatted(sample,0,badDecimals,'2.6/10.0 GB')
    end
    formatted(sample,0,nil,'2.6/10.0 GB')
    formatted(nil,0,1,'Unavailable')
    formatted({status='UNKNOWN'},1,0,'Unavailable')
    check(sample.used==2600000000 and sample.total==10000000000 and sample.count==2,
        'Unit or precision changes mutated cached paging-file bytes')

    for _,case in ipairs({{'NONE','0','0','0','No paging file'},
        {'STARTING','?','?','?','Checking...'},
        {'UNAVAILABLE','?','?','?','Unavailable'},
        {'UNSUPPORTED','?','?','?','Unsupported'}}) do
        local status = accepted(wire({[6]=case[1],[7]=case[2],[8]=case[3],[9]=case[4]}))
        check(status.status==case[1],'Paging-file status changed during parsing')
        formatted(status,0,2,case[5])
        formatted(status,1,0,case[5])
    end

    rejected(nil,'Non-string paging-file frame accepted')
    rejected(1,'Numeric paging-file frame accepted')
    for _,output in ipairs({'','RAM_PAGE',wire()..'|extra',wire()..'\n'..wire(),
        wire():sub(1,-3),string.rep('x',513)}) do
        rejected(output,'Incomplete, duplicate or oversized paging-file wire accepted')
    end
    for _,changes in ipairs({{[1]='RAM_PAGE_SESSION'},{[1]='RAM_PAGE2'},{[2]='0'},{[2]='2'},
        {[2]='01'},{[3]=otherToken},{[3]=string.rep('A',32)},{[3]=string.rep('a',31)},
        {[3]=string.rep('a',33)},{[3]=string.rep('g',32)},
        {[6]='ok'},{[6]='UNKNOWN'},{[6]='NONE',[7]='1',[8]='1',[9]='0'},
        {[6]='NONE',[7]='0',[8]='0',[9]='1'},
        {[6]='NONE',[7]='?',[8]='?',[9]='?'},
        {[6]='STARTING',[7]='0',[8]='0',[9]='0'},
        {[6]='UNAVAILABLE',[7]='0',[8]='0',[9]='0'},
        {[6]='UNSUPPORTED',[7]='0',[8]='0',[9]='0'},
        {[7]='10000000001'},{[7]='9007199254740992',[8]='9007199254740992'},
        {[8]='9007199254740992'},{[9]='0'},{[9]='513'},{[4]='9007199254740992'},
        {[5]='253402300800'}}) do
        rejected(wire(changes),'Invalid paging-file field or state accepted')
    end
    for _,index in ipairs({4,5,7,8,9}) do
        for _,value in ipairs({'','-1','+1','01','00','1.0','1e3',' 1','1 ','?','nan','inf','0x10'}) do
            rejected(wire({[index]=value}),'Non-canonical numeric paging-file field accepted')
        end
    end
    for _,status in ipairs({'STARTING','UNAVAILABLE','UNSUPPORTED'}) do
        for _,index in ipairs({7,8,9}) do
            local fields = {[6]=status,[7]='?',[8]='?',[9]='?'}
            fields[index]='0'
            rejected(wire(fields),'Partial numeric payload accepted for unavailable paging-file status')
        end
    end
    for _,unsafe in ipairs({'\0','\r','\n','\t','#','[!Execute]','%1'}) do
        rejected(wire({[6]=unsafe}),'Unsafe or control-bearing paging-file status accepted')
    end

    accepted(wire({[5]=tostring(now-8)}),'Freshness boundary rejected')
    rejected(wire({[5]=tostring(now-9)}),'Stale paging-file frame accepted')
    accepted(wire({[5]=tostring(now+5)}),'Allowed clock skew rejected')
    rejected(wire({[5]=tostring(now+6)}),'Future paging-file frame accepted')
    accepted(wire({[5]=tostring(now-11)}),'Interval-adjusted freshness boundary rejected',3000)
    rejected(wire({[5]=tostring(now-12)}),'Interval-adjusted stale frame accepted',3000)
    accepted(wire({[5]=tostring(now-12)}),'Fractional-second interval freshness boundary rejected',3001)
    rejected(wire({[5]=tostring(now-13)}),'Fractional-second interval stale frame accepted',3001)
    accepted(wire({[5]=tostring(now-92)}),'Slow-interval freshness boundary rejected',30000)
    rejected(wire({[5]=tostring(now-93)}),'Slow-interval stale frame accepted',30000)
    accepted(wire(),'Same frame reread rejected',1000,17,now)
    accepted(wire({[4]='18'}),'Next sequence in same second rejected',1000,17,now)
    accepted(wire({[4]='18',[5]=tostring(now+1)}),'Advancing frame rejected',1000,17,now)
    rejected(wire({[4]='16'}),'Regressed sequence accepted',1000,17,now)
    rejected(wire({[4]='18',[5]=tostring(now-1)}),'Regressed epoch accepted',1000,17,now)
    rejected(wire({[5]=tostring(now+1)}),'Same sequence with changed epoch accepted',1000,17,now)
    local maxOrdering = accepted(wire({[4]='9007199254740991',[5]='253402300799'}),
        'Maximum supported sequence and epoch rejected',1000,nil,nil,253402300799)
    check(maxOrdering.sequence==9007199254740991 and maxOrdering.epoch==253402300799,
        'Maximum ordering metadata changed')
    local origin = accepted(wire({[4]='0',[5]='0'}),'Canonical zero ordering values rejected',1000,nil,nil,0)
    check(origin.sequence==0 and origin.epoch==0,'Zero ordering metadata changed')
    for _,badInterval in ipairs({0,999,30001,1000.5,-1,math.huge,0/0,'1000'}) do
        check(model.Fresh(now,now,badInterval)==false,'Invalid collection interval accepted for freshness')
    end
    check(model.Fresh(now,now,nil)==false,'Missing collection interval accepted for freshness')
    for _,badTime in ipairs({-1,now+0.5,253402300800,math.huge,0/0,tostring(now)}) do
        check(model.Fresh(badTime,now,1000)==false,'Invalid epoch accepted for freshness')
        check(model.Fresh(now,badTime,1000)==false,'Invalid current time accepted for freshness')
    end
    check(model.Fresh(nil,now,1000)==false and model.Fresh(now,nil,1000)==false,
        'Missing epoch or current time accepted for freshness')
    for _,badToken in ipairs({'',otherToken,string.rep('A',32),string.rep('a',31),string.rep('a',33),1}) do
        check(model.Parse(wire(),badToken,now,1000)==nil,'Wrong or malformed expected session token accepted')
    end
    check(model.Parse(wire(),nil,now,1000)==nil,'Missing expected session token accepted')
    for _,case in ipairs({{'NONE','0','0','0'},{'STARTING','?','?','?'},
        {'UNAVAILABLE','?','?','?'},{'UNSUPPORTED','?','?','?'}}) do
        rejected(wire({[5]=tostring(now-9),[6]=case[1],[7]=case[2],[8]=case[3],[9]=case[4]}),
            'Stale status frame accepted')
    end

    local root = 'C:\\Synthetic Temp'
    local path = root..'\\Parallax-RAM-Page-'..token..'.dat'
    local function session(output, roots)
        return model.ParseSession(output,roots or {root})
    end
    local function sessionWire(value, sessionToken)
        return 'RAM_PAGE_SESSION|1|'..(sessionToken or token)..'|'..hex(value)
    end
    local validSession = session(sessionWire(path))
    check(type(validSession)=='table','Valid paging-file session rejected')
    check(validSession.token==token and validSession.path==path,'Session token or temporary path changed')
    local base = path:sub(1,-5)
    check(validSession.lease==base..'.lease' and validSession.tmp==base..'.tmp',
        'Session sidecar paths are inconsistent with the bounded data path')
    check(session(sessionWire(path),{'D:\\Other',root..'\\'})~=nil,
        'Allowed root list or trailing root separator rejected')
    check(session(sessionWire(path),{'c:/synthetic temp/'})~=nil,
        'Windows root case or separator normalization failed')
    local slashPath = path:gsub('\\','/')
    check(session(sessionWire(slashPath)).path==slashPath,'Forward-slash temporary path was rejected or rewritten')
    check(session((sessionWire(path):lower():gsub('ram_page_session','RAM_PAGE_SESSION')))~=nil,
        'Lowercase hexadecimal path encoding rejected')
    local utf8Root = 'C:\\M'..string.char(195,188)..'ller\\Temp'
    local utf8Path = utf8Root..'\\Parallax-RAM-Page-'..token..'.dat'
    check(session(sessionWire(utf8Path),{utf8Root}).path==utf8Path,'Legitimate UTF-8 temporary root was lost')
    local function invalidSession(output, message, roots)
        check(session(output,roots)==nil,message or 'Unsafe paging-file session accepted')
    end
    invalidSession(nil,'Non-string paging-file session accepted')
    invalidSession(1,'Numeric paging-file session accepted')
    invalidSession(sessionWire(path), 'Session accepted without an allowed temporary root',{})
    for _,output in ipairs({'',string.rep('x',4201),'RAM_PAGE_SESSION|1|'..token,
        sessionWire(path)..'|extra','RAM_PAGE_SESSION|2|'..token..'|'..hex(path),
        'RAM_PAGE_SESSION|1|'..token..'|0','RAM_PAGE_SESSION|1|'..token..'|GG',
        sessionWire(path,otherToken),sessionWire(path,string.rep('A',32)),
        'RAM_PAGE_SESSION|1|'..token..'|C0AF','RAM_PAGE_SESSION|1|'..token..'|EDA080'}) do
        invalidSession(output,'Malformed paging-file session accepted')
    end
    for _,badUTF8 in ipairs({'80','C0AF','C1BF','C2','C241','EDA080','F0808080','F4908080','F5808080','FF'}) do
        local bytes = badUTF8:gsub('%x%x',function(pair) return string.char(tonumber(pair,16)) end)
        local badRoot = 'C:\\Temp'..bytes
        invalidSession(sessionWire(badRoot..'\\Parallax-RAM-Page-'..token..'.dat'),
            'Invalid UTF-8 accepted in matching temporary root',{badRoot})
    end
    for _,control in ipairs({string.char(0),string.char(9),string.char(10),string.char(13),
        string.char(31),string.char(127),string.char(194,128),string.char(194,159)}) do
        local badRoot = 'C:\\Temp'..control
        invalidSession(sessionWire(badRoot..'\\Parallax-RAM-Page-'..token..'.dat'),
            'Control character accepted in matching temporary root',{badRoot})
    end
    for _,badPath in ipairs({'C:\\Elsewhere\\Parallax-RAM-Page-'..token..'.dat',
        root..'Sibling\\Parallax-RAM-Page-'..token..'.dat',
        root..'\\..\\Parallax-RAM-Page-'..token..'.dat',
        root..'\\Nested\\Parallax-RAM-Page-'..token..'.dat',
        root..'\\Parallax-RAM-Page-'..otherToken..'.dat',
        root..'\\Parallax-RAM-Page-'..token..'.txt',
        root..'\\Parallax-RAM-Page-'..token..'.dat:stream',
        root..'\\Parallax-RAM-Page-'..token..'.dat\\child',
        root..'\\Parallax-RAM-Page-'..token..'.dat\0',
        root..'\\Parallax-RAM-Page-'..token..'.dat\n',
        'Parallax-RAM-Page-'..token..'.dat',
        '\\\\server\\share\\Parallax-RAM-Page-'..token..'.dat'}) do
        invalidSession(sessionWire(badPath),'Out-of-root, mismatched or unsafe paging-file session path accepted')
    end
end
