-- enUS.lua — Base / fallback locale for SkuAuctionHouseReplacement
--
-- Two sub-tables:
--   * sku : translations injected into Sku's active locale (Sku.L). They map
--           Sku's internal (German) keys to the displayed string. For enUS this
--           is empty because Sku already ships English strings.
--   * ui  : this addon's OWN strings (menu labels, tooltip headers, messages).
--
-- To add a language: copy this file to Locales/<locale>.lua (e.g. deDE.lua),
-- fill the two tables, and add the file to the .toc. The addon automatically
-- uses the table matching the client locale and falls back to enUS per key.

local _, ns = ...
ns.locales = ns.locales or {}

ns.locales["enUS"] = {
    -- Nothing to override: Sku already provides English.
    sku = {},

    ui = {
        -- Sort order labels (auction list)
        ["SortByBuy1"] = "Buyout price per item, ascending",
        ["SortByBuy2"] = "Buyout price per stack, ascending",
        ["SortByBid1"] = "Bid price per item, ascending",
        ["SortByBid2"] = "Bid price per stack, ascending",
        ["SortLevelDesc"] = "Level, descending",
        ["SortLevelAsc"] = "Level, ascending",

        -- Equipment comparison (item tooltip)
        ["CompareHeader"] = "[Comparison: Equipped (%s)]",
        ["SlotCurrent"] = "Current",
        ["SlotFinger2"] = "Finger 2",
        ["SlotTrinket2"] = "Trinket 2",
        ["SlotOffhand"] = "Off hand",

        -- Reagent / disenchant / cooking price info (item tooltip)
        ["DisenchantHeader"] = "Disenchant (materials and prices)",
        ["DisenchantAvg"] = "Estimated average value",
        ["CookIngredientsHeader"] = "Cooking ingredients",
        ["AlchemyMatsHeader"] = "Alchemy ingredients",
        ["ReagentUsedInHeader"] = "Used in recipes",
        ["PriceEach"] = "each",
        ["PriceTotal"] = "total",
        ["PriceUnknown"] = "no price",
        ["Chance"] = "chance",

        -- Auto scan option
        ["AutoScanName"] = "Auto full scan on open",
        ["On"] = "on",
        ["Off"] = "off",
        ["AutoScanEnabled"] = "Automatic scan enabled",
        ["AutoScanDisabled"] = "Automatic scan disabled",

        -- Boot messages
        ["Loaded"] = "SkuAuctionHouseReplacement loaded successfully!",
        ["ErrNoCore"] = "[SkuAuctionHouseReplacement] Error: SkuCore not found or not loaded.",
    },
}
