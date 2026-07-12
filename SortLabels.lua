-- SortLabels.lua — Localized sort-order list ("Sortierung")
--
-- Replaces the sort menu's displayed values and current-value readout with the
-- active locale's labels, and maps the chosen label back to Sku's SortBy index.

local addonName, ns = ...

local MODULE_NAME = "SkuCore"

local function SortValues()
    return {
        [1] = ns.T["SortByBuy1"],
        [2] = ns.T["SortByBuy2"],
        [3] = ns.T["SortByBid1"],
        [4] = ns.T["SortByBid2"],
        [5] = ns.T["SortLevelDesc"],
        [6] = ns.T["SortLevelAsc"],
    }
end

-- Sku 42 : le filtre courant est passé de SkuOptions.db.char["SkuCore"] à
-- SkuSettings:Sub("SkuCore", nil, "char"). Retourne la table char-scoped qui
-- porte AuctionCurrentFilter, sur les deux versions de Sku.
local function CharStore()
    if SkuSettings and SkuSettings.Sub then
        return SkuSettings:Sub("SkuCore", nil, "char")
    end
    return SkuOptions.db and SkuOptions.db.char and SkuOptions.db.char[MODULE_NAME]
end

local function InstallSortLabels()
    local L_Sku = ns.L
    -- Sku 42 : le constructeur du menu HdV vit sur le sous-module
    -- SkuCore.AuctionHouse ; sur Sku 41 il était sur SkuCore.
    local tHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseMenuBuilder)
        and SkuCore.AuctionHouse or SkuCore
    if not tHost.AuctionHouseMenuBuilder then
        print("|cffff0000[SkuAuctionHouseReplacement]|r AuctionHouseMenuBuilder introuvable (version de Sku incompatible).")
        return
    end
    local originalAHMenuBuilder = tHost.AuctionHouseMenuBuilder
    tHost.AuctionHouseMenuBuilder = function(self)
        originalAHMenuBuilder(self)

        local tSortByValues = SortValues()

        local menuNode = SkuCore.AuctionHouseMenu or self
        if menuNode and menuNode.children then
            for _, child in ipairs(menuNode.children) do
                if child.name == L_Sku["Auktionen"] or child.name == "Auktionen" or child.name == "Enchères" or child.name == "Auctions" then
                    if not child.isHookedForAuktionenTranslation then
                        child.isHookedForAuktionenTranslation = true
                        local originalAuktionenBuildChildren = child.BuildChildren
                        child.BuildChildren = function(self_auk)
                            originalAuktionenBuildChildren(self_auk)

                            if self_auk.children then
                                for _, subChild in ipairs(self_auk.children) do
                                    if subChild.name == L_Sku["Filter und Sortierung"] or subChild.name == "Filter und Sortierung" or subChild.name == "Filtres et Tri" or subChild.name == "Filter and Sort" then
                                        if not subChild.isHookedForFaSTranslation then
                                            subChild.isHookedForFaSTranslation = true
                                            local originalFaSBuildChildren = subChild.BuildChildren
                                            subChild.BuildChildren = function(self_fas)
                                                originalFaSBuildChildren(self_fas)

                                                if self_fas.children then
                                                    for _, grandChild in ipairs(self_fas.children) do
                                                        if grandChild.name == L_Sku["Sortierung"] or grandChild.name == "Sortierung" or grandChild.name == "Tri" or grandChild.name == "Sort" then
                                                            grandChild.GetCurrentValue = function(self_node, aValue, aName)
                                                                local tStore = CharStore()
                                                                local sortBy = (tStore and tStore.AuctionCurrentFilter and tStore.AuctionCurrentFilter.SortBy) or 1
                                                                return tSortByValues[sortBy] or tSortByValues[1]
                                                            end

                                                            grandChild.OnAction = function(self_node, aValue, aName)
                                                                local tStore = CharStore()
                                                                if not tStore then return end
                                                                tStore.AuctionCurrentFilter = tStore.AuctionCurrentFilter or {}
                                                                for i = 1, #tSortByValues do
                                                                    if tSortByValues[i] == aName then
                                                                        tStore.AuctionCurrentFilter.SortBy = i
                                                                    end
                                                                end
                                                            end

                                                            grandChild.BuildChildren = function(self_node)
                                                                for i = 1, #tSortByValues do
                                                                    SkuOptions:InjectMenuItems(self_node, {tSortByValues[i]}, SkuGenericMenuItem)
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

ns.onReady(InstallSortLabels)
