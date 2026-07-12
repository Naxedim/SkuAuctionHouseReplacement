-- Compat.lua — Shared low-level helpers exposed on ns.
--
-- Container/cursor API wrappers (modern C_Container with classic fallbacks),
-- coin math, soulbound detection, and the sell-item staging + result-capture
-- helpers used by the sell menu. All are attached to ns so the feature modules
-- (loaded after this file) can share them.

local addonName, ns = ...

------------------------------------------------------------------------------
-- Container API wrappers (WoW modern / classic)
------------------------------------------------------------------------------

ns.GetContainerItemInfo = GetContainerItemInfo or function(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.iconFileID, info.stackCount, info.isLocked, info.quality,
                info.isReadable, info.isLootable, info.hyperlink, info.isFiltered,
                info.hasNoValue, info.itemID, info.isBound
        end
    end
end

ns.GetContainerNumSlots = GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots)

-- Fast, safe soulbound check (avoids freezing the client).
function ns.IsItemBound(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return (info and info.isBound) or false
    end
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return (loc and C_Item.IsBound(loc)) or false
end

------------------------------------------------------------------------------
-- Coin math
------------------------------------------------------------------------------

function ns.SplitCoin(aCopper)
    local gold = math.floor(aCopper / 10000)
    local silver = math.floor((aCopper - (gold * 10000)) / 100)
    local copper = aCopper - (gold * 10000) - (silver * 100)
    return gold, silver, copper
end

function ns.CombineCoin(aGold, aSilver, aCopper)
    return (aGold or 0) * 10000 + (aSilver or 0) * 100 + (aCopper or 0)
end

------------------------------------------------------------------------------
-- Sell-item staging (post an auction from a specific bag item)
------------------------------------------------------------------------------

function ns.Log(_, _)
    -- Local debug hook (no-op).
end

local _PickupContainerItem = PickupContainerItem -- capture the global before shadowing
local function DoPickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif _PickupContainerItem then
        _PickupContainerItem(bag, slot)
    end
end

local function SlotItemId(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.itemID or nil
    end
    if GetContainerItemInfo then
        return select(10, GetContainerItemInfo(bag, slot))
    end
    return nil
end

-- Put the requested item into the auction "sell" slot. Prefers the given
-- bag/slot, otherwise scans the bags for a matching item id.
function ns.StageSellItem(aItemId, aPreferBag, aPreferSlot)
    if not aItemId then return false end
    local tBag, tSlot
    if aPreferBag and aPreferSlot and SlotItemId(aPreferBag, aPreferSlot) == aItemId then
        tBag, tSlot = aPreferBag, aPreferSlot
    else
        for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
            local n = (ns.GetContainerNumSlots and ns.GetContainerNumSlots(bag)) or 0
            for slot = 1, n do
                if SlotItemId(bag, slot) == aItemId then
                    tBag, tSlot = bag, slot
                    break
                end
            end
            if tBag then break end
        end
    end
    if not tBag then return false end
    ClearCursor()
    DoPickupContainerItem(tBag, tSlot)
    ClickAuctionSellItemButton()
    ClearCursor()
    return true
end

------------------------------------------------------------------------------
-- Post-result capture (listens to server messages for a short window)
------------------------------------------------------------------------------

local _ASMsgFrame = _G["SkuAuctionSellMsgFrame"]
local _ASMsgTimer
local _ASMultisellEvents = {
    "AUCTION_MULTISELL_START", "AUCTION_MULTISELL_UPDATE",
    "AUCTION_MULTISELL_FAILURE", "AUCTION_HOUSE_CLOSED",
}

function ns.StopResultCapture()
    if _ASMsgFrame then
        _ASMsgFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        _ASMsgFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
        for _, e in ipairs(_ASMultisellEvents) do
            pcall(_ASMsgFrame.UnregisterEvent, _ASMsgFrame, e)
        end
    end
    if _ASMsgTimer then
        _ASMsgTimer:Cancel()
        _ASMsgTimer = nil
    end
end

function ns.CaptureResult()
    ns.StopResultCapture()
    if _ASMsgFrame then
        _ASMsgFrame:RegisterEvent("UI_ERROR_MESSAGE")
        _ASMsgFrame:RegisterEvent("CHAT_MSG_SYSTEM")
        for _, e in ipairs(_ASMultisellEvents) do
            pcall(_ASMsgFrame.RegisterEvent, _ASMsgFrame, e)
        end
    end
    _ASMsgTimer = C_Timer.NewTimer(8, ns.StopResultCapture)
end

------------------------------------------------------------------------------
-- Dedicated scanning tooltip (NEVER touch Sku's SkuScanningTooltip)
------------------------------------------------------------------------------
--
-- Sku creates SkuScanningTooltip with SetOwner(WorldFrame, ...) ON PURPOSE, so
-- it keeps working while the Sku menu hides UIParent, and it re-reads it WITHOUT
-- re-setting the owner. If we scan on that same tooltip and change its owner to
-- UIParent, Sku's later bag reads break ("empty bags") once UIParent is hidden.
-- We therefore use our OWN tooltip, owned by WorldFrame like Sku's.

ns.ScanTooltipName = "SkuAHRScanTooltip"

local _ahrScanTooltip
function ns.GetScanTooltip()
    if not _ahrScanTooltip then
        _ahrScanTooltip = CreateFrame("GameTooltip", ns.ScanTooltipName, nil, "GameTooltipTemplate")
        _ahrScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return _ahrScanTooltip
end
