-- VRK.lua - Core namespace, DB init, module registry, slash commands, bag hooks
local AceDB    = LibStub("AceDB-3.0")
local AceEvent = LibStub("AceEvent-3.0")

VRK = {}
VRK.version = "1.2.0"
VRK._modules = {}
VRK.lastHovered = nil  -- { bag, slot, link } set by bag button OnEnter hooks
VRK._errorLog = {}     -- [{ id, timestamp, text }] — rolling, max 10

AceEvent:Embed(VRK)

-- Slash commands MUST be at file scope — WoW reads SLASH_XXX globals at load time
SLASH_VRK1 = "/vrk"

-- ── DB Schema ────────────────────────────────────────────────────────────────
VRK.dbDefaults = {
    global = {
        rememberedChoices = {},
        accountLists = {
            sell    = {},
            destroy = {},
            protect = {},
        },
        settings = {
            autoSell          = true,
            autoRepair        = true,
            alwaysSellGrays   = true,
            autoDestroyOnLoot = false,
            bagHighlight      = true,
            tooltipBadge      = true,
            vendorPrice       = true,
            soundEffects      = true,
            sessionStatsChat  = true,
            listScope         = "character",
            historyMaxEntries = 200,
            minimapButton     = { hide = false, angle = 45 },
        },
    },
    char = {
        lists = {
            sell    = {},
            destroy = {},
            protect = {},
        },
        history = {},
        stats = {
            totalGoldEarned     = 0,
            totalItemsSold      = 0,
            totalItemsDestroyed = 0,
        },
        defaultsLoaded = false,
    },
}

-- ── Module Registry ───────────────────────────────────────────────────────────
function VRK:RegisterModule(name, module)
    self._modules[name] = module
    AceEvent:Embed(module)
end

function VRK:GetModule(name)
    return self._modules[name]
end

-- ── Settings shortcut ────────────────────────────────────────────────────────
function VRK:S()
    return self.db.global.settings
end

-- Current profile shortcut
function VRK:P()
    if not VRK.db.char.profiles then return nil end
    return VRK.db.char.profiles[VRK.db.char.activeProfile or "Default"]
end

-- ── History helper ───────────────────────────────────────────────────────────
function VRK:AddHistory(action, link, value)
    local h = self.db.char.history
    local maxEntries = self:S().historyMaxEntries
    table.insert(h, 1, {
        action    = action,
        link      = link,
        value     = value or 0,
        timestamp = time(),
    })
    while #h > maxEntries do
        table.remove(h)
    end
    self:SendMessage("VRK_HISTORY_ADDED")
end

-- ── Print helper ─────────────────────────────────────────────────────────────
function VRK:Print(msg)
    print("|cffFFD700VRK:|r " .. tostring(msg))
end

-- ── Clipboard helper ──────────────────────────────────────────────────────────
function VRK:CopyToClipboard(text)
    local eb = CreateFrame("EditBox")
    eb:SetSize(0, 0)
    eb:Hide()
    eb:SetText(text or "")
    eb:SetFocus()
    eb:HighlightText(0, eb:GetNumLetters())
    eb:ClearFocus()
end

-- ── Error logging with copy link ──────────────────────────────────────────────
function VRK:LogError(prefix, errText)
    local id = #VRK._errorLog + 1
    local entry = { id = id, timestamp = time(), text = prefix .. ": " .. tostring(errText) }
    table.insert(VRK._errorLog, entry)
    while #VRK._errorLog > 10 do table.remove(VRK._errorLog, 1) end
    local linkText = string.format(
        "|cffFF4444[VRK Error]|r click to copy: |cff00FF00|Hvrkcopy:err_%02d|h[📋 Copy]|h|r  %s",
        id, tostring(errText)
    )
    print(linkText)
end

-- Handle vrkcopy:err_XX hyperlinks to copy errors to clipboard
hooksecurefunc("SetItemRef", function(link, text, button)
    if link:match("^vrkcopy:err_(%d+)") then
        local id = tonumber(link:match("^vrkcopy:err_(%d+)"))
        for _, entry in ipairs(VRK._errorLog) do
            if entry.id == id then
                VRK:CopyToClipboard(entry.text)
                VRK:Print("Error copied to clipboard.")
                return
            end
        end
    end
end)

