# VRK Profiles System — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-character named profiles. Each profile holds its own sell/destroy/protect lists and remembered loot choices. Settings/stats/history remain per-character but profile-independent.

**Architecture:** Profiles live in `VRK.db.char.profiles[name]`. `Lists:GetDB()` already routes to the active profile — all existing callers work unchanged. A migration runs once on existing characters. Settings panel gets a new Profile section at the top.

**Tech Stack:** Lua 5.1, AceDB-3.0, existing VRK event bus, existing UI class pattern (ListPanel).

---

## File Map

| File | Change |
|---|---|
| `VRK.lua` | PLAYER_LOGIN migration; `VRK:P()` shortcut for current profile; init `profiles.Default` for new chars |
| `modules/Lists.lua` | Add profile CRUD functions; update `GetDB()` to use `activeProfile` |
| `ui/SettingsPanel.lua` | New Profile section (dropdown + clone/rename/delete buttons) |
| `modules/BagScan.lua` | Register `VRK_PROFILE_CHANGED` listener |
| `modules/Tooltip.lua` | Register `VRK_PROFILE_CHANGED` listener |
| `modules/LootRoll.lua` | Register `VRK_PROFILE_CHANGED` listener |

Files that need **no changes:** `Merchant.lua`, `Destroy.lua`, `Loot.lua`, `Export.lua`, `ListPanel.lua`, `HistoryPanel.lua`, `MainFrame.lua`, `MinimapButton.lua`.

---

## Task 1: Add Profile API to Lists.lua

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\modules\Lists.lua`

Add the following functions after the existing helper functions, before the `StaticPopup` hooks at the bottom:

```lua
-- Profile API
function Lists:GetActiveProfileName()
    return VRK.db.char.activeProfile or "Default"
end

function Lists:GetProfile(name)
    return VRK.db.char.profiles and VRK.db.char.profiles[name]
end

function Lists:GetCurrentProfile()
    return VRK.db.char.profiles[Lists:GetActiveProfileName()]
end

function Lists:ProfileExists(name)
    return VRK.db.char.profiles and VRK.db.char.profiles[name] ~= nil
end

function Lists:GetAllProfileNames()
    local names = {}
    for name in pairs(VRK.db.char.profiles or {}) do
        tinsert(names, name)
    end
    sort(names)
    return names
end

function Lists:CreateProfile(name)
    local default = VRK.db.char.profiles["Default"]
    VRK.db.char.profiles[name] = {
        sell = {},
        destroy = {},
        protect = {},
        rememberedChoices = {},
    }
    -- deep-copy from Default if it exists
    if default then
        for listName, items in pairs({sell=true, destroy=true, protect=true}) do
            for itemID in pairs(default[listName] or {}) do
                VRK.db.char.profiles[name][listName][itemID] = true
            end
        end
        for link, action in pairs(default.rememberedChoices or {}) do
            VRK.db.char.profiles[name].rememberedChoices[link] = action
        end
    end
    return VRK.db.char.profiles[name]
end

function Lists:CloneProfile(fromName, toName)
    local from = VRK.db.char.profiles[fromName]
    if not from then return end
    VRK.db.char.profiles[toName] = {
        sell = {},
        destroy = {},
        protect = {},
        rememberedChoices = {},
    }
    for itemID in pairs(from.sell or {}) do
        VRK.db.char.profiles[toName].sell[itemID] = true
    end
    for itemID in pairs(from.destroy or {}) do
        VRK.db.char.profiles[toName].destroy[itemID] = true
    end
    for itemID in pairs(from.protect or {}) do
        VRK.db.char.profiles[toName].protect[itemID] = true
    end
    for link, action in pairs(from.rememberedChoices or {}) do
        VRK.db.char.profiles[toName].rememberedChoices[link] = action
    end
end

