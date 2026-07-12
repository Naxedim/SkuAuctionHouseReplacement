-- Core.lua — Bootstrap for SkuAuctionHouseReplacement
--
-- Responsibilities:
--   * Apply the active-locale translations into Sku's locale table (Sku.L).
--   * Expose the addon's own localized strings as ns.T (with enUS fallback).
--   * Provide ns.L (Sku's locale) and ns.onReady() for the feature modules.
--   * Load per-character saved variables (ns.db).
--   * Install the French item-name metatable on SkuDB.itemLookup.
--
-- Feature modules (loaded after this file) register their setup via
-- ns.onReady(fn). Each callback runs once, at PLAYER_LOGIN, inside a pcall so a
-- failure in one module cannot break the others.

local addonName, ns = ...

------------------------------------------------------------------------------
-- Localization
------------------------------------------------------------------------------

-- Resolve Sku's live locale table (AceLocale). Available at load: Sku is a
-- hard dependency and therefore already loaded.
local function ResolveSkuLocale()
    if Sku and Sku.L then
        return Sku.L
    end
    if LibStub and LibStub("AceLocale-3.0", true) then
        return LibStub("AceLocale-3.0"):GetLocale("Sku", true)
    end
    return nil
end

-- Inject the active locale's Sku-key translations into Sku.L. For enUS this is
-- a no-op (Sku ships English). Applied at load so Sku's own auctionHouse.lua
-- displays translated strings immediately.
local function ApplyLocaleToSku()
    local L = ResolveSkuLocale()
    if not L then return end
    local active = ns.locales and ns.locales[GetLocale()]
    if active and active.sku then
        for k, v in pairs(active.sku) do
            L[k] = v
        end
    end
end

ApplyLocaleToSku()

-- ns.L : Sku's locale, for modules that need to read Sku strings at runtime.
ns.L = ResolveSkuLocale()

-- ns.T : this addon's own strings for the active locale, falling back per-key
-- to enUS, then to the key itself. Never errors on a missing key.
do
    local active = (ns.locales and ns.locales[GetLocale()] and ns.locales[GetLocale()].ui) or {}
    local base = (ns.locales and ns.locales["enUS"] and ns.locales["enUS"].ui) or {}
    ns.T = setmetatable({}, {
        __index = function(_, k)
            if active[k] ~= nil then return active[k] end
            if base[k] ~= nil then return base[k] end
            return k
        end,
    })
end

------------------------------------------------------------------------------
-- onReady dispatch (runs registered setups once, at PLAYER_LOGIN)
------------------------------------------------------------------------------

ns._readyQueue = {}
ns._isReady = false

-- Register a setup callback. If the addon is already initialized, runs now.
function ns.onReady(fn)
    if type(fn) ~= "function" then return end
    if ns._isReady then
        local ok, err = pcall(fn)
        if not ok then
            print("|cffff0000[SkuAuctionHouseReplacement]|r " .. tostring(err))
        end
    else
        table.insert(ns._readyQueue, fn)
    end
end

------------------------------------------------------------------------------
-- Login initialization
------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end

    if not SkuCore then
        print("|cffff0000" .. ns.T["ErrNoCore"] .. "|r")
        return
    end

    -- Refresh Sku locale reference now that everything is loaded.
    ns.L = ResolveSkuLocale() or ns.L

    -- Per-character saved variables (declared in the .toc).
    SkuAHReplacementDB = SkuAHReplacementDB or {}
    if SkuAHReplacementDB.autoScan == nil then
        SkuAHReplacementDB.autoScan = false
    end
    ns.db = SkuAHReplacementDB

    -- Noms d'objets en français dans « enchères par objet » : Sku affiche ces
    -- noms via SkuDB.itemLookup[Sku.Loc][id] (Sku.Loc = "enUS" en client FR).
    -- Ce métatable résout le nom à la demande via GetItemInfo (langue du client
    -- = français), avec repli sur la valeur stockée. Résolution paresseuse (donc
    -- uniquement pour les objets réellement affichés — pas de flood de requêtes).
    -- NB : effet de bord connu et accepté — pairs()/next() sur cette table
    -- n'itère plus les entrées (ex. la liste d'objets de l'achat stratégique).
    if SkuDB and SkuDB.itemLookup and GetLocale() == "frFR" then
        local enUSTable = SkuDB.itemLookup["enUS"] or {}
        SkuDB.itemLookup["enUS"] = setmetatable({}, {
            __index = function(_, itemID)
                local name = GetItemInfo(itemID)
                if name then return name end
                return enUSTable[itemID]
            end,
        })
    end

    -- Run all module setups, isolated from each other.
    ns._isReady = true
    for _, fn in ipairs(ns._readyQueue) do
        local ok, err = pcall(fn)
        if not ok then
            print("|cffff0000[SkuAuctionHouseReplacement]|r " .. tostring(err))
        end
    end
    ns._readyQueue = {}

    print("|cff00ff00" .. ns.T["Loaded"] .. "|r")
end)
