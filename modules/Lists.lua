-- modules/Lists.lua
local Lists = {}
VRK:RegisterModule("Lists", Lists)

-- Returns active list table from the active profile
function Lists:GetDB()
    local profileName = VRK.db.char.activeProfile or "Default"
    if not VRK.db.char.profiles then
        VRK.db.char.profiles = {}
    end
    if not VRK.db.char.profiles[profileName] then
        -- defensive: create Default if missing
        profileName = "Default"
        if not VRK.db.char.profiles["Default"] then
            VRK.db.char.profiles["Default"] = {
                sell = {}, destroy = {}, protect = {}, rememberedChoices = {}
            }
        end
        VRK.db.char.activeProfile = "Default"
    end
    return VRK.db.char.profiles[profileName]
end

-- Add item to a list. Returns true on success, false + reason on failure.
function Lists:Add(listName, itemLink)
    local itemID = tonumber(string.match(itemLink or "", "item:(%d+)"))
    if not itemID then return false, "Invalid item link" end

    local db = self:GetDB()

    if listName ~= "protect" and db.protect[itemID] then
        return false, "Item is protected — remove protect first"
    end

    if listName == "sell"    then db.destroy[itemID] = nil end
    if listName == "destroy" then db.sell[itemID]    = nil end
    if listName == "protect" then
        db.sell[itemID]    = nil
        db.destroy[itemID] = nil
    end

    local name = GetItemInfo(itemLink) or ("Item #" .. itemID)
    db[listName][itemID] = {
        name    = name,
        link    = itemLink,
        addedAt = time(),
    }

    VRK:SendMessage("VRK_LIST_CHANGED", listName)
    return true
end

function Lists:Remove(listName, itemID)
    local db = self:GetDB()
    if db[listName] and db[listName][itemID] then
        db[listName][itemID] = nil
        VRK:SendMessage("VRK_LIST_CHANGED", listName)
        return true
    end
    return false
end

function Lists:Contains(listName, itemID)
    local db = self:GetDB()
    return db[listName] ~= nil and db[listName][itemID] ~= nil
end

function Lists:GetAll(listName)
    return self:GetDB()[listName] or {}
end

function Lists:Clear(listName)
    local db = self:GetDB()
    db[listName] = {}
    VRK:SendMessage("VRK_LIST_CHANGED", listName)
end

function Lists:RemoveFromAll(itemID)
    local db = self:GetDB()
    local removed = false
    for _, listName in ipairs({ "sell", "destroy", "protect" }) do
        if db[listName] and db[listName][itemID] then
            db[listName][itemID] = nil
            removed = true
        end
    end
    if removed then
        VRK:SendMessage("VRK_LIST_CHANGED", "all")
    end
    return removed
end

-- Remembered choices (per-profile)
function Lists:Remember(itemID, action, context)
    self:GetDB().rememberedChoices[itemID] = {
        action       = action,
        context      = context or "manual",
        rememberedAt = time(),
        notified     = false,
    }
end

function Lists:Forget(itemID)
    self:GetDB().rememberedChoices[itemID] = nil
end

function Lists:GetRemembered(itemID)
    return self:GetDB().rememberedChoices[itemID]
end

-- Profile API
function Lists:GetActiveProfileName()
    return VRK.db.char.activeProfile or "Default"
end

function Lists:GetProfile(name)
    return VRK.db.char.profiles and VRK.db.char.profiles[name]
end

function Lists:GetCurrentProfile()
    if not VRK.db.char.profiles then return nil end
    return VRK.db.char.profiles[Lists:GetActiveProfileName()]
end

function Lists:ProfileExists(name)
    return VRK.db.char.profiles ~= nil and VRK.db.char.profiles[name] ~= nil
end

function Lists:GetAllProfileNames()
    if not VRK.db.char.profiles then return {"Default"} end
    local names = {}
    for name in pairs(VRK.db.char.profiles) do
        tinsert(names, name)
    end
    sort(names)
    return names
end

-- Profile helpers
local function CopyListsTo(target, source)
    if not source then return end
    for itemID, entry in pairs(source.sell or {}) do
        target.sell[itemID] = entry
    end
    for itemID, entry in pairs(source.destroy or {}) do
        target.destroy[itemID] = entry
    end
    for itemID, entry in pairs(source.protect or {}) do
        target.protect[itemID] = entry
    end
    for link, data in pairs(source.rememberedChoices or {}) do
        target.rememberedChoices[link] = data
    end