function Lists:DeleteProfile(name)
    if name == "Default" then return end
    if not VRK.db.char.profiles[name] then return end
    VRK.db.char.profiles[name] = nil
    -- if we deleted the active profile, switch to Default
    if VRK.db.char.activeProfile == name then
        VRK.db.char.activeProfile = "Default"
    end
    VRK:SendMessage("VRK_PROFILE_CHANGED", name, VRK.db.char.activeProfile)
end

function Lists:RenameProfile(oldName, newName)
    if oldName == "Default" then return end
    if not VRK.db.char.profiles[oldName] then return end
    if VRK.db.char.profiles[newName] then return end -- name taken
    VRK.db.char.profiles[newName] = VRK.db.char.profiles[oldName]
    VRK.db.char.profiles[oldName] = nil
    if VRK.db.char.activeProfile == oldName then
        VRK.db.char.activeProfile = newName
    end
    VRK:SendMessage("VRK_PROFILE_CHANGED", oldName, newName)
end

function Lists:SetActiveProfile(name)
    if not name or not VRK.db.char.profiles[name] then return end
    local old = VRK.db.char.activeProfile or "Default"
    if old == name then return end
    VRK.db.char.activeProfile = name
    VRK:SendMessage("VRK_PROFILE_CHANGED", old, name)
end
```

Then update `GetDB()` to use `activeProfile` instead of `listScope`. Find the existing `GetDB` function and replace it:

```lua
function Lists:GetDB()
    local profileName = VRK.db.char.activeProfile or "Default"
    local profile = VRK.db.char.profiles and VRK.db.char.profiles[profileName]
    if not profile then
        -- defensive: ensure Default exists
        VRK.db.char.profiles = VRK.db.char.profiles or {}
        VRK.db.char.profiles["Default"] = VRK.db.char.profiles["Default"] or {
            sell = {},
            destroy = {},
            protect = {},
            rememberedChoices = {},
        }
        VRK.db.char.activeProfile = "Default"
        profile = VRK.db.char.profiles["Default"]
    end
    return profile
end
```

Then update `GetRemembered` to read from the active profile too. Find the existing `GetRemembered` function and change `VRK.db.global.rememberedChoices` to `Lists:GetDB().rememberedChoices`. Same for `Remember` and `Forget` functions — they should write to `Lists:GetDB().rememberedChoices`.

---

## Task 2: Add Migration and Shortcuts to VRK.lua

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\VRK.lua`

### Step A: Add shortcut after the `VRK:S()` shortcut (around line 40)

```lua
function VRK:P()
    return VRK.db.char.profiles[VRK.db.char.activeProfile or "Default"]
end
```

### Step B: Add migration in `PLAYER_LOGIN` event handler

Find the `PLAYER_LOGIN` section (where `defaultsLoaded` is checked). After the defaults-loading block, add migration:

```lua
-- Migration: convert old per-char lists to profiles system
if not VRK.db.char.profiles then
    VRK.db.char.profiles = {}
    -- migrate existing lists if they exist
    if VRK.db.char.lists then
        VRK.db.char.profiles["Default"] = {
            sell = VRK.db.char.lists.sell or {},
            destroy = VRK.db.char.lists.destroy or {},
            protect = VRK.db.char.lists.protect or {},
            rememberedChoices = VRK.db.global.rememberedChoices or {},
        }
        VRK.db.char.lists = nil
        VRK.db.global.rememberedChoices = nil
    else
        VRK.db.char.profiles["Default"] = {
            sell = {},
            destroy = {},
            protect = {},
            rememberedChoices = {},
        }
    end
    VRK.db.char.activeProfile = "Default"
end
```

---

## Task 3: Update SettingsPanel.lua — Add Profile UI Section

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\ui\SettingsPanel.lua`

Find the `CreatePanel` function in `SettingsPanel:New`. Insert a new **Profiles section** at the very top of the panel, before any existing controls. The structure should be:

```lua
-- === PROFILES SECTION ===
local profileLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
profileLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
profileLabel:SetText("Profile:")

