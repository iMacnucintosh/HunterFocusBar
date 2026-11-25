-- HunterFocusBar: la barra de maná del cazador se pinta con el color del enfoque.
-- Solo cambia el aspecto; el recurso sigue siendo maná.
--
-- Notas sobre WoW Forever:
--  * Usa un PlayerFrame propio con barras sin nombre: localizamos la de maná
--    por posición (la vida va arriba, el maná justo debajo).
--  * Los valores de las barras son "secretos": no se pueden comparar.
--  * La textura de maná ya viene azul de fábrica: teñirla da un color sucio,
--    así que por defecto la cambiamos por una lisa teñible.
--  * El coste del hechizo que se está lanzando se dibuja con una textura
--    anclada al final del relleno de la barra; también la pintamos.

local function Log(...) print("|cffff8040HunterFocusBar|r", ...) end
-- Errores internos: se ignoran en silencio (el addon no escribe nada en el chat
-- salvo cuando el jugador usa /hfb).
local function Silent() end

local _, class = UnitClass("player")
local IAMHUNTER = (class == "HUNTER")  -- tu barra solo si eres cazador

local LISO = "Interface\\TargetingFrame\\UI-StatusBar"

local focus = PowerBarColor and PowerBarColor["FOCUS"] or { r = 1, g = 0.5, b = 0.25 }
local DEF_MAIN = { focus.r, focus.g, focus.b }
local DEF_COST = { 1, 0.78, 0.5 }   -- naranja claro para el coste del hechizo

local hooked = {}      -- objetos ya enganchados
local bars = {}        -- barras de maná encontradas
local costs = {}       -- texturas/barras de coste encontradas
local origTex = {}     -- textura de relleno original de cada barra
local petStyle         -- aspecto copiado de la barra de la mascota
local painting = false

local function DB()
    HunterFocusBarDB = HunterFocusBarDB or {}
    return HunterFocusBarDB
end

local function Mode() return DB().mode or "liso" end
local function MainColor() local c = DB().color or DEF_MAIN return c[1], c[2], c[3] end
local function CostColor() local c = DB().cost or DEF_COST return c[1], c[2], c[3] end

---------------------------------------------------------------------------
-- Pintado
---------------------------------------------------------------------------
local Paint, PaintCost, HookTexture

local function SetBarTexture(bar, want)
    local tex = bar:GetStatusBarTexture()
    local cur = tex and (tex.GetAtlas and tex:GetAtlas() or tex:GetTexture())
    if want and cur ~= want then
        bar:SetStatusBarTexture(want)
        HookTexture(bar)
    end
    return bar:GetStatusBarTexture()
end

local function PaintRaw(bar)
    local mode = Mode()
    local R, G, B = MainColor()
    local tex
    if mode == "mascota" and petStyle then
        tex = SetBarTexture(bar, petStyle.atlas or petStyle.file)
        if tex then
            tex:SetDesaturated(false)
            bar:SetStatusBarColor(petStyle.sr, petStyle.sg, petStyle.sb)
            tex:SetVertexColor(petStyle.vr, petStyle.vg, petStyle.vb)
        end
    elseif mode == "tinte" then
        tex = bar:GetStatusBarTexture()
        if tex then tex:SetDesaturated(true) end
        bar:SetStatusBarColor(R, G, B)
        if tex then tex:SetVertexColor(R, G, B) end
    else -- liso
        tex = SetBarTexture(bar, LISO)
        if tex then tex:SetDesaturated(false) end
        bar:SetStatusBarColor(R, G, B)
        if tex then tex:SetVertexColor(R, G, B) end
    end
end

