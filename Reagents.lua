-- Reagents.lua — Ingredient / crafting price info for the item tooltip
--
-- Builds an accessible French (localized) block that is appended to the auction
-- house item tooltip, pairing crafting data with Sku's own scanned auction
-- prices ("temps réel" when a scan is fresh, otherwise the last scan's data).
--
-- Data sources:
--   * BitesCookBook — exposes a GLOBAL table (BitesCookBook.Recipes / .Reagents /
--     .CraftablesForReagent), so we read it directly and add Sku prices per
--     ingredient (this is the price enrichment the other addons don't provide).
--   * DisenchantBuddy — an optional block that activates only if a global API is
--     present (current versions keep their data private, so it stays inactive;
--     their own tooltip lines are still captured by Tooltip.lua's scan).
--   * KeepTheHerbs — adds its lines synchronously to the game tooltip, so
--     Tooltip.lua's SetHyperlink scan already surfaces them for accessibility.
--
-- Everything here is fully guarded: a missing addon or an unexpected data shape
-- simply yields no extra lines, never an error.

local addonName, ns = ...

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function ItemName(id)
    local n = GetItemInfo(id)
    if n then return n end
    if C_Item and C_Item.GetItemNameByID then
        n = C_Item.GetItemNameByID(id)
        if n and n ~= "" then return n end
    end
    return "Objet " .. tostring(id)
end

-- Representative auction price (copper) from Sku's scan data, or nil.
local function PriceCopper(id)
    if not SkuCore then return nil end
    -- Sku 42 : la fonction vit sur le sous-module SkuCore.AuctionHouse ;
    -- sur Sku 41 elle était sur SkuCore.
    local tAH = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseGetAuctionPriceHistoryData)
        and SkuCore.AuctionHouse or SkuCore
    if not tAH.AuctionHouseGetAuctionPriceHistoryData then return nil end
    local ok, _, best = pcall(tAH.AuctionHouseGetAuctionPriceHistoryData, tAH, id)
    if ok and type(best) == "number" and best > 0 then
        return best
    end
    return nil
end

local function CoinText(copper)
    if copper and SkuGetCoinText then
        return SkuGetCoinText(copper, true, true)
    end
    return ns.T["PriceUnknown"]
end

------------------------------------------------------------------------------
-- BitesCookBook — cooking ingredients & recipes (global data)
------------------------------------------------------------------------------

local function AppendCooking(lines, itemID)
    if not (BitesCookBook and type(BitesCookBook) == "table") then return end

    -- Hovered item IS a cookable dish → list its ingredients with prices.
    local recipes = rawget(BitesCookBook, "Recipes")
    if recipes and recipes[itemID] and recipes[itemID].Materials then
        table.insert(lines, ns.T["CookIngredientsHeader"] .. " :")
        local total, complete = 0, true
        for ingId, qty in pairs(recipes[itemID].Materials) do
            local q = tonumber(qty) or 1
            local p = PriceCopper(ingId)
            local priceStr = p and (CoinText(p * q) .. " (" .. CoinText(p) .. " " .. ns.T["PriceEach"] .. ")")
                or ns.T["PriceUnknown"]
            table.insert(lines, "  " .. ItemName(ingId) .. " x" .. q .. " : " .. priceStr)
            if p then total = total + p * q else complete = false end
        end
        if total > 0 then
            local suffix = complete and "" or " (+)"
            table.insert(lines, "  " .. ns.T["PriceTotal"] .. " : " .. CoinText(total) .. suffix)
        end
    end

    -- Hovered item is a cooking reagent → which dishes use it (up to 6).
    local craftables = rawget(BitesCookBook, "CraftablesForReagent")
    if craftables and craftables[itemID] then
        local recipeIds = craftables[itemID]
        if type(recipeIds) == "table" and #recipeIds > 0 then
            table.insert(lines, ns.T["ReagentUsedInHeader"] .. " :")
            for i = 1, math.min(#recipeIds, 6) do
                table.insert(lines, "  " .. ItemName(recipeIds[i]))
            end
        end
    end
end

------------------------------------------------------------------------------
-- DisenchantBuddy — liste des matériaux de désenchantement, SANS prix
------------------------------------------------------------------------------
--
-- DisenchantBuddy garde ses données privées et n'ajoute ses lignes à l'info-
-- bulle que si une touche-modificateur est enfoncée (IsModifierDown renvoie
-- true dès que le modificateur configuré n'est pas SHIFT/ALT/CONTROL). On lit
-- donc ses lignes directement depuis GameTooltip :
--   1. un scan avec le gate ACTIF (modificateur "SHIFT", non pressé) -> DB muet ;
--   2. un scan avec le gate OUVERT (modificateur "OFF") -> DB ajoute ses lignes.
-- La différence (les lignes en fin de 2e scan) = les lignes de DisenchantBuddy.
-- On restaure aussitôt son réglage et on retire tout montant de prix.

-- Retire les montants de pièces, codes couleur et icônes d'une ligne (garde le
-- texte, ex. probabilité/quantité).
local function StripCoins(s)
    if not s then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("%d+%s*|T[^|]*|t", "")
    s = s:gsub("|T[^|]*|t", "")
    s = s:gsub("Ø", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("x%s*%)", ")")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Nettoie un texte (icônes + couleurs) pour en extraire un nom d'objet propre.
local function CleanName(s)
    if not s then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|T[^|]*|t", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Résout un nom d'objet (en cache) en itemID via GetItemInfo.
local function NameToId(name)
    if not name or name == "" then return nil end
    local _, link = GetItemInfo(name)
    if link then return tonumber(link:match("item:(%d+)")) end
    return nil
end

-- Lit toutes les lignes de GameTooltip (gauche + droite séparées) pour un lien.
local function ScanTooltipLines(link)
    GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    GameTooltip:SetHyperlink(link)
    local n = GameTooltip:NumLines() or 0
    local left, right = {}, {}
    for i = 1, n do
        local l = _G["GameTooltipTextLeft" .. i]
        local r = _G["GameTooltipTextRight" .. i]
        left[i] = (l and l:GetText()) or ""
        right[i] = (r and r:GetText()) or ""
    end
    GameTooltip:Hide()
    return n, left, right
end

-- Capture les lignes de désenchantement (DisenchantBuddy) et y adjoint le PRIX
-- Sku de chaque matériau (résolu par le nom, l'objet étant en cache).
local function CaptureDisenchantLines(link)
    if not (DisenchantBuddy_Profile and type(DisenchantBuddy_Profile) == "table") then return nil end
    if not (GameTooltip and GameTooltip.SetHyperlink) then return nil end

    local saved = DisenchantBuddy_Profile.Modifier
    local nBase, nFull, lFull, rFull
    local ok = pcall(function()
        DisenchantBuddy_Profile.Modifier = "SHIFT" -- gate actif (Maj non pressée) -> DB muet
        nBase = (ScanTooltipLines(link))
        DisenchantBuddy_Profile.Modifier = "OFF"    -- gate ouvert -> DB ajoute ses lignes
        nFull, lFull, rFull = ScanTooltipLines(link)
    end)
    DisenchantBuddy_Profile.Modifier = saved        -- restauration systématique

    if not (ok and nBase and nFull) then return nil end
    if nFull <= nBase then return nil end

    local out = {}
    for i = nBase + 1, nFull do
        local nameClean = CleanName(lFull[i])
        if nameClean ~= "" then
            local id = NameToId(nameClean)
            if id then
                -- Ligne matériau : nom + probabilité/quantité + prix Sku.
                local qty = StripCoins(rFull[i])
                local price = PriceCopper(id)
                local line = "  " .. nameClean
                if qty ~= "" then line = line .. " " .. qty end
                line = line .. " : " .. (price and (CoinText(price) .. " " .. ns.T["PriceEach"]) or ns.T["PriceUnknown"])
                table.insert(out, line)
            else
                -- En-tête / ligne non-objet (ex. « Résultats du désenchantement »).
                local merged = CleanName(lFull[i] .. " " .. StripCoins(rFull[i]))
                if merged ~= "" then
                    table.insert(out, merged)
                end
            end
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, "\r\n")
end

-- Bloc "matériaux de désenchantement" (sans prix), ou nil. Ne lève jamais d'erreur.
function ns.BuildDisenchantText(link)
    if not link then return nil end
    local ok, text = pcall(CaptureDisenchantLines, link)
    if ok then return text end
    return nil
end

------------------------------------------------------------------------------
-- Public entry point
------------------------------------------------------------------------------

local function Build(itemID)
    local lines = {}
    AppendCooking(lines, itemID)
    if #lines == 0 then return nil end
    return table.concat(lines, "\r\n")
end

-- Returns an accessible text block for the item, or nil. Never errors.
function ns.BuildReagentInfoText(itemID)
    if not itemID then return nil end
    local ok, text = pcall(Build, itemID)
    if ok then return text end
    return nil
end
