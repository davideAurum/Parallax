-- Executed in Rainmeter's own Lua runtime by Test-ColorPicker.ps1.
return function(C)
    local count=0
    local function near(actual,expected,tolerance)
        count=count+1
        assert(math.abs(actual-expected)<=tolerance,string.format('Expected %.9f, got %.9f',expected,actual))
    end
    local function check(value) count=count+1; assert(value) end
    local hsvCases={
        {{1,0,0},{0,1,1}},{{1,1,0},{60,1,1}},{{0,1,0},{120,1,1}},
        {{0,1,1},{180,1,1}},{{0,0,1},{240,1,1}},{{1,0,1},{300,1,1}},
        {{0.5,0.5,0.5},{0,0,0.5}},{{0,0,0},{0,0,0}}}
    for _,case in ipairs(hsvCases) do
        local hsv=C.RgbToHsv(case[1]); local rgb=C.HsvToRgb(case[2])
        for i=1,3 do near(hsv[i],case[2][i],1e-10); near(rgb[i],case[1][i],1e-10) end
    end
    local white=C.RgbToLab({1,1,1}); near(white[1],100,1e-6); near(white[2],0,1e-5); near(white[3],0,1e-5)
    local black=C.RgbToLab({0,0,0}); for i=1,3 do near(black[i],0,1e-9) end
    -- Independent published CSS Color 4 leaf sample, rounded by the source.
    local leaf=C.RgbToLab({0.41587,0.503670,0.36664})
    for i,v in ipairs({51.2345,-13.6271,16.2401}) do near(leaf[i],v,0.01) end
    local leafRGB=C.LabToRgb({51.2345,-13.6271,16.2401})
    for i,v in ipairs({0.41587,0.503670,0.36664}) do near(leafRGB[i],v,0.0001) end
    for r=0,4 do for g=0,4 do for b=0,4 do
        local rgb={r/4,g/4,b/4}
        local labRoundtrip=C.LabToRgb(C.RgbToLab(rgb))
        local hsvRoundtrip=C.HsvToRgb(C.RgbToHsv(rgb))
        for i=1,3 do near(labRoundtrip[i],rgb[i],0.000002); near(hsvRoundtrip[i],rgb[i],1e-10) end
    end end end
    local bytes,clipped=C.Bytes(C.LabToRgb({50,127,127})); check(clipped)
    for i=1,3 do check(bytes[i]>=0 and bytes[i]<=255 and bytes[i]%1==0) end
    check(C.String({1,0,0})=='255,0,0'); check(C.Hex({1,0.5,0})=='#FF8000')
    check(C.Hex(C.Parse('137,190,250,255'))=='#89BEFA')
    check(C.Hex(C.Parse('#FF8000'))=='#FF8000')
    check(C.Hex(C.Parse('FF0000FF'))=='#FF0000')
    check(C.Hex(C.Parse('#00FF0080'))=='#00FF00')
    for _,case in ipairs({{'12,34,56',255},{'12,34,56,0',0},{'12,34,56,128',128},{'12,34,56,255',255},{'0C2238',255},{'0C223800',0},{'#0C223880',128},{'0C2238FF',255},{'12,34,56,999',255}}) do check(C.Alpha(case[1])==case[2]) end
    check(C.Hex(C.Parse('not a color'))=='#89BEFA')
    return count
end
