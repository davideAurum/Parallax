-- Synthetic persistence fixtures. Native I/O/actions are mocked; no user file or live skin is touched.
local Suite = {}
function Suite.run(Core, fixtures)
    local passed, failed, report = 0, 0, {}
    local function equal(a, b, label) if a ~= b then error((label or 'value') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end end
    local function truth(value, label) if not value then error(label or 'expected true', 2) end end
    local function contains(value, part) truth(value:find(part, 1, true), 'missing ' .. part .. ' in ' .. value) end
    local function test(name, body)
        local ok, err = pcall(body)
        if ok then passed = passed + 1; report[#report + 1] = 'PASS: ' .. name
        else failed = failed + 1; report[#report + 1] = 'FAIL: ' .. name .. ': ' .. tostring(err) end
    end
    local root = 'C:\\ParallaxSynthetic\\@Resources\\'
    local filePath = root .. 'User\\Network.inc'
    local sourceFile = assert(io.open(fixtures.moduleRoot .. '\\SettingsMeters.inc', 'rb'))
    local meterSource = assert(sourceFile:read('*a')); sourceFile:close()
    local meterNames = {}
    for name in ('\n' .. meterSource):gmatch('\n%s*%[([^%]\r\n]+)%]') do meterNames[name] = true end
    local initial = '; synthetic fixture only\r\n[Variables]\r\nNetworkInterface=Custom adapter\r\nNetworkUnits=bits\r\nColumns=1\r\nPanelHeight=275.50\r\nNetworkInCeilingMbps=37.50\r\nNetworkOutCeilingMbps=1250.25\r\nNetworkConnectionColumns=1\r\nNetworkConnectionHeight=289.75\r\nNetworkWiFiEnabled=1\r\nNetworkWiFiInterface=0\r\nDataBarThickness=11.25\r\nUnrelatedKey=retain #literal# [data]\r\n[Other]\r\nColumns=77\r\nKeep=unchanged\r\n'
    local writeKeys = {NetworkUnits=true, Columns=true, PanelHeight=true, NetworkInCeilingMbps=true, NetworkOutCeilingMbps=true,
        NetworkWiFiEnabled=true, NetworkWiFiInterface=true}
    local function replace(data, key, value)
        local inVariables, changed = false, false
        local nextData = data:gsub('([^\r\n]*)(\r?\n)', function(line, ending)
            local section = line:match('^%s*%[([^%]]+)%]%s*$')
            if section then inVariables = section:lower() == 'variables' end
            local lineKey = line:match('^%s*([^=]+)=')
            if inVariables and lineKey and lineKey:lower() == key:lower() then
                changed = true; return lineKey .. '=' .. value .. ending
            end
            return line .. ending
        end)
        if not changed then nextData = nextData:gsub('(%[[Vv]ariables%]\r?\n)', '%1' .. key .. '=' .. value .. '\r\n', 1) end
        return nextData
    end
    local function controller(data, variables)
        local mock = {data=data or initial, calls={}, latest={}, reads=0, missing=false, failWrite=false, output='',
            variables={['@']=root, Columns='2', PanelHeight='598', NetworkUnits='wrong-local-value',
                TextColor='123,124,125', WarningColor='200,180,20'}}
        for key, value in pairs(variables or {}) do mock.variables[key] = value end
        local skin = {}
        function skin:GetVariable(key, default) return mock.variables[key] or default end
        function skin:GetX() return 20 end
        function skin:GetY() return -30 end
        function skin:GetMeter(name)
            truth(meterNames[name], 'unknown input anchor: ' .. tostring(name))
            if mock.missingMeter then return nil end
            return {GetX=function() return 150 end, GetY=function() return 101 end,
                GetW=function() return 128 end, GetH=function() return 20 end}
        end
        function skin:GetMeasure(name)
            equal(name, 'MeasureNetworkSettingsInput')
            if mock.missingInput then return nil end
            return {GetStringValue=function() return mock.output end}
        end
        function skin:Bang(bang, ...)
            local args = {...}; mock.calls[#mock.calls + 1] = {bang=bang, args=args}
            if bang == '!SetOption' then
                if args[1] == 'MeasureNetworkSettingsInput' then equal(args[2], 'Parameter')
                else
                    truth(meterNames[args[1]], 'unknown target meter: ' .. tostring(args[1]))
                    truth(args[2] == 'Text' or args[2] == 'ToolTipText' or args[2] == 'FontColor', 'unexpected meter mutation')
                end
                mock.latest[args[1] .. ':' .. args[2]] = args[3]
            elseif bang == '!WriteKeyValue' then
                equal(#args, 4); equal(args[1], 'Variables'); equal(args[4], filePath)
                truth(writeKeys[args[2]], 'nonallowlisted persistence key: ' .. tostring(args[2]))
                truth(not args[3]:find('[%c#%[%]";]'), 'noncanonical persisted value')
                if not mock.failWrite then mock.data = replace(mock.data, args[2], args[3]) end
                if mock.disappearAfterWrite then mock.missing = true end
            elseif bang == '!Refresh' then
                truth(#args == 0 or (#args == 1 and args[1] == 'Parallax\\Network'), 'unscoped refresh')
            elseif bang == '!ActivateConfig' then
                truth(args[1] == 'Parallax\\Network' and args[2] == 'Network.ini', 'unexpected navigation')
            elseif bang == '!UpdateMeasure' then equal(#args, 1); equal(args[1], 'MeasureNetworkSettingsInput')
            elseif bang == '!CommandMeasure' then equal(#args, 2); equal(args[1], 'MeasureNetworkSettingsInput'); equal(args[2], 'Run')
            elseif bang == '!UpdateMeter' then equal(#args, 1); equal(args[1], '*')
            elseif bang == '!Redraw' or bang == '!DeactivateConfig' then equal(#args, 0)
            elseif bang:sub(1, 13) == '"notepad.exe"' then
                equal(#args, 0); equal(bang, '"notepad.exe" "' .. filePath .. '"')
            else error('unexpected side effect: ' .. tostring(bang)) end
        end
        local mockIO = {}
        function mockIO.open(path, mode)
            equal(path, filePath); equal(mode, 'rb', 'settings reader must never write files directly')
            mock.reads = mock.reads + 1
            if mock.missing then return nil, 'synthetic access failure' end
            return {read=function(_, count) equal(count, 262145); return mock.data:sub(1, count) end,
                close=function() return not mock.failClose end}
        end
        local env = setmetatable({SKIN=skin, io=mockIO, dofile=function(path)
            equal(path, root .. 'Modules\\Network\\Core.lua'); return Core
        end}, {__index=_G})
        local chunk = assert(loadfile(fixtures.moduleRoot .. '\\Settings.lua'))
        setfenv(chunk, env); chunk(); env.Initialize()
        mock.env = env
        function mock:count(bang)
            local count = 0; for _, call in ipairs(self.calls) do if call.bang == bang then count = count + 1 end end; return count
        end
        function mock:refreshTargets()
            local result = {}; for _, call in ipairs(self.calls) do if call.bang == '!Refresh' then result[#result + 1] = call.args[1] or '(current)' end end
            return table.concat(result, '|')
        end
        function mock:text(suffix) return self.latest['MeterNetworkSettings' .. suffix .. 'Value:Text'] end
        function mock:cleanCalls() self.calls = {} end
        function mock:writtenKey()
            local result; for _, call in ipairs(self.calls) do if call.bang == '!WriteKeyValue' then truth(not result, 'multiple writes'); result=call.args[2] end end
            return result
        end
        return mock
    end
    test('initial render reads saved monitor values instead of settings geometry', function()
        local mock = controller(); equal(mock.reads, 0); mock.env.Update()
        equal(mock:text('Width'), '1'); equal(mock:text('Height'), '275.50'); equal(mock:text('Units'), 'bits')
        equal(mock.variables.Columns, '2'); equal(mock.variables.PanelHeight, '598')
        equal(mock:count('!WriteKeyValue'), 0); equal(mock:count('!Refresh'), 0); equal(mock:count('!ActivateConfig'), 0)
    end)
    test('custom selector, heights and ceilings remain exact and unchanged on render', function()
        local mock = controller(); mock.env.Update()
        equal(mock:text('Adapter'), 'Custom adapter'); equal(mock:text('Height'), '275.50')
        equal(mock:text('InCeiling'), '37.50'); equal(mock:text('OutCeiling'), '1250.25')
        equal(mock.data, initial)
    end)
    test('UTF-8 BOM and case-insensitive section and keys are supported', function()
        local data = '\239\187\191' .. initial:gsub('Variables', 'vArIaBlEs'):gsub('NetworkUnits', 'networkunits'):gsub('Columns=1', 'columns=1')
        local mock = controller(data); mock.env.Update(); equal(mock:text('Units'), 'bits'); equal(mock:text('Width'), '1')
        mock:cleanCalls(); mock.env.ToggleUnits(); equal(mock:text('Units'), 'bytes'); equal(mock:writtenKey(), 'NetworkUnits')
        contains(mock.data, 'networkunits=bytes'); contains(mock.data, 'Columns=77')
    end)
    test('UTF-16 little and big endian settings decode without executing their contents', function()
        for _, little in ipairs({true, false}) do
            local parts = {little and '\255\254' or '\254\255'}
            for pos=1,#initial do local byte=initial:byte(pos); parts[#parts+1] = little and string.char(byte,0) or string.char(0,byte) end
            local mock = controller(table.concat(parts)); mock.env.Update()
            equal(mock:text('Adapter'), 'Custom adapter'); equal(mock:text('InCeiling'), '37.50'); equal(mock:count('!WriteKeyValue'), 0)
        end
    end)
    test('UTF-16 surrogate pairs preserve non-ASCII adapter names', function()
        local ascii = '[Variables]\nNetworkInterface='
        local parts = {'\255\254'}; for pos=1,#ascii do parts[#parts+1] = string.char(ascii:byte(pos),0) end
        parts[#parts+1] = '\61\216\0\222\10\0'
        local mock = controller(table.concat(parts)); mock.env.Update(); equal(mock:text('Adapter'), '\240\159\152\128')
    end)
    test('literal selector delimiters and quotes never become actions or formulas', function()
        local data = replace(initial, 'NetworkInterface', 'NIC #CURRENTCONFIG# [!Quit] "quoted"')
        local mock = controller(data); mock.env.Update()
        equal(mock:text('Adapter'), "NIC  CURRENTCONFIG   !Quit  'quoted'")
        equal(mock.data, data); equal(mock:count('!ActivateConfig'), 0); equal(mock:count('!WriteKeyValue'), 0)
        for key, value in pairs(mock.latest) do
            if key:match(':Text$') or key:match(':ToolTipText$') then truth(not value:find('[%c#%[%]"]'), 'unsafe display ' .. key) end
        end
    end)
    test('tooltips are bounded without retaining executable delimiters', function()
        local mock = controller(replace(initial, 'NetworkInterface', string.rep('\195\169', 700) .. '#x#[!Quit]'))
        mock.env.Update(); local text=mock.latest['MeterNetworkSettingsAdapterValue:ToolTipText']
        truth(#text <= 1024); equal(text:sub(-3), '...'); truth(not text:find('[%c#%[%]"]'))
    end)
    test('invalid saved choices are visible and never repaired on load', function()
        local replacements = {NetworkInterface='0',NetworkUnits='octets',Columns='3',PanelHeight='0',NetworkInCeilingMbps='-1',
            NetworkOutCeilingMbps='abc',NetworkWiFiEnabled='yes',NetworkWiFiInterface='-1'}
        local data=initial; for key, value in pairs(replacements) do data=replace(data,key,value) end
        local mock=controller(data); mock.env.Update()
        for _, suffix in ipairs({'Adapter','Units','Width','Height','InCeiling','OutCeiling','WiFiEnabled','WiFiIndex'}) do equal(mock:text(suffix),'Invalid') end
        equal(mock.data,data); equal(mock:count('!WriteKeyValue'),0); contains(mock.latest['MeterNetworkSettingsStatus:Text'],'invalid')
    end)
    test('production ceiling notation and custom height formulas remain literal and unchanged', function()
        local data=replace(replace(initial,'NetworkInCeilingMbps','1e2'),'PanelHeight','(200+1)')
        local mock=controller(data); mock.env.Update()
        equal(mock:text('InCeiling'),'1e2'); equal(mock:text('Height'),'Custom'); equal(mock.data,data)
        contains(mock.latest['MeterNetworkSettingsHeightValue:ToolTipText'],'(200+1)')
        truth(not mock.latest['MeterNetworkSettingsStatus:Text']:find('invalid',1,true))
        equal(mock:count('!WriteKeyValue'),0)
    end)
    test('value tooltips retain click instructions, units and WLAN scope', function()
        local mock=controller(); mock.env.Update()
        for _, suffix in ipairs({'Adapter','Units','Width','Height','InCeiling','OutCeiling','WiFiEnabled','WiFiIndex'}) do
            contains(mock.latest['MeterNetworkSettings' .. suffix .. 'Value:ToolTipText'],'Click')
        end
        contains(mock.latest['MeterNetworkSettingsUnitsValue:ToolTipText'],'binary bytes/s')
        contains(mock.latest['MeterNetworkSettingsWiFiIndexValue:ToolTipText'],'separate from the Network adapter')
    end)
    test('missing keys stay explicit until the user chooses that setting', function()
        local data=initial:gsub('NetworkUnits=bits\r\n',''); local mock=controller(data); mock.env.Update()
        equal(mock:text('Units'),'Missing'); equal(mock.data,data); mock:cleanCalls(); mock.env.ToggleUnits()
        equal(mock:writtenKey(),'NetworkUnits'); equal(mock:text('Units'),'bits')
    end)
    test('duplicate tracked keys or Variables sections block ambiguous writes', function()
        for _, tail in ipairs({'[Variables]\nNetworkUnits=bytes\n',''}) do
            local data = tail ~= '' and initial .. tail or initial:gsub('NetworkUnits=bits','NetworkUnits=bits\nnetworkunits=bytes')
            local mock=controller(data); mock.env.Update(); mock.env.ToggleUnits()
            equal(mock:count('!WriteKeyValue'),0); contains(mock.latest['MeterNetworkSettingsStatus:ToolTipText'],'Duplicate')
        end
    end)
    test('missing file or Variables section prevents writes and refreshes', function()
        for _, noFile in ipairs({true,false}) do
            local mock=controller(noFile and initial or '[Other]\nColumns=1\n'); mock.missing=noFile
            mock.env.Update(); mock.env.ToggleUnits(); mock.env.ApplyFile()
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); contains(mock.latest['MeterNetworkSettingsStatus:Text'],'Cannot read')
        end
    end)
    test('oversize, NUL and malformed UTF-16 input fail closed', function()
        for _, data in ipairs({string.rep('x',262145), initial .. '\0', '\255\254x', '\255\254\0\216\65\0', '\255\254\0\220'}) do
            local mock=controller(data); mock.env.Update(); mock.env.ToggleUnits()
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); contains(mock.latest['MeterNetworkSettingsStatus:Text'],'Cannot read')
        end
    end)
    test('units writes one key and preserves custom, unknown and other-section data', function()
        local mock=controller(); mock.env.Update(); mock:cleanCalls(); mock.env.ToggleUnits()
        equal(mock:writtenKey(),'NetworkUnits'); equal(mock.data,replace(initial,'NetworkUnits','bytes'))
        equal(mock:refreshTargets(),'Parallax\\Network'); equal(mock:count('!ActivateConfig'),0)
    end)
    test('actions reread external saved changes before choosing the next value', function()
        local mock=controller(); mock.env.Update(); mock.data=replace(mock.data,'NetworkUnits','bytes'); mock:cleanCalls()
        mock.env.ToggleUnits(); equal(mock:text('Units'),'bits'); equal(mock:writtenKey(),'NetworkUnits')
        mock.data=replace(mock.data,'Columns','2'); mock:cleanCalls(); mock.env.AdjustNumber('Columns',-1); equal(mock:text('Width'),'1')
    end)
    test('one monitor width persists Columns while deprecated companion geometry remains untouched', function()
        local data=replace(replace(initial,'NetworkConnectionColumns','obsolete'),'NetworkConnectionHeight','[stale formula]')
        local mock=controller(data); mock.env.Update(); mock:cleanCalls(); mock.env.ToggleWidth('Network')
        equal(mock:writtenKey(),'Columns'); equal(mock:refreshTargets(),'Parallax\\Network')
        equal(mock.data,replace(data,'Columns','2')); equal(mock:text('Height'),'275.50')
        truth(not mock.latest['MeterNetworkSettingsStatus:Text']:find('invalid',1,true))
        equal(mock:text('ConnectionWidth'),nil); equal(mock:text('ConnectionHeight'),nil)
        mock:cleanCalls(); mock.env.ToggleWidth('Connection'); mock.env.OpenPanel('Connection')
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); equal(mock:count('!ActivateConfig'),0)
    end)
    test('Wi-Fi enable toggles only the saved module flag and combined monitor refresh', function()
        local mock=controller(); mock.env.ToggleWiFi(); equal(mock:writtenKey(),'NetworkWiFiEnabled')
        equal(mock:text('WiFiEnabled'),'Off'); equal(mock:refreshTargets(),'Parallax\\Network')
        mock:cleanCalls(); mock.env.ToggleWiFi(); equal(mock:text('WiFiEnabled'),'On')
    end)
    test('WLAN index moves within bounds and keeps invalid saved values untouched', function()
        for _, pair in ipairs({{'03','4'},{'62','63'}}) do
            local mock=controller(replace(initial,'NetworkWiFiInterface',pair[1])); mock.env.Update(); mock:cleanCalls(); mock.env.CycleWiFiIndex()
            equal(mock:writtenKey(),'NetworkWiFiInterface'); equal(mock:text('WiFiIndex'),pair[2]); equal(mock:refreshTargets(),'Parallax\\Network')
        end
        for _, raw in ipairs({'63','-1','64','abc'}) do
            local before=replace(initial,'NetworkWiFiInterface',raw); local mock=controller(before)
            equal(mock.env.CycleWiFiIndex(),false); equal(mock.data,before); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
    end)
    test('ceiling choices use next greater preset without wrapping or changing other values', function()
        for _, pair in ipairs({{'1','10'},{'10','25'},{'25','50'},{'50','100'},{'100','250'},{'250','500'},{'500','1000'},{'37.50','50'},{'1e2','250'}}) do
            local before=replace(initial,'NetworkInCeilingMbps',pair[1]); local mock=controller(before); mock.env.CycleCeiling('In')
            equal(mock:writtenKey(),'NetworkInCeilingMbps'); equal(mock.data,replace(before,'NetworkInCeilingMbps',pair[2]))
            equal(mock:refreshTargets(),'Parallax\\Network')
        end
        for _, raw in ipairs({'1000','1250.25','bad'}) do
            local before=replace(initial,'NetworkInCeilingMbps',raw); local mock=controller(before)
            equal(mock.env.CycleCeiling('In'),false); equal(mock.data,before); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
        local mock=controller(); mock.env.AdjustNumber('NetworkOutCeilingMbps',-1)
        equal(mock:writtenKey(),'NetworkOutCeilingMbps'); equal(mock:text('OutCeiling'),'1000')
    end)
    test('invalid action selectors cannot select a key or another config', function()
        local mock=controller(); mock.env.ToggleWidth('CPU'); mock.env.CycleCeiling('OutCeilingMbps'); mock.env.OpenPanel('[!Quit]')
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); equal(mock:count('!ActivateConfig'),0)
    end)
    test('unverified write errors do not refresh a monitor or report success', function()
        local mock=controller(); mock.failWrite=true; mock.env.ToggleUnits()
        equal(mock:count('!WriteKeyValue'),1); equal(mock:count('!Refresh'),0); equal(mock.data,initial)
        contains(mock.latest['MeterNetworkSettingsStatus:ToolTipText'],'Could not verify')
    end)
    test('read failure after a write leaves an explicit verification error', function()
        local mock=controller(); mock.disappearAfterWrite=true; mock.env.ToggleUnits()
        equal(mock:count('!WriteKeyValue'),1); equal(mock:count('!Refresh'),0); contains(mock.latest['MeterNetworkSettingsStatus:Text'],'Cannot read')
    end)
    test('Apply rereads the file and refreshes only Network plus this settings skin', function()
        local mock=controller(); mock.env.Update(); mock.data=replace(mock.data,'PanelHeight','301.25'); mock:cleanCalls(); mock.env.ApplyFile()
        equal(mock:text('Height'),'301.25'); equal(mock:refreshTargets(),'Parallax\\Network|(current)')
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!ActivateConfig'),0)
    end)
    test('OpenFile uses only a fixed trusted path and never the raw selector', function()
        local mock=controller(replace(initial,'NetworkInterface','"[!Quit] #x#')); mock.env.OpenFile()
        equal(#mock.calls,1); equal(mock.calls[1].bang,'"notepad.exe" "' .. filePath .. '"'); equal(mock.reads,0)
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
    end)
    test('explicit navigation activates only the requested panel without writes or refresh', function()
        local mock=controller(replace(initial,'NetworkInterface','[!Quit]')); mock.env.OpenPanel('Network')
        equal(#mock.calls,1); equal(mock:count('!ActivateConfig'),1); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
    end)
    test('Close deactivates only current settings without touching either monitor', function()
        local mock=controller(); mock.env.Close(); equal(#mock.calls,1); equal(mock.calls[1].bang,'!DeactivateConfig'); equal(#mock.calls[1].args,0)
    end)
    test('repeated rendering performs no writes, refreshes or external launches', function()
        local mock=controller(); for i=1,4 do mock.env.Update() end
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); equal(mock:count('!ActivateConfig'),0); equal(mock.data,initial)
    end)
    test('values retain inherited body colors rather than controller accent overrides', function()
        local mock=controller(); mock.env.Update()
        for key in pairs(mock.latest) do if key:match(':FontColor$') then equal(key,'MeterNetworkSettingsStatus:FontColor') end end
        equal(mock.latest['MeterNetworkSettingsStatus:FontColor'],'123,124,125')
    end)
    test('an unsafe fixed resource path fails without file access or launch', function()
        local mock=controller(nil,{['@']='C:\\bad"path\\'}); mock.env.Update(); mock.env.OpenFile(); mock.env.ToggleUnits()
        equal(mock.reads,0); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        for _, call in ipairs(mock.calls) do truth(call.bang:sub(1,1)=='!','unsafe path launched a command') end
    end)
    test('categorical units wrap in both directions while unknown directions do nothing', function()
        local mock=controller()
        truth(mock.env.CycleUnits(-1)); equal(mock:text('Units'),'bytes')
        truth(mock.env.CycleUnits(-1)); equal(mock:text('Units'),'bits')
        truth(mock.env.CycleUnits(1)); equal(mock:text('Units'),'bytes')
        mock:cleanCalls()
        for _, direction in ipairs({0,2,'1','[!Quit]'}) do equal(mock.env.CycleUnits(direction),false) end
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
    end)
    test('numeric arrows clamp at discrete and decimal limits without writes or refresh', function()
        for _, case in ipairs({{'Columns','1',-1},{'Columns','2',1},
                {'NetworkWiFiInterface','0',-1},{'NetworkWiFiInterface','63',1},
                {'PanelHeight','0.0001',-1},{'PanelHeight','1000000000.0000',1},
                {'NetworkInCeilingMbps','1e3',1},{'NetworkOutCeilingMbps','10.0000',-1}}) do
            local before=replace(initial,case[1],case[2]); local mock=controller(before)
            equal(mock.env.AdjustNumber(case[1],case[3]),false); equal(mock.data,before)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
    end)
    test('height arrows preserve fractions and clamp a partial final step', function()
        for _, case in ipairs({{'275.50',1,'276.5'},{'275.50',-1,'274.5'},
                {'0.5',-1,'0.0001'},{'999999999.5',1,'1000000000'}}) do
            local before=replace(initial,'PanelHeight',case[1]); local mock=controller(before)
            truth(mock.env.AdjustNumber('PanelHeight',case[2]))
            equal(mock.data,replace(before,'PanelHeight',case[3])); equal(mock:refreshTargets(),'Parallax\\Network')
        end
    end)
    test('ceiling arrows approach custom numeric values from either side without wrapping', function()
        for _, case in ipairs({{'37.5',-1,'25'},{'37.5',1,'50'},
                {'1e9',-1,'1000'},{'0.00001',1,'10'},{'1e2',-1,'50'}}) do
            local before=replace(initial,'NetworkInCeilingMbps',case[1]); local mock=controller(before)
            truth(mock.env.AdjustNumber('NetworkInCeilingMbps',case[2]))
            equal(mock.data,replace(before,'NetworkInCeilingMbps',case[3]))
        end
    end)
    test('formula and unsupported height values have no invented arrow starting value', function()
        for _, raw in ipairs({'(200+1)','1e3','0.00001','1000000001','0.12345','bad'}) do
            local before=replace(initial,'PanelHeight',raw); local mock=controller(before)
            equal(mock.env.AdjustNumber('PanelHeight',1),false); equal(mock.data,before)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
            contains(mock.latest['MeterNetworkSettingsStatus:Text'],'Enter a number')
        end
    end)
    test('numeric editor launches only canonical fixed helper arguments for all five fields', function()
        for _, case in ipairs({{'Columns','1','1','2','0'}, {'PanelHeight','275.5','0.0001','1000000000','4'},
                {'NetworkInCeilingMbps','37.5','0.0001','1000000000','4'},
                {'NetworkOutCeilingMbps','1250.25','0.0001','1000000000','4'},
                {'NetworkWiFiInterface','0','0','63','0'}}) do
            local mock=controller(nil,{Scale='1.25'})
            truth(mock.env.BeginNumberInput(case[1]))
            local parameter=mock.latest['MeasureNetworkSettingsInput:Parameter']
            contains(parameter,'-ExecutionPolicy RemoteSigned -File "SettingsInput.ps1" -Key UtilityNumber')
            contains(parameter,'-Minimum ' .. case[3] .. ' -Maximum ' .. case[4] .. ' -DecimalPlaces ' .. case[5])
            contains(parameter,'-Initial "' .. case[2] .. '" -X 170 -Y 71 -Width 128 -Height 20 -Scale 1.2500')
            equal(mock:count('!CommandMeasure'),1); equal(mock:count('!UpdateMeasure'),1)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
    end)
    test('custom numeric seeds open only the fixed file editor without starting the helper', function()
        for _, raw in ipairs({'(200+1)','1e3','1000000001','0.12345','#x#[!Quit]"'}) do
            local before=replace(initial,'PanelHeight',raw); local mock=controller(before)
            equal(mock.env.BeginNumberInput('PanelHeight'),false)
            equal(mock.latest['MeasureNetworkSettingsInput:Parameter'],nil); equal(mock:count('!CommandMeasure'),0)
            equal(mock.calls[#mock.calls].bang,'"notepad.exe" "' .. filePath .. '"')
            equal(mock.data,before); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
            for _, suffix in ipairs({'Value','Frame','Label'}) do
                contains(mock.latest['MeterNetworkSettingsHeight' .. suffix .. ':ToolTipText'],'open Network.inc')
            end
            mock.output='PARALLAX_INPUT_V1|ok|300'; equal(mock.env.FinishNumberInput(),false)
        end
    end)
    test('typed results save one canonical numeric key and preserve unrelated saved data', function()
        for _, case in ipairs({{'Columns','+02','2'}, {'PanelHeight','+300.1250','300.125'},
                {'NetworkInCeilingMbps','0.0001','0.0001'},
                {'NetworkOutCeilingMbps','1000000000','1000000000'},
                {'NetworkWiFiInterface','+063','63'}}) do
            local mock=controller(); truth(mock.env.BeginNumberInput(case[1])); mock:cleanCalls()
            mock.output='PARALLAX_INPUT_V1|ok|' .. case[2] .. '\r\n'
            truth(mock.env.FinishNumberInput()); equal(mock:writtenKey(),case[1])
            equal(mock.data,replace(initial,case[1],case[3])); equal(mock:refreshTargets(),'Parallax\\Network')
        end
        local before=replace(initial,'NetworkWiFiInterface','1'); local mock=controller(before)
        truth(mock.env.BeginNumberInput('NetworkWiFiInterface')); mock.output='PARALLAX_INPUT_V1|ok|-0'
        truth(mock.env.FinishNumberInput()); equal(mock.data,replace(before,'NetworkWiFiInterface','0'))
    end)
    test('cancel and duplicate Finish calls never write or refresh', function()
        local mock=controller(); equal(mock.env.FinishNumberInput(),false)
        truth(mock.env.BeginNumberInput('PanelHeight')); mock.output='PARALLAX_INPUT_V1|cancel|\r\n'; mock:cleanCalls()
        equal(mock.env.FinishNumberInput(),false); mock.output='PARALLAX_INPUT_V1|ok|300'
        equal(mock.env.FinishNumberInput(),false); equal(mock.data,initial)
        equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
    end)
    test('malformed, over-precision and out-of-range helper responses fail closed', function()
        for _, response in ipairs({'PARALLAX_INPUT_V1|ok|0','PARALLAX_INPUT_V1|ok|-1','PARALLAX_INPUT_V1|ok|1000000001',
                'PARALLAX_INPUT_V1|ok|1.12345','PARALLAX_INPUT_V1|ok|1e2','PARALLAX_INPUT_V1|ok|.5',
                'PARALLAX_INPUT_V1|ok|1.','PARALLAX_INPUT_V1|ok| 2','PARALLAX_INPUT_V1|ok|2px',
                'PARALLAX_INPUT_V1|ok|[!Quit]','PARALLAX_INPUT_V1|ok|NaN','PARALLAX_INPUT_V1|ok|Infinity',
                'PARALLAX_INPUT_V1|ok|1\n2','PARALLAX_INPUT_V1|ok|1|extra','noise\nPARALLAX_INPUT_V1|ok|2',
                'PARALLAX_INPUT_V2|ok|2',string.rep('2',129)}) do
            local mock=controller(); truth(mock.env.BeginNumberInput('PanelHeight')); mock.output=response; mock:cleanCalls()
            equal(mock.env.FinishNumberInput(),false); equal(mock.data,initial)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
        for _, case in ipairs({{'Columns','1.0'},{'Columns','0'},{'Columns','3'},
                {'NetworkWiFiInterface','1.0'},{'NetworkWiFiInterface','-1'},{'NetworkWiFiInterface','64'}}) do
            local mock=controller(); truth(mock.env.BeginNumberInput(case[1])); mock.output='PARALLAX_INPUT_V1|ok|' .. case[2]
            equal(mock.env.FinishNumberInput(),false); equal(mock:count('!WriteKeyValue'),0)
        end
    end)
    test('unknown keys and directions cannot select numeric persistence or helper targets', function()
        local mock=controller()
        for _, key in ipairs({'NetworkInterface','NetworkUnits','NetworkWiFiEnabled','NetworkConnectionColumns','Columns[!Quit]','Scale'}) do
            equal(mock.env.BeginNumberInput(key),false); equal(mock.env.AdjustNumber(key,1),false)
        end
        for _, direction in ipairs({0,2,'1','-1','[!Quit]'}) do equal(mock.env.AdjustNumber('Columns',direction),false) end
        equal(mock.reads,0); equal(mock:count('!CommandMeasure'),0); equal(mock:count('!WriteKeyValue'),0)
    end)
    test('one pending editor blocks overlapping launches and other persistent actions', function()
        local mock=controller(); truth(mock.env.BeginNumberInput('PanelHeight')); mock:cleanCalls()
        equal(mock.env.BeginNumberInput('Columns'),false); equal(mock.env.AdjustNumber('Columns',1),false)
        equal(mock.env.ToggleUnits(),false); equal(mock.env.ToggleWiFi(),false)
        equal(mock.env.CycleWiFiIndex(),false); equal(mock.env.CycleCeiling('In'),false)
        equal(mock.env.ApplyFile(),false); equal(mock.env.OpenFile(),false); mock.env.Update()
        equal(mock:count('!CommandMeasure'),0); equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        mock.output='PARALLAX_INPUT_V1|ok|300'; truth(mock.env.FinishNumberInput())
        equal(mock:writtenKey(),'PanelHeight'); equal(mock.data,replace(initial,'PanelHeight','300'))
        mock:cleanCalls(); equal(mock.env.FinishNumberInput(),false); equal(mock:count('!WriteKeyValue'),0)
    end)
    test('pending edits reject stale saved-key changes but preserve unrelated external edits', function()
        local mock=controller(); truth(mock.env.BeginNumberInput('PanelHeight'))
        mock.data=replace(mock.data,'PanelHeight','350'); local changed=mock.data; mock.output='PARALLAX_INPUT_V1|ok|300'
        equal(mock.env.FinishNumberInput(),false); equal(mock.data,changed); equal(mock:count('!WriteKeyValue'),0)
        contains(mock.latest['MeterNetworkSettingsStatus:Text'],'changed')
        local other=controller(); truth(other.env.BeginNumberInput('PanelHeight'))
        other.data=replace(other.data,'NetworkUnits','bytes'); local before=other.data; other.output='PARALLAX_INPUT_V1|ok|300'
        truth(other.env.FinishNumberInput()); equal(other.data,replace(before,'PanelHeight','300'))
    end)
    test('equivalent typed numbers preserve original spelling without writes or refresh', function()
        for _, case in ipairs({{'NetworkInCeilingMbps','1000.0000','1000'}, {'PanelHeight','275.50','275.5'},
                {'NetworkWiFiInterface','03','+3'},{'NetworkOutCeilingMbps','1000.0000','1000'}}) do
            local before=replace(initial,case[1],case[2]); local mock=controller(before)
            truth(mock.env.BeginNumberInput(case[1])); mock.output='PARALLAX_INPUT_V1|ok|' .. case[3]; mock:cleanCalls()
            equal(mock.env.FinishNumberInput(),false); equal(mock.data,before)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0)
        end
    end)
    test('explicit canonical input repairs invalid numeric spellings despite equal numeric values', function()
        for _, case in ipairs({{'Columns','01','1'}, {'NetworkWiFiInterface','+1','1'}}) do
            local before=replace(initial,case[1],case[2]); local mock=controller(before)
            truth(mock.env.BeginNumberInput(case[1])); mock.output='PARALLAX_INPUT_V1|ok|' .. case[3]
            truth(mock.env.FinishNumberInput()); equal(mock.data,replace(before,case[1],case[3]))
            equal(mock:count('!WriteKeyValue'),1); equal(mock:refreshTargets(),'Parallax\\Network')
        end
        local before=replace(initial,'NetworkWiFiInterface','1.0'); local mock=controller(before)
        equal(mock.env.BeginNumberInput('NetworkWiFiInterface'),false); equal(mock:count('!CommandMeasure'),0)
        equal(mock.data,before); equal(mock:count('!WriteKeyValue'),0)
    end)
    test('closing or reinitializing settings invalidates pending completion', function()
        for _, action in ipairs({'Close','Initialize'}) do
            local mock=controller(); truth(mock.env.BeginNumberInput('PanelHeight')); mock.env[action]()
            mock.output='PARALLAX_INPUT_V1|ok|300'; mock:cleanCalls(); equal(mock.env.FinishNumberInput(),false)
            equal(mock:count('!WriteKeyValue'),0); equal(mock:count('!Refresh'),0); equal(mock.data,initial)
        end
    end)
    test('missing helper measure or input anchor cannot start a numeric edit', function()
        for _, property in ipairs({'missingInput','missingMeter'}) do
            local mock=controller(); mock[property]=true
            equal(mock.env.BeginNumberInput('Columns'),false); equal(mock:count('!CommandMeasure'),0)
            equal(mock:count('!WriteKeyValue'),0); contains(mock.latest['MeterNetworkSettingsStatus:Text'],'unavailable')
        end
    end)
    report[#report + 1] = string.format('SUMMARY: %d passed, %d failed',passed,failed)
    return table.concat(report,'\n') .. '\n'
end
return Suite
