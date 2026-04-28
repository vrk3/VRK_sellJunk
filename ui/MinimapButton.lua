-- ui/MinimapButton.lua
local MinimapButton = {}
VRK:RegisterModule("MinimapButton", MinimapButton)

-- Use a custom frame instead of LibDBIcon to get full mouse control
local ICON_SIZE = 32
local MINIMAP = _G.Minimap
local isButtonCreated = false

function MinimapButton:OnLoad()
    -- Wait for Minimap to be loaded, then create button
    C_Timer.After(0.5, function() self:TryCreateButton() end)
    self:RegisterMessage("VRK_BAG_COUNT_CHANGED", "OnBadgeUpdate")
    self:SetBadge(0)
    print("VRK: MinimapButton OnLoad done")
end

function MinimapButton:TryCreateButton()
    if isButtonCreated then return end
    local _, err = pcall(self.CreateButton, self)
    if err then
        print("|cffFF4444VRK MinimapButton error:|r " .. tostring(err))
        C_Timer.After(1, function() self:TryCreateButton() end)
    end
end

function MinimapButton:CreateButton()
    isButtonCreated = true
    local btn = CreateFrame("Button", "VRK_MinimapButton", Minimap)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetToplevel(true)

    -- Position on minimap using saved angle
    local angle = VRK:S().minimapButton.angle or 45
    local radius = 78
    btn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(math.rad(angle)) * radius,
        math.sin(math.rad(angle)) * radius)

    -- Icon texture
    local tex = btn:CreateTexture("VRK_MinimapIcon", "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    -- Normal / highlight / pushed textures (standard WoW button look)
    btn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-Highlight")
    btn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")

    -- Event scripts — this is how we catch ALL mouse buttons
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffFFD700VRK|r - Junk Manager")
        GameTooltip:AddLine("Left-click: Open UI",    0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Quick menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Middle-click: Drag-Drop Window", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            local MF = VRK:GetModule("MainFrame")
            if MF and MF.Toggle then MF:Toggle() end
        elseif button == "RightButton" then
            -- Hide any WoW default dropdowns first
            CloseDropDownMenus()
            C_Timer.After(0.01, function()
                MinimapButton:ShowQuickMenu()
            end)
        elseif button == "MiddleButton" then
            local DDW = VRK:GetModule("DragDropWindow")
            if DDW and DDW.Toggle then DDW:Toggle() end
        end
    end)

    -- Drag to reposition
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        local dx, dy = cx - mx, cy - my
        local angle = math.deg(math.atan2(dy, dx))
        if angle < 0 then angle = angle + 360 end
        VRK:S().minimapButton.angle = math.floor(angle + 0.5)
        DBIcon = LibStub("LibDBIcon-1.0", true)
        if DBIcon then DBIcon:Refresh("VRK") end
    end)

    -- If hide was saved, hide it
    if VRK:S().minimapButton.hide then
        btn:Hide()
    end

    -- Setup badge
    self:UpdateBadge(0)

    print("VRK: Minimap button created")
end

function MinimapButton:UpdateBadge(count)
    local btn = _G.VRK_MinimapButton
    if not btn then return end

    if not btn._vrkBadge then
        local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 2)
        badge:SetTextColor(1, 0.2, 0.2)
        btn._vrkBadge = badge
    end

    if count and count > 0 then
        btn._vrkBadge:SetText(tostring(count))
        btn._vrkBadge:Show()
    else
        btn._vrkBadge:Hide()
    end
end

function MinimapButton:OnBadgeUpdate(_, count)
    self:UpdateBadge(count)
end

function MinimapButton:SetBadge(count)
    self:UpdateBadge(count)
end

-- ── Quick Menu ─────────────────────────────────────────────────────────────────

local QuickMenu = CreateFrame("Frame", "VRK_QuickMenu", UIParent, "UIDropDownMenuTemplate")

function MinimapButton:ShowQuickMenu()
    local settings   = VRK:S()
    local Merchant   = VRK:GetModule("Merchant")
    local DestroyMod = VRK:GetModule("Destroy")
    local Lists      = VRK:GetModule("Lists")

    UIDropDownMenu_Initialize(QuickMenu, function(frame, level)
        local info

        info = {}
        info.text = "|cffFFD700VRK|r"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Open Main UI"
        info.notCheckable = true
        info.func = function()
            local MF = VRK:GetModule("MainFrame")
            if MF and MF.Toggle then MF:Toggle() end
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = ""; info.notCheckable = true; info.disabled = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Sell Junk Now"
        info.notCheckable = true
        info.disabled = not (MerchantFrame and MerchantFrame:IsShown())
        info.func = function() if Merchant then Merchant:SellNow() end end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Destroy All Junk"
        info.notCheckable = true
        info.func = function() if DestroyMod then DestroyMod:ScanAndDestroyAll() end end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = ""; info.notCheckable = true; info.disabled = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Drag-Drop Window"
        info.notCheckable = true
        info.func = function()
            local DDW = VRK:GetModule("DragDropWindow")
            if DDW and DDW.Toggle then DDW:Toggle() end
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = ""; info.notCheckable = true; info.disabled = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Auto-Sell: " .. (settings.autoSell and "|cff00ff00ON|r" or "|cffff0000OFF|r")
        info.notCheckable = true
        info.func = function()
            settings.autoSell = not settings.autoSell
            VRK:SendMessage("VRK_SETTINGS_CHANGED")
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Auto-Repair: " .. (settings.autoRepair and "|cff00ff00ON|r" or "|cffff0000OFF|r")
        info.notCheckable = true
        info.func = function()
            settings.autoRepair = not settings.autoRepair
            VRK:SendMessage("VRK_SETTINGS_CHANGED")
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = ""; info.notCheckable = true; info.disabled = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Hide Minimap Button"
        info.notCheckable = true
        info.func = function()
            local btn = _G.VRK_MinimapButton
            if btn then btn:Hide() end
            settings.minimapButton.hide = true
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = "Show Minimap Button"
        info.notCheckable = true
        info.func = function()
            local btn = _G.VRK_MinimapButton
            if btn then btn:Show() end
            settings.minimapButton.hide = false
        end
        UIDropDownMenu_AddButton(info, level)

    end, "MENU")

    ToggleDropDownMenu(1, "CENTER", QuickMenu, 0, 0)
end