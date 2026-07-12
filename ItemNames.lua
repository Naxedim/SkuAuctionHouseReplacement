-- ItemNames.lua — Noms d'objets localisés dans « enchères par objet » (frFR)
--
-- Problème : la liste des objets d'une sous-catégorie (ex. toutes les haches à
-- une main du jeu, tous les sacs) est construite par
-- SkuCore.AuctionHouse:AuctionHouseBuildItemDBMenu, qui lit le nom de chaque
-- objet dans SkuDB.itemLookup[Sku.Loc]. Sur un client français, Sku.Loc vaut
-- "enUS" et il n'existe pas de table frFR : sans traduction, la liste s'affiche
-- en anglais. Or la plupart de ces objets n'ont jamais été rencontrés, donc ne
-- sont pas dans le cache du client : GetItemInfo renvoie nil et on ne peut pas
-- les traduire immédiatement. Impossible alors pour un utilisateur aveugle de
-- repérer et sélectionner tel sac ou telle arme précise.
--
-- Solution : on enveloppe AuctionHouseBuildItemDBMenu. Après la construction
-- native, on retrouve l'itemID de chaque entrée (mapping nom anglais → itemID,
-- reconstruit avec le même filtre classe/sous-classe que Sku) et on le STOCKE
-- sur l'entrée. On traduit tout de suite les objets déjà en cache (GetItemInfo),
-- et on demande le chargement des autres. À l'arrivée d'un nom
-- (GET_ITEM_INFO_RECEIVED), on re-libelle l'entrée par son itemID (appariement
-- fiable, insensible au tri/renommage) — sans reconstruire la liste, donc sans
-- déplacer le curseur — et on re-annonce si c'est l'entrée sous le curseur.
--
-- Ne concerne que le client français (sur enUS/deDE Sku affiche déjà des noms
-- natifs).

local addonName, ns = ...

-- Sku 42 : les fonctions Auction* vivent sur SkuCore.AuctionHouse (repli SkuCore).
local function AHHost()
    if SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseBuildItemDBMenu then
        return SkuCore.AuctionHouse
    end
    return SkuCore
end

-- Applique un nom localisé à une entrée de menu.
local function SetName(aEntry, aName)
    aEntry.name = aName
    aEntry.textFirstLine = aName
end

-- Dérive classID/subClassID de la catégorie Blizzard, comme le fait Sku.
local function DeriveFilter(aCat, aSub, aSubSub)
    if not AuctionCategories then return nil end
    local tNode
    if aCat and aSub and aSubSub then
        tNode = AuctionCategories[aCat] and AuctionCategories[aCat].subCategories[aSub]
            and AuctionCategories[aCat].subCategories[aSub].subCategories[aSubSub]
    elseif aCat and aSub then
        tNode = AuctionCategories[aCat] and AuctionCategories[aCat].subCategories[aSub]
    elseif aCat then
        tNode = AuctionCategories[aCat]
    end
    if not (tNode and tNode.filters and tNode.filters[1]) then return nil end
    return tNode.filters[1].classID, tNode.filters[1].subClassID
end

-- Mapping { nom anglais → itemID } pour une classe/sous-classe, mis en cache
-- (l'itération de toute la base d'objets est coûteuse ; on ne la refait pas à
-- chaque ré-entrée dans la même sous-catégorie).
local tNameIdCache = {}
-- Mapping global { nom anglais → itemID } de tout ce qui a été listé, pour
-- traduire le texte des requêtes serveur (voir le hook de StartQuery).
local tEnNameToId = {}
local function NameIdMap(aClassID, aSubClassID)
    local tKey = tostring(aClassID) .. ":" .. tostring(aSubClassID)
    if tNameIdCache[tKey] then return tNameIdCache[tKey] end
    local tMap = {}
    if SkuDB and SkuDB.itemDataTBC and SkuDB.itemKeys then
        local kName, kClass, kSub = SkuDB.itemKeys.name, SkuDB.itemKeys.class, SkuDB.itemKeys.subClass
        for i, v in pairs(SkuDB.itemDataTBC) do
            if v[kClass] == aClassID and v[kSub] == aSubClassID then
                local tEn = v[kName]
                if tEn and not tMap[tEn] then
                    tMap[tEn] = i
                    tEnNameToId[tEn] = i
                end
            end
        end
    end
    tNameIdCache[tKey] = tMap
    return tMap
