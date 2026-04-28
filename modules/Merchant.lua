-- modules/Merchant.lua
local Merchant = {}
VRK:RegisterModule("Merchant", Merchant)

function Merchant:OnLoad()
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
end

function Merchant:OnMerchantShow()
    if not VRK:S().autoSell then return end
    self:RunSellCycle()
end

function Merchant:SellNow()
    if not (MerchantFrame and MerchantFrame:IsShown()) then
        VRK:Print("You must be at a merchant to sell.")
        return
    end
    self:RunSellCycle()
end

function Merchant:RunSellCycle()
    local settings = VRK:S()
    local Lists    = VRK:GetModule("Lists")
    local sellList = Lists:GetAll("sell")
    local protList = Lists:GetAll("protect")

    local totalSold  = 0
    local totalValue = 0
    local repairCost = 0

    -- Auto-repair
    if settings.autoRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair then
            repairCost = cost
            if IsInGuild() and CanGuildBankRepair() then
                RepairAllItems(1)
            else
                RepairAllItems()
            end
        end
    end

    -- Sell items
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID and not protList[itemID] then
                    local shouldSell = sellList[itemID] ~= nil

                    if not shouldSell and settings.alwaysSellGrays then
                        local _, _, quality = GetItemInfo(link)
                        if quality == 0 then shouldSell = true end
                    end

                    if shouldSell then
                        local _, stackCount = GetContainerItemInfo(bag, slot)
                        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
                        stackCount  = stackCount  or 1
                        vendorPrice = vendorPrice or 0
                        totalValue  = totalValue + (vendorPrice * stackCount)
                        totalSold   = totalSold + 1
                        UseContainerItem(bag, slot)
                        VRK:AddHistory("SOLD", link, vendorPrice * stackCount)
                    end
                end
            end
        end
    end

    -- Update stats
    if totalSold > 0 then
        VRK.db.char.stats.totalItemsSold  = VRK.db.char.stats.totalItemsSold + totalSold
        VRK.db.char.stats.totalGoldEarned = VRK.db.char.stats.totalGoldEarned + totalValue
    end

    -- Session summary
    if settings.sessionStatsChat and (totalSold > 0 or repairCost > 0) then
        local msg = string.format("Sold %d item%s for %s",
            totalSold, totalSold == 1 and "" or "s",
            GetCoinTextureString(totalValue))
        if repairCost > 0 then
            msg = msg .. " · Repaired for " .. GetCoinTextureString(repairCost)
        end
        VRK:Print(msg)
    end

    if settings.soundEffects and totalSold > 0 then
        PlaySound("LOOT_COIN_SMALL")
    end
end
