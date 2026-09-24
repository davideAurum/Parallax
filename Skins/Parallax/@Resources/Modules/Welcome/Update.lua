-- Parallax Welcome: on-demand update check.
-- Nothing runs until the user clicks Check for updates. One WebParser request reads
-- the release feed; nothing is scheduled or polled. Install starts one hidden,
-- one-shot helper that downloads and verifies the package and then hands it to
-- Rainmeter's own Skin Installer, which asks the user to confirm.

local installed, releaseBase
local state = 'idle' -- idle | checking | current | available | downloading | handed
local offer

local function safeUrl(url)
    return type(url) == 'string' and #url <= 300 and url:match('^[%w%./:_%-]+$') ~= nil
        and releaseBase ~= '' and url:sub(1, #releaseBase) == releaseBase
end

local function validVersion(v)
    return type(v) == 'string' and #v <= 64 and v:match('^[%w][%w%._%-]*$') ~= nil
end

-- Semantic-version order: numeric core, then a release sorts after any pre-release of
-- the same core, then dot-separated pre-release identifiers. The character set is the
-- one Package-Parallax.ps1 accepts, so build metadata (+...) never occurs.
local function parseVersion(v)
    if not validVersion(v) then return nil end
    local major, minor, patch, rest = v:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
    if not major then return nil end
    local pre = {}
    if rest ~= '' then
        if rest:sub(1, 1) ~= '-' or #rest < 2 then return nil end
        for id in rest:sub(2):gmatch('[^%.]+') do pre[#pre + 1] = id end
    end
    return { tonumber(major), tonumber(minor), tonumber(patch), pre = pre }
end

function CompareVersions(a, b)
    local x, y = parseVersion(a), parseVersion(b)
    if not x or not y then return nil end
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] < y[i] and -1 or 1 end
    end
    if #x.pre == 0 or #y.pre == 0 then
        if #x.pre == #y.pre then return 0 end
        return #x.pre == 0 and 1 or -1
    end
    for i = 1, math.max(#x.pre, #y.pre) do
        local p, q = x.pre[i], y.pre[i]
        if p == nil then return -1 end
        if q == nil then return 1 end
        if p ~= q then
            local pn, qn = tonumber(p), tonumber(q)
            if pn and qn then return pn < qn and -1 or 1 end
            if pn then return -1 end
            if qn then return 1 end
            return p < q and -1 or 1
        end
    end
    return 0
end

-- The status line is short enough to sit beside Install and Notes; the tooltip
-- carries the full explanation, including helper errors that may be long.
local function show(text, isError, tip)
    local showOffer = state == 'available'
    SKIN:Bang('!SetOption', 'MeterUpdateStatus', 'Text', text)
    SKIN:Bang('!SetOption', 'MeterUpdateStatus', 'ToolTipText', tip or text)
    SKIN:Bang('!SetOption', 'MeterUpdateStatus', 'FontColor', SKIN:GetVariable(isError and 'DangerColor' or 'MutedColor'))
    SKIN:Bang(showOffer and '!ShowMeter' or '!HideMeter', 'MeterUpdateInstall')
    SKIN:Bang((showOffer and offer and offer.notes) and '!ShowMeter' or '!HideMeter', 'MeterUpdateNotes')
    SKIN:Bang('!SetOption', 'MeterCheckUpdates', 'Text',
        (state == 'checking' or state == 'downloading') and 'Working...' or 'Check for updates')
    SKIN:Bang('!UpdateMeterGroup', 'WelcomeUpdate')
    SKIN:Bang('!Redraw')
end

function Initialize()
    installed = SKIN:GetVariable('ParallaxVersion', '')
    releaseBase = SKIN:GetVariable('UpdateReleaseBase', '')
    state, offer = 'idle', nil
end

function Update()
    return 0
end

function Check()
    if state == 'checking' or state == 'downloading' then return false end
    state, offer = 'checking', nil
    SKIN:Bang('!EnableMeasure', 'MeasureUpdateFeed')
    SKIN:Bang('!CommandMeasure', 'MeasureUpdateFeed', 'Update')
    show('Checking for updates...', false)
    return true
end

local function field(text, name)
    return text:match('"' .. name .. '"%s*:%s*"([^"\\]*)"')
end

-- Reads the manifest Package-Parallax.ps1 writes beside each release package.
-- Returns an offer table or nil and a reason; remote text is only ever data.
function ParseFeed(text)
    if type(text) ~= 'string' or text == '' then return nil, 'The update feed returned nothing.' end
    if #text > 8192 then return nil, 'The update feed is larger than expected.' end
    if tonumber(text:match('"schema"%s*:%s*(%d+)')) ~= 1 then
        return nil, 'No Parallax release information was found at the update address.'
    end
    local item = {
        name = field(text, 'name'), version = field(text, 'version'),
        url = field(text, 'url'), sha256 = field(text, 'sha256'), notes = field(text, 'notes')
    }
    if item.name ~= 'Parallax' then return nil, 'The update feed describes a different package.' end
    if not parseVersion(item.version) then return nil, 'The update feed lists an unreadable version.' end
    if type(item.sha256) ~= 'string' or not item.sha256:match('^' .. string.rep('%x', 64) .. '$') then
        return nil, 'The update feed has no valid checksum.'
    end
    local expected = releaseBase .. 'download/v' .. item.version .. '/Parallax_' .. item.version .. '.rmskin'
    if item.url ~= expected or not safeUrl(item.url) then
        return nil, 'The update feed points outside the Parallax releases.'
    end
    if item.notes ~= nil and not safeUrl(item.notes) then item.notes = nil end
    return item
end

function FeedReady()
    if state ~= 'checking' then return false end
    local measure = SKIN:GetMeasure('MeasureUpdateFeed')
    local text = measure and measure:GetStringValue() or ''
    SKIN:Bang('!DisableMeasure', 'MeasureUpdateFeed')
    local item, reason = ParseFeed(text)
    if not item then
        state = 'idle'
        show('Update check failed.', true, reason)
        return false
    end
    local order = CompareVersions(installed, item.version)
    if order == nil then
        state = 'idle'
        show('Update check failed.', true, 'The installed version (' .. installed .. ') cannot be compared with ' .. item.version .. '.')
    elseif order < 0 then
        state, offer = 'available', item
        show('Parallax ' .. item.version .. ' is available.', false,
            'You have ' .. installed .. '. Install downloads ' .. item.version .. ', verifies it and opens Rainmeter\'s Skin Installer.')
    elseif order == 0 then
        state = 'current'
        show('Parallax ' .. installed .. ' is up to date.', false)
    else
        state = 'current'
        show('Parallax ' .. installed .. ' is up to date.', false,
            'The installed ' .. installed .. ' is newer than the latest release, ' .. item.version .. '.')
    end
    return true
end

function FeedError(kind)
    if state ~= 'checking' then return false end
    SKIN:Bang('!DisableMeasure', 'MeasureUpdateFeed')
    state = 'idle'
    if kind == 'connect' then
        show('Could not reach the update server.', true, 'Check the connection and try again. Nothing was downloaded.')
    else
        show('Update check failed.', true, 'No Parallax release information was found at the update address.')
    end
    return false
end

function Install()
    if state ~= 'available' or not offer then return false end
    local root = SKIN:GetVariable('@', '')
    local program = (SKIN:GetVariable('PROGRAMPATH', '')):gsub('\\+$', '')
    if root:find('"', 1, true) or program:find('"', 1, true) then return false end
    -- Only the validated URL, version, checksum and fixed paths enter this command.
    -- The helper validates them again and reports back through stdout as data.
    local args = string.format('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%sScripts\\UpdateInstall.ps1" -Url "%s" -Sha256 %s -Version %s -ReleaseBase "%s" -ProgramPath "%s"',
        root, offer.url, offer.sha256, offer.version, releaseBase, program)
    state = 'downloading'
    SKIN:Bang('!SetOption', 'MeasureUpdateInstall', 'Parameter', args)
    SKIN:Bang('!UpdateMeasure', 'MeasureUpdateInstall')
    SKIN:Bang('!CommandMeasure', 'MeasureUpdateInstall', 'Run')
    show('Downloading ' .. offer.version .. '...', false)
    return true
end

function InstallDone()
    if state ~= 'downloading' then return false end
    local measure = SKIN:GetMeasure('MeasureUpdateInstall')
    local output = (measure and measure:GetStringValue() or ''):gsub('[\r\n]+$', '')
    local result, detail = output:match('PARALLAX_UPDATE_V1|(%a+)|([^\r\n]*)')
    if result == 'ok' then
        state = 'handed'
        show('Confirm in Skin Installer to finish.', false,
            'The verified ' .. offer.version .. ' package is open in Rainmeter\'s Skin Installer. Nothing changes until you choose Install there; your settings are kept.')
        return true
    end
    state = 'available'
    show('Download failed. Nothing was installed.', true,
        detail ~= nil and detail ~= '' and detail or 'The download did not finish. Try again.')
    return false
end

function OpenNotes()
    if not offer or not offer.notes or not safeUrl(offer.notes) then return false end
    SKIN:Bang('["' .. offer.notes .. '"]')
    return true
end
