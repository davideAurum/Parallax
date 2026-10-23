-- Offline checks for Display.lua's idle stand-down entry points
-- (ReapplyDividers, IdleLeave). Lua 5.1 (OBS LuaJIT or Rainmeter's own); the
-- skin is a fake. Run(displayPath) returns a report or raises.
local Suite = {}

function Suite.Run(displayPath)
    local passed = 0
    local function check(ok, message) if not ok then error(message, 2) end passed = passed + 1 end
    local function fixture(variables, options)
        local state = { bangs = {}, options = options or {} }
        local skin = {}
        function skin:GetVariable(name) return variables[name] end
        function skin:GetMeter(name)
            return { GetOption = function(_, key, default) return state.options[name .. ':' .. key] or default end }
        end
        function skin:GetMeasure(name)
            if name ~= 'MeasureRAMHistorySamples' then return nil end
            return { GetOption = function(_, key, default) return state.options[name .. ':' .. key] or default end }
        end
        function skin:Bang(...) state.bangs[#state.bangs + 1] = table.concat({ ... }, ' ') end
        local env = setmetatable({ SKIN = skin }, { __index = _G })
        local chunk = assert(loadfile(displayPath))
        setfenv(chunk, env)
        chunk()
        env.Initialize()
        state.env = env
        return state
    end
    local base = { RAMUseMiB = '0', RAMDecimals = '1', RAMPercentDecimals = '0', RAMShowBar = '1', RAMShowPageBar = '1', RAMShowHistory = '1' }

    -- Before preferences are applied nothing is known about the units.
    local early = fixture(base)
    early.env.ReapplyDividers()
    check(#early.bangs == 1 and early.bangs[1] == '!SetOption MeterRAMHistoryUncollected UpdateDivider 1', 'Only the cover before preferences')

    for _, unit in ipairs({ '0', '1' }) do
        local variables = {}
        for key, value in pairs(base) do variables[key] = value end
        variables.RAMUseMiB = unit
        local state = fixture(variables)
        state.env.Update()              -- the load's ApplyPreferences
        state.bangs = {}
        state.env.ReapplyDividers()
        local shown, hidden = unit == '1' and 'MiB' or 'GiB', unit == '1' and 'GiB' or 'MiB'
        local seen = table.concat(state.bangs, '\n')
        check(seen:find('!SetOption MeterRAMUsed' .. shown .. ' UpdateDivider 1', 1, true), 'Shown unit samples (' .. shown .. ')')
        check(seen:find('!SetOption MeterRAMUsed' .. hidden .. ' UpdateDivider -1', 1, true), 'Hidden unit idles (' .. hidden .. ')')
        check(seen:find('!SetOption MeterRAMHistoryUncollected UpdateDivider 1', 1, true), 'The restarted cover updates')
        -- Bypasses caches: a second call sends the same bangs again.
        local count = #state.bangs
        state.env.ReapplyDividers()
        check(#state.bangs == 2 * count, 'ReapplyDividers ignores any change cache')
    end

    -- IdleLeave restarts the sample count (formula kept) and re-shows the cover.
    local state = fixture(base, { ['MeasureRAMHistorySamples:Formula'] = 'Min(MeasureRAMHistorySamples+1,(220-2*6))' })
    state.env.Update()
    state.bangs = {}
    state.env.IdleLeave()
    local expected = {
        '!SetOption MeasureRAMHistorySamples Formula 0',
        '!SetOption MeasureRAMHistorySamples UpdateDivider 1',
        '!UpdateMeasure MeasureRAMHistorySamples',
        '!SetOption MeasureRAMHistorySamples Formula Min(MeasureRAMHistorySamples+1,(220-2*6))',
        '!ShowMeter MeterRAMHistoryUncollected',
    }
    check(#state.bangs == #expected, 'IdleLeave bang count ' .. #state.bangs)
    for index, bang in ipairs(expected) do check(state.bangs[index] == bang, 'IdleLeave bang ' .. index .. ': ' .. tostring(state.bangs[index])) end
    -- History hidden: the cover stays hidden.
    local hiddenHistory = {}
    for key, value in pairs(base) do hiddenHistory[key] = value end
    hiddenHistory.RAMShowHistory = '0'
    local quiet = fixture(hiddenHistory, { ['MeasureRAMHistorySamples:Formula'] = 'Min(MeasureRAMHistorySamples+1,208)' })
    quiet.env.Update()
    quiet.bangs = {}
    quiet.env.IdleLeave()
    check(quiet.bangs[#quiet.bangs] == '!HideMeter MeterRAMHistoryUncollected', 'Hidden history keeps the cover hidden')
    return 'PASS: ' .. passed .. ' Display.lua idle assertions; ' .. _VERSION
end

return Suite
