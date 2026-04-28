-- modules/LootRoll.lua
local LootRoll = {}
VRK:RegisterModule("LootRoll", LootRoll)

local ROLL_PASS       = 0
local ROLL_NEED       = 1
local ROLL_GREED      = 2
local ROLL_DISENCHANT = 3

local ACTION_TO_ROLL = {
    pass = ROLL_PASS, need = ROLL_NEED,
    greed = ROLL_GREED, disenchant = ROLL_DISENCHANT,
}

local BUTTON_INFO = {
    RollButton1 = { action = "need",       rollType = ROLL_NEED       },
    RollButton2 = { action = "greed",      rollType = ROLL_GREED      },
    RollButton3 = { action = "disenchant", rollType = ROLL_DISENCHANT },
    PassButton  = { action = "pass",       rollType = ROLL_PASS       },
}

function LootRoll:OnLoad()
    self:RegisterEvent("START_LOOT_ROLL", "OnStartLootRoll")
    self:HookGroupLootFrames()
    self:RegisterMessage("VRK_PROFILE_CHANGED", function()
        self:ReRegister()
    end)
end

function LootRoll:OnStartLootRoll(rollID)
    local Lists = VRK:GetModule("Lists")
    local link  = GetLootRollItemInfo(rollID)
    if not link then return end

    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return end

    local remembered = Lists:GetRemembered(itemID)
    if not remembered then return end

    local rollType = ACTION_TO_ROLL[remembered.action]
    if rollType == nil then return end

    RollOnLoot(rollID, rollType)

    if not remembered.notified then
        VRK:Print("Auto-rolled " .. remembered.action .. " on " .. link .. " (remembered)")
        remembered.notified = true
    end
end

function LootRoll:HookGroupLootFrames()
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then self:HookFrame(frame) end
    end

    hooksecurefunc("GroupLootFrame_OpenNewFrame", function(frame, rollID)
        LootRoll:HookFrame(frame)
    end)
end

function LootRoll:HookFrame(frame)
    if frame._vrkHooked then return end
    frame._vrkHooked = true

    for btnKey, btnInfo in pairs(BUTTON_INFO) do
        local btn = frame[btnKey] or _G[(frame:GetName() or "") .. btnKey]
        if btn then
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:HookScript("OnClick", function(self, button)
                if button ~= "RightButton" then return end
                local rollID = frame.rollID
                if not rollID then return end
                local link = GetLootRollItemInfo(rollID)
                if not link then return end
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if not itemID then return end
                local Lists = VRK:GetModule("Lists")
                Lists:Remember(itemID, btnInfo.action, "loot_roll")
                VRK:Print("Remembered: " .. btnInfo.action .. " for " .. link)
            end)
        end
    end
end

function LootRoll:ReRegister()
    self:UnregisterAllEvents()
    self:RegisterEvent("START_LOOT_ROLL", "OnStartLootRoll")
    self:RegisterMessage("VRK_PROFILE_CHANGED", function()
        self:ReRegister()
    end)
end
