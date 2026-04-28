-- ui/SettingsPanel.lua
SettingsPanel = {}
SettingsPanel.__index = SettingsPanel
local profileDropdown = nil
VRK:RegisterModule("SettingsPanel", SettingsPanel)

function SettingsPanel:New(parent)
    local obj = setmetatable({}, { __index = SettingsPanel })
    obj:Build(parent)
    return obj
end

function SettingsPanel:Build(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame

    -- === PROFILES SECTION ===
    local Lists = VRK:GetModule("Lists")

    local profileHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    profileHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    profileHeader:SetText("|cffFFD700Profiles|r")

    local profileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    profileLabel:SetText("Active:")

    -- Profile dropdown
    profileDropdown = CreateFrame("Frame", "VRKProfileDropdown", frame, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", 8, 0)
    UIDropDownMenu_SetWidth(profileDropdown, 140)

    UIDropDownMenu_Initialize(profileDropdown, function(self, level)
        local names = Lists:GetAllProfileNames()
        for _, name in ipairs(names) do
            local info = {}
            info.text = name
            info.value = name
            info.func = function()
                Lists:SetActiveProfile(name)
                if profileDropdown.Text then profileDropdown.Text:SetText(name) end
                VRK:SendMessage("VRK_PROFILE_CHANGED", "dummy", name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    if profileDropdown.Text then profileDropdown.Text:SetText(Lists:GetActiveProfileName()) end

    -- Rename button
    local renameBtn = CreateFrame("Button", nil, frame, "UIMicroButtonTemplate")
    renameBtn:SetPoint("LEFT", profileDropdown, "RIGHT", 6, 0)
    renameBtn:SetText("R")
    renameBtn:SetWidth(20)
    renameBtn.tooltip = "Rename Profile"
    renameBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rename Profile")
        GameTooltip:Show()
    end)
    renameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    renameBtn:SetScript("OnClick", function()
        StaticPopup_Show("VRK_RENAME_PROFILE")
    end)

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, frame, "UIMicroButtonTemplate")
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
    deleteBtn:SetText("X")
    deleteBtn:SetWidth(20)
    deleteBtn.tooltip = "Delete Profile"
    deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Profile")
        GameTooltip:Show()
    end)
    deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    deleteBtn:SetScript("OnClick", function()
        local name = Lists:GetActiveProfileName()
        if name == "Default" then
            UIErrorsFrame:AddMessage("Cannot delete Default profile.", 1, 0.2, 0.2)
            return
        end
        StaticPopup_Show("VRK_DELETE_PROFILE_CONFIRM", name)
    end)

    -- Clone button
    local cloneBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cloneBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 12, 0)
    cloneBtn:SetText("Clone Profile")
    cloneBtn:SetWidth(100)
    cloneBtn:SetScript("OnClick", function()
        StaticPopup_Show("VRK_CLONE_PROFILE")
    end)

    -- Separator line
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", -4, -10)
    sep:SetPoint("TOPRIGHT", cloneBtn, "BOTTOMRIGHT", 0, -10)
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3)

    -- === END PROFILES SECTION ===

    local y = -10

    local function Header(text)
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
        fs:SetText("|cffFFD700" .. text .. "|r")
        y = y - 22
    end

    local function Checkbox(label, key)
        local chk = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        chk:SetSize(20, 20)
        chk:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
        chk:SetChecked(VRK:S()[key])
        chk:SetScript("OnClick", function(self)
            VRK:S()[key] = (self:GetChecked() == true)
            VRK:SendMessage("VRK_SETTINGS_CHANGED")
        end)
        local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", chk, "RIGHT", 4, 0)
        lbl:SetText(label)
        y = y - 24
        return chk
    end

    local function Slider(label, getter, setter, minVal, maxVal, step)
        local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
        lbl:SetText(label)
        local sl = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
        sl:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y - 18)
        sl:SetWidth(220)
        sl:SetMinMaxValues(minVal, maxVal)
        sl:SetValueStep(step)
        sl:SetValue(getter())
        getglobal(sl:GetName() .. "Low"):SetText(tostring(minVal))
        getglobal(sl:GetName() .. "High"):SetText(tostring(maxVal))
        getglobal(sl:GetName() .. "Text"):SetText(label .. ": " .. getter())
        sl:SetScript("OnValueChanged", function(self, val)
            val = math.floor(val / step + 0.5) * step
            setter(val)
            getglobal(self:GetName() .. "Text"):SetText(label .. ": " .. val)
            VRK:SendMessage("VRK_SETTINGS_CHANGED")
        end)
        y = y - 48
    end

    -- Selling
    Header("Selling")
    Checkbox("Auto-sell when merchant opens",               "autoSell")
    Checkbox("Always sell gray (quality 0) items",         "alwaysSellGrays")
    Checkbox("Auto-repair at merchants (guild bank first)", "autoRepair")
    Checkbox("Print session summary to chat",              "sessionStatsChat")

    y = y - 6
    Header("Destroying")
    Checkbox("Auto-destroy on loot  (immediate, no undo)", "autoDestroyOnLoot")

    y = y - 6
    Header("Bag & Tooltips")
    Checkbox("Highlight bag slots",                         "bagHighlight")
    Checkbox("Show [VRK] badge in item tooltips",           "tooltipBadge")
    Checkbox("Show vendor price in item tooltips",         "vendorPrice")
    Checkbox("Sound effects",                              "soundEffects")

    y = y - 6
    Header("Lists")

    -- List scope radio buttons
    local charRadio = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
    charRadio:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
    charRadio:SetChecked(VRK:S().listScope == "character")
    local charLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charLbl:SetPoint("LEFT", charRadio, "RIGHT", 2, 0)
    charLbl:SetText("Per character")

    local acctRadio = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
    acctRadio:SetPoint("LEFT", charLbl, "RIGHT", 16, 0)
    acctRadio:SetChecked(VRK:S().listScope == "account")
    local acctLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    acctLbl:SetPoint("LEFT", acctRadio, "RIGHT", 2, 0)
    acctLbl:SetText("Account-wide")

    charRadio:SetScript("OnClick", function()
        VRK:S().listScope = "character"
        charRadio:SetChecked(true); acctRadio:SetChecked(false)
        VRK:SendMessage("VRK_SETTINGS_CHANGED")
    end)
    acctRadio:SetScript("OnClick", function()
        VRK:S().listScope = "account"
        charRadio:SetChecked(false); acctRadio:SetChecked(true)
        VRK:SendMessage("VRK_SETTINGS_CHANGED")
    end)
    y = y - 28

    Slider("History entries",
        function() return VRK:S().historyMaxEntries end,
        function(v) VRK:S().historyMaxEntries = v end,
        50, 500, 50)

    y = y - 6
    Header("Minimap")

    -- Show minimap checkbox (inverted: hide=false means shown)
    local showMMChk = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showMMChk:SetSize(20, 20)
    showMMChk:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
    showMMChk:SetChecked(not VRK:S().minimapButton.hide)
    showMMChk:SetScript("OnClick", function(self)
        local hide = not (self:GetChecked() == true)
        VRK:S().minimapButton.hide = hide
        local btn = _G.VRK_MinimapButton
        if btn then
            if hide then btn:Hide() else btn:Show() end
        end
    end)
    local showMMLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showMMLbl:SetPoint("LEFT", showMMChk, "RIGHT", 4, 0)
    showMMLbl:SetText("Show minimap button")
    y = y - 24
