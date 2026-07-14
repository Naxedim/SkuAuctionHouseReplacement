-- SellMenu.lua — Selling flow
--
--   B. Free/fast Gold-Silver-Copper price editor (SkuCore.AuctionHouseBuildItemSellMenuSub).
--   C. Instant bag scan for the "New auction" menu (SkuCore.AuctionHouseMenuBuilder).

local addonName, ns = ...

-- Sku 42 : les fonctions Auction* vivent sur le sous-module SkuCore.AuctionHouse
-- (handle publié) ; sur Sku 41 elles étaient sur SkuCore. AHHost() retourne la
-- table qui porte réellement les fonctions, pour les hooks ET les appels.
local function AHHost()
    if SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseMenuBuilder then
        return SkuCore.AuctionHouse
    end
    return SkuCore
end

------------------------------------------------------------------------------
-- B. Price editor (Gold / Silver / Copper edit boxes)
------------------------------------------------------------------------------

local function InstallPriceEditor()
    local L_Sku = ns.L
    local tAH = AHHost()
    tAH.AuctionHouseBuildItemSellMenuSub = function(self, aSelf, aGossipItemTable)
        local tItemEntry = aSelf.parent

        local function tPriceCopper()
            local tCfg = tItemEntry.priceCfg or { gold = 0, silver = 0, copper = 0 }
            return ns.CombineCoin(tCfg.gold, tCfg.silver, tCfg.copper)
        end

        aSelf.BuildChildren = function(self)
            local tCfg = tItemEntry.priceCfg
            if not tCfg then
                tCfg = { gold = 0, silver = 0, copper = 0 }
                local tItemId = aGossipItemTable.itemId
                if _G[aGossipItemTable.containerFrameName] and _G[aGossipItemTable.containerFrameName].info then
                    tItemId = _G[aGossipItemTable.containerFrameName].info.id or tItemId
                end
                if tItemId then
                    local tBest = select(2, tAH:AuctionHouseGetAuctionPriceHistoryData(tItemId))
                    if tBest and tBest > 0 then
                        tBest = math.floor(tBest)
                        tCfg.gold, tCfg.silver, tCfg.copper = ns.SplitCoin(tBest)
                    end
                end
                tItemEntry.priceCfg = tCfg
            end

            local function tBuildAuctionCountFlow(aParent)
                local tHeader = SkuOptions:InjectMenuItems(aParent, {L_Sku["Anzahl Auktionen"]}, SkuGenericMenuItem)
                tHeader.OnEnter = function(self, aValue, aName) self.selectTarget = tItemEntry end
                local tAmount = tonumber(tItemEntry.amount) or 1
                local tNumActionsMax = math.floor((tItemEntry.amountMax or tAmount) / tAmount)
                if tNumActionsMax < 1 then tNumActionsMax = 1 end

                local function tAddCountEntry(aParent, aLabel, aCount)
                    local tEntry = SkuOptions:InjectMenuItems(aParent, {aLabel}, SkuGenericMenuItem)
                    tEntry.dynamic = true
                    tEntry.numAuctions = aCount
                    tEntry.OnEnter = function(self, aValue, aName)
                        self.selectTarget = tItemEntry
                        tItemEntry.numAuctions = self.numAuctions
                        tItemEntry.price = tPriceCopper()
                    end
                    tEntry.BuildChildren = function(self)
                        SkuOptions:InjectMenuItems(self, {L_Sku["Erstellen: 12 Stunden"]}, SkuGenericMenuItem)
                        SkuOptions:InjectMenuItems(self, {L_Sku["Erstellen: 24 Stunden"]}, SkuGenericMenuItem)
                        SkuOptions:InjectMenuItems(self, {L_Sku["Erstellen: 48 Stunden"]}, SkuGenericMenuItem)
                    end
                end

                tAddCountEntry(aParent, L_Sku["Alle ("]..tNumActionsMax..L_Sku[" mal "]..tAmount..L_Sku[")"], tNumActionsMax)
                for tNumActions = 1, tNumActionsMax do
                    tAddCountEntry(aParent, tNumActions..L_Sku[" mal "]..tAmount, tNumActions)
                end
            end

            -- 1. Pièces d'Or (Gold)
            local tGoldEntry = SkuOptions:InjectMenuItems(self, {L_Sku["Gold"]..": "..(tCfg.gold or 0)}, SkuGenericMenuItem)
            tGoldEntry.cleanName = L_Sku["Gold"]
            tGoldEntry.OnAction = function()
                PlaySound(88)
                SkuOptions.Voice:OutputStringBTtts(L_Sku["Enter text and press ENTER key"], false, true, 0.2)
                local currentVal = tostring(tCfg.gold or 0)
                SkuOptions:EditBoxShow(currentVal, function(editbox_self)
                    PlaySound(89)
                    local text = SkuOptionsEditBoxEditBox:GetText() or ""
                    local num = tonumber(text) or 0
                    if num < 0 then num = 0 end
                    tCfg.gold = num
                    tGoldEntry.name = tGoldEntry.cleanName..": "..num
                    SkuOptions.currentMenuPosition = tGoldEntry
                    SkuOptions.Voice:OutputStringBTtts(tGoldEntry.name, true, false, 0.2)
                end)
            end
            tGoldEntry.OnEnter = function(self)
                self.selectTarget = nil -- CRITIQUE: restaurer OnAction
                self.textFull = L_Sku["Gold"]..": "..(tCfg.gold or 0)
            end

            -- 2. Pièces d'Argent (Silver)
            local tSilverEntry = SkuOptions:InjectMenuItems(self, {L_Sku["Silver"]..": "..(tCfg.silver or 0)}, SkuGenericMenuItem)
            tSilverEntry.cleanName = L_Sku["Silver"]
            tSilverEntry.OnAction = function()
                PlaySound(88)
                SkuOptions.Voice:OutputStringBTtts(L_Sku["Enter text and press ENTER key"], false, true, 0.2)
                local currentVal = tostring(tCfg.silver or 0)
                SkuOptions:EditBoxShow(currentVal, function(editbox_self)
                    PlaySound(89)
                    local text = SkuOptionsEditBoxEditBox:GetText() or ""
                    local num = tonumber(text) or 0
                    if num < 0 then num = 0 end
                    if num > 99 then num = 99 end
                    tCfg.silver = num
                    tSilverEntry.name = tSilverEntry.cleanName..": "..num
                    SkuOptions.currentMenuPosition = tSilverEntry
                    SkuOptions.Voice:OutputStringBTtts(tSilverEntry.name, true, false, 0.2)
                end)
            end
            tSilverEntry.OnEnter = function(self)
                self.selectTarget = nil -- CRITIQUE: restaurer OnAction
                self.textFull = L_Sku["Silver"]..": "..(tCfg.silver or 0)
            end

            -- 3. Pièces de Cuivre (Copper)
            local tCopperEntry = SkuOptions:InjectMenuItems(self, {L_Sku["Copper"]..": "..(tCfg.copper or 0)}, SkuGenericMenuItem)
            tCopperEntry.cleanName = L_Sku["Copper"]
            tCopperEntry.OnAction = function()
                PlaySound(88)
                SkuOptions.Voice:OutputStringBTtts(L_Sku["Enter text and press ENTER key"], false, true, 0.2)
                local currentVal = tostring(tCfg.copper or 0)
                SkuOptions:EditBoxShow(currentVal, function(editbox_self)
                    PlaySound(89)
                    local text = SkuOptionsEditBoxEditBox:GetText() or ""
                    local num = tonumber(text) or 0
                    if num < 0 then num = 0 end
                    if num > 99 then num = 99 end
                    tCfg.copper = num
                    tCopperEntry.name = tCopperEntry.cleanName..": "..num
                    SkuOptions.currentMenuPosition = tCopperEntry
                    SkuOptions.Voice:OutputStringBTtts(tCopperEntry.name, true, false, 0.2)
                end)
            end
            tCopperEntry.OnEnter = function(self)
                self.selectTarget = nil -- CRITIQUE: restaurer OnAction
                self.textFull = L_Sku["Copper"]..": "..(tCfg.copper or 0)
            end

            -- 4. Étape Suivante
            local tNextEntry = SkuOptions:InjectMenuItems(self, {L_Sku["Anzahl Auktionen"]}, SkuGenericMenuItem)
            tNextEntry.dynamic = true
            tNextEntry.OnEnter = function(self)
                self.selectTarget = nil
            end
            tNextEntry.BuildChildren = function(self)
                tBuildAuctionCountFlow(self)
            end
        end
    end