-- Profile dropdown
local profileDropdown = UIDropDownMenu_Create("VRKProfileDropdown", f)
profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", 8, 0)
UIDropDownMenu_SetWidth(profileDropdown, 140)
UIDropDownMenu_Initialize(profileDropdown, function(self, level)
    local names = Lists:GetAllProfileNames()
    for _, name in ipairs(names) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = name
        info.value = name
        info.func = function()
            Lists:SetActiveProfile(name)
            UIDropDownMenu_SetSelectedName(profileDropdown, name)
            -- refresh list panels if main frame is open
            VRK:SendMessage("VRK_PROFILE_CHANGED", "dummy", name)
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetSelectedName(profileDropdown, Lists:GetActiveProfileName())

-- Rename button
local renameBtn = CreateFrame("Button", "VRKRenameBtn", f, "UIMicroButtonTemplate")
renameBtn:SetPoint("LEFT", profileDropdown, "RIGHT", 4, 0)
renameBtn:SetText("R")
renameBtn:SetWidth(20)
renameBtn:SetScript("OnClick", function()
    StaticPopup_Show("VRK_RENAME_PROFILE")
end)
renameBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Rename Profile")
    GameTooltip:Show()
end)
renameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Delete button
local deleteBtn = CreateFrame("Button", "VRKDeleteProfileBtn", f, "UIMicroButtonTemplate")
deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
deleteBtn:SetText("X")
deleteBtn:SetWidth(20)
deleteBtn:SetScript("OnClick", function()
    local name = Lists:GetActiveProfileName()
    if name == "Default" then
        UIErrorsFrame:AddMessage("Cannot delete Default profile.", 1, 0.2, 0.2)
        return
    end
    StaticPopup_Show("VRK_DELETE_PROFILE_CONFIRM")
end)
deleteBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Delete Profile")
    GameTooltip:Show()
end)
deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Clone button
local cloneBtn = CreateFrame("Button", "VRKCloneProfileBtn", f, "UIPanelButtonTemplate")
cloneBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 12, 0)
cloneBtn:SetText("Clone Profile")
cloneBtn:SetWidth(100)
cloneBtn:SetScript("OnClick", function()
    StaticPopup_Show("VRK_CLONE_PROFILE")
end)

-- Thin separator line under profile section
local sep = f:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", 0, -12)
sep:SetPoint("TOPRIGHT", cloneBtn, "BOTTOMRIGHT", 0, -12)
sep:SetHeight(1)
sep:SetColorTexture(0.3, 0.3, 0.3)

-- === END PROFILES SECTION ===
```

### Step B: Add StaticPopups for rename, delete, clone

Find where `StaticPopupDialogs` is defined (near the bottom of the file). Add three new entries:

```lua
StaticPopupDialogs["VRK_RENAME_PROFILE"] = {
    text = "Rename Profile",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnShow = function(self)
        self.editBox:SetText(Lists:GetActiveProfileName())
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local newName = self.editBox:GetText()
        local oldName = Lists:GetActiveProfileName()
        if newName == "" or newName == oldName then return end
        if Lists:ProfileExists(newName) then
            UIErrorsFrame:AddMessage("Profile '"..newName.."' already exists.", 1, 0.2, 0.2)
            return
        end
        Lists:RenameProfile(oldName, newName)
        UIDropDownMenu_SetSelectedName(profileDropdown, newName)
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
}

StaticPopupDialogs["VRK_DELETE_PROFILE_CONFIRM"] = {
    text = "Delete profile '%s'? This cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self)
        Lists:DeleteProfile(Lists:GetActiveProfileName())
        UIDropDownMenu_SetSelectedName(profileDropdown, Lists:GetActiveProfileName())
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
}

