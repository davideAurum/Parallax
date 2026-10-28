-- Appended only to isolated copies of the actual combined Network entrypoint.
local ticks, probeError = 0
local probes, names = {}, {}
local fontOptions={FontFace='Arial',FontSize='10',FontWeight='400',StringStyle='Normal',StringCase='None',CharacterSpacing='0'}
local function meter(name)
    local target=assert(SKIN:GetMeter(name),'Missing meter '..name);names[target]=name;return target
end
local function n(suffix) return meter('MeterNetwork'..suffix) end
local function c(suffix) return meter('MeterConnection'..suffix) end
local function formula(value)
    return assert(SKIN:ParseFormula('('..SKIN:ReplaceVariables(value)..')'),'Invalid formula: '..value)
end
local function variable(key) return formula(SKIN:GetVariable(key)) end
local function option(target,key) return formula(target:GetOption(key)) end
local function same(actual,expected,message,tolerance)
    assert(math.abs(actual-expected)<(tolerance or 0.001),message..': '..actual..' versus '..expected)
end
local function prepareGlyphs()
    for index=1,SELF:GetNumberOption('GlyphCount') do
        local target=meter(SELF:GetOption('GlyphTarget'..index));local probe=meter('MeterUnifiedGlyph'..index)
        probes[#probes+1]={target=target,probe=probe,width=SELF:GetNumberOption('GlyphWidth'..index)==1,
            live=SELF:GetNumberOption('GlyphLive'..index)==1}
        for key,default in pairs(fontOptions) do SKIN:Bang('!SetOption',names[probe],key,target:GetOption(key,default)) end
    end
end
local function updateLiveGlyphs()
    for _,spec in ipairs(probes) do if spec.live then SKIN:Bang('!SetOption',names[spec.probe],'Text',spec.target:GetOption('Text')) end end
