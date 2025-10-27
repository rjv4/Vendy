-- ============================================================================
-- 1. ADDON INITIALIZATION & SAVED VARIABLES
-- ============================================================================
local function OnPlayerLogin(self, event)
    if VendyDB == nil then VendyDB = {} end
    if VendyDB.enabled == nil then VendyDB.enabled = true end
    if VendyDB.filterType == nil then VendyDB.filterType = "All" end

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
-- 3. HELPER FUNCTION & DATA
-- ============================================================================
local function isArmorTypeInList(armorType, list)
    for _, value in ipairs(list) do
        if value == armorType then
            return true
        end
    end
    return false
end

-- Friendly names
local slotLabels = {
    ["INVTYPE_HEAD"] = "Head",
    ["INVTYPE_NECK"] = "Neck",
    ["INVTYPE_SHOULDER"] = "Shoulder",
    ["INVTYPE_CHEST"] = "Chest",
    ["INVTYPE_WAIST"] = "Waist",
    ["INVTYPE_LEGS"] = "Legs",
    ["INVTYPE_FEET"] = "Feet",
    ["INVTYPE_WRIST"] = "Wrist",
    ["INVTYPE_HAND"] = "Hands",
    ["INVTYPE_FINGER"] = "Finger",
    ["INVTYPE_TRINKET"] = "Trinket",
    ["INVTYPE_CLOAK"] = "Cloak",
    ["INVTYPE_WEAPON"] = "Weapon",
    ["INVTYPE_2HWEAPON"] = "Weapon",
    ["INVTYPE_WEAPONMAINHAND"] = "Weapon",
    ["INVTYPE_WEAPONOFFHAND"] = "Weapon",
    ["INVTYPE_RANGED"] = "Weapon",
    ["INVTYPE_SHIELD"] = "Shield",
}

-- List of slots to ignore when scanning the vendor
local nonEquipSlots = {
    ["INVTYPE_NON_EQUIP_IGNORE"] = true,
    ["INVTYPE_BAG"] = true,
    ["INVTYPE_TABARD"] = true,
    ["INVTYPE_RELIC"] = true,
    ["INVTYPE_HOLDABLE"] = true,
}


-- ============================================================================
-- 4. DROPDOWN FILTER (NEW SECTION)
-- ============================================================================
local availableSlots = {}

local function ScanVendorForSlots()
    wipe(availableSlots)
    for i = 1, GetMerchantNumItems() do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
            local label = slotLabels[equipLoc]
            if label and not nonEquipSlots[equipLoc] then
                availableSlots[label] = true
            end
        end
    end
end

-- dropdown menu
local dropdown = CreateFrame("Frame", "VendyFilterDropdown", MerchantFrame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 75, -30)
UIDropDownMenu_SetWidth(dropdown, 120)

local function SetFilter(self, arg1)
    VendyDB.filterType = arg1
    UIDropDownMenu_SetText(dropdown, arg1)
    MerchantFrame_Update()
end

local function InitializeDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "Show All"
    info.arg1 = "All"
    info.func = SetFilter
    info.checked = (VendyDB.filterType == "All")
    UIDropDownMenu_AddButton(info)

    local sortedSlots = {}
    for slot in pairs(availableSlots) do
        table.insert(sortedSlots, slot)
    end
    table.sort(sortedSlots)
    
    for _, slotName in ipairs(sortedSlots) do
        info = UIDropDownMenu_CreateInfo()
        info.text = slotName
        info.arg1 = slotName
        info.func = SetFilter
        info.checked = (VendyDB.filterType == slotName)
        UIDropDownMenu_AddButton(info, level)
    end
end

local merchantEvents = CreateFrame("Frame")
merchantEvents:RegisterEvent("MERCHANT_SHOW")
merchantEvents:SetScript("OnEvent", function()
    SetFilter(nil, "All")

    C_Timer.After(0.05, function()
        ScanVendorForSlots()
        UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
    end)
end)



-- ============================================================================
-- 5. CORE FILTERING LOGIC (MODIFIED)
-- ============================================================================
local classArmorBlacklist = {
	-- Cloth
    ["MAGE"] = {}, 
	["WARLOCK"] = {}, 
	["PRIEST"] = {},
    
	-- Leather
    ["DRUID"] = { "Cloth" }, 
	["ROGUE"] = { "Cloth" }, 
	["MONK"] = { "Cloth" },
    
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
                
                local slotFilterMatches = false
                if VendyDB.filterType == "All" then
                    slotFilterMatches = true
                else
                    local itemSlotLabel = slotLabels[equipLoc]
                    if itemSlotLabel == VendyDB.filterType then
                        slotFilterMatches = true
                    end
                end

                if not slotFilterMatches then
                    button:SetAlpha(filteredAlpha)
                    if button.icon then button.icon:SetDesaturated(true) end
                else
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
        end
    end)
end)
