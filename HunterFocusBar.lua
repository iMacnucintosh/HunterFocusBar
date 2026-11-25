-- HunterFocusBar: el maná de los cazadores se muestra como una barra de
-- enfoque naranja. Solo cambia el aspecto; el recurso sigue siendo maná.
--
-- Notas sobre WoW Forever:
--  * Usa un PlayerFrame propio con barras sin nombre: localizamos la de maná
--    por posición (la vida va arriba, el maná justo debajo).
--  * Los valores de las barras son "secretos": no se pueden comparar.
--  * La textura de maná ya viene azul de fábrica: teñirla da un color sucio,
--    así que la cambiamos por una lisa teñible.
--  * El coste del hechizo que se está lanzando va en un marco anclado al final
--    del relleno de la barra; pintamos todo lo que contiene.

local _, class = UnitClass("player")
local IAMHUNTER = (class == "HUNTER")  -- tu propia barra solo si eres cazador

local LISO = "Interface\\TargetingFrame\\UI-StatusBar"

local focus = PowerBarColor and PowerBarColor["FOCUS"] or { r = 1, g = 0.5, b = 0.25 }
local R, G, B = focus.r, focus.g, focus.b    -- naranja del enfoque
local CR, CG, CB = 1, 0.78, 0.5              -- naranja claro para el coste

local hooked = {}      -- objetos ya enganchados
local bars = {}        -- barras de maná encontradas
local costs = {}       -- objetos de coste encontrados
local origTex = {}     -- textura de relleno original de cada barra
local painting = false

---------------------------------------------------------------------------
-- Pintado
---------------------------------------------------------------------------
local Paint, PaintCost, HookTexture

local function PaintRaw(bar)
    local tex = bar:GetStatusBarTexture()
    local cur = tex and (tex.GetAtlas and tex:GetAtlas() or tex:GetTexture())
    if cur ~= LISO then
        -- A través de la barra, para que conserve anclajes y relleno.
        bar:SetStatusBarTexture(LISO)
        HookTexture(bar)
        tex = bar:GetStatusBarTexture()
    end
    if tex then
        tex:SetDesaturated(false)
        tex:SetVertexColor(R, G, B)
    end
    bar:SetStatusBarColor(R, G, B)
end

local function TintTexture(t)
    t:SetDesaturated(true)
    t:SetVertexColor(CR, CG, CB)
end

local function PaintCostRaw(obj)
    local function Tint(o, depth)
        if depth > 6 then return end
        local t = o:GetObjectType()
        if t == "Texture" then
            TintTexture(o)
        elseif t == "StatusBar" then
            local st = o:GetStatusBarTexture()
            if st then TintTexture(st) end
            o:SetStatusBarColor(CR, CG, CB)
        end
        if o.GetRegions then
            for _, reg in ipairs({ o:GetRegions() }) do
                if reg:GetObjectType() == "Texture" then TintTexture(reg) end
            end
        end
        if o.GetChildren then
            for _, c in ipairs({ o:GetChildren() }) do Tint(c, depth + 1) end
        end
    end
    Tint(obj, 0)
end

-- Si un pintado falla, el indicador 'painting' no debe quedarse bloqueado
-- (si no, la barra volvería al azul en la siguiente actualización del juego).
local function Guarded(fn, obj)
    if painting or not obj then return end
    painting = true
    pcall(fn, obj)
    painting = false
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

-- Barra de poder de un marco: agrupa las barras visibles por altura
-- (margen de 6 px); el 1.er grupo es la vida y el 2.º el poder.
local function FindPowerBar(frame)
    local found = {}
    CollectBars(frame, 0, found)
    table.sort(found, function(a, b) return a.top > b.top end)
    local group, lastTop = 0, nil
    for _, e in ipairs(found) do
        if e.bar:IsVisible() then
            if not lastTop or lastTop - e.top > 6 then
                group = group + 1
                lastTop = e.top
            end
            if group == 2 then return e.bar end
        end
    end
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

