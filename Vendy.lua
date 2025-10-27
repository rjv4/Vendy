-- ============================================================================
-- 1. ADDON INITIALIZATION & SAVED VARIABLES
-- ============================================================================
local function OnPlayerLogin(self, event)
    if VendyDB == nil then VendyDB = {} end
    if VendyDB.enabled == nil then VendyDB.enabled = true end

    local status = VendyDB.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    print(string.format("Vendy loaded and %s. Type /vendy for options.", status))
    self:UnregisterEvent("PLAYER_LOGIN")
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", OnPlayerLogin)



-- ============================================================================
-- 2. SLASH COMMAND HANDLER
-- ============================================================================
local function SlashCmdHandler(msg, editbox)
    local command = strlower(msg)
    if command == "on" then
        VendyDB.enabled = true
        print("Vendy is now |cff00ff00ON|r.")
    elseif command == "off" then
        VendyDB.enabled = false
        print("Vendy is now |cffff0000OFF|r.")
    else
        print("--- Vendy Options ---")
        print("/vendy on: Enables the vendor filter.")
        print("/vendy off: Disables the vendor filter.")
    end
    
    if MerchantFrame and MerchantFrame:IsVisible() then
        MerchantFrame_Update()
    end
end

SLASH_Vendy1 = "/vendy"; SLASH_Vendy2 = "/Vendy"
SlashCmdList["Vendy"] = SlashCmdHandler



-- ============================================================================
-- 3. HELPER FUNCTION
-- ============================================================================
local function isArmorTypeInList(armorType, list)
    for _, value in ipairs(list) do
        if value == armorType then
            return true
        end
    end
    return false
end



-- ============================================================================
-- 4. CORE FILTERING LOGIC
-- ============================================================================
local classArmorBlacklist = {
	-- Cloth
    ["MAGE"] = {},
    ["WARLOCK"] = {},
    ["PRIEST"] = {},
	
    -- Leather
    ["DRUID"] = { "Cloth" },
    ["ROGUE"] = { "Cloth" },
    ["MONK"] =  { "Cloth" },

    -- Mail
    ["HUNTER"] = { "Cloth", "Leather" },
    ["SHAMAN"] = { "Cloth", "Leather" },

    -- Plate
    ["WARRIOR"] = { "Cloth", "Leather", "Mail" },
    ["PALADIN"] = { "Cloth", "Leather", "Mail" },
    ["DEATHKNIGHT"] = { "Cloth", "Leather", "Mail" }
}

hooksecurefunc("MerchantFrame_Update", function()
    C_Timer.After(0.05, function()
        if not VendyDB then return end

        local _, playerClass = UnitClass("player")
        local armorToFilter = classArmorBlacklist[playerClass]
        local filteredAlpha = VendyDB.filteredAlpha or 0.3

        for i = 1, MERCHANT_ITEMS_PER_PAGE do
            local button = _G["MerchantItem" .. i]
            local index = i + (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
            local itemLink = GetMerchantItemLink(index)
            local itemID = GetMerchantItemID(index)

            if button and itemLink and itemID then
                local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemLink)
                local shouldBeGreyedOut = false
                
                if VendyDB.enabled and armorToFilter then
                    if itemType == "Armor" and isArmorTypeInList(itemSubType, armorToFilter) and equipLoc ~= "INVTYPE_CLOAK" then
                        shouldBeGreyedOut = true
                    end

                    if not shouldBeGreyedOut and equipLoc and equipLoc ~= "" and not C_PlayerInfo.CanUseItem(itemID) then
                        shouldBeGreyedOut = true
                    end
                end

                if shouldBeGreyedOut then
                    button:SetAlpha(filteredAlpha)
                    if button.icon then button.icon:SetDesaturated(true) end
                else
                    button:SetAlpha(1.0)
                    if button.icon then button.icon:SetDesaturated(false) end
                end
            end
        end
    end)
end)