StaticPopupDialogs["VRK_CLONE_PROFILE"] = {
    text = "Clone Profile",
    button1 = "Clone",
    button2 = "Cancel",
    hasEditBox = true,
    hasRadioButtons = false,
    OnShow = function(self)
        -- Create the source dropdown inside the popup frame if not already created
        if not self.sourceDropdown then
            self.sourceDropdown = UIDropDownMenu_Create("VRKCloneSourceDropdown", self)
            self.sourceDropdown:SetPoint("BOTTOMLEFT", self.editBox, "TOPLEFT", 0, 4)
            UIDropDownMenu_SetWidth(self.sourceDropdown, 180)
            UIDropDownMenu_Initialize(self.sourceDropdown, function(dropdown, level)
                local names = Lists:GetAllProfileNames()
                for _, name in ipairs(names) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.value = name
                    info.func = function()
                        self.cloneSourceName = name
                        UIDropDownMenu_SetSelectedName(dropdown, name)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            -- Label above dropdown
            local lbl = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("BOTTOM", self.sourceDropdown, "TOP", 0, 2)
            lbl:SetText("Clone from:")
            self.sourceLabel = lbl
        end
        self.editBox:SetText("")
        self.cloneSourceName = Lists:GetActiveProfileName()
        UIDropDownMenu_SetSelectedName(self.sourceDropdown, self.cloneSourceName)
    end,
    OnAccept = function(self)
        local newName = self.editBox:GetText()
        local fromName = self.cloneSourceName or Lists:GetActiveProfileName()
        if newName == "" then return end
        if Lists:ProfileExists(newName) then
            UIErrorsFrame:AddMessage("Profile '"..newName.."' already exists.", 1, 0.2, 0.2)
            return
        end
        Lists:CloneProfile(fromName, newName)
        Lists:SetActiveProfile(newName)
        UIDropDownMenu_SetSelectedName(profileDropdown, newName)
    end,
    OnHide = function(self)
        self.cloneSourceName = nil
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
}
```

---

## Task 4: Add Profile Changed Listeners to BagScan, Tooltip, LootRoll

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\modules\BagScan.lua`

In the `OnEnable` method (or after `self:RegisterMessage`), add:
```lua
self:RegisterMessage("VRK_PROFILE_CHANGED", function() VRK:GetModule("BagScan"):ForceFullRefresh() end)
```

Add a new method:
```lua
function BagScan:ForceFullRefresh()
    self:ScheduleTimer("Refresh", 0.1)
end
```

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\modules\Tooltip.lua`

In the `OnEnable` method, add:
```lua
self:RegisterMessage("VRK_PROFILE_CHANGED", function() self.needsRefresh = true end)
```

In the `OnTooltipSetBagItem` handler, clear `needsRefresh` at the top:
```lua
function Tooltip:OnTooltipSetBagItem(tooltip, bag, slot)
    self.needsRefresh = nil
    -- ... rest of function
end
```

**Modify:** `F:\Ascension\resources\ascension-live\Interface\AddOns\VRK\modules\LootRoll.lua`

In `OnEnable`, add:
```lua
self:RegisterMessage("VRK_PROFILE_CHANGED", function() self:ReRegister() end)
```

Add:
```lua
function LootRoll:ReRegister()
    self:UnregisterAllEvents()
    self:RegisterEvent("START_LOOT_ROLL", "OnLootRollStart")
    self:RegisterMessage("VRK_PROFILE_CHANGED", function() self:ReRegister() end)
end
```

---

## Task 5: In-Game Test

1. Save all modified files
2. In-game: `/reload` to load changes
3. Type `/vrk ui` to open main frame
4. Click Settings tab — verify Profile section appears at top with "Default" selected
5. Add an item to the sell list via Alt+Click, verify it appears in the Sell tab
6. Click "Clone Profile" — enter a name like "Test" — verify it appears in the dropdown and is auto-selected
7. Click the dropdown and switch back to "Default" — verify sell list is empty
8. Switch to "Test" — verify the item you added is back
9. Test rename: click Rename button, change "Test" to "MyProfile" — verify dropdown updates
10. Test delete: switch to "MyProfile", click Delete — verify it switches back to "Default" and "MyProfile" is gone from dropdown
11. Right-click a roll button — verify remembered choice still works under profile system
12. `/reload` again to verify no Lua errors on startup
