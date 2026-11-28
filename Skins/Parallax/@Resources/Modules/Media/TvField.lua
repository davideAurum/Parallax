-- One field of Media's player card for a meter (TvCard.inc). MeasureTvCard
-- (Queue\QueueReader.lua with TvCard=1) packs the fields, joined by character
-- 31, in the order of QueueReader.CARD_FIELDS; this returns the one named by its
-- Field option, so the TV's title and channel reach their meters as measure
-- values, never through a bang. No file I/O, bangs, timers or network.
local FIELDS = { screen = 1, play = 2, title = 3, channel = 4, cover = 5, timing = 6, progress = 7 }
local NUMERIC = { progress = true }
local card, index, numeric

function Initialize()
    local name = SELF:GetOption('Field', '')
    index, numeric = FIELDS[name], NUMERIC[name] == true
    card = SKIN:GetMeasure('MeasureTvCard')
end

function Update()
    local value = ''
    if card and index then
        local packed = card:GetStringValue()
        if type(packed) == 'string' then
            local at = 1
            for _ = 1, index - 1 do
                local stop = packed:find('\031', at, true)
                if not stop then at = nil break end
                at = stop + 1
            end
            if at then value = packed:sub(at, (packed:find('\031', at, true) or #packed + 1) - 1) end
        end
    end
    if numeric then
        local number = tonumber(value)
        if not number or number ~= number or number < 0 then return 0 end
        return math.min(number, 100)
    end
    return value
end
