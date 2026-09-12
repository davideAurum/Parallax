-- One report per actual loaded skin. Capturing is performed outside Lua against
-- this isolated process's window handles; no fake telemetry or screenshot drawing.
local reported = false
function Initialize() end
function Update()
    if reported then return 0 end
    local path = SELF:GetOption('ReportPath', '')
    if path == '' then return 0 end
    local boundsName = 'MeterBounds'
    local bounds = SKIN:GetMeter(boundsName)
    if not bounds then
        boundsName = 'MeterIOBounds'
        bounds = SKIN:GetMeter(boundsName)
    end
    local file = io.open(path, 'wb')
    if file then
        file:write('Config=', SKIN:GetVariable('CURRENTCONFIG'), '\n')
        file:write('File=', SKIN:GetVariable('CURRENTFILE'), '\n')
        file:write('Lua=', _VERSION, '\n')
        file:write('Columns=', SKIN:GetVariable('Columns'), '\n')
        file:write('ColumnWidth=', SKIN:GetVariable('ColumnWidth'), '\n')
        file:write('Scale=', SKIN:GetVariable('Scale'), '\n')
        file:write('FontFace=', SKIN:GetVariable('FontFace'), '\n')
        if bounds then
            file:write('BoundsMeter=', boundsName, '\n')
            file:write('Bounds=', bounds:GetW(), 'x', bounds:GetH(), '\n')
        else
            file:write('BoundsMeter=not found; see captured native window dimensions\n')
        end
        file:write('DeclaredWindowWidth=', SKIN:GetVariable('WindowWidth'), '\n')
        file:write('DeclaredWindowHeight=', SKIN:GetVariable('WindowHeight'), '\n')
        file:write('Actual module measures are running; report is not a performance or visual-quality assertion.\n')
        file:close()
        reported = true
    end
    return 0
end