end
local function glyphChecks()
    assert(not probeError,probeError)
    local failures={}
    for _,spec in ipairs(probes) do
        local probe,target=spec.probe,spec.target
        for key,default in pairs(fontOptions) do assert(probe:GetOption(key,default)==target:GetOption(key,default),'Probe font mismatch '..key) end
        assert(probe:GetOption('W','')=='' and probe:GetOption('H','')=='' and probe:GetOption('ClipString')=='0','Probe must have intrinsic bounds')
        probe:Show();local w,h=probe:GetW(),probe:GetH();probe:Hide()
        local pad={}
        for token in target:GetOption('Padding','0,0,0,0'):gmatch('[^,]+') do pad[#pad+1]=math.floor(formula(token)) end
        local aw,ah=target:GetW()-pad[1]-pad[3],target:GetH()-pad[2]-pad[4]
        -- A blank line (SSID/radio without a Wi-Fi connection) legitimately has no glyphs.
        local blank=probe:GetOption('Text')==''
        if (not blank and (w<=0 or h<=0)) or (spec.width and w>aw) or h>ah then
            failures[#failures+1]=string.format('%s:%s=%dx%d/%dx%d',names[target],probe:GetOption('Text'),w,h,aw,ah)
        end
        spec.glyphHeight=h
    end
    assert(#failures==0,'Native glyph fit failed: '..table.concat(failures,'; '))
    return #probes
end
local function bounds(target,w,h)
    local x,y,mw,mh=target:GetX(false),target:GetY(false),target:GetW(),target:GetH()
    assert(x>=0 and y>=0 and x+mw<=w and y+mh<=h,string.format('%s escapes native window: %g,%g %gx%g / %gx%g',names[target],x,y,mw,mh,w,h))
end
local function before(a,b)
    assert(a:GetY(false)+a:GetH()<=b:GetY(false),names[a]..' overlaps '..names[b])
end
local function rectangle(shape)
    local fields=assert(shape:match('^Rectangle%s+([^|]+)'),'Expected rectangular bar')
    local parts,depth,first={},0,1
    for index=1,#fields do
        local char=fields:sub(index,index)
        if char=='(' then depth=depth+1 elseif char==')' then depth=depth-1 end
        assert(depth>=0,'Unbalanced rectangle formula')
        if char==',' and depth==0 then parts[#parts+1]=fields:sub(first,index-1);first=index+1 end
    end
    assert(depth==0,'Unbalanced rectangle formula');parts[#parts+1]=fields:sub(first)
    local result={}
    for _,part in ipairs(parts) do result[#result+1]=formula(part:match('^%s*(.-)%s*$')) end
    assert(#result==4 and result[1]==0 and result[2]==0,'Unexpected bar origin')
    return result[3],result[4]
end
local function role(target,size,color)
    same(option(target,'FontSize'),variable(size)*variable('Scale'),names[target]..' font role')
    if color then assert(target:GetOption('FontColor')==SKIN:GetVariable(color),names[target]..' color role') end
end
local function header()
    local scale,center=variable('Scale'),variable('TitleRowCenterY')
    local icon,title,units,gear=n('Icon'),n('Title'),n('Units'),n('Options')
    for _,target in ipairs({title,units}) do
        assert(target:GetOption('StringAlign'):lower()=='leftcenter','Header does not use center anchor')
        same(option(target,'Y'),center,'Shared title center')
        assert(math.abs(target:GetY(false)+target:GetH()/2-center)<=1,'Native header center differs')
    end
    assert(math.abs(gear:GetY(false)+gear:GetH()/2-center)<=1,'Gear center differs from title row')
    same(gear:GetW(),18*scale,'Gear width',1);same(gear:GetH(),18*scale,'Gear height',1)
    same(gear:GetX(false)+gear:GetW(),variable('ContentX')+variable('ContentWidth'),'Gear sits in the right corner',1.5)
    assert(gear:GetOption('LeftMouseUpAction'):find('Parallax\\Network\\Settings',1,true),'Gear does not open Network settings')
    local iconScale=variable('TitleIconScale');same(iconScale,variable('TitleFontSize')*scale/10,'Shared icon scale')
    same(option(icon,'W'),14*iconScale,'Icon width');same(option(icon,'H'),14*iconScale,'Icon height')
    assert(math.abs(icon:GetY(false)+icon:GetH()/2-center)<=1,'Icon center differs')
    same(option(title,'X'),option(icon,'X')+14*iconScale+variable('TitleIconGap'),'Title/icon gap')
    assert(icon:GetX(false)+icon:GetW()<=title:GetX(false),'Icon overlaps title')
    assert(title:GetX(false)+title:GetW()<=units:GetX(false),'Title overlaps units')
    assert(units:GetX(false)+units:GetW()<=gear:GetX(false),'Units overlap gear')
    for _,target in ipairs({units,gear}) do before(target,c('Identity')) end
    for _,spec in ipairs(probes) do
        if names[spec.target]=='MeterNetworkTitle' then assert(center+math.ceil(spec.glyphHeight/2)<=c('Identity'):GetY(false)+1,'Title glyphs collide with identity panel') end
    end
    for index=1,7 do
        local shape=icon:GetOption(index==1 and 'Shape' or 'Shape'..index)
        local fields=assert(shape:match('^[^ ]+ (.-) |'),'Missing icon geometry');local count=0
        for token in fields:gmatch('[^,]+') do local value=formula(token);assert(value>=0 and value<=14*iconScale,'Icon primitive exceeds canvas');count=count+1 end
        assert(count==4,'Unexpected icon primitive')
        if index>=2 and index<=5 then same(formula(assert(shape:match('StrokeWidth%s+(.+)$'))),iconScale,'Icon stroke scale') end
    end
end
local function layout()
    local scale,cw,columns=variable('Scale'),variable('ColumnWidth'),variable('Columns')
    same(scale,SELF:GetNumberOption('ExpectedScale'),'Fixture scale');same(cw,SELF:GetNumberOption('ExpectedWidth'),'Fixture column width')
    same(columns,SELF:GetNumberOption('ExpectedColumns'),'Unified columns')
    local thickness=variable('DataBarThickness');same(thickness,SELF:GetNumberOption('ExpectedThickness'),'Fixture bar thickness')
    local bar=math.max(1,math.floor(thickness*scale+0.5));same(variable('DataBarThicknessPx'),bar,'Rounded shared bar thickness')
    assert(variable('PanelHeight')==236 and variable('NetworkConnectionHeight')==999,'Saved height fixtures changed')
    assert(variable('NetworkConnectionColumns')~=columns,'Legacy width must differ from unified width')
    local panelPx=math.max(math.floor(236*scale+0.5),math.floor(298*scale+0.5)+bar)
    same(variable('PanelHeightPx'),panelPx,'Combined content minimum ignores retired Connection height')
    local gap=2*math.floor(variable('Gutter')*scale/2+0.5)
    local expectedW=columns*(math.floor(cw*scale+0.5)+gap);local expectedH=panelPx+gap
    assert(SKIN:GetW()==expectedW and SKIN:GetH()==expectedH,'Combined native dimensions differ')
    for index=1,SELF:GetNumberOption('MeterCount') do bounds(meter(SELF:GetOption('MeterName'..index)),expectedW,expectedH) end
    for _,name in ipairs({'MeterConnectionBounds','MeterConnectionPanel','MeterConnectionTitle','MeterConnectionIcon','MeterConnectionWidth','MeterConnectionAdapter','MeterConnectionDescription','MeterConnectionWiFi','MeterNetworkAdapter'}) do
        assert(not SKIN:GetMeter(name),'Combined monitor retains duplicate UI '..name)
    end
    local maximum=SELF:GetOption('Typography')=='maximum'
    assert(variable('TitleFontSize')==(maximum and 12 or 10) and variable('FontSize')==(maximum and 10 or 9)
        and variable('HeaderFontSize')==(maximum and 10 or 8),'Fixture typography differs')
    local glyphs=glyphChecks();header()
    role(n('Title'),'TitleFontSize','TitleTextColor');role(n('Units'),'FontSize','AccentColor')
    for _,direction in ipairs({'In','Out'}) do
        role(n(direction..'Rate'),'FontSize',direction=='In' and 'NetworkInColor' or 'NetworkOutColor')
    end
    for _,suffix in ipairs({'Type','Name','SSID','Radio','Band','IPLabel','IP','GatewayLabel','Gateway','Rx','Tx','SignalLabel','Signal'}) do role(c(suffix),'FontSize') end
    for _,suffix in ipairs({'Type','Name','IPLabel','IP','GatewayLabel','Gateway','SignalLabel'}) do role(c(suffix),'FontSize','TextColor') end
    for _,suffix in ipairs({'SSID','Radio','Band'}) do role(c(suffix),'FontSize','AccentColor') end
    role(c('Rx'),'FontSize','NetworkInColor');role(c('Tx'),'FontSize','NetworkOutColor')
    for suffix,y in pairs({Identity=30,Type=32,Name=50,SSID=68,Radio=86,Band=104,IP=122,Gateway=140,Rx=158,Tx=158,Signal=188,SignalBar=208}) do
        same(option(c(suffix),'Y'),variable('Inset')+y*scale,'Connection '..suffix..' Y')
    end
    for suffix,y in pairs({TrafficRule=234,InRate=212,OutRate=212,InCaret=216,OutCaret=216,
        Grid=240,InGraph=240,OutGraph=240}) do
        same(option(n(suffix),'Y'),variable('Inset')+y*scale+bar,'Traffic '..suffix..' Y')
    end
    for _,pair in ipairs({{'Type','Name'},{'Name','SSID'},{'SSID','Radio'},{'Radio','Band'},{'Band','IP'},{'IP','Gateway'},{'Gateway','Rx'},{'Gateway','Tx'}}) do before(c(pair[1]),c(pair[2])) end
    local identity=c('Identity');assert(c('Type'):GetY(false)>=identity:GetY(false) and c('Rx'):GetY(false)+c('Rx'):GetH()<=identity:GetY(false)+identity:GetH(),'Panel lines escape the identity box')
    -- Link capacity shares one panel line: receive icon, RX value, transmit icon, TX value, left to right.
    for _,pair in ipairs({{'RxIcon','Rx'},{'Rx','TxIcon'},{'TxIcon','Tx'}}) do
        assert(c(pair[1]):GetX(false)+c(pair[1]):GetW()<=c(pair[2]):GetX(false)+1,pair[1]..' overlaps '..pair[2])
    end
    same(c('Rx'):GetY(false),c('Tx'):GetY(false),'RX and TX share a line',1)
    for _,suffix in ipairs({'RxIcon','TxIcon'}) do same(c(suffix):GetY(false)+c(suffix):GetH()/2,c('Rx'):GetY(false)+c('Rx'):GetH()/2,suffix..' is centered on its line',1.5);same(c(suffix):GetW(),14*scale,suffix..' width',1) end
    for _,suffix in ipairs({'IP','Gateway','Signal'}) do
        local label,value=c(suffix..'Label'),c(suffix)
        assert(label:GetX(false)+label:GetW()<=value:GetX(false),suffix..' label overlaps value')
    end
    before(c('Signal'),c('SignalBar'))
    local connController=assert(SKIN:GetMeasure('MeasureConnectionController'))
    local track=c('SignalBar');local trackW,trackH=rectangle(track:GetOption('Shape'))
    same(trackW,variable('ContentWidth'),'Painted signal width');same(trackH,bar,'Painted signal height')
    same(option(track,'H'),bar,'Native bar H option');assert(track:GetH()==bar and bar>=1,'Native bar must have visible whole-pixel height')
    same(connController:GetNumberOption('SignalHeight'),bar,'Controller signal height');same(connController:GetNumberOption('SignalWidth'),trackW,'Controller signal width')
    assert(n('TrafficRule'):GetY(false)-track:GetY(false)-bar>0,'Painted signal touches the traffic divider')
    local signal=c('Signal'):GetOption('Text');local known=signal:match('^%d+%%$')~=nil
    assert(known==(connController:GetValue()==1),'Signal text and known state differ')
    if known then
        local fillW,fillH=rectangle(track:GetOption('Shape2'))
        assert(fillW>=0 and fillW<=trackW+0.001,'Measured fill escapes track');same(fillH,bar,'Measured signal fill height')
    else assert(track:GetOption('Shape2')=='Line 0,0,0,0 | StrokeWidth 0','Unknown signal has fabricated fill') end
    for _,spec in ipairs({{c('Rule'),c('Tx'),c('Signal')},{n('TrafficRule'),n('InRate'),n('Grid')}}) do
        local rule,previous,following=spec[1],spec[2],spec[3]
        local stroke=formula(assert(rule:GetOption('Shape'):match('StrokeWidth%s+([^|]+)')))
        same(stroke,variable('DividerThickness')*scale,'Section divider thickness')
        assert(rule:GetOption('Shape'):find('Stroke Color '..SKIN:GetVariable('DividerColor'),1,true),'Section divider color differs')
        assert(previous:GetY(false)+previous:GetH()<=rule:GetY(false)-stroke/2,'Previous content overlaps painted divider')
        assert(rule:GetY(false)+stroke/2<following:GetY(false),'Painted divider touches following content')
    end
    for _,pair in ipairs({{'InRate','Grid'},{'OutRate','Grid'}}) do before(n(pair[1]),n(pair[2])) end
    -- Live readouts share one row under the signal bar: caret, IN rate, caret, OUT rate, left to right.
    same(n('InRate'):GetY(false),n('OutRate'):GetY(false),'IN and OUT readouts share a row',1)
    -- A caret's ink ends 7 logical px into its 10-px glyph box (as on the Disk meter).
    for _,pair in ipairs({{'InCaret','InRate'},{'InRate','OutCaret'},{'OutCaret','OutRate'}}) do
        local ink=pair[1]:match('Caret$') and 7*scale or n(pair[1]):GetW()
        assert(n(pair[1]):GetX(false)+ink<=n(pair[2]):GetX(false)+(pair[2]:match('Caret$') and 1*scale or 0)+1,pair[1]..' overlaps '..pair[2])
    end
    assert(n('OutRate'):GetX(false)+n('OutRate'):GetW()<=variable('ContentX')+variable('ContentWidth')+1,'OUT readout escapes the content width')
    before(c('SignalBar'),n('InRate'))
    local innerBottom=variable('Inset')+panelPx-variable('BorderThickness')*scale
    assert(n('Grid'):GetY(false)+n('Grid'):GetH()<=innerBottom,'Graph enters inside panel border')
    return glyphs,expectedW,expectedH,bar
end
local function providers()
    local controller=assert(SKIN:GetMeasure('MeasureNetworkController'));local conn=assert(SKIN:GetMeasure('MeasureConnectionController'))
    assert(controller:GetNumberOption('UpdateDivider')==1 and conn:GetNumberOption('UpdateDivider')==1,'Controller cadence changed')
    for _,suffix in ipairs({'Alias','Description','Guid','Status','State','In','Out'}) do
        local measure=assert(SKIN:GetMeasure('MeasureNetwork'..suffix),'Missing traffic measure')
        assert(measure:GetNumberOption('UpdateDivider')==1 and measure:GetNumberOption('DynamicVariables')==1,'Traffic measure cadence/selector changed')
    end
    -- Identity is shared with the traffic bank above; the controller samples it on these bank ticks.
    for _,suffix in ipairs({'Alias','Description','Guid','Status','State'}) do
        assert(SKIN:GetMeasure('MeasureConnection'..suffix)==nil,'Duplicated connection identity measure returned')
    end
    for _,suffix in ipairs({'Type','IP','Gateway','RxLink','TxLink'}) do
        local measure=assert(SKIN:GetMeasure('MeasureConnection'..suffix),'Missing connection measure')
        assert(measure:GetNumberOption('UpdateDivider')==2,'Connection metadata cadence changed')
        assert(conn:GetNumberOption('BankDivider')==2,'Controller bank divider differs from the connection bank')
        assert(measure:GetNumberOption('DynamicVariables')==1 and measure:GetOption('SysInfoData')==SKIN:GetVariable('NetworkInterface'),'Connection selector differs')
    end
    local kind=SELF:GetOption('CaseKind');local disabled=kind=='wifi-off' or kind=='invalid-wifi'
    for _,suffix in ipairs({'SSID','Quality','PHY','Rx','Tx'}) do
        local measure=assert(SKIN:GetMeasure('MeasureConnectionWiFi'..suffix))
        assert(measure:GetNumberOption('UpdateDivider')==5 and measure:GetNumberOption('DynamicVariables')==1,'Wi-Fi cadence changed')
        assert(conn:GetNumberOption('WiFiDivider')==5,'Controller Wi-Fi divider differs from the Wi-Fi measures')
        assert(measure:GetOption('Group')=='ConnectionWiFi|ParallaxIdlePause','Wi-Fi group differs')
        local index=measure:GetNumberOption('WiFiIntfID');assert(index>=0 and index<=63 and index==math.floor(index),'Unsafe Wi-Fi index')
        if disabled then assert(measure:GetNumberOption('Disabled')==1 and index==0,'Invalid/off Wi-Fi was queried') end
    end
    assert(c('Type'):GetOption('Text')~='Resolving adapter...' and c('Name'):GetOption('Text')~='Adapter information','A controller did not render')
    for _,direction in ipairs({'In','Out'}) do
        local graph,grid=n(direction..'Graph'),n('Grid')
        same(controller:GetNumberOption('GraphHeight'),variable('NetworkGraphHeight')*variable('Scale'),'Controller graph height')
        same(graph:GetH(),controller:GetNumberOption('GraphHeight'),'Native graph height',1)
        same(graph:GetW(),controller:GetNumberOption('GraphWidth'),'Native graph width',1)
        assert(graph:GetX(false)==grid:GetX(false) and graph:GetY(false)==grid:GetY(false) and graph:GetW()==grid:GetW() and graph:GetH()==grid:GetH(),'History path and grid bounds differ')
        for xs,ys in graph:GetOption('History'):gmatch('([%d%.]+),([%d%.]+)') do
            local x,y=tonumber(xs),tonumber(ys);assert(x>=0 and y>=0 and x<=graph:GetW() and y<=graph:GetH(),'Live history escapes graph')
        end
    end
    -- No sample counter is printed any more: 2 means a drawn path (two or more samples), 1 one reading, 0 none.
    local count=n('InGraph'):GetOption('Shape2'):match('^Path History') and 2 or (n('InRate'):GetOption('Text')~='--' and 1 or 0)
    assert(count and count>=0 and count<=60,'Invalid live history count')
    if kind=='invalid-nic' then
        assert(controller:GetValue()==0 and count==0,'Invalid adapter fabricated traffic/history')
        assert(n('InRate'):GetOption('Text')=='--' and n('OutRate'):GetOption('Text')=='--','Invalid NIC exposes rates')
        for _,suffix in ipairs({'IP','Gateway','Rx','Tx'}) do assert(c(suffix):GetOption('Text')=='--','Invalid NIC exposes fallback '..suffix) end
    elseif controller:GetValue()==1 then
        assert(count>=1 and n('InRate'):GetOption('Text')~='--' and n('OutRate'):GetOption('Text')~='--','Valid traffic lacks readings/history')
    end
    for _,direction in ipairs({'In','Out'}) do
        local shape=n(direction..'Graph'):GetOption('Shape2')
        if count>1 then assert(shape:match('^Path History'),'Multiple samples lack graph path')
        else assert(shape=='Line 1,1,1,1 | StrokeWidth 0','Missing/singleton history fabricated a segment') end
    end
    if disabled then assert(not c('Signal'):GetOption('Text'):match('%d'),'Unavailable Wi-Fi invents numeric signal') end
    if kind=='wifi-off' then assert(c('SSID'):GetOption('Text')=='' and c('Radio'):GetOption('Text')=='' and c('Band'):GetOption('Text')=='','Wi-Fi off state must leave the SSID and radio lines blank') end
    if kind=='invalid-wifi' then assert(c('SSID'):GetOption('Text')=='Check Wi-Fi settings','Malformed Wi-Fi state missing') end
    return controller:GetValue(),conn:GetValue(),count
end
function Update()
    ticks=ticks+1
    if ticks==1 then local ok,err=pcall(prepareGlyphs);if not ok then probeError=tostring(err) end end
    if ticks==8 then local ok,err=pcall(updateLiveGlyphs);if not ok then probeError=tostring(err) end end
    if ticks~=10 then return 0 end
    local ok,result=pcall(function()
        local glyphs,w,h,bar=layout();local network,connection,count=providers()
        return string.format('PASS combined width=%g scale=%g columns=%g bar=%g/%gpx size=%dx%d kind=%s controllers=%g/%g samples=%d signal=%s glyphs=%d',
            variable('ColumnWidth'),variable('Scale'),variable('Columns'),variable('DataBarThickness'),bar,w,h,SELF:GetOption('CaseKind'),network,connection,count,c('Signal'):GetOption('Text'),glyphs)
    end)
    local file=assert(io.open(SELF:GetOption('ResultFile'),'wb'));file:write(ok and result or 'FAIL '..tostring(result));file:close()
    return ok and 1 or -1
end