end

------------------------------------------------------------------------------
-- C. Instant bag scan for "New auction"
------------------------------------------------------------------------------

local function InstallBagSellScan()
    local L_Sku = ns.L
    local tAH = AHHost()
    local originalAHMenuBuilder = tAH.AuctionHouseMenuBuilder
    tAH.AuctionHouseMenuBuilder = function(self)
        originalAHMenuBuilder(self)

        if self.children then
            for _, child in ipairs(self.children) do
                -- Matcher les versions traduites et les clés brutes de Sku
                if child.name == L_Sku["Verkäufe"] or child.name == "Verkäufe" or child.name == "Ventes" or child.name == "Sells" then
                    local originalVerkaufeBuildChildren = child.BuildChildren
                    child.BuildChildren = function(self)
                        originalVerkaufeBuildChildren(self)

                        if self.children then
                            for _, subChild in ipairs(self.children) do
                                if subChild.name == L_Sku["Neue Auktion"] or subChild.name == "Neue Auktion" or subChild.name == "Nouvelle enchère" or subChild.name == "New Auction" then
                                    subChild.BuildChildren = function(self)
                                        tAH:AuctionHouseResetQuery()

                                        local tCountItems = {}
                                        for tbag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
                                            for tslot = 1, ns.GetContainerNumSlots(tbag) do
                                                local icon, titemCount, _, _, _, _, _, _, _, titemID = ns.GetContainerItemInfo(tbag, tslot)
                                                if titemID then
                                                    if tCountItems[titemID] then
                                                        tCountItems[titemID] = tCountItems[titemID] + titemCount
                                                    else
                                                        tCountItems[titemID] = titemCount
                                                    end
                                                end
                                            end
                                        end

                                        local tHasEntries = false
                                        local tFoundItems = {}
                                        for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
                                            for slot = 1, ns.GetContainerNumSlots(bag) do
                                                local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = ns.GetContainerItemInfo(bag, slot)
                                                if icon and itemID then
                                                    if ns.IsItemBound(bag, slot) == false then
                                                        local tName = GetItemInfo(itemID)
                                                        if not tName then
                                                            tName = itemLink and itemLink:match("%[(.-)%]") or "Item "..itemID
                                                        end
                                                        if tName and not tFoundItems[itemID] then
                                                            tFoundItems[itemID] = true
                                                            local tNewMenuSubSubEntry = SkuOptions:InjectMenuItems(self, {tName.." ("..tCountItems[itemID]..")"}, SkuGenericMenuItem)
                                                            tNewMenuSubSubEntry.dynamic = true
                                                            tNewMenuSubSubEntry.filterable = true
                                                            tNewMenuSubSubEntry.isSelect = true
                                                            tNewMenuSubSubEntry.itemId = itemID
                                                            tNewMenuSubSubEntry.amountMax = tCountItems[itemID]

                                                            local aGossipItemTable = {
                                                                -- [21] = lien complet de l'objet (pas seulement l'ID) :
                                                                -- indispensable pour que l'info-bulle du vendeur soit aussi
                                                                -- complète que côté achat. Avec seulement [17]=itemID, Sku
                                                                -- construit l'info-bulle via SetItemByID (objet de base, sans
                                                                -- suffixe/enchant aléatoire) et notre hook via
                                                                -- GameTooltip:SetHyperlink("item:"..id) — d'où l'absence des
                                                                -- statistiques détaillées et des lignes des autres addons.
                                                                -- Le lien complet (issu du sac) rétablit tout ce contexte.
                                                                textFull = select(2, tAH:AuctionBuildItemTooltip({[17] = itemID, [21] = itemLink}, nil, true, true)),
                                                                itemId = itemID,
                                                                bag = bag, slot = slot,
                                                                containerFrameName = "ContainerFrame"..(bag + 1).."Item"..(ns.GetContainerNumSlots(bag) - slot + 1),
                                                            }

                                                            tNewMenuSubSubEntry.textFull = aGossipItemTable.textFull

                                                            tNewMenuSubSubEntry.OnAction = function(self, aValue, aName)
                                                                local tAmount = tonumber(self.selectTarget.amount)
                                                                local tNumAuctions = tonumber(self.selectTarget.numAuctions)
                                                                local tCopperBuyout = tonumber(self.selectTarget.price)
                                                                local tCopperStartBid = tCopperBuyout and math.floor(tCopperBuyout * 0.9) or nil
                                                                if tCopperStartBid and tCopperStartBid < 1 then tCopperStartBid = 1 end
                                                                local tDuration
                                                                if aName == L_Sku["Erstellen: 12 Stunden"] or aName == "Créer : 12 heures" then
                                                                    tDuration = 1
                                                                elseif aName == L_Sku["Erstellen: 24 Stunden"] or aName == "Créer : 24 heures" then
                                                                    tDuration = 2
                                                                elseif aName == L_Sku["Erstellen: 48 Stunden"] or aName == "Créer : 48 heures" then
                                                                    tDuration = 3
                                                                end

                                                                ns.Log("post requested", {
                                                                    itemId = aGossipItemTable.itemId,
                                                                    containerFrame = aGossipItemTable.containerFrameName,
                                                                    amount = tAmount, numAuctions = tNumAuctions,
                                                                    buyout = tCopperBuyout, startBid = tCopperStartBid,
                                                                    durationLabel = aName, duration = tDuration,
                                                                })

                                                                local tBagCountBefore = GetItemCount and GetItemCount(aGossipItemTable.itemId) or nil

                                                                ClearCursor()
                                                                _G["AuctionFrameTab3"]:GetScript("OnClick")(_G["AuctionFrameTab3"], "LeftButton")
                                                                ClickAuctionSellItemButton()
                                                                ClearCursor()
                                                                ns.StageSellItem(aGossipItemTable.itemId, aGossipItemTable.bag, aGossipItemTable.slot)

                                                                local _, tSlotTex = GetAuctionSellItemInfo()

                                                                PostAuction(tCopperStartBid, tCopperBuyout, tDuration, tAmount, tNumAuctions, true)

                                                                ns.CaptureResult()

                                                                -- Rafraîchir le menu comme le flux natif de Sku : sans
                                                                -- cela, la liste des sacs (« Nouvelle enchère ») et la
                                                                -- liste des objets en vente (« Ventes ») restaient figées
                                                                -- jusqu'à la fermeture/réouverture de l'hôtel des ventes.
                                                                -- GetOwnerAuctionItems redemande la liste du vendeur au
                                                                -- serveur ; OnBack + CheckFrames reconstruit le menu local
                                                                -- (les nœuds dynamiques rescannent alors les sacs à jour).
                                                                GetOwnerAuctionItems()
                                                                C_Timer.After(0.01, function()
                                                                    if SkuOptions.currentMenuPosition and SkuOptions.currentMenuPosition.OnBack then
                                                                        pcall(function() SkuOptions.currentMenuPosition:OnBack(SkuOptions.currentMenuPosition) end)
                                                                    end
                                                                end)
                                                                C_Timer.After(0.01, function()
                                                                    pcall(function() SkuCore:CheckFrames(nil, true) end)
                                                                end)

                                                                C_Timer.After(2, function()
                                                                    local tBagCountAfter = GetItemCount and GetItemCount(aGossipItemTable.itemId) or nil
                                                                    local tConsumed = (tBagCountBefore and tBagCountAfter)
                                                                        and (tBagCountBefore - tBagCountAfter) or nil
                                                                    if tConsumed and tConsumed > 0 then
                                                                        if tNumAuctions == 1 then
                                                                            SkuOptions.Voice:OutputStringBTtts(L_Sku["Auktion erstellt"], false, true, 0.1, nil, nil, nil, 1)
                                                                        else
                                                                            SkuOptions.Voice:OutputStringBTtts(tNumAuctions..L_Sku[" Auktionen erstellt"], false, true, 0.1, nil, nil, nil, 1)
                                                                        end
                                                                    else
                                                                        SkuOptions.Voice:OutputStringBTtts(L_Sku["Einstellen fehlgeschlagen"], false, true, 0.1, nil, nil, nil, 1)
                                                                    end
                                                                end)
                                                            end

                                                            tNewMenuSubSubEntry.BuildChildren = function(self)
                                                                local tStackMenuEntry = SkuOptions:InjectMenuItems(self, {L_Sku["Stack Größe"]}, SkuGenericMenuItem)
                                                                local _, _, _, _, _, _, _, itemStackMaxCount = GetItemInfo(self.itemId)

                                                                local tCount = self.amountMax or 1
                                                                if itemStackMaxCount and itemStackMaxCount < tCount then
                                                                    tCount = itemStackMaxCount
                                                                end

                                                                for z = 1, tonumber(tCount) do
                                                                    local tStackMenuEntry = SkuOptions:InjectMenuItems(self, {tostring(z)}, SkuGenericMenuItem)
                                                                    tStackMenuEntry.filterable = true
                                                                    tStackMenuEntry.dynamic = true
                                                                    tStackMenuEntry.OnEnter = function(self, aValue, aName)
                                                                        self.selectTarget.amount = z
                                                                    end
                                                                    tAH:AuctionHouseBuildItemSellMenuSub(tStackMenuEntry, aGossipItemTable)
                                                                end
                                                            end
                                                            tHasEntries = true
                                                        end
                                                    end
                                                end
                                            end
                                        end

                                        if tHasEntries == false then
                                            SkuOptions:InjectMenuItems(self, {L_Sku["Menu empty"]}, SkuGenericMenuItem)
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end
end

------------------------------------------------------------------------------

ns.onReady(function()
    InstallPriceEditor()
    InstallBagSellScan()
end)
