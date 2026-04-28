-- modules/BagScan.lua
local BagScan = {}
VRK:RegisterModule("BagScan", BagScan)

local COLORS = {
    sell    = { 0,   1,   0,   0.35 },
    destroy = { 1,   0,   0,   0.35 },
    protect = { 0,   0.5, 1,   0.35 },
    gray    = { 1,   1,   0,   0.25 },
}

local ItemContextMenu = CreateFrame("Frame", "VRK_ItemContextMenu", UIParent, "UIDropDownMenuTemplate")

function BagScan:ShowItemContextMenu(bag, slot, link)
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return end

    local Lists = VRK:GetModule("Lists")

    UIDropDownMenu_Initialize(ItemContextMenu, function(frame, level)
        local info

        info = {}
        info.text = GetItemInfo(link) or "Item"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = ""; info.notCheckable = true; info.disabled = true
        UIDropDownMenu_AddButton(info, level)

        local inSell    = Lists:Contains("sell",    itemID)
        local inDestroy = Lists:Contains("destroy", itemID)
        local inProtect = Lists:Contains("protect", itemID)

        info = {}
        info.text = (inSell and "|cff00ff00✔|r " or "") .. "Sell List"
        info.checked = inSell
        info.func = function()
            if inSell then
                Lists:Remove("sell", itemID)
            else
                Lists:Add("sell", link)
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = (inDestroy and "|cff00ff00✔|r " or "") .. "Destroy List"
        info.checked = inDestroy
        info.func = function()
            if inDestroy then
                Lists:Remove("destroy", itemID)
            else
                Lists:Add("destroy", link)
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info = {}
        info.text = (inProtect and "|cff00ff00✔|r " or "") .. "Always Keep"
        info.checked = inProtect
        info.func = function()
            if inProtect then
                Lists:Remove("protect", itemID)
            else
                Lists:Add("protect", link)
            end
        end
        UIDropDownMenu_AddButton(info, level)

    end, "MENU")

    ToggleDropDownMenu(1, nil, ItemContextMenu, 0, 0)
end

function BagScan:OnLoad()
    self:RegisterMessage("VRK_LIST_CHANGED",     "RefreshAll")
    self:RegisterMessage("VRK_SETTINGS_CHANGED", "RefreshAll")
    self:RegisterEvent("BAG_UPDATE",             "RefreshAll")
    self:RegisterMessage("VRK_PROFILE_CHANGED", function()
        self:CancelAllTimers()
        self:ScheduleTimer("Refresh", 0.2)
    end)

    -- Hook ContainerFrame_Update if it exists (WotLK)
    local ok, err = pcall(hooksecurefunc, "ContainerFrame_Update", function(cf)
        if cf and cf.GetID and cf.IsShown and cf:IsShown() then
            for j = 1, MAX_CONTAINER_ITEMS do
                local btn = _G[cf:GetName() .. "Item" .. j]
                if btn then
                    BagScan:UpdateButton(btn)
                    BagScan:TryHookButton(btn)
                end
            end
        end
    end)
    -- If hooksecurefunc fails (API doesn't exist), BAG_UPDATE refresh is sufficient

    -- Hook right-click on all container item buttons
    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        if cf then BagScan:HookAllContainers() end
    end
    -- Also hook whenever a new container frame opens
    pcall(hooksecurefunc, "ContainerFrame_LoadUI", function()
        BagScan:ScheduleTimer("HookAllContainers", 0.5)
    end)
end

function BagScan:TryHookButton(btn)
    if btn and not btn.vrkRightClickHooked then
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnMouseDown", function(self, button)
            if button == "RightButton" then
                local bag = self:GetParent():GetID()
                local slot = self:GetID()
                local link = GetContainerItemLink(bag, slot)
                if link then
                    CloseDropDownMenus()
                    C_Timer.After(0.01, function()
                        BagScan:ShowItemContextMenu(bag, slot, link)
                    end)
                end
            end
        end)
        btn.vrkRightClickHooked = true
    end
end

function BagScan:HookAllContainers()
    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then
            for j = 1, MAX_CONTAINER_ITEMS do
                local btn = _G[cf:GetName() .. "Item" .. j]
                if btn then BagScan:TryHookButton(btn) end
            end
        end
    end
end

local function GetHighlightTex(btn)
    if not btn.vrkTex then
        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(btn)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetBlendMode("ADD")
        btn.vrkTex = tex
    end
    return btn.vrkTex
end

function BagScan:UpdateButton(btn)
    local parent = btn:GetParent()
    if not (parent and parent.GetID) then return end

    local bag  = parent:GetID()
    local slot = btn:GetID()
    local tex  = GetHighlightTex(btn)

    if not VRK.db or not VRK:S().bagHighlight then
        tex:Hide()
        return
    end

    local link = GetContainerItemLink(bag, slot)
    if not link then tex:Hide(); return end

    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then tex:Hide(); return end

    local Lists = VRK:GetModule("Lists")
    local color

    if Lists:Contains("protect", itemID) then
        color = COLORS.protect
    elseif Lists:Contains("destroy", itemID) then
        color = COLORS.destroy
    elseif Lists:Contains("sell", itemID) then
        color = COLORS.sell
    elseif VRK:S().alwaysSellGrays then
        local _, _, quality = GetItemInfo(link)
        if quality == 0 then color = COLORS.gray end
    end

    if color then
        tex:SetVertexColor(color[1], color[2], color[3])
        tex:SetAlpha(color[4])
        tex:Show()
    else
        tex:Hide()
    end
end

function BagScan:RefreshAll()
    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then
            for j = 1, MAX_CONTAINER_ITEMS do
                local btn = _G["ContainerFrame" .. i .. "Item" .. j]
                if btn then
                    self:UpdateButton(btn)
                    self:TryHookButton(btn)
                end
            end
        end
    end
    self:UpdateBadgeCount()
end

function BagScan:Refresh()
    self:RefreshAll()
end

function BagScan:UpdateBadgeCount()
    local Lists    = VRK:GetModule("Lists")
    local sellList = Lists:GetAll("sell")
    local destList = Lists:GetAll("destroy")
    local protList = Lists:GetAll("protect")
    local count    = 0

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID and not protList[itemID] then
                    if sellList[itemID] or destList[itemID] then
                        count = count + 1
                    elseif VRK:S().alwaysSellGrays then
                        local _, _, quality = GetItemInfo(link)
                        if quality == 0 then count = count + 1 end
                    end
                end
            end
        end
    end

    VRK:SendMessage("VRK_BAG_COUNT_CHANGED", count)
end
