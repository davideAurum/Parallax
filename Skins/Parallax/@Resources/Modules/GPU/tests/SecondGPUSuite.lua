-- Original Parallax second-GPU regressions for native Rainmeter Lua 5.1.
-- SecondGPU.lua (the section) and Temperature.lua's Second GPU launch option
-- run against fixtures only: files, time and environment are faked; nothing
-- is launched, read from disk or written.
local Suite = {}

function Suite.run(secondPath, temperaturePath)
    local total, failed, lines = 0, 0, {}
    local function eq(actual, expected, label)
        total = total + 1
        if actual ~= expected then
            error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
        end
    end
    local function ok(value, label) eq(not not value, true, label) end
    local function test(name, body)
        local pass, err = pcall(body)
        lines[#lines + 1] = (pass and 'PASS: ' or 'FAIL: ') .. name .. (pass and '' or ': ' .. tostring(err))
        if not pass then failed = failed + 1 end
    end
    local function hex(value)
        return (value:gsub('.', function(c) return string.format('%02X', c:byte()) end))
    end
    local tempRoot = 'C:\\Fixture Temp'
    -- A fixed 32-digit session token, built so it is plainly not a secret.
    local token = string.rep('0a', 16)
    local dataPath = tempRoot .. '\\Parallax-GPU-' .. token .. '.dat'
    local secondFile = tempRoot .. '\\Parallax-GPU-' .. token .. '.second'
    local luid = '0000000000010618'

    local function fixture(mode)
        local f = {now = 1000, calls = {}, options = {}, files = {}, reads = {}, variables = {GPUSecondBlock = '0'}}
        local skin = {}
        function skin:GetVariable(name, fallback)
            if name == 'MetricsInterval' then return '1000' end
            if name == 'SensorInterval' then return '2000' end
            if name == 'GPUEngineBarWidth' then return '98' end
            if name == 'DataBarThicknessPx' then return '6' end
            -- The collapsed panel at load (width 220, scale 1, table on).
            local layout = {PanelHeightPx = '(Round(Max(0,462)*1))', WindowHeight = '((Round(Max(0,462)*1))+8)',
                GPUNaturalHeight = '(304+110+48+0+0)', GPUPanelMinimum = '(0)', Scale = '1'}
            if layout[name] then return layout[name] end
            error('unexpected variable ' .. tostring(name))
        end
        function skin:ReplaceVariables(raw) return raw end
        local known = {['(Round(Max(0,462)*1))'] = 462, ['((Round(Max(0,462)*1))+8)'] = 470, ['(304+110+48+0+0)'] = 462, ['(0)'] = 0, ['1'] = 1}
        function skin:ParseFormula(raw) return known[raw] or tonumber(raw:match('^%((.*)%)$')) end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = table.concat({command, ...}, ' ')
            if command == '!SetOption' then
                assert(#args == 3, 'scalar option')
                if args[2] ~= 'Shape2' and args[2] ~= 'Formula' then
                    assert(not args[3]:find('[#%[%]"%c]'), 'unsafe display data: ' .. args[3])
                end
                f.options[args[1] .. ':' .. args[2]] = args[3]
            elseif command == '!SetVariable' then
                local derived = {GPUSecondBlock = true, GPUSecondShown = true, GPUSecondRowsShown = true,
                    GPUNaturalHeight = true, PanelHeightPx = true, WindowHeight = true}
                assert(derived[args[1]], 'only the section height and its derived variables: ' .. tostring(args[1]))
                f.variables[args[1]] = args[2]
            elseif command == '!SetOptionGroup' then
                assert(args[1] == 'GPUSecondLayout' and args[2] == 'DynamicVariables' and (args[3] == '1' or args[3] == '0'), 'one layout re-read')
            elseif command == '!UpdateMeterGroup' then
                assert(args[1] == 'GPUSecondLayout')
            elseif command == '!ShowMeterGroup' or command == '!HideMeterGroup' then
                assert(args[1] == 'GPUSecondLine' or args[1] == 'GPUSecondRows' or args[1] == 'GPUSecondTrace')
                f.visible = f.visible or {}
                f.visible[args[1]] = command == '!ShowMeterGroup'
            elseif command == '!UpdateMeasure' then
                assert(args[1] == 'MeasureGPUSecondHistory')
                f.points = f.points or {}
                f.points[#f.points + 1] = tonumber(f.options['MeasureGPUSecondHistory:Formula'])
            elseif command == '!UpdateMeter' then
                assert(args[1] == 'MeterGPUSecondGraph')
            elseif command == '!Redraw' then
            else error('unexpected bang ' .. tostring(command)) end
        end
        local self = {}
        function self:GetOption(name, fallback)
            assert(name == 'Mode'); return mode
        end
        local fakeio = {open = function(path, openMode)
            assert(openMode == 'rb', 'read only')
            assert(path == secondFile, 'only the session second file is read: ' .. tostring(path))
            f.reads[#f.reads + 1] = path
            if not f.files[path] then return nil end
            return {read = function(_, count) assert(count == 8193, 'bounded read'); return f.files[path] end,
                close = function() return true end}
        end}
        local fakeos = setmetatable({time = function() return f.now end, getenv = function(key)
            assert(key == 'TMP' or key == 'TEMP'); return tempRoot end}, {__index = function() error('unexpected os call') end})
        local blocked = function() error('unexpected external work') end
        local env = setmetatable({SKIN = skin, SELF = self, io = fakeio, os = fakeos,
            require = blocked, dofile = blocked, loadfile = blocked, loadstring = blocked}, {__index = _G})
        local chunk = assert(loadfile(secondPath)); setfenv(chunk, env); chunk()
        f.env = env
        env.Initialize()
        function f:sample(overrides)
            local values = {'GPU_SECOND', '1', token, tostring(self.sequence or 1), tostring(self.now), 'OK', luid, 'D',
                hex('Fixture RTX'), 'OK', '37', '12', '4294967296', '1288490189'}
            for key, value in pairs(overrides or {}) do values[key] = value end
            self.files[secondFile] = table.concat(values, '|')
        end
        function f:session(path) self.env.Session(path) end
        function f:update() return self.env.Update() end
        function f:text(meter) return self.options[meter .. ':Text'] end
        return f
    end

    test('Off reads nothing and changes nothing', function()
        for _, mode in ipairs({'0', '', '4', 'x', '1.0'}) do
            local f = fixture(mode)
            f:session(hex(dataPath)); f:sample(); f:update()
            eq(#f.reads, 0, 'no read for mode ' .. mode); eq(#f.calls, 0, 'no bang for mode ' .. mode)
        end
    end)

    test('without a session nothing is read and the panel stays as today', function()
        local f = fixture('1')
        f:sample(); f:update()
        eq(#f.reads, 0); eq(f.variables.GPUSecondBlock, '0'); eq(#f.calls, 0)
    end)

    test('only a TMP/TEMP Parallax session path is accepted', function()
        for _, bad in ipairs({'', 'zz', hex('C:\\Elsewhere\\Parallax-GPU-' .. token .. '.dat'),
            hex(tempRoot .. '\\Parallax-GPU-' .. token:sub(2) .. '.dat'), hex(tempRoot .. '\\Parallax-GPU-' .. token .. '.lease'),
            hex(tempRoot .. '\\..\\Parallax-GPU-' .. token .. '.dat'), hex(tempRoot .. '\\Other-' .. token .. '.dat')}) do
            local f = fixture('2')
            f:session(bad); f:sample(); f:update()
            eq(#f.reads, 0, 'rejected ' .. bad)
        end
        local f = fixture('2')
        f:session(hex(dataPath)); f:sample(); f:update()
        eq(#f.reads, 1, 'the valid session is read')
    end)

    test('One line opens a 32 px section with the name and load only', function()
        local f = fixture('1')
        f:session(hex(dataPath)); f:sample(); f:update()
        eq(f.variables.GPUSecondBlock, '32'); eq(f.visible.GPUSecondLine, true)
        eq(f.variables.GPUSecondShown, '1'); eq(f.variables.GPUSecondRowsShown, '0')
        eq(f.variables.GPUNaturalHeight, '494'); eq(f.variables.PanelHeightPx, '494'); eq(f.variables.WindowHeight, '502')
        eq(f.visible.GPUSecondRows, nil, 'rows stay hidden'); eq(f.visible.GPUSecondTrace, nil, 'trace stays hidden')
        eq(f:text('MeterGPUSecondName'), 'Fixture RTX'); eq(f:text('MeterGPUSecondLoad'), '37%')
        eq(f:text('MeterGPUSecondVideoValue'), nil, 'no row writes in One line'); eq(f.points, nil, 'no trace in One line')
        local before = #f.calls
        f:update()
        eq(#f.calls, before, 'an unchanged sample repaints nothing')
    end)

    test('Rows adds Video with its bar and memory in use; Shared on an integrated GPU', function()
        local f = fixture('2')
        f:session(hex(dataPath)); f:sample(); f:update()
        eq(f.variables.GPUSecondBlock, '64'); eq(f.visible.GPUSecondRows, true); eq(f.visible.GPUSecondTrace, nil)
        eq(f.variables.GPUSecondRowsShown, '1'); eq(f.variables.PanelHeightPx, '526'); eq(f.variables.WindowHeight, '534')
        eq(f:text('MeterGPUSecondVideoValue'), '12%'); eq(f:text('MeterGPUSecondMemoryLabel'), 'VRAM')
        eq(f:text('MeterGPUSecondMemoryValue'), '1.3/4.3 GB')
        ok(f.options['MeterGPUSecondVideoBar:Shape2']:find('Line 0,3.000,11.760,3.000 | StrokeWidth 6.000', 1, true), 'bar at 12% of 98 px')
        f.sequence, f.now = 2, f.now + 2
        f:sample({[8] = 'I', [13] = '8491673600', [14] = '1200000000'})
        f:update()
        eq(f:text('MeterGPUSecondMemoryLabel'), 'Shared'); eq(f:text('MeterGPUSecondMemoryValue'), '1.2/8.5 GB')
    end)

    test('Rows + history pushes one point per new sample, 0 when unread, none while starting', function()
        local f = fixture('3')
        f:session(hex(dataPath)); f:sample({[10] = 'STARTING', [11] = '?', [12] = '?'}); f:update()
        eq(f.visible.GPUSecondTrace, true); eq(f.points, nil, 'starting adds no point')
        eq(f:text('MeterGPUSecondLoad'), '--')
        f.sequence, f.now = 2, f.now + 2; f:sample(); f:update()
        eq(#f.points, 1); eq(f.points[1], 37)
        f.now = f.now + 1; f:update()
        eq(#f.points, 1, 'the same sample is never plotted twice')
        f.sequence, f.now = 3, f.now + 1; f:sample({[10] = 'UNAVAILABLE', [11] = '?', [12] = '?'}); f:update()
        eq(#f.points, 2); eq(f.points[2], 0); eq(f:text('MeterGPUSecondLoad'), '--'); eq(f:text('MeterGPUSecondVideoValue'), '--')
    end)

    test('no second GPU, or one that went away, collapses the section', function()
        for _, status in ipairs({'NONE', 'UNSUPPORTED', 'DEVICE_CHANGED'}) do
            local f = fixture('2')
            f:session(hex(dataPath)); f:sample(); f:update()
            eq(f.variables.GPUSecondBlock, '64')
            f.sequence, f.now = 2, f.now + 2
            f:sample({[6] = status, [7] = '?', [8] = '?', [9] = '?', [10] = '?', [11] = '?', [12] = '?', [13] = '?', [14] = '?'})
            f:update()
            eq(f.variables.GPUSecondBlock, '0', status); eq(f.visible.GPUSecondLine, false); eq(f.visible.GPUSecondRows, false)
            eq(f.variables.PanelHeightPx, '462', 'collapsed panel is as today'); eq(f.variables.WindowHeight, '470'); eq(f.variables.GPUSecondShown, '0')
        end
        local f = fixture('1')
        f:session(hex(dataPath)); f:sample({[6] = 'NONE', [7] = '?', [8] = '?', [9] = '?'}); f:update()
        eq(f.variables.GPUSecondBlock, '0'); eq(#f.calls, 0, 'a single-GPU machine never opens the section')
    end)

    test('stale, foreign or malformed samples read -- and never open the section', function()
        local f = fixture('2')
        f:session(hex(dataPath)); f:sample(); f:update()
        f.now = f.now + 9; f:update()
        eq(f:text('MeterGPUSecondLoad'), '--', 'stale'); eq(f:text('MeterGPUSecondMemoryValue'), '--')
        eq(f.variables.GPUSecondBlock, '64', 'a stale sample keeps the layout')
        for _, overrides in ipairs({{[3] = string.rep('f', 32)}, {[1] = 'GPU_TEMP'}, {[2] = '2'}, {[4] = '-1'}, {[5] = 'x'}}) do
            local g = fixture('2')
            g:session(hex(dataPath)); g:sample(overrides); g:update()
            eq(g.variables.GPUSecondBlock, '0', 'rejected sample opens nothing')
        end
        local g = fixture('2')
        g:session(hex(dataPath)); g.files[secondFile] = 'GPU_SECOND|1|' .. token; g:update()
        eq(g.variables.GPUSecondBlock, '0', 'short sample')
        g:sample({[7] = 'XYZ'}); g:update()
        eq(g.variables.GPUSecondBlock, '0', 'bad LUID')
        g:sample({[11] = '101', [12] = '-1', [13] = '10', [14] = '20'}); g:update()
        eq(g:text('MeterGPUSecondLoad'), '--', 'out-of-range load'); eq(g:text('MeterGPUSecondVideoValue'), '--')
        eq(g:text('MeterGPUSecondMemoryValue'), '--', 'used above total')
    end)

    test('the name is provider data: decoded, sanitized, with a fallback', function()
        local f = fixture('1')
        f:session(hex(dataPath)); f:sample({[9] = hex('Bad #name [x] "q"')}); f:update()
        eq(f:text('MeterGPUSecondName'), "Bad name (x) 'q'")
        f.sequence = 2; f:sample({[9] = '?'}); f:update()
        eq(f:text('MeterGPUSecondName'), 'Second GPU')
        f.sequence = 3; f:sample({[8] = 'I', [9] = 'GG'}); f:update()
        eq(f:text('MeterGPUSecondName'), 'Integrated GPU')
        f.sequence = 4; f:sample({[9] = hex('a\1b')}); f:update()
        eq(f:text('MeterGPUSecondName'), 'Second GPU', 'control characters are rejected')
    end)

    test('a session that ends blanks the readings; a new one is read afresh', function()
        local f = fixture('3')
        f:session(hex(dataPath)); f.sequence = 5; f:sample(); f:update()
        eq(#f.points, 1)
        f:session(''); f:update()
        eq(f:text('MeterGPUSecondLoad'), '--')
        local reads = #f.reads
        f:update(); eq(#f.reads, reads, 'no session, no read')
        f:session(hex(dataPath)); f.sequence = 1; f.now = f.now + 2; f:sample(); f:update()
        eq(#f.points, 2, 'a new session restarts the sequence')
    end)

    -- Temperature.lua: the Second GPU option only adds the host's fourth
    -- argument and the session notice; Off is today's launch exactly.
    local function launchFixture(option)
        local f = {calls = {}, parameter = nil, removed = {}}
        local metadata = 'OK|Fixture|8589934592|GDDR6|?|PHYSICAL|1|2\nGPU_ADAPTER|1|0000000000010A3F'
        local skin = {}
        function skin:GetVariable(name, fallback)
            local values = {MetricsInterval = '1000', SensorInterval = '2000', GPUEnableSensors = '0', GPUPowerSource = '0',
                GPUClockSource = '0', SETTINGSPATH = 'C:\\S\\', CURRENTCONFIG = 'Parallax\\GPU', ['@'] = 'C:\\R\\'}
            return values[name] or fallback
        end
        function skin:ReplaceVariables(raw) return raw end
        function skin:ParseFormula() return 0 end
        function skin:GetMeasure(name)
            if name == 'MeasureGPUInfo' then return {GetValue = function() return 1 end, GetStringValue = function() return metadata end} end
            if name == 'MeasureGPUTemperatureLauncher' then return {GetValue = function() return f.launcherStatus or -1 end,
                GetStringValue = function() return f.launcherOutput or '' end} end
            if name == 'MeasureGPUProcessController' then return {GetStringValue = function() return '?' end} end
            return nil
        end
        function skin:Bang(command, ...)
            local args = {...}
            f.calls[#f.calls + 1] = table.concat({command, ...}, ' ')
            if command == '!SetOption' and args[1] == 'MeasureGPUTemperatureLauncher' then f.parameter = args[3] end
        end
        local self = option and {GetOption = function(_, name, fallback) assert(name == 'SecondGPU'); return option end} or {}
        local fakeio = {open = function(path, openMode)
            if openMode == 'wb' then return {write = function(h) return h end, close = function() return true end} end
            return nil
        end}
        local fakeos = {time = function() return 1000 end, getenv = function() return tempRoot end,
            remove = function(path) f.removed[#f.removed + 1] = path; return true end}
        local env = setmetatable({SKIN = skin, SELF = self, io = fakeio, os = fakeos}, {__index = _G})
        local chunk = assert(loadfile(temperaturePath)); setfenv(chunk, env); chunk()
        env.Initialize(); env.Update()
        f.env = env
        return f
    end
    test('Temperature.lua: Second GPU on adds only the host argument and the session notice', function()
        for _, option in ipairs({'1', '2', '3'}) do
            local f = launchFixture(option)
            ok(f.parameter and f.parameter:find("[ParallaxGpuTemperature]::Run(''@T@'',''0000000000010A3F'',2000,''1'')", 1, true), 'fourth argument for ' .. option)
            f.launcherStatus, f.launcherOutput = 1, 'GPU_TEMP_SESSION|1|' .. token .. '|' .. hex(dataPath) .. '|0000000000010A3F'
            f.env.Update()
            local notice = "!CommandMeasure MeasureGPUSecond Session('" .. hex(dataPath) .. "')"
            local found = false
            for _, call in ipairs(f.calls) do if call == notice then found = true end end
            ok(found, 'session notice for ' .. option)
            f.env.Stop()
            eq(f.calls[#f.calls], "!CommandMeasure MeasureGPUSecond Session('')", 'stop clears the session')
            local removedSecond = false
            for _, path in ipairs(f.removed) do if path == tempRoot .. '\\Parallax-GPU-' .. token .. '.second' then removedSecond = true end end
            ok(removedSecond, 'stop removes the second file')
        end
    end)
    test('Temperature.lua: Off, a malformed option or no option launch exactly as before', function()
        for _, option in ipairs({'0', 'x', '', false}) do
            local f = launchFixture(option or nil)
            ok(f.parameter and f.parameter:find("[ParallaxGpuTemperature]::Run(''@T@'',''0000000000010A3F'',2000)", 1, true), 'three arguments for ' .. tostring(option))
            f.launcherStatus, f.launcherOutput = 1, 'GPU_TEMP_SESSION|1|' .. token .. '|' .. hex(dataPath) .. '|0000000000010A3F'
            f.env.Update(); f.env.Stop()
            for _, call in ipairs(f.calls) do ok(not call:find('MeasureGPUSecond', 1, true), 'no second-GPU notice for ' .. tostring(option)) end
            for _, path in ipairs(f.removed) do ok(not path:find('.second', 1, true), 'no second file touched') end
        end
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