-- ── Initialisation ───────────────────────────────────────────────────────────
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "VRK" then
        VRK.db = AceDB:New("VRK_DB", VRK.dbDefaults)

        -- Load defaults OR migrate old lists — runs once on first login
        if not VRK.db.char.defaultsLoaded then
            -- Ensure profiles structure exists
            if not VRK.db.char.profiles then
                VRK.db.char.profiles = {}
            end
            if not VRK.db.char.profiles["Default"] then
                VRK.db.char.profiles["Default"] = {
                    sell = {}, destroy = {}, protect = {}, rememberedChoices = {}
                }
            end

            -- Migrate old per-char lists into Default profile
            if VRK.db.char.lists then
                -- Only migrate if there's actual data
                local oldLists = VRK.db.char.lists
                local newProfile = VRK.db.char.profiles["Default"]
                -- Migrate sell/destroy/protect (merge: old data wins if there are collisions)
                for itemID, entry in pairs(oldLists.sell or {}) do
                    if not newProfile.sell[itemID] then
                        newProfile.sell[itemID] = entry
                    end
                end
                for itemID, entry in pairs(oldLists.destroy or {}) do
                    if not newProfile.destroy[itemID] then
                        newProfile.destroy[itemID] = entry
                    end
                end
                for itemID, entry in pairs(oldLists.protect or {}) do
                    if not newProfile.protect[itemID] then
                        newProfile.protect[itemID] = entry
                    end
                end
                -- Migrate remembered choices
                for link, data in pairs(VRK.db.global.rememberedChoices or {}) do
                    if not newProfile.rememberedChoices[link] then
                        newProfile.rememberedChoices[link] = data
                    end
                end
                VRK.db.char.lists = nil
            else
                -- Fresh install: populate from VRK_DEFAULT_JUNK if available
                if VRK_DEFAULT_JUNK then
                    for itemID, name in pairs(VRK_DEFAULT_JUNK) do
                        local fakeLink = "item:" .. itemID .. ":0:0:0:0:0:0:0"
                        VRK.db.char.profiles["Default"].sell[itemID] = {
                            name    = name,
                            link    = fakeLink,
                            addedAt = time(),
                        }
                    end
                end
            end

            if not VRK.db.char.activeProfile then
                VRK.db.char.activeProfile = "Default"
            end
            VRK.db.char.defaultsLoaded = true
        end

        -- Notify all modules (each in pcall so one failure doesn't break the rest)
        for name, module in pairs(VRK._modules) do
            if module.OnLoad then
                local ok, err = pcall(module.OnLoad, module)
                if not ok then
                    VRK:LogError("Module '"..name.."' OnLoad error", err)
                end
            end
        end

        VRK:SetupBagHooks()
        VRK:SetupSlashCommands()
        VRK:Print("v" .. VRK.version .. " loaded. Type /vrk help for commands.")
    end
end)

-- ── Bag hover tracking ───────────────────────────────────────────────────────
function VRK:SetupBagHooks()
    hooksecurefunc("ContainerFrameItemButton_OnEnter", function(btn)
        local bag  = btn:GetParent():GetID()
        local slot = btn:GetID()
        local link = GetContainerItemLink(bag, slot)
        if link then
            VRK.lastHovered = { bag = bag, slot = slot, link = link }
        end
    end)

    hooksecurefunc("ContainerFrame_OnModifiedClick", function(btn, kind)
        local bag  = btn:GetParent():GetID()
        local slot = btn:GetID()
        local link = GetContainerItemLink(bag, slot)
        if not link then return end
        local Lists = VRK:GetModule("Lists")
        if not Lists then
            print("VRK: Lists module not loaded")
            return
        end
        print("VRK click: bag="..bag.." slot="..slot.." alt="..tostring(IsAltKeyDown()).." ctrl="..tostring(IsControlKeyDown()).." link="..(link or "nil"))
        if IsAltKeyDown() and not IsControlKeyDown() then
            local ok, err = Lists:Add("sell", link)
            if ok then VRK:Print("Sell: " .. link) else VRK:Print(err) end
        elseif IsControlKeyDown() and not IsAltKeyDown() then
            local ok, err = Lists:Add("destroy", link)
            if ok then VRK:Print("Destroy: " .. link) else VRK:Print(err) end
        end
    end)

    hooksecurefunc("ContainerFrameItemButton_OnClick", function(btn, button)
        if button ~= "RightButton" then return end
        local bag  = btn:GetParent():GetID()
        local slot = btn:GetID()
        local link = GetContainerItemLink(bag, slot)
        if not link then return end

        if IsAltKeyDown() then
            -- Alt+RightClick: add to destroy list
            local Lists = VRK:GetModule("Lists")
            if Lists then
                local ok, err = Lists:Add("destroy", link)
                if ok then VRK:Print("Destroy: " .. link) else VRK:Print(err) end
            end
        else
            VRK:ShowContextMenu(btn, bag, slot, link)
        end
    end)
