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
            updatedGroups = {}, redraws = 0, reads = 0, vars = {}, panels = {}, asked = {}, questions = 0,
            welcome = { x = 40, y = 60, w = 456, h = 408 } }
        local vars = { SETTINGSPATH = settingsPath, TextColor = '220,220,220', MutedColor = '175,175,175' }
        local byConfig = {}
        for key, config in pairs(configs) do byConfig[config] = key end
        local skin = {}
        function skin:GetVariable(key, default) return f.vars[key] or vars[key] or default end
        function skin:GetX() return f.welcome.x end
        function skin:GetY() return f.welcome.y end
        function skin:GetW() return f.welcome.w end
        function skin:GetH() return f.welcome.h end
        function skin:Bang(command, ...)
            local a = { ... }
            f.calls[#f.calls + 1] = { command = command, args = a }
            if command == '!ShowMeter' or command == '!HideMeter' then
                assert(#a == 1 and (a[1]:match('^MeterWelcomeCheck[1-9]$') or a[1] == 'MeterWelcomeUndo'), 'unexpected visibility target')
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
            elseif command == '!SetVariable' then
                -- Every panel is asked by its own number and always told to stop.
                assert(#a == 3 and a[1] == 'ParallaxPlaceAsked' and byConfig[a[3]], 'unexpected variable')
                assert(a[2] == '0' or a[2] == tostring(slots[byConfig[a[3]]]), 'wrong panel number')
                assert(type(a[2]) == 'string', 'variables are text')
                f.asked[a[3]] = tonumber(a[2])
            elseif command == '!UpdateMeasure' then
                assert(#a == 2 and a[1] == 'MeasureParallaxPlace' and byConfig[a[2]], 'unexpected measure update')
                -- The panel answers from inside this call, as Rainmeter runs it.
                local key = byConfig[a[2]]
                local p = f.panels[key]
                if f.asked[a[2]] ~= 0 then
                    f.questions = f.questions + 1
                    if p then f.env.Placed(slots[key], p.x, p.y, p.w, p.h) end
                end
            elseif command == '!Move' then
                assert((#a == 2 or #a == 3) and a[1]:match('^%-?%d+$') and a[2]:match('^%-?%d+$'), 'moves are whole pixels')
                local key = #a == 2 and 'Welcome' or byConfig[a[3]]
                local p = assert(key == 'Welcome' and f.welcome or f.panels[key], 'moved a panel that gave no place')
                p.x, p.y, p.moved = tonumber(a[1]), tonumber(a[2]), true
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
            local content = f.content or content
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

    -- Arrange. Sizes are window sizes in pixels; the first set is the Surface
    -- laptop on 2026-11-25, where every panel but Welcome had been left at 0,0.
    local function sizes(list)
        local out = {}
        for key, size in pairs(list) do out[key] = { x = 0, y = 0, w = size[1], h = size[2] } end
        return out
    end
    local laptop = { Chronometer = { 228, 160 }, CPU = { 228, 494 }, RAM = { 228, 339 }, GPU = { 228, 470 },
        IO = { 228, 286 }, Network = { 228, 312 }, Media = { 456, 391 }, Visualizer = { 456, 154 }, Settings = { 456, 1005 } }
    local function screen(f, number, x, y, w, h)
        f.vars['WORKAREAX@' .. number], f.vars['WORKAREAY@' .. number] = tostring(x), tostring(y)
        f.vars['WORKAREAWIDTH@' .. number], f.vars['WORKAREAHEIGHT@' .. number] = tostring(w), tostring(h)
        if number == 1 then
            f.vars.PWORKAREAX, f.vars.PWORKAREAY, f.vars.PWORKAREAWIDTH, f.vars.PWORKAREAHEIGHT = tostring(x), tostring(y), tostring(w), tostring(h)
        end
    end
    local function desk(list, w, h)
        local entries = {}
        for key in pairs(list) do entries[#entries + 1] = { configs[key], 1 } end
        local f = fixture(ini(entries))
        f.panels = sizes(list)
        screen(f, 1, 0, 0, w, h)
        f.env.Render(); f:clear()
        return f
    end
    local function all(f)
        local out = { Welcome = f.welcome }
        for key, p in pairs(f.panels) do out[key] = p end
        return out
    end
    local function overlaps(f)
        local list, found = {}, {}
        for key, p in pairs(all(f)) do list[#list + 1] = { key = key, p = p } end
        table.sort(list, function(a, b) return a.key < b.key end)
        for i = 1, #list do
            for j = i + 1, #list do
                local a, b = list[i].p, list[j].p
                if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
                    found[#found + 1] = list[i].key .. '/' .. list[j].key
                end
            end
        end
        return table.concat(found, ' ')
    end
    local function outside(f, x, y, w, h)
        local found = {}
        for key, p in pairs(all(f)) do
            if p.x < x or p.y < y or p.x + p.w > x + w or p.y + p.h > y + h then found[#found + 1] = key end
        end
        table.sort(found)
        return table.concat(found, ' ')
    end
    local function at(f, key) local p = all(f)[key]; return p.x .. ',' .. p.y end

    test('arrange unstacks the laptop with its real sizes', function()
        local f = desk(laptop, 1600, 1019)
        ok(overlaps(f) ~= '', 'the panels start stacked')
        eq(f.env.Arrange(), true, 'result')
        eq(overlaps(f), '', 'overlaps')
        eq(outside(f, 0, 0, 1600, 1019), '', 'outside')
        eq(at(f, 'CPU'), '1372,0'); eq(at(f, 'GPU'), '1144,0'); eq(at(f, 'IO'), '1144,470')
        eq(at(f, 'Chronometer'), '1144,756'); eq(at(f, 'Network'), '916,0'); eq(at(f, 'RAM'), '916,312')
        eq(at(f, 'Visualizer'), '460,0'); eq(at(f, 'Media'), '460,154'); eq(at(f, 'Welcome'), '460,545')
        eq(at(f, 'Settings'), '4,0')
        eq(f:status(), '10 panels arranged. Undo puts them back.', 'status')
        eq(f.visible.MeterWelcomeUndo, true, 'undo offered')
        eq(#f.activated + #f.deactivated, 0, 'nothing loaded or unloaded')
    end)

    test('arrange with shipped sizes matches the first placement', function()
        -- docs/WELCOME.md, 1920 x 1032 with 12 threads.
        local f = desk({ Chronometer = { 228, 160 }, CPU = { 228, 566 }, RAM = { 228, 339 }, GPU = { 228, 470 }, IO = { 228, 160 },
            Network = { 228, 312 }, Media = { 456, 186 }, Visualizer = { 456, 154 }, Settings = { 456, 1005 } }, 1920, 1032)
        f.env.Arrange()
        eq(at(f, 'CPU'), '1692,0'); eq(at(f, 'GPU'), '1464,0'); eq(at(f, 'IO'), '1464,470'); eq(at(f, 'Chronometer'), '1464,630')
        eq(at(f, 'Network'), '1236,0'); eq(at(f, 'RAM'), '1236,312'); eq(at(f, 'Visualizer'), '780,0'); eq(at(f, 'Media'), '780,154')
        eq(at(f, 'Welcome'), '780,340'); eq(at(f, 'Settings'), '324,0')
    end)

    test('a narrow panel keeps to the right of a wide column', function()
        local f = desk({ Visualizer = { 228, 154 }, Media = { 456, 186 } }, 1920, 1032)
        f.env.Arrange()
        eq(at(f, 'Visualizer'), '1692,0'); eq(at(f, 'Media'), '1464,154')
        eq(overlaps(f), '', 'overlaps')
    end)

    test('a panel its column has no room for goes under another column', function()
        local f = desk({ CPU = { 228, 494 }, GPU = { 228, 470 }, IO = { 228, 286 }, Chronometer = { 228, 160 } }, 1600, 800)
        f.env.Arrange()
        eq(at(f, 'Chronometer'), '1372,494', 'below CPU')
        eq(overlaps(f), '', 'overlaps')
        eq(outside(f, 0, 0, 1600, 800), '', 'outside')
    end)

    test('a screen without room keeps every title visible and says so', function()
        -- A 1080p screen at 150%.
        local f = desk(laptop, 1280, 672)
        f.env.Arrange()
        eq(f:status(), '10 panels arranged, 3 overlapping: the screen is full.', 'status')
        local seen = {}
        for key, p in pairs(all(f)) do
            ok(p.x >= 0 and p.y >= 0 and p.x + p.w <= 1280 and p.y <= 640, key .. ' title on screen')
            ok(not seen[at(f, key)], key .. ' has its own corner')
            seen[at(f, key)] = true
        end
        -- IO, Global Settings and Welcome have no room; the rest stay apart.
        local crossing = overlaps(f)
        for pair in crossing:gmatch('%S+') do ok(pair:find('IO') or pair:find('Settings') or pair:find('Welcome'), pair) end
    end)

    test('only loaded panels are asked and moved', function()
        local f = fixture(ini({ { configs.CPU, 1 }, { configs.Media, 2 }, { configs.GPU, 0 } }))
        f.panels = sizes({ CPU = { 228, 494 }, Media = { 456, 200 }, GPU = { 228, 470 } })
        screen(f, 1, 0, 0, 1920, 1032)
        f.env.Arrange()
        eq(f.questions, 2, 'questions')
        eq(f.panels.CPU.moved, true, 'CPU'); eq(f.panels.Media.moved, true, 'the Media setup view'); eq(f.panels.GPU.moved, nil, 'GPU')
        for config, value in pairs(f.asked) do eq(value, 0, config .. ' was told to stop') end
    end)

    test('a panel that gives no answer stays where it is', function()
        local f = fixture(ini({ { configs.CPU, 1 }, { configs.GPU, 1 } }))
        f.panels = sizes({ CPU = { 228, 494 } })
        screen(f, 1, 0, 0, 1920, 1032)
        f.env.Arrange()
        eq(f:status(), '2 panels arranged. Undo puts them back.', 'status')
    end)

    test('arrange uses the screen Welcome is on', function()
        local f = desk({ CPU = { 228, 494 } }, 1600, 1019)
        screen(f, 2, 1600, -200, 2560, 1400)
        f.welcome.x, f.welcome.y = 2000, 100
        f.env.Arrange()
        eq(at(f, 'CPU'), '3932,-200'); eq(at(f, 'Welcome'), '3476,-200')
        -- Off every screen, the primary one is used.
        f.welcome.x, f.welcome.y = -9000, -9000
        f.env.Arrange()
        eq(at(f, 'CPU'), '1372,0')
    end)

    test('undo puts back what arrange moved, once', function()
        local f = desk(laptop, 1600, 1019)
        f.panels.GPU.x, f.panels.GPU.y = -300, 77
        f.env.Arrange()
        ok(at(f, 'GPU') ~= '-300,77', 'GPU moved')
        eq(f.env.Undo(), true, 'result')
        eq(at(f, 'GPU'), '-300,77'); eq(at(f, 'CPU'), '0,0'); eq(at(f, 'Welcome'), '40,60')
        eq(f:status(), '10 panels put back.', 'status')
        eq(f.visible.MeterWelcomeUndo, false, 'undo withdrawn')
        f:clear()
        f.env.Undo()
        for _, call in ipairs(f.calls) do ok(call.command ~= '!Move', 'a second undo moves nothing') end
    end)

    test('undo skips a panel that has been unloaded since', function()
        local f = desk({ CPU = { 228, 494 }, GPU = { 228, 470 } }, 1600, 1019)
        f.env.Arrange()
        f.content = ini({ { configs.CPU, 1 }, { configs.GPU, 0 } })
        f.env.Undo()
        eq(f:status(), '2 panels put back.', 'status')
        eq(at(f, 'CPU'), '0,0'); eq(at(f, 'GPU'), '1144,0', 'GPU')
    end)

    test('arrange moves nothing when Rainmeter or the screen cannot be read', function()
        local f = fixture(nil)
        screen(f, 1, 0, 0, 1600, 1019)
        f.env.Arrange()
        eq(f:status(), 'Rainmeter settings are not readable; check marks show clicks only.', 'status')
        eq(f.welcome.moved, nil, 'Welcome')
        local g = fixture(ini({ { configs.CPU, 1 } }))
        g.panels = sizes({ CPU = { 228, 494 } })
        g.env.Arrange()
        eq(g:status(), 'The screen size is not readable; nothing was moved.', 'status')
        eq(g.panels.CPU.moved, nil, 'CPU'); eq(g.visible.MeterWelcomeUndo, nil, 'undo')
    end)

    test('an answer nobody asked for is ignored', function()
        local f = desk({ CPU = { 228, 494 } }, 1600, 1019)
        f.env.Placed(2, 0, 0, 100, 100)
        f.env.Placed(99, 0, 0, 100, 100)
        eq(#f.calls, 0, 'bangs')
    end)

    lines[#lines + 1] = string.format('SUMMARY: %d assertions, %d failed', total, failed)
    local report = table.concat(lines, '\n')
    if failed > 0 then error(report, 0) end
    return total, report
end

return Suite
