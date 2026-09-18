-- Original Parallax Welcome tests. Runs against a mocked Rainmeter skin and a
-- mocked settings file. No real config is activated, no real file is read or
-- written, and every bang the controller issues is checked against an allowlist.
local Suite = {}

function Suite.run(path)
    local total, failed, lines = 0, 0, {}
    local settingsPath = 'C:\\ParallaxTests\\Settings\\'
    local settingsFile = settingsPath .. 'Rainmeter.ini'
    local function eq(a, b, label)
        total = total + 1
        if a ~= b then error((label or 'value') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
    end
    local function ok(a, label) eq(not not a, true, label) end
    local function test(name, body)
        local pass, err = pcall(body)
        lines[#lines + 1] = (pass and 'PASS: ' or 'FAIL: ') .. name .. (pass and '' or ': ' .. tostring(err))
        if not pass then failed = failed + 1 end
    end

    local slots = { Chronometer = 1, CPU = 2, RAM = 3, GPU = 4, IO = 5,
        Network = 6, Media = 7, Visualizer = 8, Settings = 9 }
    local files = { Chronometer = 'Chronometer.ini', CPU = 'CPU.ini', RAM = 'RAM.ini',
        GPU = 'GPU.ini', IO = 'IO-Disk.ini', Network = 'Network.ini', Media = 'Media.ini',
        Visualizer = 'Visualizer.ini', Settings = 'Settings.ini' }
    local configs = { Chronometer = 'Parallax\\Chronometer', CPU = 'Parallax\\CPU',
        RAM = 'Parallax\\RAM', GPU = 'Parallax\\GPU', IO = 'Parallax\\IO',
        Network = 'Parallax\\Network', Media = 'Parallax\\Media',
        Visualizer = 'Parallax\\Visualizer', Settings = 'Parallax\\Settings' }

    -- Rainmeter stores its own settings file as UTF-16LE with a byte order mark.
    local function utf16(text)
        local out = { '\255\254' }
        for i = 1, #text do out[#out + 1] = text:sub(i, i) .. '\0' end
        return table.concat(out)
    end

    local function ini(entries, header)
        local text = header or '[Rainmeter]\r\nLogging=1\r\n'
        for _, entry in ipairs(entries) do
            text = text .. '[' .. entry[1] .. ']\r\nActive=' .. entry[2] .. '\r\nWindowX=0\r\n'
        end
        return text
    end

    -- content = nil models an unreadable settings file.
    local function fixture(content)
        local f = { calls = {}, options = {}, visible = {}, activated = {}, deactivated = {},
            updatedGroups = {}, redraws = 0, reads = 0 }
        local vars = { SETTINGSPATH = settingsPath, TextColor = '220,220,220', MutedColor = '175,175,175' }
        local skin = {}
        function skin:GetVariable(key, default) return vars[key] or default end
        function skin:Bang(command, ...)
            local a = { ... }
            f.calls[#f.calls + 1] = { command = command, args = a }
            if command == '!ShowMeter' or command == '!HideMeter' then
                assert(#a == 1 and a[1]:match('^MeterWelcomeCheck[1-9]$'), 'unexpected visibility target')
                f.visible[a[1]] = command == '!ShowMeter'
            elseif command == '!SetOption' then
                assert(#a == 3, 'unexpected option arity')
                assert((a[1]:match('^MeterWelcomeName[1-9]$') and a[2] == 'FontColor')
                    or (a[1] == 'MeterWelcomeStatus' and a[2] == 'Text'), 'unsafe option write')
                f.options[a[1]] = f.options[a[1]] or {}
                f.options[a[1]][a[2]] = a[3]
            elseif command == '!UpdateMeterGroup' then
                assert(#a == 1 and a[1] == 'WelcomeRows', 'unexpected meter group')
                f.updatedGroups[#f.updatedGroups + 1] = a[1]
            elseif command == '!UpdateMeter' then
                assert(#a == 1 and a[1] == 'MeterWelcomeStatus', 'unexpected meter update')
            elseif command == '!Redraw' then
                assert(#a == 0, 'unexpected redraw arity')
                f.redraws = f.redraws + 1
            elseif command == '!ActivateConfig' then
                assert(#a == 2, 'activation needs a config and a file')
                f.activated[#f.activated + 1] = a[1] .. '|' .. a[2]
            elseif command == '!DeactivateConfig' then
                assert(#a == 1, 'deactivation takes only a config')
                f.deactivated[#f.deactivated + 1] = a[1]
            else
                error('unexpected bang: ' .. tostring(command))
            end
        end
        local fakeio = {}
        function fakeio.open(target, mode)
            assert(mode == 'rb', 'settings file must be opened read only')
            if target ~= settingsFile or content == nil then return nil end
            f.reads = f.reads + 1
            local handle = {}
            function handle:read(count)
                assert(type(count) == 'number' and count > 0, 'reads must be bounded')
                return content:sub(1, count)
            end
            function handle:close() end
            return handle
        end
        local blocked = setmetatable({}, { __index = function() error('blocked library access', 2) end })
        local function forbidden() error('forbidden global', 2) end
        local env = setmetatable({ SKIN = skin, SELF = {}, io = fakeio, os = blocked,
            package = blocked, debug = blocked, require = forbidden, dofile = forbidden,
            loadfile = forbidden, loadstring = forbidden }, { __index = _G })
        env._G = env
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
        f.env = env
        env.Initialize()
        function f:clear()
            self.calls = {}; self.activated = {}; self.deactivated = {}
            self.updatedGroups = {}; self.redraws = 0
        end
        function f:status() return (self.options.MeterWelcomeStatus or {}).Text end
        function f:checked(key) return self.visible['MeterWelcomeCheck' .. slots[key]] end
        function f:named(key) return (self.options['MeterWelcomeName' .. slots[key]] or {}).FontColor end
        return f
    end

    test('a UTF-16LE settings file reports exactly the active configs', function()
        local f = fixture(utf16(ini({ { 'Parallax\\CPU', 1 }, { 'Parallax\\Media', 1 } })))
        f.env.Render()
        eq(f:checked('CPU'), true, 'CPU check')
        eq(f:checked('Media'), true, 'Media check')
        eq(f:checked('GPU'), false, 'GPU check')
        eq(f:status(), '2 of 9 components loaded.', 'status')
        eq(f:named('CPU'), '220,220,220', 'loaded name color')
        eq(f:named('GPU'), '175,175,175', 'unloaded name color')
        eq(f.redraws, 1, 'redraws')
    end)

    test('a UTF-8 settings file parses the same way', function()
        local f = fixture(ini({ { 'Parallax\\Visualizer', 1 } }))
        f.env.Render()
        eq(f:checked('Visualizer'), true, 'Visualizer check')
        eq(f:status(), '1 of 9 components loaded.', 'status')
    end)

    test('case differences and stray whitespace in the settings file still match', function()
        local f = fixture('[parallax\\network]\r\n  Active =  1  \r\n')
        f.env.Render()
        eq(f:checked('Network'), true, 'Network check')
    end)

    test('inactive, absent and non-numeric entries read as unloaded', function()
        local f = fixture(ini({ { 'Parallax\\CPU', 0 }, { 'Parallax\\GPU', 'yes' } }))
        f.env.Render()
        eq(f:checked('CPU'), false, 'explicit zero')
        eq(f:checked('GPU'), false, 'non-numeric')
        eq(f:checked('RAM'), false, 'absent section')
        eq(f:status(), '0 of 9 components loaded.', 'status')
    end)

    test('a different skin file in the same config does not count as loaded', function()
        -- Active=2 is Media's Setup.ini, not the Media player this row loads.
        local f = fixture(ini({ { 'Parallax\\Media', 2 } }))
        f.env.Render()
        eq(f:checked('Media'), false, 'Media check')
        eq(f:status(), '0 of 9 components loaded.', 'status')
    end)

    test('keys outside a section and other configs are ignored', function()
        local f = fixture('Active=1\r\n[Parallax\\Chronometer]\r\nActive=1\r\n[SomeOtherSuite\\CPU]\r\nActive=1\r\n')
        f.env.Render()
        eq(f:checked('Chronometer'), true, 'Chronometer check')
        eq(f:checked('CPU'), false, 'foreign config')
    end)

    test('an unreadable settings file clears every check and says so', function()
        local f = fixture(nil)
        f.env.Render()
        for key in pairs(slots) do eq(f:checked(key), false, key .. ' check') end
        eq(f:status(), 'Rainmeter settings are not readable; check marks show clicks only.', 'status')
    end)

    test('clicking an unloaded row activates that config and checks it immediately', function()
        local f = fixture(ini({}))
        f.env.Render(); f:clear()
        eq(f.env.Toggle('GPU'), true, 'toggle result')
        eq(#f.activated, 1, 'activations')
        eq(f.activated[1], configs.GPU .. '|' .. files.GPU, 'activated config')
        eq(#f.deactivated, 0, 'deactivations')
        eq(f:checked('GPU'), true, 'optimistic check')
        eq(f:status(), '1 of 9 components loaded.', 'status')
    end)

    test('clicking a loaded row deactivates that config and clears it immediately', function()
        local f = fixture(ini({ { configs.IO, 1 } }))
        f.env.Render(); f:clear()
        eq(f.env.Toggle('IO'), true, 'toggle result')
        eq(#f.deactivated, 1, 'deactivations')
        eq(f.deactivated[1], configs.IO, 'deactivated config')
        eq(#f.activated, 0, 'activations')
        eq(f:checked('IO'), false, 'optimistic check')
    end)

    test('the optimistic check lasts one render and then follows the settings file', function()
        local f = fixture(ini({}))
        f.env.Toggle('RAM')
        eq(f:checked('RAM'), true, 'click feedback')
        f.env.Render()
        eq(f:checked('RAM'), false, 'state after the activation was not recorded')
    end)

    test('an unknown component name changes nothing', function()
        local f = fixture(ini({}))
        f.env.Render(); f:clear()
        for _, key in ipairs({ 'Welcome', 'ColorPicker', '', 'Parallax\\CPU', 'CPU.ini' }) do
            eq(f.env.Toggle(key), false, 'toggle ' .. key)
        end
        eq(#f.calls, 0, 'bangs')
    end)

    test('load all activates only what is missing and reports every component', function()
        local f = fixture(ini({ { configs.CPU, 1 }, { configs.Settings, 1 } }))
        f.env.Render(); f:clear()
        eq(f.env.LoadAll(), true, 'load all result')
        eq(#f.activated, 7, 'activations')
        for _, entry in ipairs(f.activated) do
            ok(not entry:match('^' .. configs.CPU:gsub('%\\', '%%\\') .. '|'), 'CPU was left alone')
        end
        for key in pairs(slots) do eq(f:checked(key), true, key .. ' check') end
        eq(f:status(), '9 of 9 components loaded.', 'status')
        eq(#f.deactivated, 0, 'deactivations')
    end)

    test('load all activates every component when the settings file is unreadable', function()
        local f = fixture(nil)
        f.env.LoadAll()
        eq(#f.activated, 9, 'activations')
        eq(#f.deactivated, 0, 'deactivations')
    end)

    test('unload all deactivates only loaded components', function()
        local f = fixture(ini({ { configs.Media, 1 }, { configs.Network, 1 } }))
        f.env.Render(); f:clear()
        eq(f.env.UnloadAll(), true, 'unload all result')
        eq(#f.deactivated, 2, 'deactivations')
        eq(#f.activated, 0, 'activations')
        for key in pairs(slots) do eq(f:checked(key), false, key .. ' check') end
    end)

    test('unload all deactivates nothing when the loaded set is unknown', function()
        local f = fixture(nil)
        f.env.UnloadAll()
        eq(#f.deactivated, 0, 'deactivations')
        eq(f:status(), 'Rainmeter settings are not readable; check marks show clicks only.', 'status')
    end)

    test('the first update paints once and later updates do not repeat it', function()
        local f = fixture(ini({ { configs.CPU, 1 } }))
        eq(f.env.Update(), 0, 'update result')
        eq(f.redraws, 1, 'first update redraw')
        f:clear()
        f.env.Update(); f.env.Update()
        eq(f.redraws, 0, 'later updates')
        eq(#f.calls, 0, 'later bangs')
    end)

    test('a missing settings path never opens a file', function()
        local f = fixture(ini({ { configs.CPU, 1 } }))
        f.env.SKIN.GetVariable = function(_, key, default)
            if key == 'SETTINGSPATH' then return default end
            return key == 'TextColor' and '220,220,220' or '175,175,175'
        end
        f.env.Initialize()
        local before = f.reads
        f.env.Render()
        eq(f.reads, before, 'file reads')
        eq(f:status(), 'Rainmeter settings are not readable; check marks show clicks only.', 'status')
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
