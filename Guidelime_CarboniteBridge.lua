--[[
Guidelime_CarboniteBridge.lua v6

Objetivo:
  Mostrar en el mapa de Carbonite los marcadores numerados de pasos de Guidelime
  que aparecen en el mapa original de World of Warcraft Classic/TBC.

Cambios v6:
  - Corrige el falso positivo real observado en guias con pasos DO:.
  - En modo smart se omiten los GOTO/LOC dinamicos que Guidelime genera desde
    objetivos de mision, mobs, items u objetos, porque Carbonite/Questie ya los muestran.
  - Anota los mapIcons envolviendo M.addMapIcon para distinguir ruta real de objetivo.
  - La flecha ya no acepta elementos attached/objective salvo ACCEPT/TURNIN.

Instalacion:
  1) Copia este archivo dentro de: Interface\AddOns\Guidelime\
  2) Edita Guidelime-TBC.toc y añade al final:
       Guidelime_CarboniteBridge.lua
  3) /reload
  4) /glcarb status

Comandos:
  /glcarb status        Estado y conteo de pines copiados.
  /glcarb refresh       Reconstruye los pines desde Guidelime.
  /glcarb on            Activa la capa.
  /glcarb off           Desactiva y limpia la capa.
  /glcarb smart         Modo recomendado: solo pasos de guia, no objetivos de mobs/loot.
  /glcarb all           Modo diagnostico: copia todos los tipos de Guidelime.
  /glcarb size          Muestra la escala global actual.
  /glcarb size 1.60     Cambia la escala global. Rango recomendado: 1.20 a 2.00.
  /glcarb stepsize      Muestra la escala relativa de los pasos numerados.
  /glcarb stepsize 1.00 Hace que los pasos numerados tengan el tamaño base de la flecha.
  /glcarb stepsize 1.20 Hace los pasos un 20% mas grandes que el tamaño base.
  /glcarb arrowsize     Muestra la escala relativa solo de la flecha.
  /glcarb arrowsize 1.00 Flecha con tamaño base.
  /glcarb arrowsize 1.20 Flecha un 20% mas grande sin tocar pasos numerados.
  /glcarb arrow on      Muestra el primer punto activo/flecha verde de Guidelime.
  /glcarb arrow off     Oculta ese pin adicional.
  /glcarb arrowmode route Solo usa como flecha los waypoints de ruta GOTO/LOC. Recomendado.
  /glcarb arrowmode any  Comportamiento antiguo: acepta cualquier arrowFrame.element.
  /glcarb debug         Muestra tipos encontrados en addon.M.mapIcons.

Notas tecnicas:
  - Debe cargarse dentro del addon Guidelime porque addon.M.mapIcons no es una API global publica.
  - Convierte mapID+x/y de Guidelime a coordenadas mundo de Carbonite con Nx.Map:GetWorldPos().
  - Copia el texcoord del atlas de Guidelime para conservar los numeros 1,2,3...
  - Por defecto, solo convierte en flecha los waypoints de ruta GOTO/LOC.
--]]

local addonName, addon = ...
if addonName ~= "Guidelime" or type(addon) ~= "table" then return end

local BRIDGE_NAME = "GuidelimeCarboniteBridge"
local VERSION = "v6"

local MAX_MAP_INDEX = 58
local SPECIAL_MAP_INDEX = {
    monster = 60,
    item = 61,
    object = 62,
    npc = 63,
    LOC = 63,
    ACCEPT = 59,
    TURNIN = 59,
}

-- Modo recomendado: evita duplicar objetivos que Carbonite/Questie ya pintan.
-- GOTO es lo importante para los pasos numerados. LOC/ACCEPT/TURNIN/npc se dejan
-- porque tambien pueden formar parte del paso activo de Guidelime.
local SMART_TYPES = {
    GOTO = true,
    LOC = true,
    ACCEPT = true,
    TURNIN = true,
    npc = true,
}

local provider
local installed = false
local hooked = false
local addMapIconWrapped = false
local syncPending = false
local warnedNoCarbonite = false
local lastCount = 0
local lastArrowCount = 0
local lastTypeCounts = {}
local lastSkipped = 0
local lastRouteArrowFromMapIcons = 0
local lastRouteArrowPos = nil
local lastArrowSource = ""
local lastRawArrowType = ""
local lastArrowSkipReason = ""
local frame = CreateFrame("Frame")

