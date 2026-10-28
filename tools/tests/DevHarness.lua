-- Test-only driver for tools\tests\Test-DevModeNative.ps1. Lives in an isolated Rainmeter instance
-- beside the skins under test: twice a second it reads a trigger file, empties it, and runs each line
-- as one bang. The test script writes `!CommandMeasure ...` lines there instead of sending bangs from
-- the command line, which would reach whichever Rainmeter answers. Never ships.
local path

function Initialize()
    path = SKIN:GetVariable('TriggerFile', '')
end

function Update()
    if path == '' then return 0 end
    local file = io.open(path, 'rb')
    if not file then return 0 end
    local text = file:read('*a')
    file:close()
    if text == '' then return 0 end
    local clear = io.open(path, 'wb')
    if clear then clear:close() end
    for line in text:gmatch('[^\r\n]+') do SKIN:Bang(line) end
    return 0
end