end

function Lists:CreateProfile(name)
    if not name or name == "" or strmatch(name, "^%s+$") then return end
    if not VRK.db.char.profiles then VRK.db.char.profiles = {} end
    local default = VRK.db.char.profiles["Default"]
    local profile = {
        sell = {}, destroy = {}, protect = {}, rememberedChoices = {}
    }
    VRK.db.char.profiles[name] = profile
    if default then
        CopyListsTo(profile, default)
    end
    return profile
end

function Lists:CloneProfile(fromName, toName)
    if not fromName or fromName == "" or strmatch(fromName, "^%s+$") then return end
    if not toName or toName == "" or strmatch(toName, "^%s+$") then return end
    local from = VRK.db.char.profiles and VRK.db.char.profiles[fromName]
    if not from then return end
    if not VRK.db.char.profiles then VRK.db.char.profiles = {} end
    local to = {
        sell = {}, destroy = {}, protect = {}, rememberedChoices = {}
    }
    VRK.db.char.profiles[toName] = to
    CopyListsTo(to, from)
    return to
end

function Lists:DeleteProfile(name)
    if name == "Default" then return end
    if not VRK.db.char.profiles or not VRK.db.char.profiles[name] then return end
    VRK.db.char.profiles[name] = nil
    if VRK.db.char.activeProfile == name then
        VRK.db.char.activeProfile = "Default"
        VRK:SendMessage("VRK_PROFILE_CHANGED", name, "Default")
    end
end

function Lists:RenameProfile(oldName, newName)
    if oldName == "Default" then return end
    if newName == "Default" then return end
    if not VRK.db.char.profiles or not VRK.db.char.profiles[oldName] then return end
    if VRK.db.char.profiles[newName] then return end -- name taken
    VRK.db.char.profiles[newName] = VRK.db.char.profiles[oldName]
    VRK.db.char.profiles[oldName] = nil
    if VRK.db.char.activeProfile == oldName then
        VRK.db.char.activeProfile = newName
    end
    VRK:SendMessage("VRK_PROFILE_CHANGED", oldName, newName)
end

function Lists:SetActiveProfile(name)
    if not name or not VRK.db.char.profiles or not VRK.db.char.profiles[name] then return end
    local old = VRK.db.char.activeProfile or "Default"
    if old == name then return end
    VRK.db.char.activeProfile = name
    VRK:SendMessage("VRK_PROFILE_CHANGED", old, name)
end

-- Hook native WoW confirm dialogs to auto-accept remembered items
function Lists:OnLoad()
    local origDE = StaticPopupDialogs["CONFIRM_DISENCHANT_ITEM"]
    if origDE then
        local origOnShow = origDE.OnShow
        origDE.OnShow = function(self, data)
            if origOnShow then origOnShow(self, data) end
            if type(data) == "string" then
                local itemID = tonumber(string.match(data, "item:(%d+)"))
                if itemID then
                    local r = Lists:GetRemembered(itemID)
                    if r and r.action == "disenchant" then
                        if not r.notified then
                            VRK:Print("Auto-confirmed disenchant for " .. data .. " (remembered)")
                            r.notified = true
                        end
                        local btn = self.button1
                        if btn and btn:IsShown() then btn:Click() end
                    end
                end
            end
        end
    end

    local origDel = StaticPopupDialogs["DELETE_ITEM"]
    if origDel then
        local origOnShow = origDel.OnShow
        origDel.OnShow = function(self, data)
            if origOnShow then origOnShow(self, data) end
            if type(data) == "string" then
                local itemID = tonumber(string.match(data, "item:(%d+)"))
                if itemID then
                    local r = Lists:GetRemembered(itemID)
                    if r and r.action == "destroy" then
                        if not r.notified then
                            VRK:Print("Auto-confirmed delete for " .. data .. " (remembered)")
                            r.notified = true
                        end
                        local btn = self.button1
                        if btn and btn:IsShown() then btn:Click() end
                    end
                end
            end
        end
    end
end
