-- Appended only to an isolated copy of the real Connection entrypoint.
-- Tests real native dimensions and effective settings without requiring live Wi-Fi.
local ticks, probeError = 0
local probes = {}
local fontOptions = {FontFace='Arial', FontSize='10', FontWeight='400',
    StringStyle='Normal', StringCase='None', CharacterSpacing='0'}

local function meter(suffix)
    return assert(SKIN:GetMeter('MeterConnection' .. suffix), suffix .. ' meter missing')
end

local function numberOption(target, key)
    return assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(target:GetOption(key)) .. ')'), 'Invalid numeric option: ' .. key)
end

local function numberVariable(key)
    return assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(SKIN:GetVariable(key)) .. ')'), 'Invalid variable: ' .. key)
end

local function prepareGlyphs()
    for index = 1, SELF:GetNumberOption('GlyphCount') do
        probes[#probes + 1] = {tostring(index), SELF:GetOption('GlyphTarget' .. index),
            SELF:GetNumberOption('GlyphWidth' .. index) == 1, SELF:GetNumberOption('GlyphLive' .. index) == 1}
    end
    for _, spec in ipairs(probes) do
        local target = meter(spec[2])
        for key, default in pairs(fontOptions) do
            local desired = target:GetOption(key, default)
            if meter('Glyph' .. spec[1]):GetOption(key, default) ~= desired then
                SKIN:Bang('!SetOption', 'MeterConnectionGlyph' .. spec[1], key, desired)
            end
        end
    end
end