end

-- ── Context Menu ─────────────────────────────────────────────────────────────
local VRK_DropDown = CreateFrame("Frame", "VRK_DropDown", UIParent, "UIDropDownMenuTemplate")

function VRK:ShowContextMenu(anchor, bag, slot, link)
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return end
    local Lists = VRK:GetModule("Lists")
    if not Lists then return end
    local remembered = Lists:GetRemembered(itemID)

    UIDropDownMenu_Initialize(VRK_DropDown, function(frame, level)
        local info

        info = {}
        info.text = "VRK"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        if level == 1 then
            info = {}
            info.text = "|cff00ff00Mark as: Sell|r"
            info.notCheckable = true
            info.func = function()
                local ok, err = Lists:Add("sell", link)
                VRK:Print(ok and ("Added to sell list: " .. link) or err)
            end
            UIDropDownMenu_AddButton(info, level)

            info = {}
            info.text = "|cffff0000Mark as: Destroy|r"
            info.notCheckable = true
            info.func = function()
                local ok, err = Lists:Add("destroy", link)
                VRK:Print(ok and ("Added to destroy list: " .. link) or err)
            end
            UIDropDownMenu_AddButton(info, level)

            info = {}
            info.text = "|cff0088ffMark as: Protect|r"
            info.notCheckable = true
            info.func = function()
                local ok, err = Lists:Add("protect", link)
                VRK:Print(ok and ("Protected: " .. link) or err)
            end
            UIDropDownMenu_AddButton(info, level)

            info = {}
            info.text = ""; info.notCheckable = true; info.disabled = true
            UIDropDownMenu_AddButton(info, level)

            info = {}
            info.text = remembered
                and ("|cff888888Remembered: " .. remembered.action .. " (change)|r")
                or "Remember a choice..."
            info.notCheckable = true
            info.hasArrow = true
            info.value = { itemID = itemID, link = link }
            UIDropDownMenu_AddButton(info, level)

            if remembered then
                info = {}
                info.text = "|cff888888Forget remembered choice|r"
                info.notCheckable = true
                info.func = function()
                    Lists:Forget(itemID)
                    VRK:Print("Forgot choice for " .. link)
                end
                UIDropDownMenu_AddButton(info, level)
            end

            info = {}
            info.text = ""; info.notCheckable = true; info.disabled = true
            UIDropDownMenu_AddButton(info, level)

            info = {}
            info.text = "Remove from VRK lists"
            info.notCheckable = true
            info.func = function()
                Lists:RemoveFromAll(itemID)
                VRK:Print("Removed from all lists: " .. link)
            end
            UIDropDownMenu_AddButton(info, level)

        elseif level == 2 then
            local menuList = UIDROPDOWNMENU_MENU_VALUE
            if menuList and menuList.itemID then
                local iID   = menuList.itemID
                local iLink = menuList.link
                local actions = {
                    { text = "Need",       action = "need"       },
                    { text = "Greed",      action = "greed"      },
                    { text = "Disenchant", action = "disenchant" },
                    { text = "Pass",       action = "pass"       },
                    { text = "Sell",       action = "sell"       },
                    { text = "Destroy",    action = "destroy"    },
                }
                for _, entry in ipairs(actions) do
                    local a = entry.action
                    info = {}
                    info.text = entry.text
                    info.notCheckable = true
                    info.func = function()
                        Lists:Remember(iID, a, "manual")
                        VRK:Print("Remembered: " .. a .. " for " .. iLink)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end, "MENU")

    ToggleDropDownMenu(1, nil, VRK_DropDown, anchor, 0, 0)
end

