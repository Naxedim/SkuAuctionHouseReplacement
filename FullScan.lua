-- FullScan.lua — Full-scan speed-up + automatic scan on open
--
--   * Overrides SkuCore.AuctionFullScanProcessChunk to ingest 400 rows/frame.
--   * Adds a per-character "auto full scan on open" toggle to the AH menu.
--   * When enabled, launches a full scan shortly after the auction house opens
--     (respecting Sku's own cooldown and the server's getAll availability).

local addonName, ns = ...

local MODULE_NAME = "SkuCore"

-- Sku 42 : les fonctions Auction* vivent sur le sous-module SkuCore.AuctionHouse
-- (handle publié) ; sur Sku 41 elles étaient sur SkuCore.
local function AHHost()
    if SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionFullScanProcessChunk then
        return SkuCore.AuctionHouse
    end
    return SkuCore
end

-- Sku 42 : l'horodatage du dernier scan complet est passé de
-- SkuOptions.db.char["SkuCore"] à SkuSettings:Sub("SkuCore", nil, "char").
local function CharStore()
    if SkuSettings and SkuSettings.Sub then
        return SkuSettings:Sub("SkuCore", nil, "char")
    end
    return SkuOptions.db and SkuOptions.db.char and SkuOptions.db.char[MODULE_NAME]
end

------------------------------------------------------------------------------
-- A. Faster getAll ingest (400 items per frame)
------------------------------------------------------------------------------

local function InstallFastIngest()
    local tAH = AHHost()
    tAH.AuctionFullScanProcessChunk = function(self)
        local fs = SkuCore.FullScanIngest
        if not fs or not fs.active then return end

        local tEnd = math.min(fs.processed + 400, fs.total) -- Chunk size sécurisé à 400
        local tDB = FullScanResultsDB
        local i = fs.processed
        while i < tEnd do
            i = i + 1
            local tInfo = { fs.getInfo("list", i) }
            if (not tInfo[1] or tInfo[1] == "") and not tInfo[17] then
                fs.reachedEnd = true
                break
            end
            tInfo[21] = fs.getLink("list", i)
            local tID = tInfo[17]
            if tInfo[6] == nil or tInfo[6] > 10000 then
                local row = tID and fs.itemData[tID]
                if row then tInfo[6] = row[fs.reqLevelKey] end
                if tInfo[6] == nil then tInfo[6] = fs.fallbackLevel end
            end
            if tInfo[1] == "" and tID and fs.itemLookup[tID] then
                tInfo[1] = fs.itemLookup[tID]
            end
            fs.dbn = fs.dbn + 1
            tDB[fs.dbn] = tInfo
        end
        fs.processed = i

        if not fs.reachedEnd and fs.total > 0 then
            local tPct = math.floor(fs.processed * 100 / fs.total)
            while tPct >= fs.nextPct and fs.nextPct <= 100 do
                local tSay = fs.nextPct
                pcall(function()
                    SkuOptions.Voice:OutputStringBTtts(tSay .. ns.L[" Prozent"], false, true, 0.2, nil, nil, nil, 2)
                end)
                fs.nextPct = fs.nextPct + 25
            end
        end

        if fs.reachedEnd or fs.processed >= fs.total then
            tAH:AuctionFullScanFinishIngest()
        end
    end
end

------------------------------------------------------------------------------
-- Full-scan trigger (shared by the auto-scan)
------------------------------------------------------------------------------

-- Attempts to start a full (getAll) scan. Returns true if a scan was launched.
-- Mirrors Sku's own "start full scan" menu action: respects the 16-minute
-- cooldown and the server's getAll availability.
function ns.TryStartFullScan()
    if not SkuCore then return false end
    local tAH = AHHost()
    if not tAH.AuctionHouseStartQuery then return false end
    if SkuCore.AuctionHouseOpen ~= true then return false end
    if tAH.AuctionFullScanCooldownRemaining
        and tAH:AuctionFullScanCooldownRemaining() > 0 then
        return false
    end
    local _, canQueryAll = CanSendAuctionQuery()
    if canQueryAll ~= true then return false end

    local started = tAH:AuctionHouseStartQuery(
        nil, "AUCTION_ITEM_LIST_UPDATE", "", nil, nil, nil, nil, nil,
        true, false, nil, function() end
    )
    if started == true then
        local tStore = CharStore()
        if tStore then
            tStore.AuctionLastFullScanTime = GetServerTime()
        end
        pcall(function()
            SkuOptions.Voice:OutputStringBTtts(ns.L["Full scan started"], true, true, 0.1, nil, nil, nil, 1)
        end)
        return true
    end
    return false
