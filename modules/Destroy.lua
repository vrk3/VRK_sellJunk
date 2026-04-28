-- modules/Destroy.lua
local Destroy = {}
VRK:RegisterModule("Destroy", Destroy)

-- Destroy a single bag slot item instantly — no confirmation ever.
function Destroy:Item(bag, slot)
    PickupContainerItem(bag, slot)
    DeleteCursorItem()
end

-- Scan all bags, destroy every destroy-list item that isn't protected.
function Destroy:ScanAndDestroyAll()
    local Lists    = VRK:GetModule("Lists")
    local destList = Lists:GetAll("destroy")
    local protList = Lists:GetAll("protect")
    local count    = 0

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID and destList[itemID] and not protList[itemID] then
                    VRK:AddHistory("DESTROYED", link, 0)
                    VRK.db.char.stats.totalItemsDestroyed =
                        VRK.db.char.stats.totalItemsDestroyed + 1
                    self:Item(bag, slot)
                    count = count + 1
                    if VRK:S().soundEffects then
                        PlaySound("INTERFACE_SOUND_LOST_TARGET_UNIT")
                    end
                end
            end
        end
    end

    if count > 0 then
        VRK:Print(string.format("Destroyed %d item%s.", count, count == 1 and "" or "s"))
    else
        VRK:Print("No destroy-list items found in bags.")
    end
end
