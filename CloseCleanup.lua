-- CloseCleanup.lua — Keep the auction house and the Sku menu in sync on close,
-- and guarantee Enter/Escape are freed afterwards.
--
-- Observed bug (blind user, quits with Escape only): after closing the AH the
-- ARROW keys work again (character moves) but ENTER and ESCAPE still trigger Sku
-- sounds, the screen reader goes silent and chat can't be opened. Those two keys
-- — and only those two — are what the secure-buy binder (SkuAuctionSecureBinder)
-- binds (ENTER / NUMPADENTER / ESCAPE). That binder is a standalone frame, not
-- tied to the menu's visibility, which is exactly why arrows free up but not
-- Enter/Escape. Sku's own menu buttons can also get Enter/Escape re-bound by the
-- buy-restore path at a bad moment.
--
-- Fix: whenever the Sku menu closes, aggressively clear the override bindings on
-- every frame that could hold Enter/Escape (the buy binder AND the menu buttons),
-- in several passes to defeat any late re-arm. This is safe: when the menu is
-- closed there is no buy interaction in progress and no menu bindings are needed;
-- reopening the menu re-installs them via the buttons' OnShow.

local addonName, ns = ...

local function InstallCloseHandlers()
    local tAHCloseSyncing = false

    -- Purge des bindings Entrée/Échap résiduelles. Ne s'exécute QUE si le menu
    -- Sku est fermé (sinon les bindings sont légitimes) et hors combat.
    local function tClearStuckBindings()
        if InCombatLockdown and InCombatLockdown() then return end
        local main = _G["OnSkuOptionsMain"]
        if main and main.IsShown and main:IsShown() then
            return -- menu réellement ouvert : ne rien toucher
        end
        for _, name in ipairs({
            "SkuAuctionSecureBinder",        -- binder d'achat : Entrée/NumpadEntrée/Échap
            "OnSkuOptionsMainOption1",        -- flèches + Échap du menu
            "SecureOnSkuOptionsMainOption1",  -- Entrée du menu
        }) do
            local f = _G[name]
            if f then pcall(ClearOverrideBindings, f) end
        end
    end

    -- Plusieurs passes : tout de suite, puis après les timers/ré-armements de Sku.
    local function tScheduleClears()
        tClearStuckBindings()
        C_Timer.After(0.10, tClearStuckBindings)
        C_Timer.After(0.35, tClearStuckBindings)
        C_Timer.After(1.00, tClearStuckBindings)
    end

    -- D. À la fermeture du menu Sku : fermer l'HdV Blizzard si besoin, purger le
    -- curseur (correctif sacs) et LIBÉRER Entrée/Échap (le cœur du correctif).
    local tFrame = _G["OnSkuOptionsMain"]
    if tFrame then
        local originalOnHide = tFrame:GetScript("OnHide")
        tFrame:SetScript("OnHide", function(self)
            if SkuCore.AuctionHouseOpen == true and not tAHCloseSyncing then
                tAHCloseSyncing = true
                SkuCore.AuctionHouseOpen = false
                pcall(CloseAuctionHouse)
                tAHCloseSyncing = false
            end
            pcall(ClearCursor)
            if originalOnHide then
                originalOnHide(self)
            end
            -- Le menu vient de se masquer : purger les bindings coincées.
            tScheduleClears()
        end)
    end

    -- G. Réconciliation quand l'HdV se ferme par un autre biais que la remontée
    -- du menu (Échap sur le cadre Blizzard, éloignement du PNJ…). Ferme le menu
    -- Sku de façon fiable, puis purge les bindings.
    local tReconcilePending = false
    local function tReconcileAHClosed()
        tReconcilePending = false
        if SkuCore.AuctionHouseOpen == true then return end
        if InCombatLockdown and InCombatLockdown() then return end

        pcall(ClearCursor)

        -- Fermer le menu Sku de façon fiable : CloseMenu (voie officielle) puis,
        -- en filet, un Hide() direct (déclenche le OnHide -> tScheduleClears).
        local main = _G["OnSkuOptionsMain"]
        if main and main.IsShown and main:IsShown() then
            tAHCloseSyncing = true
            if SkuOptions and SkuOptions.CloseMenu then
                pcall(function() SkuOptions:CloseMenu() end)
            end
            if main:IsShown() then
                pcall(function() main:Hide() end)
            end
            tAHCloseSyncing = false
        end

        tScheduleClears()
    end
    local function tScheduleReconcile()
        if tReconcilePending then return end
        tReconcilePending = true
        C_Timer.After(0.05, tReconcileAHClosed)
    end

    -- Source 1a : hook de la méthode de session de Sku.
    -- Sku 42 : AUCTION_HOUSE_CLOSED/SHOW sont des méthodes du module
    -- SkuCore.AuctionHouse (AceEvent résout la méthode au moment de
    -- l'événement, donc remplacer le champ du module fonctionne) ;
    -- sur Sku 41 elles étaient sur SkuCore.
    local tEvtHost = (SkuCore.AuctionHouse and SkuCore.AuctionHouse.AUCTION_HOUSE_CLOSED)
        and SkuCore.AuctionHouse or SkuCore
    local originalAuctionHouseClosed = tEvtHost.AUCTION_HOUSE_CLOSED
    tEvtHost.AUCTION_HOUSE_CLOSED = function(self, ...)
        if originalAuctionHouseClosed then
            originalAuctionHouseClosed(self, ...)
        end
        tScheduleReconcile()
    end

    -- Source 1b : notre PROPRE écoute de l'événement, indépendante du hook
    -- ci-dessus (au cas où l'ordre d'enregistrement changerait un jour).
    local tEventFrame = CreateFrame("Frame")
    tEventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    tEventFrame:SetScript("OnEvent", function()
        tScheduleReconcile()
    end)

    -- Source 2 : fermeture de la fenêtre Blizzard (Échap sur le cadre, croix…).
    -- AuctionFrame est load-on-demand : on attache le hook à la 1re ouverture.
    local tAuctionFrameHooked = false
    local function tHookAuctionFrame()
        if tAuctionFrameHooked then return end
        local tAF = _G["AuctionFrame"]
        if tAF and tAF.HookScript then
            tAuctionFrameHooked = true
            tAF:HookScript("OnHide", function()
                tScheduleReconcile()
            end)
        end
    end
    local originalAuctionHouseShow = tEvtHost.AUCTION_HOUSE_SHOW
    tEvtHost.AUCTION_HOUSE_SHOW = function(self, ...)
        if originalAuctionHouseShow then
            originalAuctionHouseShow(self, ...)
        end
        tHookAuctionFrame()
    end
    tHookAuctionFrame()
end

ns.onReady(InstallCloseHandlers)
