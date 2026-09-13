-- Test-only synthetic process rankings. Never loaded by production skins.
return function(model, check)
    local function contains(value, needle, message)
        check(value:find(needle,1,true) ~= nil, message or ('Missing '..needle))
    end
    local function excludes(value, needle, message)
        check(value:find(needle,1,true) == nil, message or ('Unexpected '..needle))
    end
    local function sample(name, bytes) return {name=name,bytes=bytes} end
    local function formatted(samples, units, decimals)
        local result = model.Format(samples,units,decimals)
        check(type(result.rows)=='table' and type(result.state)=='string' and type(result.tip)=='string',
            'Invalid process-model contract')
        check(#result.rows<=5,'More than five ranks displayed')
        return result
    end
    for _, input in ipairs({false,1,'invalid',{}}) do
        local result = formatted(input)
        check(#result.rows==0 and result.state=='No process data','Empty inventory must be explicit')
        contains(result.tip,'not measured zero')
    end
    check(formatted(nil).state=='No process data','Nil input must be unavailable')
    local five = {
        sample('Browser',2500000000), sample('Editor',1234567890),
        sample('Service',400000000), sample('Player',120000000), sample('Shell',15000000)
    }
    local result = formatted(five,0,1)
    check(#result.rows==5 and result.state=='','Complete ranking should display five rows')
    check(result.rows[1].name=='Browser' and result.rows[1].text=='2.5 GB','Incorrect first rank')
    check(result.rows[2].name=='Editor' and result.rows[2].text=='1.2 GB','Incorrect second rank')
    contains(result.rows[1].tip,'2500000000 bytes')
    contains(result.tip,'same counter name are combined')
    contains(result.tip,'resident process memory excluding shared pages')
    contains(result.tip,'no separate freshness signal')
    contains(result.tip,'1 GB = 1000000000 bytes')
    contains(result.tip,'5 of 5 ranked entries')
    check(formatted(five,1,1).rows[2].text=='1234.6 MB','MB conversion must be decimal')
    check(formatted(five,'1','2').rows[2].text=='1234.57 MB','Numeric preference strings rejected')
    check(formatted(five,0,0).rows[2].text=='1 GB','Zero-decimal setting ignored')
    check(formatted(five,0,2).rows[2].text=='1.23 GB','Two-decimal setting ignored')
    check(formatted(five,0,99).rows[2].text=='1.23 GB','Precision upper bound ignored')
    check(formatted(five,0,-99).rows[2].text=='1 GB','Precision lower bound ignored')
    check(formatted(five,0,1.9).rows[2].text=='1.2 GB','Fractional precision not floored')
    for _, precision in ipairs({0/0,math.huge,-math.huge,'invalid',false,{}}) do
        check(formatted(five,0,precision).rows[2].text=='1.2 GB','Invalid precision must default')
    end
    check(formatted(five,2,1).rows[1].text=='2.5 GB','Unknown unit flag must use GB')
    check(five[1].bytes==2500000000 and five[1].name=='Browser','Formatting mutated cached sample')

    local small = {sample('Small',1)}
    check(formatted(small,0,0).rows[1].text=='<1 GB','Small positive GB reading displayed as zero')
    check(formatted(small,0,1).rows[1].text=='<0.1 GB','Small positive one-decimal reading displayed as zero')
    check(formatted(small,1,2).rows[1].text=='<0.01 MB','Small positive MB reading displayed as zero')
    contains(formatted(small).rows[1].tip,'1 byte)')
    local invalidBytes = {0,-1,0/0,math.huge,-math.huge,9007199254740992,1.5,'1000',false,{}}
    for _,bytes in ipairs(invalidBytes) do
        check(#formatted({sample('Invalid',bytes)}).rows==0,'Invalid byte count accepted')
    end
    check(#formatted({sample('Missing',nil)}).rows==0,'Missing byte count accepted')
    check(#formatted({sample('Maximum',9007199254740991)}).rows==1,'Safe integer maximum rejected')

    local partial = formatted({
        sample('',1000000),sample('Second',2000000),sample('Third',0),
        sample('Fourth',4000000),sample('Fifth',5000000),sample('Sixth',6000000)
    },1,0)
    check(#partial.rows==3 and partial.state=='','Valid partial rankings should remain visible')
    check(partial.rows[1].name=='Second' and partial.rows[2].name=='Fourth','Provider order changed')
    check(partial.rows[3].name=='Fifth','Sixth input rank leaked into the top five')
    contains(partial.tip,'3 of 5 ranked entries')
    local sparse = formatted({[2]=sample('Only',1000000)})
    check(#sparse.rows==1 and sparse.rows[1].name=='Only','Missing early ranks hid later ranks')
    for _, name in ipairs({'','  ','_Total','Idle','IDLE',' \t\r\n ',string.rep('x',1025),false,3,{}}) do
        check(#formatted({sample(name,1000000)}).rows==0,'Invalid or excluded name accepted')
    end
    check(#formatted({sample(nil,1000000)}).rows==0,'Missing name accepted')
    check(#formatted({sample(string.rep('x',1024),1000000)}).rows==1,'Maximum bounded name rejected')
    check(#formatted({false,1,'row',{},sample('Valid',1000000)}).rows==1,'Invalid row shape accepted')

    local unsafe = formatted({sample('  A#B[Measure]%1 "x" \'y\' !Bang \\path\r\n\tend  ',1000000)})
    local safe = unsafe.rows[1]
    check(safe.name=='A B Measure 1 x y Bang path end','Process name was not made literal')
    for _,token in ipairs({'#','[',']','%','"',"'",'!','\\','\r','\n','\t'}) do
        excludes(safe.name,token,'Unsafe name token remained')
        excludes(safe.tip,token,'Unsafe tooltip token remained')
    end
    local unicode = 'Editeur '..string.char(195,169)..' '..string.char(230,181,139,232,175,149)
    check(formatted({sample(unicode,1000000)}).rows[1].name==unicode,'Legitimate Unicode name corrupted')
    local control = 'safe'..string.char(226,128,174)..'name'..string.char(194,133)..'end'
    check(formatted({sample(control,1000000)}).rows[1].name=='safe name end','Unicode controls remained')
    for _, bytes in ipairs({
        {128},{192,175},{193,191},{194},{194,65},{237,160,128},
        {240,128,128,128},{244,144,128,128},{245,128,128,128},{255}
    }) do
        local parts = {}
        for _,byte in ipairs(bytes) do parts[#parts+1]=string.char(byte) end
        check(#formatted({sample(table.concat(parts),1000000)}).rows==0,'Invalid UTF-8 name accepted')
    end
    local sameNames = formatted({sample('App',3000000),sample('App',2000000)},1,0)
    check(#sameNames.rows==2 and sameNames.rows[1].text=='3 MB' and sameNames.rows[2].text=='2 MB',
        'Formatter must not merge independently read ranks or fabricate a new aggregate')
end
