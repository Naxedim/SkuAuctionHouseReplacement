-- deDE.lua — German locale for SkuAuctionHouseReplacement
-- See Locales/enUS.lua for the format (sku = injected into Sku.L, ui = addon strings).
--
-- sku is empty: Sku ships its German strings natively (its internal keys are
-- German, and its own locales/deDE.lua defines every key this addon reads via
-- ns.L — STRAT_*, sort labels, prompts, menu entry names), so nothing needs to
-- be injected on a German client.

local _, ns = ...
ns.locales = ns.locales or {}

ns.locales["deDE"] = {
    sku = {},

    ui = {
        -- Sortierreihenfolge (Auktionsliste)
        ["SortByBuy1"] = "Sofortkaufpreis pro Gegenstand, aufsteigend",
        ["SortByBuy2"] = "Sofortkaufpreis pro Stapel, aufsteigend",
        ["SortByBid1"] = "Gebotspreis pro Gegenstand, aufsteigend",
        ["SortByBid2"] = "Gebotspreis pro Stapel, aufsteigend",
        ["SortLevelDesc"] = "Stufe, absteigend",
        ["SortLevelAsc"] = "Stufe, aufsteigend",

        -- Ausrüstungsvergleich (Gegenstands-Tooltip)
        ["CompareHeader"] = "[Vergleich: Angelegt (%s)]",
        ["SlotCurrent"] = "Aktuell",
        ["SlotFinger2"] = "Finger 2",
        ["SlotTrinket2"] = "Schmuck 2",
        ["SlotOffhand"] = "Schildhand",

        -- Reagenzien / Entzaubern / Kochen Preisinfo (Gegenstands-Tooltip)
        ["DisenchantHeader"] = "Entzaubern (Materialien und Preise)",
        ["DisenchantAvg"] = "Geschätzter Durchschnittswert",
        ["CookIngredientsHeader"] = "Kochzutaten",
        ["AlchemyMatsHeader"] = "Alchemiezutaten",
        ["ReagentUsedInHeader"] = "Verwendet in Rezepten",
        ["PriceEach"] = "pro Stück",
        ["PriceTotal"] = "gesamt",
        ["PriceUnknown"] = "kein Preis",
        ["Chance"] = "Chance",

        -- Auto-Scan-Option
        ["AutoScanName"] = "Automatischer Vollscan beim Öffnen",
        ["On"] = "an",
        ["Off"] = "aus",
        ["AutoScanEnabled"] = "Automatischer Scan aktiviert",
        ["AutoScanDisabled"] = "Automatischer Scan deaktiviert",

        -- Startmeldungen
        ["Loaded"] = "SkuAuctionHouseReplacement erfolgreich geladen!",
        ["ErrNoCore"] = "[SkuAuctionHouseReplacement] Fehler: SkuCore nicht gefunden oder nicht geladen.",
    },
}