local function textBox(target)
    local padding = {}
    for token in target:GetOption('Padding', '0,0,0,0'):gmatch('[^,]+') do
        local n = assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(token) .. ')'), 'Invalid padding formula')
        padding[#padding + 1] = n < 0 and math.ceil(n) or math.floor(n)
    end
    assert(#padding == 4, 'Expected four padding values')
    return target:GetW() - padding[1] - padding[3], target:GetH() - padding[2] - padding[4]
end

local function glyphChecks()
    assert(not probeError, probeError)
    local measurements, failures = {}, {}
    for _, spec in ipairs(probes) do
        local target, probe = meter(spec[2]), meter('Glyph' .. spec[1])
        for key, default in pairs(fontOptions) do
            assert(probe:GetOption(key, default) == target:GetOption(key, default), spec[1] .. ' font mismatch: ' .. key)
        end
        assert(probe:GetOption('W', '') == '' and probe:GetOption('H', '') == '', 'Probe must measure intrinsic text size')
        assert(probe:GetOption('ClipString') == '0', 'Probe must not clip')
        -- Hidden meters report zero bounds; briefly show transparent probes for native size.
        probe:Show()
        local w, h = probe:GetW(), probe:GetH()
        probe:Hide()
        local aw, ah = textBox(target)
        local detail = string.format('%s:%s=%dx%d/%dx%d%s', spec[2], probe:GetOption('Text'), w, h, aw, ah,
            spec[3] and '' or ' (width may clip)')
        if not (w > 0 and h > 0 and (not spec[3] or w <= aw) and h <= ah) then failures[#failures + 1] = detail end
        measurements[#measurements + 1] = detail
    end
    assert(#failures == 0, 'Native glyph fit failed: ' .. table.concat(failures, ', '))
    return string.format('%d probes; %s; %s; %s', #measurements, measurements[1], measurements[2], measurements[3])
end

local function boundsCheck(suffix, expectedW, expectedH)
    local target = meter(suffix)
    -- false returns the actual top-left, including centered/right anchor adjustment.
    local x, y, w, h = target:GetX(false), target:GetY(false), target:GetW(), target:GetH()
    assert(x >= 0 and y >= 0 and x + w <= expectedW and y + h <= expectedH,
        string.format('%s outside skin: %.2f %.2f %.2f %.2f', suffix, x, y, w, h))
end

local function headerChecks(scale, titleSize)
    local title, width, icon, adapter = meter('Title'), meter('Width'), meter('Icon'), meter('Adapter')
    local center, iconScale = numberVariable('TitleRowCenterY'), numberVariable('TitleIconScale')
    local iconSize, gap = numberVariable('TitleIconSize'), numberVariable('TitleIconGap')
    assert(math.abs(iconScale - scale * titleSize / 10) < 0.001, 'Shared icon typography scaling differs')
    assert(math.abs(numberOption(icon, 'W') - iconSize) < 0.001 and math.abs(iconSize - 14 * iconScale) < 0.001,
        'Icon width does not scale with title size')
    assert(math.abs(numberOption(icon, 'H') - 12 * iconScale) < 0.001, 'Icon aspect ratio changed')
    assert(math.abs(icon:GetY(false) + icon:GetH() / 2 - center) <= 1.001,
        string.format('Icon is not centered: top=%g height=%g center=%g', icon:GetY(false), icon:GetH(), center))
    for _, target in ipairs({title, width}) do
        assert(target:GetOption('StringAlign'):lower() == 'leftcenter', 'Header text must use a center anchor')
        assert(math.abs(numberOption(target, 'Y') - center) < 0.001, 'Header control does not use shared row center')
        assert(math.abs(target:GetY(false) + target:GetH() / 2 - center) <= 1, 'Native padded header center differs')
    end
    assert(math.abs(numberOption(title, 'H') - numberVariable('TitleRowHeight')) < 0.001, 'Title bypasses shared row height')
    assert(math.abs(numberOption(title, 'X') - numberVariable('ContentX') - iconSize - gap) < 0.001,
        'Title does not begin after the scaled icon and shared gap')
    assert(title:GetX(false) >= icon:GetX(false) + icon:GetW() + gap - 1, 'Scaled icon collides with title')
    assert(title:GetX(false) + title:GetW() <= width:GetX(false), 'Title overlaps the padded width control')
    assert(math.abs(numberOption(adapter, 'Y') - numberVariable('Inset') - 26 * scale) < 0.001,
        'First Connection content row moved')
    for _, shape in ipairs({
        {'Shape', 'Rectangle', {0,0,5,5}, 0}, {'Shape2', 'Rectangle', {9,7,5,5}, 0},
        {'Shape3', 'Line', {5,2.5,11.5,2.5}, 1}, {'Shape4', 'Line', {11.5,2.5,11.5,7}, 1}
    }) do
        local path = icon:GetOption(shape[1])
        local coordinates = assert(path:match('^' .. shape[2] .. '%s+([^|]+)'), 'Unexpected icon shape type')
        local index = 0
        for coordinate in coordinates:gmatch('[^,]+') do
            index = index + 1
            local actual = assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(coordinate:match('^%s*(.-)%s*$')) .. ')'),
                'Invalid icon coordinate')
            assert(shape[3][index] and math.abs(actual - shape[3][index] * iconScale) < 0.001,
                string.format('%s coordinate %d differs: %g vs %g', shape[1], index, actual, (shape[3][index] or 0) * iconScale))
        end
        assert(index == #shape[3], 'Unexpected icon coordinate count')
        local stroke = assert(path:match('StrokeWidth%s+([^|]+)'), 'Missing icon stroke')
        assert(math.abs(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(stroke:match('^%s*(.-)%s*$')) .. ')') - shape[4] * iconScale) < 0.001,
            shape[1] .. ' stroke does not scale with title')
    end
    local glyphBottom
    for _, spec in ipairs(probes) do
        if spec[2] == 'Title' then
            local probe = meter('Glyph' .. spec[1])
            probe:Show()
            local intrinsicHeight = probe:GetH()
            probe:Hide()
            glyphBottom = title:GetY(true) + math.ceil(intrinsicHeight / 2)
            assert(glyphBottom <= adapter:GetY(false) + 1, 'Centered title glyph overlaps first content row')
        end
    end
    assert(width:GetY(false) + width:GetH() <= adapter:GetY(false) + 1, 'Padded width action overlaps first content row')
    return string.format('center=%.2f icon=%.2fx%.2f glyphBottom=%g bodyTop=%g', center,
        numberOption(icon, 'W'), numberOption(icon, 'H'), glyphBottom, adapter:GetY(false))
end

local function run()
    local scale = tonumber(SKIN:GetVariable('Scale'))
    local columns = tonumber(SKIN:GetVariable('Columns'))
    local columnWidth = tonumber(SKIN:GetVariable('ColumnWidth'))
    local panelHeight = numberVariable('PanelHeight')
    local gutter = tonumber(SKIN:GetVariable('Gutter'))
    assert(columnWidth == SELF:GetNumberOption('ExpectedColumnWidth'), 'ColumnWidth fixture override failed')
    assert(scale == SELF:GetNumberOption('ExpectedScale'), 'Scale fixture override failed')
    assert(columns == SELF:GetNumberOption('ExpectedColumns'), 'Connection column override failed')
    assert(columns == tonumber(SKIN:GetVariable('NetworkConnectionColumns')), 'Connection uses throughput Columns')
    local savedHeight, thickness = numberVariable('NetworkConnectionHeight'), numberVariable('DataBarThickness')
    assert(panelHeight == math.max(savedHeight, 236 + thickness), 'Computed Connection panel height differs from saved minimum/bar clearance')
    local gap = 2 * math.floor(gutter * scale / 2 + 0.5)
    local expectedW = columns * (math.floor(columnWidth * scale + 0.5) + gap)
    local expectedH = math.floor(panelHeight * scale + 0.5) + gap
    assert(SKIN:GetW() == expectedW, 'Unexpected skin width: ' .. SKIN:GetW())
    assert(SKIN:GetH() == expectedH, 'Unexpected skin height: ' .. SKIN:GetH())
    local titleSize, bodySize = tonumber(SKIN:GetVariable('TitleFontSize')), tonumber(SKIN:GetVariable('FontSize'))
    if SELF:GetNumberOption('DataBarFocus') == 1 then
        assert(thickness == SELF:GetNumberOption('ExpectedThickness') and titleSize == 12 and bodySize == 10,
            'Signal-bar fixture overrides failed')
        assert(numberVariable('BorderThickness') == 4, 'Signal-bar fixture must use maximum border thickness')
        for _, suffix in ipairs({'Bounds','Panel','SignalLabel','Signal','SignalBar','Radio'}) do boundsCheck(suffix, expectedW, expectedH) end
        local track, radio, signal = meter('SignalBar'), meter('Radio'), meter('Signal')
        local controller = assert(SKIN:GetMeasure('MeasureConnectionController'), 'Connection controller missing')
        local height, contentWidth, inset = math.max(1, math.floor(thickness * scale + 0.5)), numberVariable('ContentWidth'), numberVariable('Inset')
        assert(math.abs(numberVariable('DataBarThicknessPx') - height) < 0.001, 'Shared bar-height geometry differs')
        assert(math.abs(numberOption(track, 'H') - height) < 0.001 and math.abs(controller:GetNumberOption('SignalHeight') - height) < 0.001,
            'Track or controller does not honor rounded global thickness')
        assert(math.abs(numberOption(track, 'W') - contentWidth) < 0.001 and math.abs(controller:GetNumberOption('SignalWidth') - contentWidth) < 0.001,
            'Track or controller width differs from content bounds')
        assert(track:GetH() == height and track:GetH() >= 1 and math.abs(track:GetW() - contentWidth) < 1,
            'Native track must match the visible whole-pixel shared height')
        assert(math.abs(numberOption(track, 'Y') - inset - 211 * scale) < 0.001, 'Signal track top moved')
        assert(math.abs(numberOption(radio, 'Y') - inset - 213 * scale - height) < 0.001,
            'Radio row does not follow the bar thickness')
        local function rectangle(path)
            local fields = assert(path:match('^Rectangle%s+([^|]+)'), 'Expected rectangular signal track/fill')
            -- Expanded shape options may contain Max/Round function arguments.
            -- Only commas outside parentheses separate rectangle coordinates.
            local tokens, depth, first = {}, 0, 1
            for index = 1, #fields do
                local character = fields:sub(index, index)
                if character == '(' then depth = depth + 1 end
                if character == ')' then depth = depth - 1 end
                assert(depth >= 0, 'Unbalanced signal rectangle formula')
                if character == ',' and depth == 0 then
                    tokens[#tokens + 1], first = fields:sub(first, index - 1), index + 1
                end
            end
            assert(depth == 0, 'Unbalanced signal rectangle formula')
            tokens[#tokens + 1] = fields:sub(first)
            local result = {}
            for _, token in ipairs(tokens) do
                result[#result + 1] = assert(SKIN:ParseFormula('(' .. SKIN:ReplaceVariables(token:match('^%s*(.-)%s*$')) .. ')'),
                    'Invalid signal rectangle coordinate')
            end
            assert(#result == 4 and result[1] == 0 and result[2] == 0, 'Invalid signal rectangle origin')
            return result[3], result[4]
        end
        local trackWidth, trackHeight = rectangle(track:GetOption('Shape'))
        assert(math.abs(trackWidth - contentWidth) < 0.001 and math.abs(trackHeight - height) < 0.001,
            'Painted track dimensions do not match configured thickness')
        local signalText, fill = signal:GetOption('Text'), track:GetOption('Shape2')
        if signalText:match('^%d+%%$') then
            local fillWidth, fillHeight = rectangle(fill)
            assert(controller:GetValue() == 1 and fillWidth >= 0 and fillWidth <= trackWidth + 0.001
                and math.abs(fillHeight - height) < 0.001, 'Known signal fill escapes configured track')
        else
            assert(controller:GetValue() == 0 and fill == 'Line 0,0,0,0 | StrokeWidth 0',
                'Unavailable signal has a fabricated fill')
        end
        for _, suffix in ipairs({'SignalLabel','Signal'}) do
            local label = meter(suffix)
            assert(label:GetY(false) + label:GetH() <= track:GetY(false), suffix .. ' overlaps the signal track')
        end
        assert(track:GetY(false) + track:GetH() <= radio:GetY(false), 'Signal bar overlaps Radio row')
        assert(math.abs(numberOption(radio, 'Y') - numberOption(track, 'Y') - trackHeight - 2 * scale) < 0.001,
            'Fractional track must keep two logical pixels before Radio')
        local radioGap = radio:GetY(false) - track:GetY(false) - trackHeight
        assert(radioGap > 0, 'Fractional painted track touches or overlaps Radio row')
        local border = 4 * scale
        local innerRight, innerBottom = inset + numberVariable('PanelWidth') - border,
            inset + math.floor(panelHeight * scale + 0.5) - border
        for _, target in ipairs({track, radio}) do
            assert(target:GetX(false) >= inset + border and target:GetX(false) + target:GetW() <= innerRight,
                'Signal/footer horizontal bounds overlap the inside border')
            assert(target:GetY(false) + target:GetH() <= innerBottom, 'Signal/footer extends into bottom border')
        end
        local glyphs = glyphChecks()
        return string.format('PASS databar width=%d scale=%g thickness=%g heightPx=%g nativeH=%g panelHeight=%g savedMinimum=%g size=%dx%d radioGapPx=%g signal=%s glyphs[%s]',
            columnWidth, scale, thickness, height, track:GetH(), panelHeight, savedHeight, expectedW, expectedH, radioGap, signalText, glyphs)
    end
    if SELF:GetNumberOption('HeaderFocus') == 1 then
        assert(titleSize == SELF:GetNumberOption('ExpectedTitleSize') and bodySize == 10, 'Header focus typography fixture failed')
        for _, suffix in ipairs({'Bounds','Panel','Icon','Title','Width'}) do boundsCheck(suffix, expectedW, expectedH) end
        assert(math.abs(numberOption(meter('Title'), 'FontSize') - titleSize * scale) < 0.001, 'Title bypasses shared font size')
        assert(math.abs(numberOption(meter('Width'), 'FontSize') - bodySize * scale) < 0.001, 'Width control bypasses body font size')
        local glyphs = glyphChecks()
        local header = headerChecks(scale, titleSize)
        return string.format('PASS header width=%d scale=%g title=%g body=%g size=%dx%d %s glyphs[%s]',
            columnWidth, scale, titleSize, bodySize, expectedW, expectedH, header, glyphs)
    end
    for _, suffix in ipairs({'Bounds', 'Panel', 'Icon', 'Title', 'Width', 'Adapter', 'Description', 'Status',
        'InternetLabel', 'Internet', 'IPLabel', 'IP', 'GatewayLabel', 'Gateway', 'RxLabel', 'Rx',
        'TxLabel', 'Tx', 'Rule', 'WiFi', 'SignalLabel', 'Signal', 'SignalBar', 'Radio'}) do
        boundsCheck(suffix, expectedW, expectedH)
    end
    assert(meter('Title'):GetX(true) + meter('Title'):GetW() <= meter('Width'):GetX(true),
        'Header title overlaps width control')
    local typography = SELF:GetOption('Typography')
    if typography == 'maximum' then
        assert(titleSize == 12 and bodySize == 10 and tonumber(SKIN:GetVariable('HeaderFontSize')) == 10, 'Maximum typography fixture did not apply')
    end
    if typography == 'default' then
        assert(titleSize == 10 and bodySize == 9 and tonumber(SKIN:GetVariable('HeaderFontSize')) == 8, 'Default typography fixture did not apply')
    end
    if typography == 'title10-body10' then assert(titleSize == 10 and bodySize == 10, 'Mixed title10/body10 fixture failed') end
    if typography == 'title12-body9' then assert(titleSize == 12 and bodySize == 9, 'Mixed title12/body9 fixture failed') end
    assert(math.abs(numberOption(meter('Title'), 'FontSize') - titleSize * scale) < 0.001, 'Title does not honor shared size')
    assert(meter('Title'):GetOption('FontColor') == SKIN:GetVariable('TitleTextColor'), 'Title does not honor shared color')
    assert(meter('Width'):GetOption('FontColor') == SKIN:GetVariable('AccentColor2'), 'Width action is not the secondary accent')
    for _, suffix in ipairs({'Width','Adapter','Description','Status','InternetLabel','Internet','IPLabel','IP',
        'GatewayLabel','Gateway','RxLabel','Rx','TxLabel','Tx','WiFi','SignalLabel','Signal','Radio'}) do
        assert(math.abs(numberOption(meter(suffix), 'FontSize') - bodySize * scale) < 0.001,
            suffix .. ' does not honor shared body size')
    end
    for _, suffix in ipairs({'Adapter','Description','InternetLabel','IPLabel','IP','GatewayLabel','Gateway',
        'RxLabel','TxLabel','WiFi','SignalLabel','Radio'}) do
        assert(meter(suffix):GetOption('FontColor') == SKIN:GetVariable('TextColor'), suffix .. ' does not honor body text color')
    end
    assert(meter('Rx'):GetOption('FontColor') == SKIN:GetVariable('NetworkInColor'), 'RX lost metric color')
    assert(meter('Tx'):GetOption('FontColor') == SKIN:GetVariable('NetworkOutColor'), 'TX lost metric color')
    local rows = {'Title','Adapter','Description','Status','Internet','IP','Gateway','Rx','Tx','WiFi','Signal','SignalBar','Radio'}
    for index = 1, #rows - 1 do
        local previous, following = meter(rows[index]), meter(rows[index + 1])
        assert(previous:GetY(false) + previous:GetH() <= following:GetY(false), rows[index] .. ' overlaps next row')
    end
    for _, valueName in ipairs({'Internet','IP','Gateway','Rx','Tx','Signal'}) do
        local left, right = meter(valueName .. 'Label'), meter(valueName)
        assert(left:GetX(true) + left:GetW() <= right:GetX(true) - right:GetW(), valueName .. ' label overlaps value')
    end
    local surface = SELF:GetOption('Surface')
    if surface ~= 'source' then
        assert(tonumber(SKIN:GetVariable('BorderThickness')) == tonumber(surface), 'Border thickness fixture failed')
        assert(tonumber(SKIN:GetVariable('DividerThickness')) == tonumber(surface), 'Divider thickness fixture failed')
        for _, suffix in ipairs({'Panel','Rule'}) do
            local width = meter(suffix):GetOption('Shape'):match('StrokeWidth%s+([^|]+)')
            assert(width and math.abs(SKIN:ParseFormula(width) - tonumber(surface) * scale) < 0.001,
                suffix .. ' does not inherit shared stroke thickness')
        end
        assert(meter('Rule'):GetOption('Shape'):find('Stroke Color ' .. SKIN:GetVariable('DividerColor'), 1, true),
            'Divider does not inherit shared color')
    end
    local glyphs = glyphChecks()
    local controller = assert(SKIN:GetMeasure('MeasureConnectionController'), 'Controller missing')
    assert(controller:GetNumberOption('UpdateDivider') == 1, 'Controller cadence differs from one second')
    for _, suffix in ipairs({'Alias', 'Description', 'Guid', 'Status', 'State', 'Type', 'Internet', 'IP', 'Gateway', 'RxLink', 'TxLink'}) do
        local native = assert(SKIN:GetMeasure('MeasureConnection' .. suffix), suffix .. ' native measure missing')
        assert(native:GetNumberOption('UpdateDivider') == 2, suffix .. ' does not have two-second cadence')
        if suffix ~= 'Internet' then
            assert(native:GetNumberOption('DynamicVariables') == 1, suffix .. ' cannot reselect')
        else
            assert(native:GetOption('SysInfoData', '') == '', 'PC-wide Internet measure misleadingly scoped to adapter')
        end
    end
    local kind = SELF:GetOption('CaseKind')
    local signal = meter('Signal'):GetOption('Text')
    local wifi = meter('WiFi'):GetOption('Text')
    local signalBar = meter('SignalBar')
    local signalWidth, signalHeight = controller:GetNumberOption('SignalWidth'), controller:GetNumberOption('SignalHeight')
    assert(math.abs(signalBar:GetW() - signalWidth) < 1 and math.abs(signalBar:GetH() - signalHeight) < 1,
        'Signal bar dimensions differ from controller')
    local signalShape = signalBar:GetOption('Shape2')
    -- A pending or unsupported query is also unknown; a measured 0% is known.
    local signalKnown = signal:match('^%d+%%$') ~= nil
    assert(signalKnown == (controller:GetValue() == 1), 'Signal text and controller availability disagree')
    if not signalKnown then
        assert(signalShape == 'Line 0,0,0,0 | StrokeWidth 0', 'Unavailable signal has fabricated colored fill')
    else
        local x, y, w, h = signalShape:match('^Rectangle ([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)')
        assert(x and tonumber(x) == 0 and tonumber(y) == 0, 'Signal shape has invalid origin')
        assert(tonumber(w) >= 0 and tonumber(w) <= signalWidth and tonumber(h) == signalHeight,
            'Signal fill outside declared track')
    end
    for _, suffix in ipairs({'SSID', 'Quality', 'PHY', 'Rx', 'Tx'}) do
        local native = assert(SKIN:GetMeasure('MeasureConnectionWiFi' .. suffix), suffix .. ' WiFi measure missing')
        local index = native:GetNumberOption('WiFiIntfID')
        assert(index >= 0 and index == math.floor(index), suffix .. ' unsafe WiFi index supplied')
        assert(native:GetNumberOption('UpdateDivider') == 5, suffix .. ' WiFi cadence is not five seconds')
        assert(native:GetNumberOption('DynamicVariables') == 1, suffix .. ' WiFi cannot apply validated index')
        assert(native:GetOption('Group') == 'ConnectionWiFi', suffix .. ' WiFi group differs')
    end
    if kind == 'invalid-adapter' then
        assert(meter('IP'):GetOption('Text') == '--', 'Invalid NIC exposes fallback IP')
        assert(meter('Gateway'):GetOption('Text') == '--', 'Invalid NIC exposes fallback gateway')
        assert(meter('Rx'):GetOption('Text') == '--' and meter('Tx'):GetOption('Text') == '--', 'Invalid NIC exposes fallback link speeds')
    end
    if kind == 'invalid-wifi' or kind == 'disabled-wifi' then
        assert(not signal:match('%d'), 'Unavailable Wi-Fi displays numeric signal: ' .. signal)
        for _, suffix in ipairs({'SSID', 'Quality', 'PHY', 'Rx', 'Tx'}) do
            local native = assert(SKIN:GetMeasure('MeasureConnectionWiFi' .. suffix), suffix .. ' WiFi measure missing')
            assert(native:GetNumberOption('Disabled') == 1, suffix .. ' WiFi measure enabled despite invalid/disabled configuration')
            assert(native:GetNumberOption('WiFiIntfID') == 0, suffix .. ' invalid/disabled WiFi index not sanitized')
        end
    end
    assert(meter('Status'):GetOption('Text') ~= 'Waiting for adapter', 'Controller did not render status')
    return string.format('PASS width=%d scale=%g columns=%d size=%dx%d typography=%s title=%g body=%g case=%s controller=%g signal=%s wifi=%s glyphs[%s]',
        columnWidth, scale, columns, expectedW, expectedH, SELF:GetOption('Typography'), titleSize, bodySize, kind, controller:GetValue(), signal, wifi, glyphs)
end

function Update()
    ticks = ticks + 1
    if ticks == 1 then
        local ok, err = pcall(prepareGlyphs)
        if not ok then probeError = tostring(err) end
    end
    if ticks == 9 then
        for _, spec in ipairs(probes) do
            if spec[4] then SKIN:Bang('!SetOption', 'MeterConnectionGlyph' .. spec[1], 'Text', meter(spec[2]):GetOption('Text')) end
        end
    end
    local reportTick = (SELF:GetNumberOption('HeaderFocus') == 1 or SELF:GetNumberOption('DataBarFocus') == 1) and 4 or 11
    if ticks ~= reportTick then return 0 end
    local ok, result = pcall(run)
    local output = assert(io.open(SELF:GetOption('ResultFile'), 'wb'))
    output:write(ok and result or ('FAIL ' .. tostring(result)))
    output:close()
    return ok and 1 or -1
end
