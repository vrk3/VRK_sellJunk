-- modules/Tooltip.lua
local Tooltip = {}
VRK:RegisterModule("Tooltip", Tooltip)

local BADGE = {
    sell    = "|cff00ff00[VRK: Sell]|r",
    destroy = "|cffff0000[VRK: Destroy]|r",
    protect = "|cff0088ff[VRK: Protected]|r",
}

local function OnTooltipSetBagItem(tooltip, bag, slot)
    if not VRK.db then return end
    if Tooltip.needsRefresh then
        Tooltip.needsRefresh = false
    end
    local s    = VRK:S()
    local link = GetContainerItemLink(bag, slot)
    if not link then return end
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return end

    local Lists = VRK:GetModule("Lists")

    if s.tooltipBadge then
        for _, listName in ipairs({ "protect", "destroy", "sell" }) do
            if Lists:Contains(listName, itemID) then
                tooltip:AddLine(BADGE[listName])
                break
            end
        end
        if s.alwaysSellGrays
            and not Lists:Contains("sell", itemID)
            and not Lists:Contains("destroy", itemID)
            and not Lists:Contains("protect", itemID)
        then
            local _, _, quality = GetItemInfo(link)
            if quality == 0 then
                tooltip:AddLine("|cffffff00[VRK: Gray — will sell]|r")
            end
        end
    end

    if s.vendorPrice then
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
        if vendorPrice and vendorPrice > 0 then
            tooltip:AddDoubleLine(
                "Vendor price:", GetCoinTextureString(vendorPrice),
                0.8, 0.8, 0.8, 1, 1, 1
            )
        end
    end

    local remembered = Lists:GetRemembered(itemID)
    if remembered then
        tooltip:AddLine("|cff888888[VRK remembered: " .. remembered.action .. "]|r")
    end

    tooltip:Show()
end

function Tooltip:OnLoad()
    -- Hook GameTooltip:SetBagItem (WotLK)
    local ok = pcall(hooksecurefunc, GameTooltip, "SetBagItem", function(tooltip, bag, slot)
        OnTooltipSetBagItem(tooltip, bag, slot)
    end)
    if not ok then
        print("|cffFF4444VRK Tooltip: SetBagItem hook failed — tooltip badges disabled|r")
    end
    self.needsRefresh = false
    self:RegisterMessage("VRK_PROFILE_CHANGED", function()
        self.needsRefresh = true
    end)
end