local function PaintCostRaw(obj)
    local r, g, b = CostColor()
    local function Tint(o, depth)
        if depth > 6 then return end
        local t = o:GetObjectType()
        if t == "Texture" then
            o:SetDesaturated(true)
            o:SetVertexColor(r, g, b)
        elseif t == "StatusBar" then
            local st = o:GetStatusBarTexture()
            if st then st:SetDesaturated(true); st:SetVertexColor(r, g, b) end
            o:SetStatusBarColor(r, g, b)
        end
        -- Contenedores (Forever usa un Frame para el coste): pintar su contenido.
        if o.GetRegions then
            for _, reg in ipairs({ o:GetRegions() }) do
                if reg:GetObjectType() == "Texture" then
                    reg:SetDesaturated(true)
                    reg:SetVertexColor(r, g, b)
                end
            end
        end
        if o.GetChildren then
            for _, c in ipairs({ o:GetChildren() }) do Tint(c, depth + 1) end
        end
    end
    Tint(obj, 0)
end

-- Ejecuta fn protegida: si falla, el indicador 'painting' no se queda
-- bloqueado (eso hacía que la barra volviera al azul) y se avisa una vez.
local reported = {}
local function Guarded(fn, obj)
    if painting or not obj then return end
    painting = true
    local ok, err = pcall(fn, obj)
    painting = false
    if not ok and not reported[err] then
        reported[err] = true
        Silent(err)
    end
end

function Paint(bar) Guarded(PaintRaw, bar) end
function PaintCost(obj) Guarded(PaintCostRaw, obj) end

local function HookRegion(obj, fn)
    if hooked[obj] then return end
    hooked[obj] = true
    for _, m in ipairs({ "SetVertexColor", "SetAtlas", "SetTexture", "SetColorTexture",
                         "SetDesaturated", "SetStatusBarColor", "SetStatusBarTexture", "Show" }) do
        if obj[m] then hooksecurefunc(obj, m, fn) end
    end
end

-- Engancha el objeto de coste y todo lo que contiene, repintando el conjunto.
local function HookCostTree(root, obj, depth)
    obj, depth = obj or root, depth or 0
    if depth > 6 then return end
    HookRegion(obj, function() PaintCost(root) end)
    if obj.GetRegions then
        for _, reg in ipairs({ obj:GetRegions() }) do
            if reg:GetObjectType() == "Texture" then
                HookRegion(reg, function() PaintCost(root) end)
            end
        end
    end
    if obj.GetChildren then
        for _, c in ipairs({ obj:GetChildren() }) do HookCostTree(root, c, depth + 1) end
    end
end

function HookTexture(bar)
    local tex = bar:GetStatusBarTexture()
    if tex then HookRegion(tex, function() Paint(bar) end) end
end