end

-- Profile StaticPopups
StaticPopupDialogs["VRK_RENAME_PROFILE"] = {
    text = "Rename Profile",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnShow = function(self)
        self.editBox:SetText(VRK:GetModule("Lists"):GetActiveProfileName())
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local Lists = VRK:GetModule("Lists")
        local newName = strtrim(self.editBox:GetText())
        local oldName = Lists:GetActiveProfileName()
        if newName == "" or newName == oldName then return end
        if Lists:ProfileExists(newName) then
            UIErrorsFrame:AddMessage("Profile '"..newName.."' already exists.", 1, 0.2, 0.2)
            return
        end
        Lists:RenameProfile(oldName, newName)
        if profileDropdown.Text then profileDropdown.Text:SetText(newName) end
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["VRK_DELETE_PROFILE_CONFIRM"] = {
    text = "Delete profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self)
        local Lists = VRK:GetModule("Lists")
        Lists:DeleteProfile(Lists:GetActiveProfileName())
        if profileDropdown.Text then profileDropdown.Text:SetText(Lists:GetActiveProfileName()) end
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["VRK_CLONE_PROFILE"] = {
    text = "Clone Profile",
    button1 = "Clone",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local Lists = VRK:GetModule("Lists")
        self.editBox:SetText("")
        self.editBox:SetWidth(180)
        -- Source dropdown inside popup
        if not self.sourceDropdown then
            self.sourceDropdown = CreateFrame("Frame", "VRKCloneSourceDropdown", self, "UIDropDownMenuTemplate")
            self.sourceDropdown:SetPoint("BOTTOMLEFT", self.editBox, "TOPLEFT", 0, 4)
            UIDropDownMenu_SetWidth(self.sourceDropdown, 180)
        end
        UIDropDownMenu_Initialize(self.sourceDropdown, function(dropdown, level)
            local names = Lists:GetAllProfileNames()
            for _, name in ipairs(names) do
                local info = {}
                info.text = name
                info.value = name
                info.func = function()
                    self.cloneSourceName = name
                    if dropdown.Text then dropdown.Text:SetText(name) end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        self.cloneSourceName = Lists:GetActiveProfileName()
        if self.sourceDropdown.Text then self.sourceDropdown.Text:SetText(self.cloneSourceName) end
    end,
    OnAccept = function(self)
        local Lists = VRK:GetModule("Lists")
        local newName = strtrim(self.editBox:GetText())
        local fromName = self.cloneSourceName or Lists:GetActiveProfileName()
        if newName == "" then return end
        if Lists:ProfileExists(newName) then
            UIErrorsFrame:AddMessage("Profile '"..newName.."' already exists.", 1, 0.2, 0.2)
            return
        end
        Lists:CloneProfile(fromName, newName)
        Lists:SetActiveProfile(newName)
        if profileDropdown.Text then profileDropdown.Text:SetText(newName) end
    end,
    OnHide = function(self)
        self.cloneSourceName = nil
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
}
