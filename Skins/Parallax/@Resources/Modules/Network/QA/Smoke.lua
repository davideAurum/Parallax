-- Test-only harness appended to a temporary copy of the actual Network entrypoint.
local ticks = 0
local probeError
local probes = {
    { 'Width1', 'Width', '1x' }, { 'Width2', 'Width', '2x' },
    { 'UnitsBytes', 'Units', 'bytes' }, { 'TitleNetwork', 'Title', 'Network' },
    { 'HeaderIn', 'InLabel', 'IN' }, { 'HeaderOut', 'OutLabel', 'OUT' },
    { 'BodyAdapter', 'Adapter', 'Ethernet' }, { 'BodyStatus', 'Status', 'Selected NIC not found' },
    { 'BodyRate', 'InRate', '1023.9 Gbit/s' }, { 'BodyCeiling', 'InCeiling', 'Set positive graph ceiling' },
    { 'BodyFooter', 'Footer', '60/60 samples / incl. LAN' }
}
local fontOptions = { FontFace = 'Arial', FontSize = '10', FontWeight = '400',
    StringStyle = 'Normal', StringCase = 'None', CharacterSpacing = '0' }

local function prepareGlyphs()
    for _, spec in ipairs(probes) do
        local target = assert(SKIN:GetMeter('MeterNetwork' .. spec[2]))
        for key, default in pairs(fontOptions) do
            SKIN:Bang('!SetOption', 'MeterGlyph' .. spec[1], key, target:GetOption(key, default))
        end
    end
end

