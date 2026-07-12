-- StratBuy.lua — Achat stratégique utilisable en français
--
-- Le menu « Stratégie d'achat » de Sku a deux problèmes sur un client FR :
--   1. La liste de sélection de l'objet itère SkuDB.itemLookup["enUS"] avec
--      pairs() — table remplacée par notre métatable de traduction, donc liste
--      vide (et de toute façon en anglais à l'origine).
--   2. Or/Argent/Cuivre se choisissent dans des listes de 0..999 entrées, très
--      lentes à parcourir pour un utilisateur aveugle.
--
-- On remplace le contenu du sous-menu par le même schéma que la mise en vente :
--   * Nom de l'objet : saisie libre (EditBox). Le texte est envoyé tel quel à
--     la recherche serveur de l'HdV, donc le nom FRANÇAIS fonctionne.
--   * Or / Argent / Cuivre maximum : EditBox chiffrées, identiques aux entrées
--     de prix de la mise en vente (Entrée pour saisir, Entrée pour valider).
--   * Quantité + Lancer l'achat : logique d'origine de Sku, conservée.
--
-- Le démarrage passe toujours par SkuCore:StrategyBuyStart — aucune logique
-- d'achat n'est modifiée, seulement la saisie.

local addonName, ns = ...

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function Cfg()
    SkuCore.StratBuyConfig = SkuCore.StratBuyConfig or {}
    return SkuCore.StratBuyConfig
end

-- Entrée « pièce » à saisie libre, clone du comportement de la mise en vente
-- (SellMenu.lua) : Entrée -> EditBox -> nombre -> mise à jour + focus conservé.
local function AddCoinEditEntry(aParent, aKey, aLabel, aMaxVal)
    local L_Sku = ns.L
    local cfg = Cfg()
    local tEntry = SkuOptions:InjectMenuItems(aParent, {aLabel .. ": " .. (cfg[aKey] or 0)}, SkuGenericMenuItem)
    tEntry.cleanName = aLabel
    tEntry.OnAction = function()
        PlaySound(88)
        SkuOptions.Voice:OutputStringBTtts(L_Sku["Enter text and press ENTER key"], false, true, 0.2)
        SkuOptions:EditBoxShow(tostring(cfg[aKey] or 0), function()
            PlaySound(89)
            local text = SkuOptionsEditBoxEditBox:GetText() or ""
            local num = tonumber(text) or 0
            if num < 0 then num = 0 end
            if aMaxVal and num > aMaxVal then num = aMaxVal end
            cfg[aKey] = num
            tEntry.name = tEntry.cleanName .. ": " .. num
            -- Garder le focus sur l'entrée et vocaliser la nouvelle valeur.
            SkuOptions.currentMenuPosition = tEntry
            SkuOptions.Voice:OutputStringBTtts(tEntry.name, true, false, 0.2)
        end)
    end
    tEntry.OnEnter = function(self)
        self.selectTarget = nil -- CRITIQUE : restaurer OnAction (même schéma que la vente)
        self.name = self.cleanName .. ": " .. (cfg[aKey] or 0)
        self.textFull = self.name
    end
    return tEntry
end

------------------------------------------------------------------------------
-- Contenu du sous-menu « Stratégie d'achat »
------------------------------------------------------------------------------

local function BuildStratChildren(self)
    -- IDEMPOTENT : toujours repartir d'une liste vide. Nécessaire car
    -- SkuOptions:VocalizeCurrentMenuName (appelé après chaque frappe) exécute
    -- BuildChildren SANS vider children — sans ce reset, chaque passage du
    -- curseur sur « Stratégie d'achat » ré-ajoutait les 6 entrées (6→12→18…).
    self.children = {}

    local L_Sku = ns.L
    local cfg = Cfg()

    -- 1. Nom de l'objet : saisie libre (fonctionne avec le nom français).
    local tItemEntry = SkuOptions:InjectMenuItems(self, {L_Sku["STRAT_ItemName"] .. ": " .. (cfg.itemName or L_Sku["STRAT_NotSet"])}, SkuGenericMenuItem)
    tItemEntry.OnAction = function()
        PlaySound(88)
        SkuOptions.Voice:OutputStringBTtts(L_Sku["Enter text and press ENTER key"], false, true, 0.2)
        SkuOptions:EditBoxShow(cfg.itemName or "", function()
            PlaySound(89)
            local text = SkuOptionsEditBoxEditBox:GetText() or ""
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then
                cfg.itemName = text
                tItemEntry.name = L_Sku["STRAT_ItemName"] .. ": " .. cfg.itemName
                SkuOptions.currentMenuPosition = tItemEntry
                SkuOptions.Voice:OutputStringBTtts(L_Sku["STRAT_ItemSet"] .. ": " .. cfg.itemName, true, false, 0.2)
            else
                SkuOptions.currentMenuPosition = tItemEntry
                SkuOptions.Voice:OutputStringBTtts(tItemEntry.name, true, false, 0.2)
            end
        end)
    end
    tItemEntry.OnEnter = function(self)
        self.selectTarget = nil
        self.name = L_Sku["STRAT_ItemName"] .. ": " .. (cfg.itemName or L_Sku["STRAT_NotSet"])
        self.textFull = self.name
    end

    -- 2-4. Prix maximum : Or / Argent / Cuivre en saisie libre (comme la vente).
    AddCoinEditEntry(self, "maxGold", L_Sku["STRAT_MaxGold"], nil)
    AddCoinEditEntry(self, "maxSilver", L_Sku["STRAT_MaxSilver"], 99)
    AddCoinEditEntry(self, "maxCopper", L_Sku["STRAT_MaxCopper"], 99)

    -- 5. Quantité : logique d'origine de Sku (liste 1..20).
    local tAmountEntry = SkuOptions:InjectMenuItems(self, {L_Sku["STRAT_Amount"] .. ": " .. (cfg.amount or 1)}, SkuGenericMenuItem)
    tAmountEntry.dynamic = true
    tAmountEntry.isSelect = true
    tAmountEntry.noStepUpAfterSelect = true
    tAmountEntry.OnAction = function(self, aValue, aName)
        local tNum = tonumber(aName)
        if not tNum and aValue and aValue.name then tNum = tonumber(aValue.name) end
        if not tNum then
            local tStr = aName or (aValue and aValue.name) or ""
            tNum = tonumber(string.match(tostring(tStr), "^(%d+)"))
        end
        cfg.amount = tNum or 1
        self.name = L_Sku["STRAT_Amount"] .. ": " .. cfg.amount
        pcall(function() SkuOptions.Voice:OutputStringBTtts(cfg.amount .. " " .. L_Sku["STRAT_Pieces"], true, true, 0.2, nil, nil, nil, 2) end)
    end
    tAmountEntry.BuildChildren = function(self)
        local tMaxCopper = ns.CombineCoin(cfg.maxGold, cfg.maxSilver, cfg.maxCopper)
        for x = 1, 20 do
            local tLabel = tostring(x) .. " " .. L_Sku["STRAT_Times"] .. " " .. (cfg.itemName or "?") .. " " .. L_Sku["STRAT_For"] .. " " .. SkuGetCoinText(tMaxCopper, false, true) .. " " .. L_Sku["STRAT_PerPiece"]
            SkuOptions:InjectMenuItems(self, {tLabel}, SkuGenericMenuItem)
        end
    end

    -- 6. Lancer l'achat : logique d'origine, avec libellé rafraîchi à l'entrée
    -- (les valeurs changent désormais sans reconstruction du sous-menu).
    local function tStartLabel()
        local tMaxCopper = ns.CombineCoin(cfg.maxGold, cfg.maxSilver, cfg.maxCopper)
        return L_Sku["STRAT_Start"] .. ": " .. (cfg.amount or 1) .. " " .. (cfg.itemName or "?") .. " " .. L_Sku["STRAT_For"] .. " " .. SkuGetCoinText(tMaxCopper, false, true) .. " " .. L_Sku["STRAT_PerPiece"]
    end
    local tStartEntry = SkuOptions:InjectMenuItems(self, {tStartLabel()}, SkuGenericMenuItem)
    tStartEntry.OnEnter = function(self)
        self.selectTarget = nil
        self.name = tStartLabel()
        self.textFull = self.name
    end
    tStartEntry.OnAction = function(self, aValue, aName)
        if not cfg.itemName or cfg.itemName == "" then
            pcall(function() SkuOptions.Voice:OutputStringBTtts(L_Sku["STRAT_NoItem"], true, true, 0.2, nil, nil, nil, 2) end)
            return
        end
        local tMaxPrice = ns.CombineCoin(cfg.maxGold, cfg.maxSilver, cfg.maxCopper)
        if tMaxPrice <= 0 then
            pcall(function() SkuOptions.Voice:OutputStringBTtts(L_Sku["STRAT_NoPrice"], true, true, 0.2, nil, nil, nil, 2) end)
            return
        end
        -- Sku 42 : StrategyBuyStart vit sur le sous-module SkuCore.AuctionHouse ;
        -- sur Sku 41 il était sur SkuCore.
        local tAH = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.StrategyBuyStart)
            and SkuCore.AuctionHouse or SkuCore
        tAH:StrategyBuyStart(cfg.itemName, tMaxPrice, cfg.amount or 1)
    end
