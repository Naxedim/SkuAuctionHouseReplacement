-- Tooltip.lua — Enriched item tooltip (SkuCore.AuctionBuildItemTooltip)
--
--   * Captures third-party tooltip lines (Pawn, TSM, KeepTheHerbs, BitesCookBook,
--     DisenchantBuddy, …) by re-reading GameTooltip after SetHyperlink, so their
--     info becomes accessible through Sku's spoken tooltip.
--   * Adds an equipped-item comparison for gear.
--   * Appends the reagent/crafting price block (see Reagents.lua), which pairs
--     crafting data with Sku's own scanned auction prices.

local addonName, ns = ...

-- Chaîne de qualité localisée (« Épique », « Rare », …) pour un objet, dans le
-- format utilisé par les info-bulles natives de Sku : appondue au nom de l'objet
-- sous la forme « Nom (Qualité) ». Respecte le réglage Sku ShowItemQality
-- (activé par défaut) pour que l'affichage reste cohérent avec le reste de Sku.
local function GetItemQualityString(aItemData)
    -- Réglage Sku : ne rien afficher si l'utilisateur a désactivé la qualité.
    local ok, sub = pcall(function() return SkuSettings and SkuSettings:Sub("SkuCore") end)
    if not ok or not sub or not sub.itemSettings or sub.itemSettings.ShowItemQality ~= true then
        return nil
    end

    -- Indice de qualité : d'abord la donnée d'enchère (champ 4), sinon résolution
    -- via le lien / l'ID de l'objet.
    local quality = aItemData[4]
    if quality == nil then
        local link = aItemData[21]
        if link then
            quality = select(3, GetItemInfo(link))
        end
    end
    if quality == nil and aItemData[17] then
        quality = select(3, GetItemInfo(aItemData[17]))
        if quality == nil and C_Item and C_Item.GetItemQualityByID then
            quality = C_Item.GetItemQualityByID(aItemData[17])
        end
    end
    if quality == nil then
        return nil
    end

    return _G["ITEM_QUALITY" .. quality .. "_DESC"]
end