local function textBox(meter)
    local padding = {}
    for token in meter:GetOption('Padding', '0,0,0,0'):gmatch('[^,]+') do
        local n = assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(token) .. ')'), 'Padding formula invalid')
        -- Installed Rainmeter parses each padding component as an integer before summing.
        padding[#padding + 1] = n < 0 and math.ceil(n) or math.floor(n)
    end
    assert(#padding == 4, 'Expected four padding values')
    return meter:GetW() - padding[1] - padding[3], meter:GetH() - padding[2] - padding[4]
end

local function measureGlyphs()
    assert(not probeError, probeError)
    local measurements, failures = {}, {}
    for _, spec in ipairs(probes) do
        local target = assert(SKIN:GetMeter('MeterNetwork' .. spec[2]))
        local probe = assert(SKIN:GetMeter('MeterGlyph' .. spec[1]))
        for key, default in pairs(fontOptions) do
            assert(probe:GetOption(key, default) == target:GetOption(key, default), spec[1] .. ' font mismatch: ' .. key)
        end
        assert(probe:GetOption('W', '') == '' and probe:GetOption('H', '') == '', 'Glyph probe must have intrinsic dimensions')
        assert(probe:GetOption('ClipString') == '0', 'Glyph probe must not clip')
        -- Native GetW/GetH return zero while Hidden=1. Briefly show the transparent probe
        -- in this AlphaValue=0 test skin, read its already computed size, and hide before redraw.
        probe:Show()
        local width, height = probe:GetW(), probe:GetH()
        probe:Hide()
        local availableW, availableH = textBox(target)
        local detail = string.format('%s=%dx%d/%dx%d', spec[3], width, height, availableW, availableH)
        measurements[#measurements + 1] = detail
        if width <= 0 or height <= 0 or width > availableW or height > availableH then
            failures[#failures + 1] = detail
        end
    end
    assert(#failures == 0, 'Native glyph fit failed (intrinsic/textbox): ' .. table.concat(failures, ', '))
    return table.concat(measurements, ', ')
end

local function run()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local columns = tonumber(SKIN:GetVariable('Columns'))
    local columnWidth = tonumber(SKIN:GetVariable('ColumnWidth'))
    local panelHeight = tonumber(SKIN:GetVariable('PanelHeight'))
    local gutter = tonumber(SKIN:GetVariable('Gutter'))
    assert(columnWidth == SELF:GetNumberOption('ExpectedColumnWidth'), 'Fixture ColumnWidth override did not apply')
    assert(scale == SELF:GetNumberOption('ExpectedScale'), 'Fixture Scale override did not apply')
    assert(columns == SELF:GetNumberOption('ExpectedColumns'), 'Fixture Columns override did not apply')
    local gap = 2 * math.floor(gutter * scale / 2 + 0.5)
    local expectedW = columns * (math.floor(columnWidth * scale + 0.5) + gap)
    local expectedH = math.floor(panelHeight * scale + 0.5) + gap
    assert(SKIN:GetW() == expectedW, 'Unexpected skin width: ' .. SKIN:GetW())
    assert(SKIN:GetH() == expectedH, 'Unexpected skin height: ' .. SKIN:GetH())
    local glyphs = measureGlyphs()
    local function meter(suffix) return assert(SKIN:GetMeter('MeterNetwork' .. suffix)) end
    local function role(suffix, size, color)
        local actualSize = SKIN:ParseFormula(SKIN:ReplaceVariables(meter(suffix):GetOption('FontSize')))
        assert(math.abs(actualSize - tonumber(SKIN:GetVariable(size)) * scale) < 0.001,
            suffix .. ' does not follow ' .. size)
        if color then assert(meter(suffix):GetOption('FontColor') == SKIN:GetVariable(color), suffix .. ' does not follow ' .. color) end
    end
    role('Title', 'TitleFontSize', 'TitleTextColor')
    role('InLabel', 'HeaderFontSize', 'HeaderTextColor'); role('OutLabel', 'HeaderFontSize', 'HeaderTextColor')
    for _, suffix in ipairs({'Adapter', 'Status', 'InRate', 'OutRate', 'InCeiling', 'OutCeiling', 'Footer', 'Units', 'Width'}) do
        role(suffix, 'FontSize')
    end
    role('Units', 'FontSize', 'AccentColor'); role('Width', 'FontSize', 'AccentColor2')
    role('InRate', 'FontSize', 'NetworkInColor'); role('OutRate', 'FontSize', 'NetworkOutColor')
    for _, suffix in ipairs({'Adapter', 'InCeiling', 'OutCeiling', 'Footer'}) do role(suffix, 'FontSize', 'TextColor') end
    local panelStroke = assert(meter('Panel'):GetOption('Shape'):match('StrokeWidth%s+(.+)$'), 'Panel stroke missing')
    assert(math.abs(SKIN:ParseFormula(SKIN:ReplaceVariables(panelStroke)) - tonumber(SKIN:GetVariable('BorderThickness')) * scale) < 0.001,
        'Panel does not inherit selected border thickness')
    local innerBottom = gap / 2 + math.floor(panelHeight * scale + 0.5)
        - tonumber(SKIN:GetVariable('BorderThickness')) * scale
    assert(meter('Footer'):GetY(true) + meter('Footer'):GetH() <= innerBottom, 'Footer overlaps inside panel border')
    assert(meter('Title'):GetX(true) + meter('Title'):GetW() <= meter('Units'):GetX(true), 'Title overlaps units')
    assert(meter('Units'):GetX(true) + meter('Units'):GetW() <= meter('Width'):GetX(true), 'Units overlap width')
    for _, pair in ipairs({{'Title','Adapter'}, {'Units','Adapter'}, {'Width','Adapter'}, {'Adapter','Status'},
        {'Status','InLabel'}, {'InLabel','InCeiling'}, {'InRate','InCeiling'}, {'InCeiling','InGrid'},
        {'InGrid','OutLabel'}, {'OutLabel','OutCeiling'}, {'OutRate','OutCeiling'}, {'OutCeiling','OutGrid'}, {'OutGrid','Footer'}}) do
        assert(meter(pair[1]):GetY(true) + meter(pair[1]):GetH() <= meter(pair[2]):GetY(true),
            pair[1] .. ' overlaps next row ' .. pair[2])
    end
    for _, suffix in ipairs({'Bounds', 'Panel', 'Icon', 'Title', 'Units', 'Width', 'Adapter', 'Status',
        'InLabel', 'InRate', 'InCeiling', 'InGrid', 'InGraph', 'OutLabel', 'OutRate', 'OutCeiling', 'OutGrid', 'OutGraph', 'Footer'}) do
        local meter = assert(SKIN:GetMeter('MeterNetwork' .. suffix), suffix .. ' missing')
        local x, y, w, h = meter:GetX(true), meter:GetY(true), meter:GetW(), meter:GetH()
        -- GetX(true) resolves relative placement but preserves a String meter's anchor.
        if meter:GetOption('StringAlign'):lower() == 'right' then x = x - w end
        assert(x >= 0 and y >= 0 and x + w <= expectedW and y + h <= expectedH,
            string.format('%s out of bounds: %.2f %.2f %.2f %.2f', suffix, x, y, w, h))
    end
    local controller = assert(SKIN:GetMeasure('MeasureNetworkController'))
    for _, direction in ipairs({'In', 'Out'}) do
        local graph = assert(SKIN:GetMeter('MeterNetwork' .. direction .. 'Graph'))
        local graphHeight = controller:GetNumberOption('GraphHeight')
        assert(math.abs(graph:GetH() - graphHeight) < 1, direction .. ' graph height differs from controller')
        assert(math.abs(graph:GetW() - controller:GetNumberOption('GraphWidth')) < 1,
            direction .. ' graph width differs from controller')
        for xs, ys in graph:GetOption('History'):gmatch('([%d%.]+),([%d%.]+)') do
            local x, y = tonumber(xs), tonumber(ys)
            assert(x >= 0 and y >= 0 and x <= graph:GetW() and y <= graph:GetH(),
                direction .. ' live history path escapes graph')
        end
    end
    for _, suffix in ipairs({'Alias', 'Description', 'Guid', 'Status', 'State', 'In', 'Out'}) do
        local measure = assert(SKIN:GetMeasure('MeasureNetwork' .. suffix))
        assert(measure:GetNumberOption('UpdateDivider') == 1, suffix .. ' slowed')
        assert(measure:GetNumberOption('DynamicVariables') == 1, suffix .. ' cannot reselect')
    end
    local selector = SKIN:GetVariable('NetworkInterface')
    if selector ~= 'Best' then
        assert(controller:GetValue() == 0, 'Invalid selector accepted')
        assert(SKIN:GetMeter('MeterNetworkInRate'):GetOption('Text') == '--', 'Invalid IN displayed')
        assert(SKIN:GetMeter('MeterNetworkOutRate'):GetOption('Text') == '--', 'Invalid OUT displayed')
        assert(SKIN:GetMeter('MeterNetworkFooter'):GetOption('Text'):match('^0/60'), 'Invalid history exists')
    else
        local state = SKIN:GetMeter('MeterNetworkStatus'):GetOption('Text')
        assert(state ~= 'Waiting for native measures', 'Controller did not update')
        if controller:GetValue() == 1 then
            assert(SKIN:GetMeter('MeterNetworkInRate'):GetOption('Text') ~= '--', 'Valid IN missing')
            -- A first valid sample after startup/gap has no preceding point to draw.
            local count = tonumber(meter('Footer'):GetOption('Text'):match('^(%d+)/60'))
            assert(count and count >= 1, 'Valid snapshot has no history sample')
            local shape = meter('InGraph'):GetOption('Shape2')
            if count > 1 then assert(shape:match('^Path History'), 'Multiple valid samples did not build history')
            else assert(shape == 'Line 1,1,1,1 | StrokeWidth 0', 'Singleton history fabricated a segment') end
        end
    end
    return string.format('PASS width=%d scale=%g columns=%d panelHeight=%g size=%dx%d selector=%s controller=%g glyphs[%s]',
        columnWidth, scale, columns, panelHeight, expectedW, expectedH, selector, controller:GetValue(), glyphs)
end

function Update()
    ticks = ticks + 1
    if ticks == 1 then
        local ok, err = pcall(prepareGlyphs)
        if not ok then probeError = tostring(err) end
    end
    if ticks ~= 7 then return 0 end
    local ok, result = pcall(run)
    local f = assert(io.open(SELF:GetOption('ResultFile'), 'wb'))
    f:write(ok and result or ('FAIL ' .. tostring(result)))
    f:close()
    return ok and 1 or -1
end