end

------------------------------------------------------------------------------
-- Hook : remplacer le contenu du sous-menu « Stratégie d'achat »
------------------------------------------------------------------------------
--
-- IMPORTANT : l'entrée « Stratégie d'achat » n'est PAS un enfant direct du menu
-- HdV — Sku l'injecte DANS le sous-menu « Enchères » (Auktionen). On enveloppe
-- donc le BuildChildren de « Enchères », puis on remplace le BuildChildren de
-- l'entrée STRAT une fois qu'elle existe.

local function InstallStratBuyMenu()
    local L_Sku = ns.L
    -- Sku 42 : le constructeur du menu HdV vit sur le sous-module
    -- SkuCore.AuctionHouse ; sur Sku 41 il était sur SkuCore.
    local tHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseMenuBuilder)
        and SkuCore.AuctionHouse or SkuCore
    local originalBuilder = tHost.AuctionHouseMenuBuilder
    tHost.AuctionHouseMenuBuilder = function(self)
        originalBuilder(self)
        if not (self and self.children) then return end
        for _, child in ipairs(self.children) do
            if child.name == L_Sku["Auktionen"] or child.name == "Auktionen"
                or child.name == "Enchères" or child.name == "enchères" or child.name == "Auctions" then
                if not child.isHookedForStratBuy then
                    child.isHookedForStratBuy = true
                    local originalAukBuildChildren = child.BuildChildren
                    child.BuildChildren = function(self_auk)
                        if originalAukBuildChildren then
                            originalAukBuildChildren(self_auk)
                        end
                        if self_auk.children then
                            for _, sub in ipairs(self_auk.children) do
                                if sub.name == L_Sku["STRAT_Title"] or sub.name == "STRAT_Title"
                                    or sub.name == "Stratégie d'achat" or sub.name == "Strategy buy single items" then
                                    sub.dynamic = true
                                    sub.BuildChildren = BuildStratChildren
                                    break
                                end
                            end
                        end
                    end
                end
                break
            end
        end
    end
end

ns.onReady(InstallStratBuyMenu)
