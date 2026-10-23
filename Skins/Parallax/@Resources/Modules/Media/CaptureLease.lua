-- Media spectrum drawer capture lease (docs/PERFORMANCE-REVIEW.md T2, VIS-01).
-- The drawer's capture state lives in Modules\Media\CaptureState.inc and
-- MediaOptions.ApplyLease is its only writer. This stub carries only the
-- explicit resume a click on the paused plot asks for; the automatic park and
-- resume follow in the next change.

local function loaded()
    return SKIN:GetVariable('MediaDrawerCapture', '0')
end

function Initialize() end

function Update()
    return tonumber(loaded()) or 0
end

-- The paused plot's click target: back to live capture with one reload.
function Unpark(reason)
    if loaded() ~= '1' then return false end
    SKIN:Bang('!CommandMeasure', 'MeasureMediaOptions', "ApplyLease(0, nil, 'unpark')")
    return true
end