-- El coste del hechizo está anclado al relleno de la barra de maná.
local function FindCostBars(mana)
    local fills = {}
    if origTex[mana] then fills[origTex[mana]] = true end
    local cur = mana:GetStatusBarTexture()
    if cur then fills[cur] = true end

    local candidates = {}
    CollectRegions(PlayerFrame, 0, candidates)
    for _, obj in ipairs(candidates) do
        if not fills[obj] and obj ~= mana and not hooked[obj] and AnchoredTo(obj, fills) then
            local t = obj:GetObjectType()
            if t == "Texture" or t == "StatusBar" then
                costs[#costs + 1] = obj
                HookCostTree(obj)
            end
        end
    end
    -- Nombres de Blizzard, que Forever conserva para el coste.
    for _, obj in ipairs({ mana.ManaCostPredictionBar, PlayerFrame.myManaCostPredictionBar,
                           _G.PlayerFrameManaCostPredictionBar }) do
        if obj and not hooked[obj] then
            costs[#costs + 1] = obj
            HookCostTree(obj)
        end
    end
end

local function RefreshPlayer()
    if not IAMHUNTER then return end
    local mana = FindPowerBar(PlayerFrame)
    if mana then
        Hook(mana)
        FindCostBars(mana)
    end
    for _, bar in ipairs(bars) do Paint(bar) end
    for _, c in ipairs(costs) do PaintCost(c) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
f:SetScript("OnEvent", function()
    -- Pequeño retraso para que el PlayerFrame de Forever termine de montarse.
    C_Timer.After(0.5, function() pcall(RefreshPlayer) end)
end)

---------------------------------------------------------------------------
-- Otros marcos (objetivo, objetivo del objetivo, foco, grupo): esas barras se
-- reutilizan para cualquier unidad, así que no las tocamos. Encima ponemos
-- una barra naranja propia que copia su valor y solo se ve cuando la unidad
-- mostrada es un cazador (tú u otro jugador).
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

local function MakeOverlay(bar)
    local ov = CreateFrame("StatusBar", nil, bar)
    ov:SetAllPoints(bar)
    ov:SetFrameLevel(bar:GetFrameLevel())
    if bar.GetOrientation then ov:SetOrientation(bar:GetOrientation()) end
    if bar.GetReverseFill then ov:SetReverseFill(bar:GetReverseFill()) end
    ov:SetStatusBarTexture(LISO)
    ov:SetStatusBarColor(R, G, B)
    -- Mismas máscaras (bordes redondeados) que el relleno original.
    local src, dst = bar:GetStatusBarTexture(), ov:GetStatusBarTexture()
    if src and dst and src.GetNumMaskTextures then
        for i = 1, src:GetNumMaskTextures() do
            local m = src:GetMaskTexture(i)
            if m then dst:AddMaskTexture(m) end
        end
    end
    hooksecurefunc(bar, "SetMinMaxValues", function(_, a, b) ov:SetMinMaxValues(a, b) end)
    hooksecurefunc(bar, "SetValue", function(_, v) ov:SetValue(v) end)
    ov:SetMinMaxValues(bar:GetMinMaxValues())
    ov:SetValue(bar:GetValue())
    ov:Hide()
    return ov
end

local function UpdateOthers()
    for _, def in ipairs(OtherFrames()) do
        local frame, unit = def[1], def[2]
        if frame then
            unit = frame.unit or unit
            local show = frame:IsVisible() and IsHunter(unit)
            local o = others[frame]
            if show and not o then
                local bar = frame.manabar or frame.ManaBar
                if not bar or bar:GetObjectType() ~= "StatusBar" then
                    bar = FindPowerBar(frame)
                end
                if bar then
                    o = { bar = bar, ov = MakeOverlay(bar) }
                    others[frame] = o
                end
            end
            if o then
                if show then
                    o.ov:SetMinMaxValues(o.bar:GetMinMaxValues())
                    o.ov:SetValue(o.bar:GetValue())
                end
                o.ov:SetShown(show and true or false)
            end
        end
    end
end

-- Marcos de banda / grupo compactos: el juego pone el color en cada
-- actualización, así que basta con teñir después si es cazador.
if CompactUnitFrame_UpdatePowerColor then
    hooksecurefunc("CompactUnitFrame_UpdatePowerColor", function(frame)
        local bar = frame and frame.powerBar
        local unit = frame and (frame.displayedUnit or frame.unit)
        if bar and unit and IsHunter(unit) then
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
    C_Timer.After(0, function() pcall(UpdateOthers) end)
end)