end

------------------------------------------------------------------------------
-- Auto-scan on auction house open
------------------------------------------------------------------------------

local function ScheduleAutoScan()
    if not (ns.db and ns.db.autoScan) then return end
    -- The server needs a moment after opening before getAll is available; try a
    -- few times over ~12s, then give up silently. A cooldown or an unavailable
    -- getAll simply means no scan this visit.
    local attempts = 0
    local function attempt()
        if not (ns.db and ns.db.autoScan) then return end
        if SkuCore.AuctionHouseOpen ~= true then return end
        attempts = attempts + 1
        if ns.TryStartFullScan() then return end
        if attempts < 6 then
            C_Timer.After(2, attempt)
        end
    end
    C_Timer.After(1.5, attempt)
end

local function InstallAutoScanOnOpen()
    -- Sku 42 : AUCTION_HOUSE_SHOW est une méthode du module SkuCore.AuctionHouse
    -- (AceEvent résout la méthode au moment de l'événement, donc remplacer le
    -- champ du module fonctionne) ; sur Sku 41 elle était sur SkuCore.
    local tHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AUCTION_HOUSE_SHOW)
        and SkuCore.AuctionHouse or SkuCore
    local originalShow = tHost.AUCTION_HOUSE_SHOW
    tHost.AUCTION_HOUSE_SHOW = function(self, ...)
        if originalShow then originalShow(self, ...) end
        pcall(ScheduleAutoScan)
    end
end

------------------------------------------------------------------------------
-- Auto-scan toggle in the auction house menu
------------------------------------------------------------------------------

local function AutoScanLabel()
    local state = (ns.db and ns.db.autoScan) and ns.T["On"] or ns.T["Off"]
    return ns.T["AutoScanName"] .. " : " .. state
end

local function InstallAutoScanMenuToggle()
    local tHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AuctionHouseMenuBuilder)
        and SkuCore.AuctionHouse or SkuCore
    local originalBuilder = tHost.AuctionHouseMenuBuilder
    tHost.AuctionHouseMenuBuilder = function(self)
        originalBuilder(self)

        if not self then return end

        -- Ne pas ré-injecter si l'entrée existe déjà (au cas où le nœud ne serait
        -- pas reconstruit à chaque passage) : on évite tout doublon.
        if self.children then
            for _, existing in ipairs(self.children) do
                if existing.isAHRAutoScanToggle then
                    existing.name = AutoScanLabel()
                    return
                end
            end
        end

        -- IMPORTANT : entrée-action (comme « start full scan » de Sku).
        -- dynamic=false + pas de BuildChildren => Entrée appelle bien self:OnAction.
        -- (Avec dynamic=true, Sku route Entrée vers parent:OnAction et ignore le nôtre.)
        local tEntry = SkuOptions:InjectMenuItems(self, { AutoScanLabel() }, SkuGenericMenuItem)
        tEntry.isAHRAutoScanToggle = true
        tEntry.dynamic = false
        tEntry.isSelect = true
        tEntry.noStepUpAfterSelect = true
        tEntry.OnEnter = function(node)
            node.name = AutoScanLabel()
            node.textFull = AutoScanLabel()
        end
        tEntry.OnAction = function(node)
            if not ns.db then return end
            ns.db.autoScan = not ns.db.autoScan
            node.name = AutoScanLabel()
            local msg = ns.db.autoScan and ns.T["AutoScanEnabled"] or ns.T["AutoScanDisabled"]
            pcall(function()
                SkuOptions.Voice:OutputStringBTtts(msg, true, true, 0.1, nil, nil, nil, 1)
            end)
            -- If just enabled while the AH is open, try to scan right away.
            if ns.db.autoScan then
                pcall(ScheduleAutoScan)
            end
        end
    end
end

------------------------------------------------------------------------------

ns.onReady(function()
    InstallFastIngest()
    InstallAutoScanOnOpen()
    InstallAutoScanMenuToggle()
end)