end

local function InstallItemNames()
    if GetLocale() ~= "frFR" then return end

    local tAH = AHHost()
    if not tAH.AuctionHouseBuildItemDBMenu then return end

    -- 1. Enveloppe du constructeur de la liste d'objets.
    local orig = tAH.AuctionHouseBuildItemDBMenu
    tAH.AuctionHouseBuildItemDBMenu = function(self, aNode, aCat, aSub, aSubSub)
        orig(self, aNode, aCat, aSub, aSubSub)
        if not (aNode and aNode.children) then return end

        local classID, subClassID = DeriveFilter(aCat, aSub, aSubSub)
        if not classID then return end
        local tMap = NameIdMap(classID, subClassID)

        for _, tChild in ipairs(aNode.children) do
            -- Les entrées non traduites portent encore le nom anglais, présent
            -- dans le mapping ; les entrées déjà en français (objets en cache)
            -- et l'entrée « Tout » n'y sont pas et sont laissées telles quelles.
            local tItemID = tChild.name and tMap[tChild.name]
            if tItemID then
                tChild.itemId = tItemID
                local tFr = GetItemInfo(tItemID)
                if tFr and tFr ~= tChild.name then
                    SetName(tChild, tFr)            -- déjà en cache → traduire tout de suite
                elseif not tFr then
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, tItemID)  -- forcer le chargement
                    end
                end
            end
        end
    end

    -- 2. Re-libellage à l'arrivée des noms chargés de façon asynchrone.
    local function RelabelByItemId(aNode, aItemID, aFr)
        if not (aNode and aNode.children) then return false end
        local tChanged = false
        for _, tChild in ipairs(aNode.children) do
            if tChild.itemId == aItemID and tChild.name ~= aFr then
                SetName(tChild, aFr)
                tChanged = true
            end
        end
        return tChanged
    end

    local tFrame = CreateFrame("Frame")
    tFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    tFrame:SetScript("OnEvent", function(_, _, aItemID, aSuccess)
        if aSuccess == false then return end
        if SkuCore.AuctionHouseOpen ~= true then return end
        local tPos = SkuOptions and SkuOptions.currentMenuPosition
        if not tPos then return end
        local tFr = GetItemInfo(aItemID)
        if not tFr then return end

        -- La liste peut être le nœud courant (curseur sur la sous-catégorie) ou
        -- son parent (curseur sur un objet de la liste).
        local tChanged = RelabelByItemId(tPos, aItemID, tFr)
        tChanged = RelabelByItemId(tPos.parent, aItemID, tFr) or tChanged

        -- Si c'est l'objet précisément sous le curseur, l'annoncer maintenant en
        -- français (l'utilisateur n'a pas à naviguer ailleurs et revenir).
        if tChanged and tPos.itemId == aItemID then
            pcall(function() SkuOptions.Voice:OutputStringBTtts(tFr, true, false, 0.2) end)
        end
    end)

    -- 3. Traduction du texte des requêtes serveur. Quand on sélectionne un
    -- objet de la liste, le OnEnter natif de Sku lance la recherche avec le
    -- nom CAPTURÉ à la construction (variable interne tLocName) — donc le nom
    -- anglais — en correspondance exacte. Sur un client français, l'hôtel des
    -- ventes compare aux noms français : « Runecloth Bag » ne correspond à
    -- rien → 0 résultat alors que des « Sac en étoffe runique » sont en vente.
    -- On intercepte donc AuctionHouseStartQuery : si le texte est un nom
    -- anglais connu de nos listes et que sa traduction est chargée, on le
    -- remplace par le nom français avant l'envoi. Les autres requêtes
    -- (recherche libre, achat stratégique, scan complet, texte vide) ne sont
    -- jamais touchées : leur texte n'est pas dans le mapping.
    local origStartQuery = tAH.AuctionHouseStartQuery
    tAH.AuctionHouseStartQuery = function(self, aContinue, aType, aFilterText, ...)
        if type(aFilterText) == "string" and aFilterText ~= "" then
            local tItemID = tEnNameToId[aFilterText]
            if tItemID then
                local tFr = GetItemInfo(tItemID)
                if tFr and tFr ~= aFilterText then
                    aFilterText = tFr
                end
            end
        end
        return origStartQuery(self, aContinue, aType, aFilterText, ...)
    end
end

ns.onReady(InstallItemNames)