local function Hook(bar)
    if hooked[bar] then return end
    hooked[bar] = true
    bars[#bars + 1] = bar
    origTex[bar] = bar:GetStatusBarTexture()
    hooksecurefunc(bar, "SetStatusBarColor", Paint)
    hooksecurefunc(bar, "SetStatusBarTexture", function() HookTexture(bar); Paint(bar) end)
    HookTexture(bar)
end

---------------------------------------------------------------------------
-- Búsqueda de barras
---------------------------------------------------------------------------
local function CollectBars(frame, depth, out)
    if not frame or depth > 10 then return end
    if frame:GetObjectType() == "StatusBar" then
        local ok, top, width = pcall(function() return frame:GetTop(), frame:GetWidth() end)
        if ok and top and width and width > 40 then
            out[#out + 1] = { bar = frame, top = top }
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        CollectBars(child, depth + 1, out)
    end
end

-- Devuelve todas las barras del marco y la de poder (2.º grupo visible).
local function FindPowerBar(frame)
    local found = {}
    CollectBars(frame, 0, found)
    table.sort(found, function(a, b) return a.top > b.top end)
    local group, lastTop, power = 0, nil, nil
    for _, e in ipairs(found) do
        if e.bar:IsVisible() then
            if not lastTop or lastTop - e.top > 6 then
                group = group + 1
                lastTop = e.top
            end
            e.group = group
            if group == 2 and not power then power = e end
        end
    end
    if power then power.mana = true end
    return found, power and power.bar
end

-- ¿Está 'region' anclada a alguno de los objetivos?
local function AnchoredTo(region, targets)
    local ok, n = pcall(region.GetNumPoints, region)
    if not ok or not n then return false end
    for i = 1, n do
        local _, rel = region:GetPoint(i)
        if rel and targets[rel] then return true end
    end
    return false
end

local function CollectRegions(frame, depth, out)
    if not frame or depth > 10 then return end
    for _, r in ipairs({ frame:GetRegions() }) do out[#out + 1] = r end
    for _, c in ipairs({ frame:GetChildren() }) do
        out[#out + 1] = c
        CollectRegions(c, depth + 1, out)
    end
end

-- La barra de coste está anclada al relleno de la barra de maná.
local function FindCostBars(mana)
    local fills = {}
    if origTex[mana] then fills[origTex[mana]] = true end
    local cur = mana:GetStatusBarTexture()
    if cur then fills[cur] = true end

    local candidates = {}
    CollectRegions(PlayerFrame, 0, candidates)
    for _, obj in ipairs(candidates) do
        if not fills[obj] and obj ~= mana and AnchoredTo(obj, fills) then
            local t = obj:GetObjectType()
            if t == "Texture" or t == "StatusBar" then
                if not hooked[obj] then
                    costs[#costs + 1] = obj
                    HookCostTree(obj)
                end
            end
        end
    end
    -- Nombres de Blizzard, por si Forever los conserva.
    for _, obj in ipairs({ mana.ManaCostPredictionBar, PlayerFrame.myManaCostPredictionBar,
                           _G.PlayerFrameManaCostPredictionBar }) do
        if obj and not hooked[obj] then
            costs[#costs + 1] = obj
            HookCostTree(obj)
        end
    end
end

local function CapturePetStyle()
    if not PetFrame or not PetFrame:IsVisible() then return end
    local _, petBar = FindPowerBar(PetFrame)
    if not petBar then return end
    local tex = petBar:GetStatusBarTexture()
    if not tex then return end
    local st = {}
    st.atlas = tex.GetAtlas and tex:GetAtlas() or nil
    if not st.atlas then st.file = tex:GetTexture() end
    st.vr, st.vg, st.vb = tex:GetVertexColor()
    st.sr, st.sg, st.sb = petBar:GetStatusBarColor()
    petStyle = st
end

local function Scan()
    if not IAMHUNTER then return {} end
    local found, mana = FindPowerBar(PlayerFrame)
    if mana then
        Hook(mana)
        FindCostBars(mana)
    end
    return found
end

local function RefreshUnsafe()
    CapturePetStyle()
    Scan()
    for _, bar in ipairs(bars) do Paint(bar) end
    for _, c in ipairs(costs) do PaintCost(c) end
end

local function Refresh()
    local ok, err = pcall(RefreshUnsafe)
    if not ok then Silent(err) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
f:RegisterUnitEvent("UNIT_PET", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")

---------------------------------------------------------------------------
-- Coste del hechizo, buscado en pleno casteo: es la textura visible que cae
-- dentro de la barra de maná y no es el relleno de ninguna barra. Su tamaño
-- depende del maná (valor secreto), así que si medirla da error también la
-- consideramos candidata.
---------------------------------------------------------------------------

local function ScanCostDuringCast()
    local mana = bars[1]
    if not mana or not mana:IsVisible() then return end

    -- Rellenos de todas las barras del PlayerFrame (vida, maná, ocultas...).
    local fills = {}
    local all = {}
    CollectBars(PlayerFrame, 0, all)
    for _, e in ipairs(all) do
        local t = e.bar:GetStatusBarTexture()
        if t then fills[t] = true end
        fills[e.bar] = true
    end
    for _, t in pairs(origTex) do fills[t] = true end

    local L, B, W, H = mana:GetRect()
    local regions = {}
    CollectRegions(PlayerFrame, 0, regions)
    local nuevos = 0
    for _, r in ipairs(regions) do
        if not fills[r] and not hooked[r] and r:GetObjectType() == "Texture" and r:IsVisible() then
            local ok, inside = pcall(function()
                local l, b, w, h = r:GetRect()
                if not l then return false end
                local cx, cy = l + w / 2, b + h / 2
                return cx >= L and cx <= L + W and cy >= B and cy <= B + H
                       and w < W * 0.9 and h <= H + 2
            end)
            if (ok and inside) or not ok then
                costs[#costs + 1] = r
                HookRegion(r, function() PaintCost(r) end)
                PaintCost(r)
                nuevos = nuevos + 1
            end
        end
    end
end

f:SetScript("OnEvent", function(_, event)
    if event == "UNIT_SPELLCAST_START" then
        C_Timer.After(0.05, function()
            local ok, err = pcall(ScanCostDuringCast)
            if not ok then Silent(err) end
        end)
        return
    end
    C_Timer.After(0.5, Refresh)
end)

---------------------------------------------------------------------------
-- Otros marcos (objetivo, objetivo del objetivo, foco, grupo...): esas
-- barras se reutilizan para cualquier unidad, así que no las tocamos. Encima
-- ponemos una barra naranja propia que copia su valor y solo se ve cuando la
-- unidad mostrada es un cazador (tú u otro jugador).
---------------------------------------------------------------------------
local others = {}   -- [marco] = { bar = StatusBar, ov = StatusBar }

-- Marcos con su unidad. Se resuelven cada vez porque algunos se crean tarde.
local function OtherFrames()
    local list = {
        { _G.TargetFrame, "target" },
        { _G.TargetFrameToT, "targettarget" },
        { _G.FocusFrame, "focus" },
        { _G.FocusFrameToT, "focustarget" },
    }
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
            or (_G.PartyFrame and _G.PartyFrame["MemberFrame" .. i])
        if pf then list[#list + 1] = { pf, pf.unit or ("party" .. i) } end
    end
    return list
end

local function IsHunter(unit)
    local ok, yes = pcall(function()
        if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
        local _, c = UnitClass(unit)
        return c == "HUNTER" and UnitPowerType(unit) == 0
    end)
    return ok and yes == true
end

local function StyleOverlay(ov)
    local R, G, B = MainColor()
    if Mode() == "mascota" and petStyle then
        ov:SetStatusBarTexture(petStyle.atlas or petStyle.file)
        ov:SetStatusBarColor(petStyle.sr, petStyle.sg, petStyle.sb)
        local t = ov:GetStatusBarTexture()
        if t then t:SetVertexColor(petStyle.vr, petStyle.vg, petStyle.vb) end
    else
        ov:SetStatusBarTexture(LISO)
        ov:SetStatusBarColor(R, G, B)
    end
end

local function MakeOverlay(bar)
    local ov = CreateFrame("StatusBar", nil, bar)
    ov:SetAllPoints(bar)
    ov:SetFrameLevel(bar:GetFrameLevel())
    if bar.GetOrientation then ov:SetOrientation(bar:GetOrientation()) end
    if bar.GetReverseFill then ov:SetReverseFill(bar:GetReverseFill()) end
    StyleOverlay(ov)
    -- Mismas máscaras (bordes redondeados) que el relleno original.
    local src, dst = bar:GetStatusBarTexture(), ov:GetStatusBarTexture()
    if src and dst and src.GetNumMaskTextures then
        for i = 1, src:GetNumMaskTextures() do
            local m = src:GetMaskTexture(i)
            if m then dst:AddMaskTexture(m) end
        end
    end
    local function Sync()
        ov:SetMinMaxValues(bar:GetMinMaxValues())
        ov:SetValue(bar:GetValue())
    end
    hooksecurefunc(bar, "SetMinMaxValues", function(_, a, b) ov:SetMinMaxValues(a, b) end)
    hooksecurefunc(bar, "SetValue", function(_, v) ov:SetValue(v) end)
    Sync()
    ov:Hide()
    return ov
end

local function UpdateOthersUnsafe()
    for _, def in ipairs(OtherFrames()) do
        local frame, unit = def[1], def[2]
        if frame then
            unit = frame.unit or unit
            local show = frame:IsVisible() and IsHunter(unit)
            local o = others[frame]
            if show and not o then
                local bar = frame.manabar or frame.ManaBar
                if not bar or bar:GetObjectType() ~= "StatusBar" then
                    local _
                    _, bar = FindPowerBar(frame)
                end
                if bar then
                    o = { bar = bar, ov = MakeOverlay(bar) }
                    others[frame] = o
                end
            end
            if o then
                if show then
                    StyleOverlay(o.ov)
                    o.ov:SetMinMaxValues(o.bar:GetMinMaxValues())
                    o.ov:SetValue(o.bar:GetValue())
                end
                o.ov:SetShown(show and true or false)
            end
        end
    end
end

local function UpdateOthers()
    local ok, err = pcall(UpdateOthersUnsafe)
    if not ok and not reported[err] then
        reported[err] = true
        Silent(err)
    end
end

if CompactUnitFrame_UpdatePowerColor then
    hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame)
        local bar = frame and frame.powerBar
        local unit = frame and (frame.displayedUnit or frame.unit)
        if bar and unit and IsHunter(unit) then
            local R, G, B = MainColor()
            bar:SetStatusBarColor(R, G, B)
        end
    end)
end

local fo = CreateFrame("Frame")
fo:RegisterEvent("PLAYER_ENTERING_WORLD")
fo:RegisterEvent("PLAYER_TARGET_CHANGED")
fo:RegisterEvent("PLAYER_FOCUS_CHANGED")
fo:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
fo:RegisterEvent("GROUP_ROSTER_UPDATE")
fo:RegisterEvent("UNIT_DISPLAYPOWER")
fo:SetScript("OnEvent", function()
    -- Primero dejamos que el juego actualice sus marcos.
    C_Timer.After(0, UpdateOthers)
end)

---------------------------------------------------------------------------
-- /hfb (alias /foco)
---------------------------------------------------------------------------
local function ParseColor(args)
    local r, g, b = args:match("^(%S+)%s+(%S+)%s+(%S+)$")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not (r and g and b) then return nil end
    if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
    return { r, g, b }
end

local AYUDA = {
    "/hfb - diagnóstico",
    "/hfb modo liso | mascota | tinte",
    "/hfb color R G B - color de la barra (0-255), /hfb color reset",
    "/hfb coste R G B - color del coste del hechizo, /hfb coste reset",
}

SLASH_HUNTERFOCUSBAR1 = "/hfb"
SLASH_HUNTERFOCUSBAR2 = "/foco"
SlashCmdList.HUNTERFOCUSBAR = function(msg)
    msg = strtrim((msg or ""):lower())
    local cmd, args = msg:match("^(%S+)%s*(.*)$")

    if cmd == "modo" then
        if args == "liso" or args == "mascota" or args == "tinte" then
            DB().mode = args
            Log("modo:", args, "- escribe /reload para aplicarlo")
        else
            Log("modos válidos: liso, mascota, tinte")
        end
        return
    elseif cmd == "color" or cmd == "coste" then
        local key = cmd == "color" and "color" or "cost"
        if args == "reset" then
            DB()[key] = nil
        else
            local c = ParseColor(args)
            if not c then Log("uso: /hfb", cmd, "R G B   (ej. 255 128 64)") return end
            DB()[key] = c
        end
        Refresh()
        UpdateOthers()
        Log(cmd, "aplicado")
        return
    elseif cmd == "ayuda" or cmd == "help" then
        for _, l in ipairs(AYUDA) do Log(l) end
        return
    end

    Refresh()
    local r, g, b = MainColor()
    local cr, cg, cb = CostColor()
    Log("modo:", Mode(), string.format("color: %d %d %d  coste: %d %d %d",
        r * 255, g * 255, b * 255, cr * 255, cg * 255, cb * 255))
    Log("barras de maná:", #bars, "- texturas de coste:", #costs)
    for i, c in ipairs(costs) do
        Log("  coste", i, c:GetObjectType(), c:GetName() or "(sin nombre)")
    end
    Log("escribe /hfb ayuda para ver los comandos")
end
