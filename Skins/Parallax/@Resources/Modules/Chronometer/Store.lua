-- Two alternating snapshots keep the last completed save if the next write fails.
local Store = {}

local function read(path, decode)
    local file = io.open(path, 'rb')
    if not file then return nil, false end
    local contents = file:read(8193)
    file:close()
    return decode(contents), true
end

function Store.open(prefix, core)
    local a, hadA = read(prefix .. '.a.state', core.decode)
    local b, hadB = read(prefix .. '.b.state', core.decode)
    local slot, state
    if a and (not b or a.generation >= b.generation) then slot, state = 'a', a
    elseif b then slot, state = 'b', b end
    return { prefix = prefix, core = core, slot = slot, generation = state and state.generation or 0 },
        state, (hadA and not a) or (hadB and not b)
end

function Store.save(store, state)
    local slot = store.slot == 'a' and 'b' or 'a'
    local generation = store.generation + 1
    local text = store.core.encode(state, generation)
    local file = io.open(store.prefix .. '.' .. slot .. '.state', 'wb')
    if not file then return false end
    local written = file:write(text)
    local closed = file:close()
    if not written or not closed then return false end
    -- Verify the closed snapshot before it becomes the newest in-memory generation.
    local verified = read(store.prefix .. '.' .. slot .. '.state', store.core.decode)
    if not verified or verified.generation ~= generation then return false end
    store.slot, store.generation, state.generation = slot, generation, generation
    return true
end

return Store
