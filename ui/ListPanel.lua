-- ui/ListPanel.lua
-- Reusable scrollable list panel. Instantiate with ListPanel:New(parent, listName, actionButtonText, actionFunc)

ListPanel = {}
ListPanel.__index = ListPanel

local ROW_HEIGHT = 24
local ICON_SIZE  = 20

function ListPanel:New(parent, listName, actionButtonText, actionFunc)
    local obj = setmetatable({}, ListPanel)
    obj.listName   = listName
    obj.actionFunc = actionFunc
    obj.rows       = {}
    obj.filter     = ""
    obj:Build(parent, actionButtonText)
    return obj
end

function ListPanel:Build(parent, actionButtonText)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame

    -- Search box (plain EditBox — SearchBoxTemplate doesn't exist in WotLK)
    local searchBox = CreateFrame("EditBox", nil, frame)
    searchBox:SetSize(180, 22)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(4, 4, 2, 2)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    searchBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        frame.vrkPanel.filter = strlower(self:GetText() or "")
        frame.vrkPanel:Refresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.searchBox = searchBox

    -- Add hovered item button
    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(170, 22)
    addBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    addBtn:SetText("+ Add Hovered Item")
    addBtn:SetScript("OnClick", function()
        if not VRK.lastHovered then
            VRK:Print("Hover over a bag item first.")
            return
        end
        local Lists = VRK:GetModule("Lists")
        local ok, err = Lists:Add(frame.vrkPanel.listName, VRK.lastHovered.link)
        if not ok then VRK:Print(err) end
    end)

    -- Clear list button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear List")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("VRK_CONFIRM_CLEAR", frame.vrkPanel.listName)
    end)

    -- Static popup for confirm
    if not StaticPopupDialogs["VRK_CONFIRM_CLEAR"] then
        StaticPopupDialogs["VRK_CONFIRM_CLEAR"] = {
            text = "Clear the entire %s list?",
            button1 = "Yes", button2 = "No",
            OnAccept = function(_, listName)
                local Lists = VRK:GetModule("Lists")
                if Lists then Lists:Clear(listName) end
            end,
            timeout = 0, whileDead = 1, hideOnEscape = 1,
        }
    end

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     8,  -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 56)
    self.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 1)
    scrollFrame:SetScrollChild(content)
    self.content = content

    -- Keep content width synced with scrollFrame
    scrollFrame:HookScript("OnSizeChanged", function(sf)
        if self.content then
            local w = sf:GetWidth() or 600
            self.content:SetWidth(w)
            -- Update all row widths too
            for _, row in ipairs(self.rows) do
                if row and row.SetWidth then
                    row:SetWidth(w)
                end
            end
        end
    end)

    -- Bottom bar
    local selectAllChk = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    selectAllChk:SetSize(20, 20)
    selectAllChk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 10)
    selectAllChk:SetScript("OnClick", function(self)
        frame.vrkPanel:SetAllChecked(self:GetChecked())
    end)

    local selAllLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selAllLbl:SetPoint("LEFT", selectAllChk, "RIGHT", 2, 0)
    selAllLbl:SetText("All")

    local removeSelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    removeSelBtn:SetSize(110, 22)
    removeSelBtn:SetPoint("LEFT", selAllLbl, "RIGHT", 8, 0)
    removeSelBtn:SetText("Remove Selected")
    removeSelBtn:SetScript("OnClick", function()
        frame.vrkPanel:RemoveSelected()
    end)

    if actionButtonText and actionFunc then
        local actionBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        actionBtn:SetSize(130, 22)
        actionBtn:SetPoint("LEFT", removeSelBtn, "RIGHT", 8, 0)
        actionBtn:SetText(actionButtonText)
        actionBtn:SetScript("OnClick", actionFunc)
    end

    local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportBtn:SetSize(70, 22)
    exportBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 10)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local Exp = VRK:GetModule("Export")
        if Exp then Exp:ShowPopup() end
    end)

    self.countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countLabel:SetPoint("RIGHT", exportBtn, "LEFT", -8, 0)
    self.countLabel:SetTextColor(0.8, 0.8, 0.8)

    frame.vrkPanel = self
end

function ListPanel:Refresh()
    local Lists = VRK:GetModule("Lists")
    if not Lists then return end

    local items  = Lists:GetAll(self.listName)
    local filter = self.filter or ""
    local sorted = {}

    for itemID, data in pairs(items) do
        local name = data.name or ""
        if filter == "" or strlower(name):find(filter, 1, true) then
            table.insert(sorted, { itemID = itemID, data = data })
        end
    end
    table.sort(sorted, function(a, b)
        return (a.data.name or "") < (b.data.name or "")
    end)

    for i = #self.rows + 1, #sorted do
        self.rows[i] = self:CreateRow(self.content, i)
    end
    for i = #sorted + 1, #self.rows do
        self.rows[i]:Hide()
    end

    for i, entry in ipairs(sorted) do
        self:PopulateRow(self.rows[i], entry.itemID, entry.data)
        self.rows[i]:Show()
    end

    self.content:SetHeight(math.max(1, #sorted * ROW_HEIGHT))
    self.content:SetWidth(self.scrollFrame:GetWidth() or 1)
    self.countLabel:SetText(#sorted .. " item" .. (#sorted == 1 and "" or "s"))
end

function ListPanel:CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(600)  -- Will be updated by OnSizeChanged hook
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetTexture(0.1, 0.1, 0.1, 0.5)
    else
        bg:SetTexture(0.05, 0.05, 0.05, 0.5)
    end

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local chk = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    chk:SetSize(18, 18)
    chk:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.chk = chk

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", chk, "RIGHT", 4, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT",  icon, "RIGHT", 6,    0)
    nameText:SetPoint("RIGHT", row,  "RIGHT", -100, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    priceText:SetTextColor(1, 0.82, 0)
    row.priceText = priceText

    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeBtn:SetSize(55, 18)
    removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    removeBtn:SetText("Remove")
    row.removeBtn = removeBtn

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

function ListPanel:PopulateRow(row, itemID, data)
    row.itemID   = itemID
    row.itemLink = data.link

    local _, _, _, _, _, _, _, _, _, texture, vendorPrice = GetItemInfo(data.link or "")
    row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    local name = data.name or GetItemInfo(data.link or "") or ("Item #" .. itemID)
    row.nameText:SetText(name)

    if vendorPrice and vendorPrice > 0 then
        row.priceText:SetText(GetCoinTextureString(vendorPrice))
    else
        row.priceText:SetText("")
    end

    local listName = self.listName
    row.removeBtn:SetScript("OnClick", function()
        local Lists = VRK:GetModule("Lists")
        if Lists then Lists:Remove(listName, itemID) end
    end)
end

function ListPanel:SetAllChecked(checked)
    for _, row in ipairs(self.rows) do
        if row:IsShown() then row.chk:SetChecked(checked) end
    end
end

function ListPanel:RemoveSelected()
    local Lists = VRK:GetModule("Lists")
    if not Lists then return end
    for _, row in ipairs(self.rows) do
        if row:IsShown() and row.chk:GetChecked() and row.itemID then
            Lists:Remove(self.listName, row.itemID)
        end
    end
end