-- ── Slash Commands ────────────────────────────────────────────────────────────
function VRK:SetupSlashCommands()
    SlashCmdList["VRK"] = function(msg)
        local cmd, rest = string.match(strtrim(msg or ""), "^(%S*)%s*(.-)$")
        cmd  = strlower(cmd or "")
        rest = strtrim(rest or "")

        local Lists     = VRK:GetModule("Lists")
        local Merchant  = VRK:GetModule("Merchant")
        local Destroy   = VRK:GetModule("Destroy")
        local Export    = VRK:GetModule("Export")
        local MainFrame = VRK:GetModule("MainFrame")

        if cmd == "" or cmd == "ui" then
            if MainFrame then MainFrame:Toggle()
            else VRK:Print("UI not loaded yet.") end

        elseif cmd == "help" then
            VRK:PrintHelp()

        elseif cmd == "sell" then
            if Merchant then Merchant:SellNow() end

        elseif cmd == "destroy" then
            if Destroy then Destroy:ScanAndDestroyAll() end

        elseif cmd == "add" then
            if rest ~= "sell" and rest ~= "destroy" and rest ~= "protect" then
                VRK:Print("Usage: /vrk add sell|destroy|protect  (hover an item first)")
                return
            end
            if not VRK.lastHovered then
                VRK:Print("Hover over a bag item first.")
                return
            end
            local ok, err = Lists:Add(rest, VRK.lastHovered.link)
            VRK:Print(ok and ("Added to " .. rest .. ": " .. VRK.lastHovered.link) or err)

        elseif cmd == "remove" then
            if not VRK.lastHovered then
                VRK:Print("Hover over a bag item first.")
                return
            end
            local itemID = tonumber(string.match(VRK.lastHovered.link, "item:(%d+)"))
            Lists:RemoveFromAll(itemID)
            VRK:Print("Removed from all lists: " .. VRK.lastHovered.link)

        elseif cmd == "clear" then
            if rest ~= "sell" and rest ~= "destroy" and rest ~= "protect" then
                VRK:Print("Usage: /vrk clear sell|destroy|protect")
                return
            end
            Lists:Clear(rest)
            VRK:Print("Cleared " .. rest .. " list.")

        elseif cmd == "export" then
            if Export then Export:ShowPopup() end

        elseif cmd == "import" then
            if rest == "" then
                VRK:Print("Usage: /vrk import VRK:v1:sell:id,id|destroy:id,id")
                return
            end
            if Export then Export:Deserialize(rest) end

        elseif cmd == "stats" then
            local s = VRK.db.char.stats
            VRK:Print(string.format(
                "Sold: %d items (%s) · Destroyed: %d items",
                s.totalItemsSold,
                GetCoinTextureString(s.totalGoldEarned),
                s.totalItemsDestroyed
            ))

        elseif cmd == "toggle" then
            local toggles = {
                autosell    = "autoSell",
                autorepair  = "autoRepair",
                grays       = "alwaysSellGrays",
                highlight   = "bagHighlight",
                sounds      = "soundEffects",
                lootdestroy = "autoDestroyOnLoot",
            }
            local key = toggles[strlower(rest)]
            if key then
                VRK:S()[key] = not VRK:S()[key]
                VRK:Print(rest .. ": " .. (VRK:S()[key] and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
                VRK:SendMessage("VRK_SETTINGS_CHANGED")
            else
                VRK:Print("Unknown toggle. Options: autosell autorepair grays highlight sounds lootdestroy")
            end

        else
            VRK:Print("Unknown command. Type /vrk help")
        end
    end
end

function VRK:PrintHelp()
    local lines = {
        "|cffFFD700VRK v" .. VRK.version .. " — commands:|r",
        "  /vrk              open/close UI",
        "  /vrk sell         sell sell-list items (must be at merchant)",
        "  /vrk destroy      destroy all destroy-list items",
        "  /vrk add sell|destroy|protect   (hover item first)",
        "  /vrk remove       remove hovered item from all lists",
        "  /vrk clear sell|destroy|protect",
        "  /vrk export       show export popup",
        "  /vrk import <str> import list from string",
        "  /vrk stats        lifetime statistics",
        "  /vrk toggle autosell|autorepair|grays|highlight|sounds|lootdestroy",
        "|cffFFD700Keybindings:|r",
        "  Alt+Click (bag)       add to sell list",
        "  Alt+RightClick (bag)  add to destroy list",
        "  RightClick (bag)      VRK context menu",
    }
    for _, line in ipairs(lines) do print(line) end
end