local function printMsg(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80ff80Guidelime->Carbonite|r " .. VERSION .. ": " .. tostring(msg))
    end
end

local function later(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
        return
    end
    local elapsedTotal = 0
    local waitFrame = CreateFrame("Frame")
    waitFrame:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

local function clamp(n, lo, hi)
    n = tonumber(n)
    if not n then return nil end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function ensureDB()
    if GuidelimeData == nil then GuidelimeData = {} end
    if GuidelimeData.carboniteBridgeEnabled == nil then
        GuidelimeData.carboniteBridgeEnabled = true
    end
    if GuidelimeData.carboniteBridgeMode == nil then
        GuidelimeData.carboniteBridgeMode = "smart"
    end
    if GuidelimeData.carboniteBridgeSizeScale == nil then
        GuidelimeData.carboniteBridgeSizeScale = 1.40
    end
    if GuidelimeData.carboniteBridgeShowArrowPin == nil then
        GuidelimeData.carboniteBridgeShowArrowPin = true
    end
    if GuidelimeData.carboniteBridgeStepSizeScale == nil then
        -- 1.00 = pasos numerados con el mismo tamaño visual base que la flecha/arrowElement.
        GuidelimeData.carboniteBridgeStepSizeScale = 1.00
    end
    if GuidelimeData.carboniteBridgeArrowSizeScale == nil then
        -- 1.00 = flecha con el tamaño visual base. No afecta a los pasos numerados.
        GuidelimeData.carboniteBridgeArrowSizeScale = 1.00
    end
    if GuidelimeData.carboniteBridgeArrowMode == nil then
        -- route = solo GOTO/LOC; evita mostrar como flecha el objetivo activo de una mision.
        GuidelimeData.carboniteBridgeArrowMode = "route"
    end
end

local function bridgeEnabled()
    ensureDB()
    return GuidelimeData.carboniteBridgeEnabled == true
end

local function bridgeMode()
    ensureDB()
    return GuidelimeData.carboniteBridgeMode or "smart"
end

local function bridgeSizeScale()
    ensureDB()
    return clamp(GuidelimeData.carboniteBridgeSizeScale, 0.50, 3.00) or 1.40
end

local function bridgeStepSizeScale()
    ensureDB()
    return clamp(GuidelimeData.carboniteBridgeStepSizeScale, 0.50, 3.00) or 1.00
end

local function bridgeArrowSizeScale()
    ensureDB()
    return clamp(GuidelimeData.carboniteBridgeArrowSizeScale, 0.50, 3.00) or 1.00
end

local function bridgeShowArrowPin()
    ensureDB()
    return GuidelimeData.carboniteBridgeShowArrowPin ~= false
end

local function bridgeArrowMode()
    ensureDB()
    local mode = tostring(GuidelimeData.carboniteBridgeArrowMode or "route"):lower()
    if mode ~= "route" and mode ~= "any" then mode = "route" end
    return mode
end

local function safeUpper(v)
    if v == nil then return "" end
    return string.upper(tostring(v))
end

local function stepLooksLikeDo(step)
    if type(step) ~= "table" then return false end

    local fields = {
        step.action, step.command, step.cmd, step.t, step.typ, step.type, step.keyword, step.tag, step.mode
    }
    for _, v in ipairs(fields) do
        local u = safeUpper(v)
        if u == "DO" or u == "COMPLETE" or u == "OBJECTIVE" then
            return true
        end
    end

    -- Fallback conservador: solo para textos que empiezan claramente por DO:.
    -- No se usa para ACCEPT/TURNIN.
    local txt
    if addon.CG and type(addon.CG.getStepText) == "function" then
        local ok, r = pcall(addon.CG.getStepText, step)
        if ok then txt = r end
    end
    if type(txt) == "string" and txt:match("^%s*[Dd][Oo]%s*:") then
        return true
    end

    return false
end

local function isQuestObjectiveElement(e)
    if type(e) ~= "table" then return false end

    local attached = e.attached
    local attachedT = attached and safeUpper(attached.t) or ""
    local markerTyp = safeUpper(e.markerTyp)
    local et = safeUpper(e.t)
    local eType = safeUpper(e.type)

    -- ACCEPT/TURNIN/npc son pasos de ruta útiles; no se consideran objetivos DO.
    if attachedT == "ACCEPT" or attachedT == "TURNIN" or markerTyp == "ACCEPT" or markerTyp == "TURNIN" or et == "ACCEPT" or et == "TURNIN" then
        return false
    end

    -- Guidelime genera posiciones dinamicas de misiones para pasos DO mediante
    -- element.attached / element.objectives / element.type. Esos puntos ya los cubre
    -- Carbonite/Questie y no deben convertirse en flecha de ruta.
    if eType == "COLLECT_ITEM" or eType == "TARGET" or eType == "KILL" or eType == "LOOT" then
        return true
    end
    if attached then
        if attached.objective ~= nil or attached.finished ~= nil then return true end
        if attachedT ~= "" and attachedT ~= "ACCEPT" and attachedT ~= "TURNIN" then return true end
    end
    if e.objectives ~= nil or e.objective ~= nil or e.objectId ~= nil or e.itemId ~= nil then
        return true
    end

    -- Si el elemento pertenece a un paso DO:, aunque sea t=GOTO/LOC, lo tratamos
    -- como objetivo de mision, no como waypoint de ruta.
    if stepLooksLikeDo(e.step) then
        return true
    end

    return false
end

local function hasCarboniteProviderAPI()
    return type(Carbonite) == "table"
        and type(Carbonite.Map) == "table"
        and type(Carbonite.Map.CreateProvider) == "function"
end

local function tryLoadCarbonite()
    if hasCarboniteProviderAPI() then return true end

    local loaders = { "Carbonite", "CarboniteAllinOneRetailClassic" }
    for _, name in ipairs(loaders) do
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, name)
        elseif LoadAddOn then
            pcall(LoadAddOn, name)
        end
        if hasCarboniteProviderAPI() then return true end
    end

    return hasCarboniteProviderAPI()
end

local function defaultMarkerTexture(styleType)
    local style = 1
    if GuidelimeData then
        style = GuidelimeData["mapMarkerStyle" .. styleType] or style
    end
    local key = "MAP_MARKER_" .. tostring(style)
    return addon.icons and (addon.icons[key] or addon.icons.MAP_MARKER_1 or addon.icons.MAP or addon.icons.LOC)
end

local function defaultSize(styleType, active, arrow)
    local size = 18
    if GuidelimeData then
        size = tonumber(GuidelimeData["mapMarkerSize" .. styleType]) or size
    end
    size = size * bridgeSizeScale()
    if active then size = size + (4 * bridgeSizeScale()) end
    if arrow then size = size + (8 * bridgeSizeScale()) end
    return math.floor(size + 0.5)
end

local function arrowBaseDisplaySize()
    -- Tamaño base comun usado para igualar visualmente flecha y pasos cuando
    -- arrowsize=1.00 y stepsize=1.00. Incluye /glcarb size.
    return defaultSize("GOTO", true, true)
end

local function arrowDisplaySize()
    -- /glcarb arrowsize solo modifica la flecha/primer punto activo.
    return math.floor((arrowBaseDisplaySize() * bridgeArrowSizeScale()) + 0.5)
end

local function stepDisplaySize(styleType, active)
    -- /glcarb stepsize solo modifica los pasos numerados.
    -- No depende de arrowsize, para que arrowsize sea realmente solo flecha.
    return math.floor((arrowBaseDisplaySize() * bridgeStepSizeScale()) + 0.5)
end

local function defaultAlpha(styleType)
    local alpha = 1
    if GuidelimeData then
        alpha = tonumber(GuidelimeData["mapMarkerAlpha" .. styleType]) or alpha
    end
    if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
    return alpha
end

local function alphaColor(alpha)
    local a = math.floor((alpha or 1) * 255 + 0.5)
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return string.format("%02xFFFFFF", a)
end

local function definePins(p)
    local tex = defaultMarkerTexture("GOTO")
    local stepSize = stepDisplaySize("GOTO", false)
    local arrowSize = arrowDisplaySize()

    -- Importante: algunas versiones de Carbonite usan el tamano de DefinePin y no
    -- el w/h dinamico de cada Add(). Por eso StepWP/StepActiveWP se definen ya al
    -- tamano de la flecha. El w/h dinamico de Add() queda como respaldo.
    p:DefinePin("StepWP",       { tex = tex, w = stepSize,  h = stepSize,  drawMode = "WP", alpha = 1, frameLvl = 65, noDockMinimap = true })
    p:DefinePin("StepActiveWP", { tex = tex, w = stepSize,  h = stepSize,  drawMode = "WP", alpha = 1, frameLvl = 85, noDockMinimap = true })
    p:DefinePin("ArrowWP",      { tex = tex, w = arrowSize, h = arrowSize, drawMode = "WP", alpha = 1, frameLvl = 95, noDockMinimap = true })
    p:DefinePin("StepZP",       { tex = tex, w = stepSize,  h = stepSize,  drawMode = "ZP", alpha = 1, frameLvl = 65, noDockMinimap = true })
    p:DefinePin("StepActiveZP", { tex = tex, w = stepSize,  h = stepSize,  drawMode = "ZP", alpha = 1, frameLvl = 85, noDockMinimap = true })
    p:DefinePin("ArrowZP",      { tex = tex, w = arrowSize, h = arrowSize, drawMode = "ZP", alpha = 1, frameLvl = 95, noDockMinimap = true })
end

local function ensureProvider()
    if provider then return provider end
    if not tryLoadCarbonite() then return nil end

    local ok, p = pcall(function()
        return Carbonite.Map:CreateProvider(BRIDGE_NAME)
    end)
    if not ok or not p then return nil end

    provider = p
    pcall(definePins, provider)
    if provider.SetEnabled then provider:SetEnabled(true) end
    return provider
end

local function redefinePinsSafe()
    if provider then
        pcall(definePins, provider)
    end
end

local function clearProvider()
    if provider and provider.Clear then
        pcall(provider.Clear, provider)
    end
    lastCount = 0
    lastArrowCount = 0
    lastSkipped = 0
    lastRouteArrowFromMapIcons = 0
    lastRouteArrowPos = nil
    lastArrowSource = ""
    lastRawArrowType = ""
    lastArrowSkipReason = ""
    wipe(lastTypeCounts)
end

local function markerIndexForType(t, index)
    local idx = tonumber(index) or 1
    if t ~= "GOTO" then
        idx = SPECIAL_MAP_INDEX[t] or SPECIAL_MAP_INDEX.LOC
    elseif idx > MAX_MAP_INDEX then
        idx = SPECIAL_MAP_INDEX.LOC
    elseif idx < 0 then
        idx = 0
    end
    return idx
end

local function texCoordsForMarker(t, index)
    local idx = markerIndexForType(t, index)
    local col = idx % 8
    local row = math.floor(idx / 8)
    -- Carbonite llama SetTexCoord(tx1, ty1, tx2, ty2). En la API de WoW
    -- de 4 argumentos esto equivale a left, right, top, bottom.
    return col / 8, (col + 1) / 8, row / 8, (row + 1) / 8
end

local function styleTypeFor(t)
    if t == "GOTO" then return "GOTO" end
    return "LOC"
end

local function shouldMirrorType(t)
    if bridgeMode() ~= "all" and not SMART_TYPES[t] then
        return false
    end

    local st = styleTypeFor(t)
    if GuidelimeData and GuidelimeData["showMapMarkers" .. st] == false then
        return false
    end

    return true
end

local function shouldMirrorMapIcon(t, mapIcon)
    if not shouldMirrorType(t) then return false end

    -- En modo smart no copiamos objetivos DO generados dinamicamente desde
    -- misiones/mobs/items/objects. Esos puntos ya los muestra Carbonite/Questie
    -- y, si se copian como index 0, parecen una segunda flecha de Guidelime.
    if bridgeMode() == "smart" and mapIcon and isQuestObjectiveElement(mapIcon._glcarbElement) then
        return false
    end

    return true
end

local function getTooltip(mapIcon)
    local tip
    if mapIcon and mapIcon.map then tip = mapIcon.map.tooltip end
    if (tip == nil or tip == "") and mapIcon and mapIcon.minimap then tip = mapIcon.minimap.tooltip end
    if tip == nil or tip == "" then tip = "Guidelime" end
    return "|cff80ff80Guidelime|r\n" .. tostring(tip)
end

local function getElementTooltip(element)
    local tip
    if addon.M and type(addon.M.getMapTooltip) == "function" then
        local ok, result = pcall(addon.M.getMapTooltip, element)
        if ok then tip = result end
    end
    if tip == nil or tip == "" then tip = "Primer punto activo de Guidelime" end
    return "|cff80ff80Guidelime|r\n" .. tostring(tip)
end

local function getCarboniteMapObject()
    if not (_G.Nx and Nx.Map) then return nil end

    if type(Nx.Map.GetMap) == "function" then
        local ok, map = pcall(function() return Nx.Map:GetMap(1) end)
        if ok and type(map) == "table" then return map end
    end

    return Nx.Map
end

local function getCarboniteCurrentMapID()
    if not (_G.Nx and Nx.Map) then return nil end

    local ok, mapID = pcall(function()
        local m = getCarboniteMapObject()
        return (m and (m.MapId or m.UpdateMapID or m.RMapId))
            or Nx.Map.RMapId
            or Nx.Map.UpdateMapID
            or (type(Nx.Map.GetCurrentMapAreaID) == "function" and Nx.Map:GetCurrentMapAreaID())
    end)

    if ok and (type(mapID) == "number" or type(mapID) == "string") then
        return tonumber(mapID)
    end
    return nil
end

local function carboniteWorldPos(mapID, x, y)
    mapID = tonumber(mapID)
    x = tonumber(x)
    y = tonumber(y)
    if not mapID or not x or not y then return nil end

    local map = getCarboniteMapObject()
    if map and type(map.GetWorldPos) == "function" then
        local ok, wx, wy = pcall(function() return map:GetWorldPos(mapID, x, y) end)
        if ok and tonumber(wx) and tonumber(wy) and not (wx == 0 and wy == 0 and x ~= 0 and y ~= 0) then
            return tonumber(wx), tonumber(wy)
        end
    end

    if _G.Nx and Nx.Map and type(Nx.Map.GetWorldPos) == "function" then
        local ok, wx, wy = pcall(function() return Nx.Map:GetWorldPos(mapID, x, y) end)
        if ok and tonumber(wx) and tonumber(wy) and not (wx == 0 and wy == 0 and x ~= 0 and y ~= 0) then
            return tonumber(wx), tonumber(wy)
        end
    end

    return nil
end

local function isRouteArrowType(t)
    return t == "GOTO" or t == "LOC"
end

local function isRouteActiveMarker(t, mapIcon)
    return isRouteArrowType(t) and mapIcon and tonumber(mapIcon.index) == 0
end

local function pinKind(mapIcon, useWorld, t)
    local active = mapIcon and tonumber(mapIcon.index) == 0
    if isRouteActiveMarker(t, mapIcon) and not isQuestObjectiveElement(mapIcon._glcarbElement) then
        return useWorld and "ArrowWP" or "ArrowZP"
    end
    if useWorld then
        return active and "StepActiveWP" or "StepWP"
    end
    return active and "StepActiveZP" or "StepZP"
end

local function addPinAt(p, kindWorld, kindZone, mapID, x, y, opts)
    local wx, wy = carboniteWorldPos(mapID, x, y)
    if wx and wy then
        p:Add(kindWorld, wx, wy, opts)
        return true
    end

    -- Fallback limitado: ZP solo tiene sentido si Carbonite esta mostrando el mismo mapa.
    local currentMapID = getCarboniteCurrentMapID()
    if currentMapID == nil or currentMapID == tonumber(mapID) then
        p:Add(kindZone, x, y, opts)
        return true
    end

    return false
end

local function addCarbonitePin(p, t, mapIcon)
    if type(mapIcon) ~= "table" or not mapIcon.inUse then return false end
    if not shouldMirrorMapIcon(t, mapIcon) then return false end

    local mapID = tonumber(mapIcon.mapID)
    local x = tonumber(mapIcon.x)
    local y = tonumber(mapIcon.y)
    if not mapID or not x or not y then return false end

    local st = styleTypeFor(t)
    local routeActive = isRouteActiveMarker(t, mapIcon) and not isQuestObjectiveElement(mapIcon._glcarbElement)
    local tx1, ty1, tx2, ty2
    local size

    if routeActive then
        -- El indice 0 de GOTO/LOC es la flecha verde real de ruta. Usa arrowsize,
        -- no stepsize, y no lo trates como un paso numerado normal.
        tx1, ty1, tx2, ty2 = texCoordsForMarker("GOTO", 0)
        size = arrowDisplaySize()
    else
        tx1, ty1, tx2, ty2 = texCoordsForMarker(t, mapIcon.index)
        size = stepDisplaySize(st, tonumber(mapIcon.index) == 0)
    end

    local opts = {
        mapID = mapID,
        tip = getTooltip(mapIcon),
        tex = defaultMarkerTexture(st),
        tx1 = tx1,
        ty1 = ty1,
        tx2 = tx2,
        ty2 = ty2,
        w = size,
        h = size,
        color = alphaColor(defaultAlpha(st)),
        userData = { source = "Guidelime", type = routeActive and "ARROW_MAPICON" or t, index = mapIcon.index, mapID = mapID, x = x, y = y },
    }

    local added = addPinAt(p, pinKind(mapIcon, true, t), pinKind(mapIcon, false, t), mapID, x, y, opts)
    if added and routeActive then
        lastRouteArrowFromMapIcons = lastRouteArrowFromMapIcons + 1
        lastRouteArrowPos = { mapID = mapID, x = x, y = y }
    end
    return added
end

local function elementHasMapPos(e)
    return type(e) == "table" and e.mapID and e.x and e.y
end

local function arrowElementAllowed(e)
    if not elementHasMapPos(e) then return false end
    if bridgeArrowMode() == "any" then return true end
    return isRouteArrowType(e.t) and not isQuestObjectiveElement(e)
end

local function sameMapPoint(a, b)
    if not a or not b then return false end
    if tonumber(a.mapID) ~= tonumber(b.mapID) then return false end
    local ax, ay = tonumber(a.x), tonumber(a.y)
    local bx, by = tonumber(b.x), tonumber(b.y)
    if not ax or not ay or not bx or not by then return false end
    local tol = (ax > 1 or ay > 1 or bx > 1 or by > 1) and 0.10 or 0.001
    return math.abs(ax - bx) <= tol and math.abs(ay - by) <= tol
end

local function getArrowElement()
    local M = addon.M
    lastArrowSource = ""
    lastRawArrowType = ""
    lastArrowSkipReason = ""

    if type(M) ~= "table" then return nil end

    if M.arrowFrame and type(M.arrowFrame.element) == "table" then
        local e = M.arrowFrame.element
        lastRawArrowType = tostring(e.t)
        if arrowElementAllowed(e) then
            lastArrowSource = "arrowFrame.element"
            return e
        elseif elementHasMapPos(e) then
            lastArrowSkipReason = "arrowFrame.element omitido: t=" .. tostring(e.t) .. ", attached=" .. tostring(e.attached and e.attached.t) .. ", type=" .. tostring(e.type) .. ", do/objective=" .. tostring(isQuestObjectiveElement(e)) .. ", arrowmode=" .. bridgeArrowMode()
        end
    end

    -- Fallback: busca solo un waypoint de ruta real. En v5 tambien aceptaba
    -- ACCEPT/TURNIN y eso podia convertir el objetivo activo de mision en flecha.
    local CG = addon.CG
    if type(CG) == "table" and type(CG.currentGuide) == "table" and type(CG.currentGuide.steps) == "table" then
        for _, step in ipairs(CG.currentGuide.steps) do
            if not step.skip and not step.completed and step.available and step.active and type(step.elements) == "table" then
                for _, element in ipairs(step.elements) do
                    if not element.completed and arrowElementAllowed(element) then
                        lastArrowSource = "active guide step"
                        return element
                    end
                end
            end
        end
    end

    if lastArrowSkipReason == "" then lastArrowSkipReason = "sin waypoint de ruta GOTO/LOC" end
    return nil
end

local function addArrowPin(p)
    if not bridgeShowArrowPin() then return 0 end

    local element = getArrowElement()
    if type(element) ~= "table" then return 0 end

    if bridgeArrowMode() == "route" and lastRouteArrowPos and sameMapPoint(element, lastRouteArrowPos) then
        lastArrowSkipReason = "arrowFrame omitido: la flecha de ruta ya venia de mapIcons"
        return 0
    end

    local mapID = tonumber(element.mapID)
    local x = tonumber(element.x)
    local y = tonumber(element.y)
    if not mapID or not x or not y then return 0 end

    -- En Guidelime el punto activo/highlight usa el indice 0 del atlas de marcadores.
    -- Ese indice es el que se ve como flecha/indicador verde en el mapa original.
    local tx1, ty1, tx2, ty2 = texCoordsForMarker("GOTO", 0)
    local size = arrowDisplaySize()
    local opts = {
        mapID = mapID,
        tip = getElementTooltip(element),
        tex = defaultMarkerTexture("GOTO"),
        tx1 = tx1,
        ty1 = ty1,
        tx2 = tx2,
        ty2 = ty2,
        w = size,
        h = size,
        color = alphaColor(defaultAlpha("GOTO")),
        userData = { source = "Guidelime", type = "ARROW", index = 0, mapID = mapID, x = x, y = y },
    }

    if addPinAt(p, "ArrowWP", "ArrowZP", mapID, x, y, opts) then
        return 1
    end
    return 0
end

local function updateStepsMapIconsSafe()
    if addon.M and type(addon.M.updateStepsMapIcons) == "function" then
        pcall(addon.M.updateStepsMapIcons)
    end
end

local function syncNow()
    syncPending = false

    if not bridgeEnabled() then
        clearProvider()
        return
    end

    local p = ensureProvider()
    if not p then
        if not warnedNoCarbonite then
            warnedNoCarbonite = true
            printMsg("Carbonite no esta listo o no expone Carbonite.Map:CreateProvider(). Actualiza Carbonite y usa /reload.")
        end
        return
    end

    local M = addon.M
    if type(M) ~= "table" or type(M.mapIcons) ~= "table" then
        clearProvider()
        return
    end

    p:Clear()
    wipe(lastTypeCounts)
    lastSkipped = 0
    lastArrowCount = 0
    lastRouteArrowFromMapIcons = 0
    lastRouteArrowPos = nil
    lastArrowSource = ""
    lastRawArrowType = ""
    lastArrowSkipReason = ""

    local count = 0
    for t, icons in pairs(M.mapIcons) do
        if type(icons) == "table" then
            -- Mismo orden visual que Guidelime: indices altos primero, activos al final/encima.
            for i = #icons, 0, -1 do
                local mapIcon = icons[i]
                if mapIcon then
                    if addCarbonitePin(p, t, mapIcon) then
                        count = count + 1
                        lastTypeCounts[t] = (lastTypeCounts[t] or 0) + 1
                    elseif mapIcon.inUse then
                        lastSkipped = lastSkipped + 1
                    end
                end
            end
            -- Por seguridad, tambien cubre tablas no secuenciales.
            for i, mapIcon in pairs(icons) do
                if type(i) ~= "number" then
                    if addCarbonitePin(p, t, mapIcon) then
                        count = count + 1
                        lastTypeCounts[t] = (lastTypeCounts[t] or 0) + 1
                    elseif type(mapIcon) == "table" and mapIcon.inUse then
                        lastSkipped = lastSkipped + 1
                    end
                end
            end
        end
    end

    lastArrowCount = addArrowPin(p)
    if lastArrowCount > 0 then
        count = count + lastArrowCount
        lastTypeCounts.ARROW = (lastTypeCounts.ARROW or 0) + lastArrowCount
    end

    lastCount = count

    if p.Refresh then
        pcall(p.Refresh, p)
    elseif p.NotifyMapChanged then
        local mapID = getCarboniteCurrentMapID()
        if mapID then pcall(p.NotifyMapChanged, p, mapID) end
    end
end

local function scheduleSync(delay)
    if syncPending then return end
    syncPending = true
    later(delay or 0.05, syncNow)
end

local function wrapGuidelimeAddMapIcon()
    local M = addon.M
    if addMapIconWrapped or type(M) ~= "table" or type(M.addMapIcon) ~= "function" then return end
    addMapIconWrapped = true

    local originalAddMapIcon = M.addMapIcon
    M.addMapIcon = function(element, highlight, ignoreMaxNumOfMarkers)
        local a, b, c, d, e = originalAddMapIcon(element, highlight, ignoreMaxNumOfMarkers)

        if type(element) == "table" and element.mapIndex ~= nil and type(M.mapIcons) == "table" then
            local iconType = element.markerTyp or element.t
            local icons = M.mapIcons[iconType]
            local mapIcon = type(icons) == "table" and icons[element.mapIndex]
            if type(mapIcon) == "table" then
                mapIcon._glcarbElement = element
                mapIcon._glcarbHighlight = highlight and true or false
                mapIcon._glcarbElementT = element.t
                mapIcon._glcarbMarkerTyp = element.markerTyp
                mapIcon._glcarbAttachedT = element.attached and element.attached.t
                mapIcon._glcarbElementType = element.type
                mapIcon._glcarbStepActive = element.step and element.step.active
                mapIcon._glcarbIsQuestObjective = isQuestObjectiveElement(element)
            end
        end

        return a, b, c, d, e
    end
end

local function installBridge()
    if installed then return true end
    if type(addon.M) ~= "table" then return false end
    if not ensureProvider() then return false end
    wrapGuidelimeAddMapIcon()

    if not hooked then
        hooked = true

        if type(addon.M.updateStepsMapIcons) == "function" then
            hooksecurefunc(addon.M, "updateStepsMapIcons", function()
                scheduleSync(0.05)
            end)
        end

        if type(addon.M.showMapIcons) == "function" then
            hooksecurefunc(addon.M, "showMapIcons", function()
                scheduleSync(0.05)
            end)
        end

        if type(addon.M.showArrow) == "function" then
            hooksecurefunc(addon.M, "showArrow", function()
                scheduleSync(0.05)
            end)
        end

        if type(addon.M.hideArrow) == "function" then
            hooksecurefunc(addon.M, "hideArrow", function()
                scheduleSync(0.05)
            end)
        end

        if type(addon.M.setMapIconTextures) == "function" then
            hooksecurefunc(addon.M, "setMapIconTextures", function()
                -- Releer tamaño/alpha/texture si cambias opciones de Guidelime.
                scheduleSync(0.05)
            end)
        end

        if type(addon.M.removeMapIcons) == "function" then
            hooksecurefunc(addon.M, "removeMapIcons", function()
                clearProvider()
            end)
        end

        if addon.CG and type(addon.CG.updateSteps) == "function" then
            hooksecurefunc(addon.CG, "updateSteps", function()
                scheduleSync(0.10)
            end)
        end
    end

    installed = true
    warnedNoCarbonite = false
    printMsg("puente activo en modo " .. bridgeMode() .. ", size=" .. string.format("%.2f", bridgeSizeScale()) .. ", stepsize=" .. string.format("%.2f", bridgeStepSizeScale()) .. ", arrowsize=" .. string.format("%.2f", bridgeArrowSizeScale()) .. ", arrow=" .. tostring(bridgeShowArrowPin()) .. ", arrowmode=" .. bridgeArrowMode() .. ".")

    updateStepsMapIconsSafe()
    scheduleSync(0.20)
    return true
end

local function tryInstallSoon()
    if installed then return end
    if installBridge() then return end
    later(1.0, function()
        if not installed then installBridge() end
    end)
end

local function typeCountString()
    local out = {}
    for k, v in pairs(lastTypeCounts) do
        out[#out + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(out)
    if #out == 0 then return "sin tipos" end
    return table.concat(out, ", ")
end

local function debugMapIcons()
    local M = addon.M
    if type(M) ~= "table" or type(M.mapIcons) ~= "table" then
        printMsg("addon.M.mapIcons no esta disponible.")
        return
    end

    for t, icons in pairs(M.mapIcons) do
        local total, inUse = 0, 0
        if type(icons) == "table" then
            for _, icon in pairs(icons) do
                if type(icon) == "table" then
                    total = total + 1
                    if icon.inUse then inUse = inUse + 1 end
                end
            end
        end
        printMsg("tipo " .. tostring(t) .. ": total=" .. total .. ", inUse=" .. inUse .. ", mirrorTipo=" .. tostring(shouldMirrorType(t)))
        if type(icons) == "table" then
            for i, icon in pairs(icons) do
                if type(icon) == "table" and icon.inUse and icon._glcarbIsQuestObjective then
                    printMsg("  omitido smart candidato: tipo=" .. tostring(t) .. ", index=" .. tostring(i) .. ", e.t=" .. tostring(icon._glcarbElementT) .. ", markerTyp=" .. tostring(icon._glcarbMarkerTyp) .. ", attached=" .. tostring(icon._glcarbAttachedT) .. ", e.type=" .. tostring(icon._glcarbElementType) .. ", stepActive=" .. tostring(icon._glcarbStepActive))
                end
            end
        end
    end

    local raw = addon.M and addon.M.arrowFrame and addon.M.arrowFrame.element
    if raw then
        printMsg("raw arrowFrame.element: t=" .. tostring(raw.t) .. ", attached=" .. tostring(raw.attached and raw.attached.t) .. ", e.type=" .. tostring(raw.type) .. ", do/objective=" .. tostring(isQuestObjectiveElement(raw)) .. ", mapID=" .. tostring(raw.mapID) .. ", x=" .. tostring(raw.x) .. ", y=" .. tostring(raw.y) .. ", routeAllowed=" .. tostring(arrowElementAllowed(raw)))
    else
        printMsg("raw arrowFrame.element: no encontrado")
    end

    local ae = getArrowElement()
    if ae then
        printMsg("selected arrowElement: t=" .. tostring(ae.t) .. ", attached=" .. tostring(ae.attached and ae.attached.t) .. ", e.type=" .. tostring(ae.type) .. ", do/objective=" .. tostring(isQuestObjectiveElement(ae)) .. ", source=" .. tostring(lastArrowSource) .. ", mapID=" .. tostring(ae.mapID) .. ", x=" .. tostring(ae.x) .. ", y=" .. tostring(ae.y) .. ", completed=" .. tostring(ae.completed))
    else
        printMsg("selected arrowElement: no encontrado; reason=" .. tostring(lastArrowSkipReason))
    end
end

_G.SLASH_GLIME_CARBONITE_BRIDGE1 = "/glcarb"
SlashCmdList.GLIME_CARBONITE_BRIDGE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""
    ensureDB()

    local sizeArg = msg:match("^size%s+([%d%.]+)$") or msg:match("^scale%s+([%d%.]+)$")
    local stepSizeArg = msg:match("^stepsize%s+([%d%.]+)$") or msg:match("^stepscale%s+([%d%.]+)$")
    local arrowSizeArg = msg:match("^arrowsize%s+([%d%.]+)$") or msg:match("^arrowscale%s+([%d%.]+)$")
    local arrowArg = msg:match("^arrow%s+(%S+)$")
    local arrowModeArg = msg:match("^arrowmode%s+(%S+)$") or msg:match("^arrowtarget%s+(%S+)$")

    if msg == "on" then
        GuidelimeData.carboniteBridgeEnabled = true
        tryInstallSoon()
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("activado.")
    elseif msg == "off" then
        GuidelimeData.carboniteBridgeEnabled = false
        clearProvider()
        printMsg("desactivado; capa limpiada.")
    elseif msg == "smart" then
        GuidelimeData.carboniteBridgeMode = "smart"
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("modo smart: solo pasos de Guidelime, evitando objetivos duplicados de Questie.")
    elseif msg == "all" then
        GuidelimeData.carboniteBridgeMode = "all"
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("modo all: copia todos los tipos de Guidelime; util para diagnostico.")
    elseif msg == "refresh" or msg == "r" then
        tryInstallSoon()
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("refresco solicitado.")
    elseif msg == "debug" then
        debugMapIcons()
    elseif msg == "size" or msg == "scale" then
        printMsg("size=" .. string.format("%.2f", bridgeSizeScale()) .. ". Cambialo con /glcarb size 1.60. Rango: 0.50-3.00; recomendado 1.20-2.00.")
    elseif sizeArg then
        GuidelimeData.carboniteBridgeSizeScale = clamp(sizeArg, 0.50, 3.00) or 1.40
        redefinePinsSafe()
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("size=" .. string.format("%.2f", bridgeSizeScale()) .. "; refrescando iconos.")
    elseif msg == "stepsize" or msg == "stepscale" then
        printMsg("stepsize=" .. string.format("%.2f", bridgeStepSizeScale()) .. ". 1.00 = tamano base de la flecha, sin depender de arrowsize. Cambialo con /glcarb stepsize 1.20. Rango: 0.50-3.00.")
    elseif stepSizeArg then
        GuidelimeData.carboniteBridgeStepSizeScale = clamp(stepSizeArg, 0.50, 3.00) or 1.00
        redefinePinsSafe()
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("stepsize=" .. string.format("%.2f", bridgeStepSizeScale()) .. "; solo pasos numerados. Refrescando iconos.")
    elseif msg == "arrowsize" or msg == "arrowscale" then
        printMsg("arrowsize=" .. string.format("%.2f", bridgeArrowSizeScale()) .. ". 1.00 = tamano base de la flecha. Cambialo con /glcarb arrowsize 1.20. Rango: 0.50-3.00.")
    elseif arrowSizeArg then
        GuidelimeData.carboniteBridgeArrowSizeScale = clamp(arrowSizeArg, 0.50, 3.00) or 1.00
        redefinePinsSafe()
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("arrowsize=" .. string.format("%.2f", bridgeArrowSizeScale()) .. "; solo flecha/primer punto activo. Refrescando iconos.")
    elseif arrowModeArg == "route" or arrowModeArg == "safe" then
        GuidelimeData.carboniteBridgeArrowMode = "route"
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("arrowmode=route: solo GOTO/LOC; evita convertir objetivos activos de mision en flecha.")
    elseif arrowModeArg == "any" or arrowModeArg == "legacy" then
        GuidelimeData.carboniteBridgeArrowMode = "any"
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("arrowmode=any: comportamiento antiguo; acepta cualquier arrowFrame.element.")
    elseif msg == "arrowmode" or msg == "arrowtarget" then
        printMsg("arrowmode=" .. bridgeArrowMode() .. ". Usa /glcarb arrowmode route recomendado, o /glcarb arrowmode any para el comportamiento antiguo.")
    elseif arrowArg == "on" or arrowArg == "1" or arrowArg == "true" then
        GuidelimeData.carboniteBridgeShowArrowPin = true
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("arrow pin activado.")
    elseif arrowArg == "off" or arrowArg == "0" or arrowArg == "false" then
        GuidelimeData.carboniteBridgeShowArrowPin = false
        updateStepsMapIconsSafe()
        scheduleSync(0.05)
        printMsg("arrow pin desactivado.")
    elseif msg == "status" or msg == "" then
        printMsg("enabled=" .. tostring(bridgeEnabled())
            .. ", mode=" .. tostring(bridgeMode())
            .. ", size=" .. string.format("%.2f", bridgeSizeScale())
            .. ", stepsize=" .. string.format("%.2f", bridgeStepSizeScale())
            .. ", arrowsize=" .. string.format("%.2f", bridgeArrowSizeScale())
            .. ", arrowmode=" .. tostring(bridgeArrowMode())
            .. ", stepPx=" .. tostring(stepDisplaySize("GOTO", false))
            .. ", arrowPx=" .. tostring(arrowDisplaySize())
            .. ", arrow=" .. tostring(bridgeShowArrowPin())
            .. ", installed=" .. tostring(installed)
            .. ", wrapped=" .. tostring(addMapIconWrapped)
            .. ", pins=" .. tostring(lastCount)
            .. ", arrowPins=" .. tostring(lastArrowCount)
            .. ", routeArrowMapIcons=" .. tostring(lastRouteArrowFromMapIcons)
            .. ", arrowSource=" .. tostring(lastArrowSource)
            .. ", arrowSkip=" .. tostring(lastArrowSkipReason)
            .. ", skipped=" .. tostring(lastSkipped)
            .. ", carboniteAPI=" .. tostring(hasCarboniteProviderAPI())
            .. ", tipos={" .. typeCountString() .. "}")
    else
        printMsg("comandos: /glcarb on | off | smart | all | refresh | status | debug | size 1.60 | stepsize 1.00 | arrowsize 1.00 | arrow on|off | arrowmode route|any")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == "Carbonite" or loadedAddon == "CarboniteAllinOneRetailClassic" or loadedAddon == "Guidelime" then
            tryInstallSoon()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        tryInstallSoon()
        scheduleSync(0.50)
        return
    end

    if installed then
        scheduleSync(0.25)
    end
end)

-- Si el archivo esta al final del TOC de Guidelime, esto ya deberia funcionar.
tryInstallSoon()
