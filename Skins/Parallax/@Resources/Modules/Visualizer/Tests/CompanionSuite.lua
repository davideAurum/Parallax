-- Developer-only checks for Companion.lua, the standalone Audio Visualizer's
-- one-capture notice to Media. Files and Bangs are injected; nothing reaches
-- Rainmeter. Lua 5.1 (Rainmeter's own, or OBS's LuaJIT through ctypes).
-- Suite.Run(companionPath, linkPath) returns a report and raises on failure.
local Suite = {}

local function utf16le(text)
    local out = { '\255\254' }
    for index = 1, #text do out[#out + 1] = text:sub(index, index) .. '\0' end
    return table.concat(out)
end

function Suite.Run(companionPath, linkPath)
    local passed, cases = 0, {}
    local function check(ok, message) if not ok then error(message, 2) end passed = passed + 1 end
    local function equal(actual, expected, message)
        if actual ~= expected then error((message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
        passed = passed + 1
    end
    local function scenario(name, body)
        local before = passed
        local ok, message = pcall(body)
        if not ok then error(name .. ': ' .. tostring(message), 0) end
        cases[#cases + 1] = name .. ': ' .. (passed - before) .. ' assertions'
    end
    local resources = 'C:\\Fixture\\Skins\\Parallax\\@Resources\\'
    local settings = 'C:\\Fixture\\Settings\\'
    local silent = { '!SetVariableGroup ParallaxCompanionCheck 1 Parallax', '!UpdateMeasureGroup ParallaxMediaCompanion *' }

    -- media/own: Rainmeter.ini Active values for Parallax\Media and
    -- Parallax\Visualizer (nil omits the section); drawer: User\Media.inc.
    local function fixture(options)
        local lines = { '[Rainmeter]', 'SkinPath=C:\\Fixture\\Skins\\' }
        if options.media ~= nil then lines[#lines + 1] = '[Parallax\\Media]'; lines[#lines + 1] = 'Active=' .. options.media end
        if options.own ~= nil then lines[#lines + 1] = '[Parallax\\Visualizer]'; lines[#lines + 1] = 'Active=' .. options.own end
        local text = table.concat(lines, '\r\n') .. '\r\n'
        local settingsText = options.utf8 and text or utf16le(text)
        if options.unreadable then settingsText = false end
        local files = {
            [settings .. 'Rainmeter.ini'] = settingsText,
            [resources .. 'User\\Media.inc'] = '[Variables]\r\nVisualizerDrawer=' .. (options.drawer or '2') .. '\r\n',
            [resources .. 'Idle\\Link.lua'] = not options.noLink and '-- link' or nil,
        }
        local state = { bangs = {}, loads = 0 }
        local skin = {}
        local variables = { ['@'] = resources, SETTINGSPATH = settings, ROOTCONFIG = 'Parallax', CURRENTCONFIG = 'Parallax\\Visualizer' }
        function skin:GetVariable(name, default)
            local value = variables[name]
            if value == nil then return default end
            return value
        end
        function skin:Bang(...) state.bangs[#state.bangs + 1] = table.concat({ ... }, ' ') end
        local fakeIo = { open = function(path, mode)
            assert(mode == 'rb', 'Read-only')
            local text = files[path]
            if text == nil or text == false then return nil end
            return { read = function(_, limit) return text:sub(1, limit) end, close = function() return true end }
        end }
        local env = setmetatable({ SKIN = skin, io = fakeIo, os = { time = function() return 0 end } }, { __index = _G })
        env.dofile = function(path)
            assert(path == resources .. 'Idle\\Link.lua', 'Only the shared link is loaded')
            assert(not options.noLink, 'A missing link file must not be passed to dofile')
            state.loads = state.loads + 1
            local chunk = assert(loadfile(linkPath))
            setfenv(chunk, env)
            return chunk()
        end
        local chunk = assert(loadfile(companionPath))
        setfenv(chunk, env)
        chunk()
        env.Initialize()
        equal(#state.bangs, 0, 'Initialize sends nothing')
        state.env = env
        return state
    end
    local function expectSilent(state, message)
        equal(#state.bangs, 2, message .. ' (two bangs)')
        equal(state.bangs[1], silent[1], message .. ' (flag)')
        equal(state.bangs[2], silent[2], message .. ' (silent group request)')
    end

    scenario('Announce tells a running Media.ini, whatever its drawer state', function()
        for _, drawer in ipairs({ '1', '2' }) do
            for _, utf8 in ipairs({ false, true }) do
                local state = fixture({ media = 1, own = 1, drawer = drawer, utf8 = utf8 })
                equal(state.env.Announce(), true, 'Announced')
                expectSilent(state, 'Drawer ' .. drawer .. (utf8 and ' (UTF-8 settings)' or ' (UTF-16LE settings)'))
            end
        end
    end)

    scenario('Announce stays quiet without Media.ini running', function()
        for _, media in ipairs({ 0, 2 }) do
            local state = fixture({ media = media, own = 1 })
            equal(state.env.Announce(), false, 'Media Active=' .. media)
            equal(#state.bangs, 0, 'Nothing sent for Media Active=' .. media)
        end
        local never = fixture({ own = 1 })
        equal(never.env.Announce(), false, 'Media never loaded')
        equal(#never.bangs, 0, 'Nothing sent without a Media section')
        local unreadable = fixture({ media = 1, own = 1, unreadable = true })
        equal(unreadable.env.Announce(), false, 'Unreadable settings')
        equal(#unreadable.bangs, 0, 'Nothing sent without settings')
    end)

    scenario('Closing acts only after a real unload', function()
        local unload = fixture({ media = 1, own = 0 })
        equal(unload.env.Closing(), true, 'Unloaded (Active=0) with Media running')
        expectSilent(unload, 'Unload')
        local exit = fixture({ media = 1, own = 1 })
        equal(exit.env.Closing(), false, 'Rainmeter exit or game mode (Active still 1)')
        equal(#exit.bangs, 0, 'Nothing sent at exit')
        local alone = fixture({ media = 0, own = 0 })
        equal(alone.env.Closing(), false, 'Unloaded with Media not running')
        equal(#alone.bangs, 0, 'Nothing sent without Media')
        local unreadable = fixture({ media = 1, own = 0, unreadable = true })
        equal(unreadable.env.Closing(), false, 'Unreadable settings')
        equal(#unreadable.bangs, 0, 'Nothing sent without settings')
    end)

    scenario('a missing shared link file disables the notice without a dofile', function()
        local state = fixture({ media = 1, own = 0, noLink = true })
        equal(state.loads, 0, 'No dofile for a missing file (Rainmeter would log an error)')
        equal(state.env.Announce(), false, 'No announce')
        equal(state.env.Closing(), false, 'No closing notice')
        equal(#state.bangs, 0, 'Nothing sent')
    end)

    return 'PASS: ' .. passed .. ' assertions in ' .. #cases .. ' companion scenarios; ' .. _VERSION .. '.\n' .. table.concat(cases, '\n')
end

return Suite
