-- modules/Loot.lua
local Loot = {}
VRK:RegisterModule("Loot", Loot)

Loot._snapshot = {}

local function TakeSnapshot()
    local snap = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then snap[bag .. ":" .. slot] = link end
        end
    end
    return snap
end

function Loot:OnLoad()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdateDelayed")
    self:RegisterEvent("LOOT_CLOSED",        "OnLootClosed")
    self._snapshot = TakeSnapshot()

    -- Skull warning overlay on loot frame buttons
    for i = 1, 4 do
        local lootSlot = _G["LootButton" .. i]
        if lootSlot then
            lootSlot:HookScript("OnEnter", function(btn)
                local slot = btn:GetID()
                local link = GetLootSlotLink(slot)
                if link then
                    local itemID = tonumber(string.match(link, "item:(%d+)"))
                    local Lists  = VRK:GetModule("Lists")
                    if itemID and Lists and Lists:Contains("destroy", itemID) then
                        GameTooltip:AddLine(
                            "|cffff0000[VRK: DESTROY LIST — will auto-destroy if lootdestroy ON]|r"
                        )
                        GameTooltip:Show()
                    end
                end
            end)
        end
    end
end

function Loot:OnLootClosed()
    self._snapshot = TakeSnapshot()
end

function Loot:OnBagUpdateDelayed()
    if not VRK:S().autoDestroyOnLoot then
        self._snapshot = TakeSnapshot()
        return
    end

    local Lists    = VRK:GetModule("Lists")
    local Destroy  = VRK:GetModule("Destroy")
    local destList = Lists:GetAll("destroy")
    local protList = Lists:GetAll("protect")
    local newSnap  = TakeSnapshot()

    for key, link in pairs(newSnap) do
        if not self._snapshot[key] then
            local itemID = tonumber(string.match(link, "item:(%d+)"))
            if itemID and destList[itemID] and not protList[itemID] then
                local bagStr, slotStr = string.match(key, "^(%d+):(%d+)$")
                local bag  = tonumber(bagStr)
                local slot = tonumber(slotStr)
                VRK:AddHistory("DESTROYED", link, 0)
                VRK.db.char.stats.totalItemsDestroyed =
                    VRK.db.char.stats.totalItemsDestroyed + 1
                Destroy:Item(bag, slot)
                VRK:Print("Auto-destroyed on loot: " .. link)
            end
        end
    end

    self._snapshot = newSnap
end
