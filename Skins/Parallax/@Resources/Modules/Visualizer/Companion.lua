-- One capture at a time (docs/PERFORMANCE-REVIEW.md XMOD-02). Media's open
-- spectrum drawer and this standalone Audio Visualizer would otherwise each
-- run an AudioLevel capture of the same output. Media's drawer defers to this
-- skin while it is loaded ("Spectrum is shown in Audio Visualizer") and takes
-- the capture back when it unloads. This script only tells Media to re-check:
--   Announce()  100 ms after each load (OnRefreshAction, [!Delay 100]);
--   Closing()   from OnCloseAction, and only after a real unload: Rainmeter
--               has already recorded Active=0 for this config then; at
--               Rainmeter exit or a game-mode unload it has not, and nothing
--               is sent.
-- Both send, only while Rainmeter.ini shows Parallax\Media running Media.ini:
--   !SetVariableGroup ParallaxCompanionCheck 1 Parallax
--   !UpdateMeasureGroup ParallaxMediaCompanion *
-- Both are silent when Media's drawer is not open (no measure in that group).
-- Media decides from Rainmeter.ini itself. No polling, process or file write;
-- the bounded settings reader is the shared @Resources\Idle\Link.lua.

local Link

function Initialize()
    Link = nil
    local path = SKIN:GetVariable('@') .. 'Idle\\Link.lua'
    -- Rainmeter's dofile logs an error for a missing file, so look first.
    local file = io.open(path, 'rb')
    if not file then return end
    file:close()
    local ok, module = pcall(dofile, path)
    if ok and type(module) == 'table' and type(module.activeOf) == 'function' then Link = module end
end

function Update() return 0 end

local function settingsFile()
    return (SKIN:GetVariable('SETTINGSPATH', '') or '') .. 'Rainmeter.ini'
end

local function notify()
    if not Link then return false end
    local media = Link.activeOf(settingsFile(), SKIN:GetVariable('ROOTCONFIG', 'Parallax') .. '\\Media')
    if media ~= 1 then return false end
    SKIN:Bang('!SetVariableGroup', 'ParallaxCompanionCheck', '1', 'Parallax')
    SKIN:Bang('!UpdateMeasureGroup', 'ParallaxMediaCompanion', '*')
    return true
end

function Announce()
    return notify()
end

function Closing()
    if not Link then return false end
    if Link.activeOf(settingsFile(), SKIN:GetVariable('CURRENTCONFIG', '')) ~= 0 then return false end
    return notify()
end
