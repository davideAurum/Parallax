-- Original Parallax cover preview: shows three still frames of the playing
-- YouTube video in turn, each fading into the next. WebParser measures do the
-- downloading; this script names the video, chooses the frame and fades it in.
local FRAMES = 3
-- Seconds each picture holds, and of that, how long it takes to come in.
local HOLD, FADE = 0.6, 0.25
local video, ready, turn, shown, changed, alpha

local function text(name)
    local measure = SKIN:GetMeasure(name)
    return measure and measure:GetStringValue() or ''
end

local function number(name)
    local measure = SKIN:GetMeasure(name)
    return measure and measure:GetValue() or 0
end

-- The id in a YouTube thumbnail address, or nil for anything else.
function VideoId(address)
    local id = (address or ''):match('^https://i%d?%.ytimg%.com/vi[_%a]*/([%w_%-]+)/')
    if id and #id == 11 then return id end
    return nil
end

local function playing()
    if number('MeasureConnection') ~= 1 or text('MeasurePlayer') ~= 'YouTube' then return nil, false end
    return VideoId(text('MeasureCoverAddress')), number('MeasureState') == 1
end

local function option(meter, name, value)
    SKIN:Bang('!SetOption', meter, name, value)
end

local function redraw()
    SKIN:Bang('!UpdateMeter', 'MeterCoverPreview')
    SKIN:Bang('!UpdateMeter', 'MeterCoverPreviewNext')
    SKIN:Bang('!Redraw')
end

local function hide()
    if not shown then return end
    shown, alpha = nil, nil
    SKIN:Bang('!HideMeter', 'MeterCoverPreview')
    SKIN:Bang('!HideMeter', 'MeterCoverPreviewNext')
    redraw()
end

-- Brings `frame` in over the picture now showing, or over the still cover.
local function change(frame, now)
    if shown then
        option('MeterCoverPreview', 'ImageName', text('MeasurePreviewFrame' .. shown))
        SKIN:Bang('!ShowMeter', 'MeterCoverPreview')
    end
    shown, changed, alpha = frame, now, nil
    option('MeterCoverPreviewNext', 'ImageName', text('MeasurePreviewFrame' .. frame))
    SKIN:Bang('!ShowMeter', 'MeterCoverPreviewNext')
end

-- A skin ticking slower than this cannot fade: the picture just changes.
local function canFade()
    local interval = tonumber(SKIN:ParseFormula(SKIN:ReplaceVariables('#MediaTickInterval#')))
    return interval ~= nil and interval <= 100
end

local function fade(now)
    local part = canFade() and math.min(1, (now - changed) / FADE) or 1
    local level = math.floor(255 * part + 0.5)
    if level == alpha then return end
    alpha = level
    option('MeterCoverPreviewNext', 'ImageAlpha', tostring(level))
    redraw()
end

local function request(id)
    video, ready, turn = id, {}, 0
    hide()
    for frame = 1, FRAMES do
        local measure = 'MeasurePreviewFrame' .. frame
        if id then
            SKIN:Bang('!SetOption', measure, 'URL', 'https://i.ytimg.com/vi/' .. id .. '/mq' .. frame .. '.jpg')
            SKIN:Bang('!EnableMeasure', measure)
            SKIN:Bang('!UpdateMeasure', measure)
            SKIN:Bang('!CommandMeasure', measure, 'Update')
        else
            SKIN:Bang('!DisableMeasure', measure)
        end
    end
end

-- A download finished (each measure's FinishAction).
function Ready(frame)
    if video then ready[frame] = true end
end

function Initialize()
    video, ready, turn, shown, changed, alpha = nil, {}, 0, nil, 0, nil
end

function Update()
    local id, moving = playing()
    if id ~= video then request(id) end
    if not video or not moving then
        hide()
        return 'still'
    end
    local available = {}
    for frame = 1, FRAMES do
        if ready[frame] then available[#available + 1] = frame end
    end
    if #available == 0 then
        hide()
        return 'waiting'
    end
    local now = os.clock()
    if not shown or now - changed >= HOLD then
        turn = turn % #available + 1
        -- A lone frame stays as it is rather than fading into itself.
        if available[turn] ~= shown then change(available[turn], now) end
    end
    fade(now)
    return 'frame ' .. shown
end