-- Appond « (Qualité) » à la fin de la première ligne (le nom de l'objet) du texte
-- d'info-bulle, comme le font les info-bulles natives de Sku.
local function AppendQualityToFirstLine(aText, aQualityString)
    if not aQualityString or aText == "" then
        return aText
    end
    local lineEnd = string.find(aText, "\r\n", 1, true)
    if lineEnd then
        local firstLine = string.sub(aText, 1, lineEnd - 1)
        return firstLine .. " (" .. aQualityString .. ")" .. string.sub(aText, lineEnd)
    end
    return aText .. " (" .. aQualityString .. ")"
end

local function InstallTooltipHook()
    -- Sku 42 : les fonctions Auction* vivent sur le sous-module
    -- SkuCore.AuctionHouse (handle publié) ; sur Sku 41 elles étaient sur
    -- SkuCore. On accroche la table qui porte réellement la fonction.
    local tHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionBuildItemTooltip)
        and SkuCore.AuctionHouse or SkuCore
    if not tHost.AuctionBuildItemTooltip then
        print("|cffff0000[SkuAuctionHouseReplacement]|r AuctionBuildItemTooltip introuvable (version de Sku incompatible).")
        return
    end
    local originalAuctionBuildItemTooltip = tHost.AuctionBuildItemTooltip
    tHost.AuctionBuildItemTooltip = function(self, aItemData, aIndex, aAddCurrentPriceData, aAddHistoryPriceData)
        local tTextFirstLine, tPriceHistoryData = originalAuctionBuildItemTooltip(self, aItemData, aIndex, aAddCurrentPriceData, aAddHistoryPriceData)

        if tPriceHistoryData and aItemData then
            -- Supprimer temporairement les lignes de DisenchantBuddy du scan
            -- principal : elles sont réinjectées séparément SANS prix plus bas.
            -- Évite les doublons et l'affichage de prix de désenchantement.
            local dbHad, dbSaved = false, nil
            if DisenchantBuddy_Profile and type(DisenchantBuddy_Profile) == "table" then
                dbHad = true
                dbSaved = DisenchantBuddy_Profile.Modifier
                DisenchantBuddy_Profile.Modifier = "SHIFT" -- gate actif (Maj non pressée) -> DB muet
            end

            -- Déclencher les hooks des addons tiers via GameTooltip. Propriétaire
            -- WorldFrame (toujours visible) : le menu Sku masque souvent UIParent,
            -- ce qui empêcherait le tooltip de se remplir.
            GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            GameTooltip:ClearLines()
            if aItemData[21] then
                GameTooltip:SetHyperlink(aItemData[21])
            else
                GameTooltip:SetHyperlink("item:" .. aItemData[17])
            end

            -- Extraction séquentielle et ordonnée des lignes de GameTooltip
            local otherAddonsLines = {}
            local numLines = GameTooltip:NumLines() or 0
            for i = 1, numLines do
                local leftLine = _G["GameTooltipTextLeft" .. i]
                local rightLine = _G["GameTooltipTextRight" .. i]
                local leftText = leftLine and leftLine:GetText() or ""
                local rightText = rightLine and rightLine:GetText() or ""
                local lineText = leftText
                if rightText ~= "" then
                    lineText = lineText .. " " .. rightText
                end
                if lineText ~= "" then
                    table.insert(otherAddonsLines, lineText)
                end
            end
            GameTooltip:Hide()

            if dbHad then
                DisenchantBuddy_Profile.Modifier = dbSaved -- restauration
            end

            local fullText = ""
            if #otherAddonsLines > 0 then
                fullText = table.concat(otherAddonsLines, "\r\n")
            else
                fullText = tPriceHistoryData[1] or ""
            end

            -- Comparaison d'équipement
            local itemID = aItemData[17]
            if itemID then
                local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID)
                if itemEquipLoc and itemEquipLoc ~= "" then
                    local INVSLOT_HEAD = INVSLOT_HEAD or 1
                    local INVSLOT_NECK = INVSLOT_NECK or 2
                    local INVSLOT_SHOULDER = INVSLOT_SHOULDER or 3
                    local INVSLOT_BODY = INVSLOT_BODY or 4
                    local INVSLOT_CHEST = INVSLOT_CHEST or 5
                    local INVSLOT_WAIST = INVSLOT_WAIST or 6
                    local INVSLOT_LEGS = INVSLOT_LEGS or 7
                    local INVSLOT_FEET = INVSLOT_FEET or 8
                    local INVSLOT_WRIST = INVSLOT_WRIST or 9
                    local INVSLOT_HAND = INVSLOT_HAND or 10
                    local INVSLOT_FINGER1 = INVSLOT_FINGER1 or 11
                    local INVSLOT_FINGER2 = INVSLOT_FINGER2 or 12
                    local INVSLOT_TRINKET1 = INVSLOT_TRINKET1 or 13
                    local INVSLOT_TRINKET2 = INVSLOT_TRINKET2 or 14
                    local INVSLOT_BACK = INVSLOT_BACK or 15
                    local INVSLOT_MAINHAND = INVSLOT_MAINHAND or 16
                    local INVSLOT_OFFHAND = INVSLOT_OFFHAND or 17
                    local INVSLOT_RANGED = INVSLOT_RANGED or 18

                    local equipLocToSlot = {
                        ["INVTYPE_HEAD"] = { INVSLOT_HEAD },
                        ["INVTYPE_NECK"] = { INVSLOT_NECK },
                        ["INVTYPE_SHOULDER"] = { INVSLOT_SHOULDER },
                        ["INVTYPE_BODY"] = { INVSLOT_BODY },
                        ["INVTYPE_CHEST"] = { INVSLOT_CHEST },
                        ["INVTYPE_ROBE"] = { INVSLOT_CHEST },
                        ["INVTYPE_WAIST"] = { INVSLOT_WAIST },
                        ["INVTYPE_LEGS"] = { INVSLOT_LEGS },
                        ["INVTYPE_FEET"] = { INVSLOT_FEET },
                        ["INVTYPE_WRIST"] = { INVSLOT_WRIST },
                        ["INVTYPE_HAND"] = { INVSLOT_HAND },
                        ["INVTYPE_FINGER"] = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
                        ["INVTYPE_TRINKET"] = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
                        ["INVTYPE_CLOAK"] = { INVSLOT_BACK },
                        ["INVTYPE_WEAPON"] = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
                        ["INVTYPE_SHIELD"] = { INVSLOT_OFFHAND },
                        ["INVTYPE_2HWEAPON"] = { INVSLOT_MAINHAND },
                        ["INVTYPE_WEAPONMAINHAND"] = { INVSLOT_MAINHAND },
                        ["INVTYPE_WEAPONOFFHAND"] = { INVSLOT_OFFHAND },
                        ["INVTYPE_HOLDABLE"] = { INVSLOT_OFFHAND },
                        ["INVTYPE_RANGED"] = { INVSLOT_RANGED },
                        ["INVTYPE_RANGEDRIGHT"] = { INVSLOT_RANGED },
                        ["INVTYPE_THROWN"] = { INVSLOT_RANGED },
                        ["INVTYPE_RELIC"] = { INVSLOT_RANGED },
                    }

                    local slots = equipLocToSlot[itemEquipLoc]
                    if slots then
                        for _, slotID in ipairs(slots) do
                            local equippedLink = GetInventoryItemLink("player", slotID)
                            if equippedLink then
                                -- Notre propre tooltip (propriétaire WorldFrame), pour ne PAS
                                -- perturber SkuScanningTooltip que Sku utilise pour lire les sacs.
                                local scanTooltip = ns.GetScanTooltip and ns.GetScanTooltip()
                                if scanTooltip then
                                    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                                    scanTooltip:ClearLines()
                                    scanTooltip:SetHyperlink(equippedLink)

                                    local equippedLines = {}
                                    local numEquippedLines = scanTooltip:NumLines() or 0
                                    for k = 1, numEquippedLines do
                                        local leftLine = _G[ns.ScanTooltipName .. "TextLeft" .. k]
                                        local rightLine = _G[ns.ScanTooltipName .. "TextRight" .. k]
                                        local leftText = leftLine and leftLine:GetText() or ""
                                        local rightText = rightLine and rightLine:GetText() or ""
                                        local lineText = leftText
                                        if rightText ~= "" then
                                            lineText = lineText .. " " .. rightText
                                        end
                                        if lineText ~= "" then
                                            table.insert(equippedLines, lineText)
                                        end
                                    end

                                    if #equippedLines > 0 then
                                        local equippedText = table.concat(equippedLines, "\r\n")
                                        local slotLabel = ns.T["SlotCurrent"]
                                        if slotID == INVSLOT_FINGER2 then
                                            slotLabel = ns.T["SlotFinger2"]
                                        elseif slotID == INVSLOT_TRINKET2 then
                                            slotLabel = ns.T["SlotTrinket2"]
                                        elseif slotID == INVSLOT_OFFHAND then
                                            slotLabel = ns.T["SlotOffhand"]
                                        end
                                        fullText = fullText .. "\r\n\r\n"
                                            .. string.format(ns.T["CompareHeader"], slotLabel)
                                            .. "\r\n" .. equippedText
                                    end
                                    scanTooltip:Hide()
                                end
                            end
                        end
                    end
                end

                -- Bloc ingrédients / artisanat avec les prix scannés par Sku
                local reagentText = ns.BuildReagentInfoText and ns.BuildReagentInfoText(itemID)
                if reagentText and reagentText ~= "" then
                    fullText = fullText .. "\r\n\r\n" .. reagentText
                end

                -- Matériaux de désenchantement (via DisenchantBuddy), SANS prix
                local dbLink = aItemData[21] or ("item:" .. itemID)
                local disenchantText = ns.BuildDisenchantText and ns.BuildDisenchantText(dbLink)
                if disenchantText and disenchantText ~= "" then
                    fullText = fullText .. "\r\n\r\n" .. disenchantText
                end
            end

            -- Qualité de l'objet appondue au nom (« Nom (Épique) »), comme dans
            -- les info-bulles natives de Sku.
            fullText = AppendQualityToFirstLine(fullText, GetItemQualityString(aItemData))

            -- Sku 42 : Unescape a déménagé de SkuChat vers SkuUtil
            if SkuUtil and SkuUtil.Unescape then
                tPriceHistoryData[1] = SkuUtil:Unescape(fullText)
            elseif SkuChat and SkuChat.Unescape then
                tPriceHistoryData[1] = SkuChat:Unescape(fullText)
            else
                tPriceHistoryData[1] = fullText
            end
        end

        return tTextFirstLine, tPriceHistoryData
    end
end

ns.onReady(InstallTooltipHook)
