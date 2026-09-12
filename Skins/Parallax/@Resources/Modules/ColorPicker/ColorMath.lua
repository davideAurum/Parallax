-- Original implementation of the sRGB / HSV / CIELAB D50 conversions.
-- Constants and reference equations: W3C CSS Color 4, conversion sample code.
local M = {}
function M.Clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function matrix(a, x)
    return {a[1][1]*x[1]+a[1][2]*x[2]+a[1][3]*x[3],
        a[2][1]*x[1]+a[2][2]*x[2]+a[2][3]*x[3],
        a[3][1]*x[1]+a[3][2]*x[2]+a[3][3]*x[3]}
end
local function decode(c)
    local a = math.abs(c)
    return a <= 0.04045 and c/12.92 or (c < 0 and -1 or 1)*((a+0.055)/1.055)^2.4
end
local function encode(c)
    local a = math.abs(c)
    return a <= 0.0031308 and 12.92*c or (c < 0 and -1 or 1)*(1.055*a^(1/2.4)-0.055)
end
local toXYZ = {
    {506752/1228815,87881/245763,12673/70218},
    {87098/409605,175762/245763,12673/175545},
    {7918/409605,87881/737289,1001167/1053270}}
local toRGB = {
    {12831/3959,-329/214,-1974/3959},
    {-851781/878810,1648619/878810,36519/878810},
    {705/12673,-2585/12673,705/667}}
local toD50 = {
    {1.0479297925449969,0.022946870601609652,-0.05019226628920524},
    {0.02962780877005599,0.9904344267538799,-0.017073799063418826},
    {-0.009243040646204504,0.015055191490298152,0.7518742814281371}}
local toD65 = {
    {0.955473421488075,-0.02309845494876471,0.06325924320057072},
    {-0.0283697093338637,1.0099953980813041,0.021041441191917323},
    {0.012314014864481998,-0.020507649298898964,1.330365926242124}}
local white = {0.3457/0.3585,1,(1-0.3457-0.3585)/0.3585}
local epsilon, kappa = 216/24389, 24389/27
function M.RgbToLab(rgb)
    local xyz = matrix(toD50, matrix(toXYZ, {decode(rgb[1]),decode(rgb[2]),decode(rgb[3])}))
    local f = {}
    for i=1,3 do
        local t = xyz[i]/white[i]
        f[i] = t > epsilon and t^(1/3) or (kappa*t+16)/116
    end
    return {116*f[2]-16,500*(f[1]-f[2]),200*(f[2]-f[3])}
end
function M.LabToRgb(lab)
    local fy = (lab[1]+16)/116
    local f, xyz = {fy+lab[2]/500,fy,fy-lab[3]/200}, {}
    for i=1,3 do
        xyz[i] = (f[i]^3 > epsilon and f[i]^3 or (116*f[i]-16)/kappa)*white[i]
    end
    local linear = matrix(toRGB, matrix(toD65, xyz))
    return {encode(linear[1]),encode(linear[2]),encode(linear[3])}
end
function M.RgbToHsv(rgb)
    local r,g,b = rgb[1],rgb[2],rgb[3]
    local hi,lo = math.max(r,g,b),math.min(r,g,b)
    local d,h = hi-lo,0
    if d > 0 then
        if hi == r then h = ((g-b)/d)%6
        elseif hi == g then h = (b-r)/d+2
        else h = (r-g)/d+4 end
    end
    return {h*60,hi == 0 and 0 or d/hi,hi}
end
function M.HsvToRgb(hsv)
    local h,s,v = (hsv[1]%360)/60,hsv[2],hsv[3]
    local i,f = math.floor(h),h-math.floor(h)
    local p,q,t = v*(1-s),v*(1-s*f),v*(1-s*(1-f))
    local sectors = {{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    return sectors[i+1]
end
function M.Bytes(rgb)
    local out, clipped = {},false
    for i=1,3 do
        if rgb[i] < -0.000001 or rgb[i] > 1.000001 then clipped = true end
        out[i] = math.floor(M.Clamp(rgb[i],0,1)*255+0.5)
    end
    return out,clipped
end
function M.String(rgb)
    local b, clipped = M.Bytes(rgb)
    return string.format('%d,%d,%d',b[1],b[2],b[3]),clipped
end
function M.Hex(rgb)
    local b = M.Bytes(rgb)
    return string.format('#%02X%02X%02X',b[1],b[2],b[3])
end
function M.Parse(value)
    local r,g,b = tostring(value):match('^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
    if not r then
        local hex = tostring(value):match('^%s*#?(%x%x%x%x%x%x)%x%x%s*$') or tostring(value):match('^%s*#?(%x%x%x%x%x%x)%s*$')
        if hex then r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16) end
    end
    if not r or tonumber(r)>255 or tonumber(g)>255 or tonumber(b)>255 then return {137/255,190/255,250/255} end
    return {tonumber(r)/255,tonumber(g)/255,tonumber(b)/255}
end
function M.Alpha(value)
    local r,g,b,a=tostring(value):match('^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
    if a and tonumber(r)<=255 and tonumber(g)<=255 and tonumber(b)<=255 and tonumber(a)<=255 then return tonumber(a) end
    local hex=tostring(value):match('^%s*#?(%x%x%x%x%x%x%x%x)%s*$')
    if hex then return tonumber(hex:sub(7,8),16) end
    -- Rainmeter RGB and six-digit hex are opaque. Invalid alpha also falls back.
    return 255
end
return M
