-- Event-only hidden provider control for the standalone queue panel.
-- Interactive sign-in remains a deliberate visible console/browser flow.
local control = 'MeasureQueueProviderControl'
local launched = false
local actions = {
    Start = { command = 'Start', poll = true },
    Stop = { command = 'Stop' },
    Disconnect = { command = 'Disconnect' },
    ResumeQuota = { command = 'Start', quota = true }
}

local function interval()
    local raw = SKIN:GetVariable('QueuePollSeconds', '30')
    local value = type(raw) == 'string' and raw:match('^%d+$') and tonumber(raw) or nil
    if not value or value < 30 or value > 150 then return 30 end
    return math.floor(value)
end

function Initialize() launched = false end
function Update() return 0 end

function Run(action)
    local spec = actions[action]
    local measure = spec and SKIN:GetMeasure(control) or nil
    if not measure then return false end
    -- Refresh RunCommand's cached state. Do not stack another transient host
    -- while a previous control request is still exiting.
    SKIN:Bang('!UpdateMeasure', control)
    if launched and measure:GetValue() == 0 then return false end
    launched = false
    local arguments = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "QueueProvider.ps1" -Command "'
        .. spec.command .. '"'
    if spec.poll then arguments = arguments .. ' -PollSeconds "' .. interval() .. '"' end
    if spec.quota then arguments = arguments .. ' -ResumeAfterQuota' end
    arguments = arguments .. ' -Quiet'
    SKIN:Bang('!SetOption', control, 'Parameter', arguments)
    SKIN:Bang('!UpdateMeasure', control)
    SKIN:Bang('!CommandMeasure', control, 'Run')
    launched = true
    return true
end
