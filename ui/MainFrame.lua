-- ui/MainFrame.lua
-- Single window: master bag list at top, 3 panes below (Sell / Destroy / Keep)
local MainFrame = {}
VRK:RegisterModule("MainFrame", MainFrame)

local FRAME_W, FRAME_H = 820, 580
local TITLE_H    = 30
local LIST_H     = 180  -- top bag list height
local PANE_GAP   = 6    -- gap between list and panes

function MainFrame:OnLoad()
    self.frame = CreateFrame("Frame", "VRK_MainFrame", UIParent)
    self.frame:SetSize(FRAME_W, FRAME_H)
    self.frame:SetPoint("CENTER")
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        MainFrame:SavePosition()
    end)
    self.frame:SetFrameStrata("DIALOG")
    self.frame:Hide()
    tinsert(UISpecialFrames, "VRK_MainFrame")

    self.frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\UI-Silver-Button-Border",
        edgeSize = 10,
    })
    self.frame:SetBackdropColor(0.06, 0.06, 0.09, 0.97)
    self.frame:SetBackdropBorderColor(0.4, 0.35, 0.25)

    self:BuildTitleBar()
    self:BuildBagList()
    self:BuildPanes()

    self:RegisterMessage("VRK_BAG_COUNT_CHANGED", "Refresh")
    self:RegisterMessage("VRK_LIST_CHANGED", "Refresh")
    self:RegisterMessage("VRK_PROFILE_CHANGED", "Refresh")
    self:RegisterEvent("BAG_UPDATE", "Refresh")

    self:RefreshProfileButton()
    self:Refresh()
end

-- ── Title Bar ─────────────────────────────────────────────────────────────────

function MainFrame:BuildTitleBar()
    local titleBar = CreateFrame("Frame", nil, self.frame)
    titleBar:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",   4, -4)
    titleBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function(f) f:GetParent():StartMoving() end)
    titleBar:SetScript("OnDragStop",   function(f) f:GetParent():StopMovingOrSizing(); MainFrame:SavePosition() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleText:SetText("|cffFFD700VRK|r — Junk Manager  |cff808080v" .. VRK.version .. "|r")

    -- Profile button (right of title)
    local profileBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    profileBtn:SetSize(90, 20)
    profileBtn:SetPoint("LEFT", titleText, "RIGHT", 8, 0)
    local Lists = VRK:GetModule("Lists")
    profileBtn:SetText(Lists:GetActiveProfileName())
    profileBtn:SetScript("OnClick", function()
        MainFrame:ShowProfileMenu(profileBtn)
    end)
    self.profileBtn = profileBtn

    local sep = titleBar:CreateTexture(nil, "BOTTOM")
    sep:SetPoint("BOTTOMLEFT",  titleBar, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -36, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(0.4, 0.35, 0.2)

    local closeBtn = CreateFrame("Button", nil, self.frame)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -6, -6)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)

    -- Resize handle (bottom-right corner grip)
    local resizeHandle = CreateFrame("Frame", nil, self.frame)
    resizeHandle:SetSize(20, 20)
    resizeHandle:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -4, -4)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function()
        self.frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        self:SavePosition()
        self:Refresh()
    end)
    local gripTex = resizeHandle:CreateTexture(nil, "OVERLAY")
    gripTex:SetTexture("Interface\\ChatFrame\\UI-Chat-Resize Grip")
    gripTex:SetAllPoints()
    self.resizeHandle = resizeHandle
end

-- ── Bag List (Top) ─────────────────────────────────────────────────────────────

function MainFrame:BuildBagList()
    local listFrame = CreateFrame("Frame", nil, self.frame)
    listFrame:SetPoint("TOPLEFT",  self.frame, "TOPLEFT",  8, -34)
    listFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -8, -4)
    listFrame:SetHeight(LIST_H)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\UI-Silver-Button-Border",
        edgeSize = 6,
    })
    listFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    listFrame:SetBackdropBorderColor(0.25, 0.22, 0.18)
    self.listFrame = listFrame

    local hdr = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -6)
    hdr:SetText("|cffFFD700All Bag Items|r  |cff808080Right=SELL | Left=DESTROY | Middle=KEEP|r")
    hdr:SetTextColor(0.7, 0.65, 0.5)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, listFrame)
    searchBox:SetSize(160, 22)
    searchBox:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -28, -4)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(4, 4, 2, 2)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    searchBox:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(6, 6, 4, 4)

    local searchLbl = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLbl:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    searchLbl:SetText("Search:")
    searchLbl:SetTextColor(0.7, 0.65, 0.5)

    local clearBtn = CreateFrame("Button", nil, listFrame)
    clearBtn:SetSize(20, 20)
    clearBtn:SetPoint("RIGHT", searchBox, "LEFT", -4, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    clearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    clearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        MainFrame.searchFilter = strlower(self:GetText() or "")
        MainFrame:RefreshBagList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    self.searchBox = searchBox
    self.searchFilter = ""

    local scroll = CreateFrame("ScrollFrame", "VRK_BagListScroll", listFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",   listFrame, "TOPLEFT",   6, -52)
    scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -24, 6)
    self.scrollFrame = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth() or 700)
    scroll:SetScrollChild(content)
    self.listContent = content

    scroll:HookScript("OnSizeChanged", function()
        local w = scroll:GetWidth() or 700
        content:SetWidth(w)
        for _, row in ipairs(self.itemRows or {}) do
            row:SetWidth(w)
        end
    end)

    self.itemRows = {}
end

-- ── Panes (Bottom) ─────────────────────────────────────────────────────────────

function MainFrame:BuildPanes()
    -- Pane sizing: 3 panes fit horizontally with 8px left/right margins and 6px gap between panes
    -- Each pane width = (available - gaps) / 3, anchored so rightmost one always touches frame edge
    local MARGIN = 8
    local GAP = 6
    -- Use a generous pane width; last pane's right edge anchors to frame edge
    local paneW = math.floor((FRAME_W - 2*MARGIN - 2*GAP) / 3)
    local paneH = 180  -- 40% smaller than 300

    self.panes = {}
    local configs = {
        { name = "|cff00FF00SELL|r",     key = "sell",    col = {0,   0.8, 0  }, btn = "Sell All"   },
        { name = "|cffFF4444DESTROY|r",   key = "destroy", col = {0.8, 0,   0  }, btn = "Destroy All"},
        { name = "|cff44AAFFKEEP|r",      key = "protect", col = {0,   0.45, 0.8}, btn = nil        },
    }

    for i, cfg in ipairs(configs) do
        local p = self:CreatePane(cfg.name, cfg.key, cfg.col, paneW, paneH, cfg.btn)
        if i == 1 then
            p:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", MARGIN, MARGIN)
        elseif i == 2 then
            p:SetPoint("BOTTOMLEFT", self.panes[1], "BOTTOMRIGHT", GAP, 0)
        else
            -- Third pane: right edge anchors to frame so it never overflows
            p:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -MARGIN, MARGIN)
        end
        self.panes[i] = p
    end

    -- Make frame resizable and set min size
    self.frame:SetResizable(true)
    self.frame:SetMinResize(600, 400)
    self.frame:SetMaxResize(1200, 900)
end

function MainFrame:CreatePane(name, key, col, w, h, btnText)
    local pane = CreateFrame("Frame", nil, self.frame)
    pane:SetSize(w, h)
    pane.key = key
    pane:SetResizable(true)
    pane:SetMinResize(100, 100)

    pane:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\UI-Silver-Button-Border",
        edgeSize = 6,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    pane:SetBackdropColor(col[1], col[2], col[3], 0.1)
    pane:SetBackdropBorderColor(col[1], col[2], col[3], 0.5)

    local hdr = pane:CreateTexture(nil, "BORDER")
    hdr:SetPoint("TOPLEFT",   pane, "TOPLEFT")
    hdr:SetPoint("TOPRIGHT",  pane, "TOPRIGHT")
    hdr:SetHeight(22)
    hdr:SetColorTexture(col[1], col[2], col[3], 0.3)

    local hdrTxt = pane:CreateFontString(nil, "BORDER", "GameFontNormal")
    hdrTxt:SetPoint("CENTER", hdr, "CENTER", 0, 0)
    hdrTxt:SetText(name)
    hdrTxt:SetTextColor(1, 1, 1)

    local clearBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    clearBtn:SetSize(44, 18)
    clearBtn:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -4, -4)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        local Lists = VRK:GetModule("Lists")
        if Lists then Lists:Clear(key) end
        self:RefreshPanes()
    end)

    local scroller = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroller:SetPoint("TOPLEFT",   pane, "TOPLEFT",   4, -26)
    scroller:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -20, btnText and 36 or 6)
    pane.scroll = scroller

    local cont = CreateFrame("Frame", nil, scroller)
    cont:SetWidth(200)
    scroller:SetScrollChild(cont)
    pane.content = cont

    scroller:HookScript("OnSizeChanged", function()
        local w = scroller:GetWidth() or 200
        cont:SetWidth(w)
        for _, row in ipairs(pane.rows or {}) do
            row:SetWidth(w)
        end
    end)

    local cntLbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 4, 6)
    cntLbl:SetTextColor(0.6, 0.6, 0.6)
    pane.countLabel = cntLbl

    pane.rows = {}

    if btnText then
        local ab = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
        ab:SetSize(110, 22)
        ab:SetPoint("BOTTOM", pane, "BOTTOM", 0, 6)
        ab:SetText(btnText)
        if key == "sell" then
            ab:SetScript("OnClick", function()
                local M = VRK:GetModule("Merchant")
                if M then M:SellNow() end
            end)
        elseif key == "destroy" then
            ab:SetScript("OnClick", function()
                local D = VRK:GetModule("Destroy")
                if D then D:ScanAndDestroyAll() end
            end)
        end
    end

    -- Resize grip (bottom-right of pane) — use Button so it captures mouse properly
    local grip = CreateFrame("Button", nil, pane)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-Chat-Resize Grip")
    grip:SetScript("OnMouseDown", function()
        pane:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        pane:StopMovingOrSizing()
        MainFrame:RefreshPanes()
    end)
    grip:SetScript("OnMouseWheel", function() end)

    return pane
end

-- ── Refresh ────────────────────────────────────────────────────────────────────

function MainFrame:Refresh()
    self:RefreshProfileButton()
    self:RefreshBagList()
    self:RefreshPanes()
end

function MainFrame:RefreshBagList()
    local content = self.listContent
    if not content then return end
    if not self.itemRows then self.itemRows = {} end

    local items = {}
    local Lists = VRK:GetModule("Lists")
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID then
                    -- Skip items on the KEEP list
                    if Lists and Lists:Contains("protect", itemID) then
                        -- skip
                    else
                        local name, _, quality, _, _, _, _, _, _, tex, vPrice = GetItemInfo(link)
                        local _, count = GetContainerItemInfo(bag, slot)
                        tinsert(items, {
                            bag = bag, slot = slot, link = link, itemID = itemID,
                            name = name or "?",
                            quality = quality or 1,
                            texture = tex,
                            vendorPrice = vPrice or 0,
                            stackCount = count or 1,
                        })
                    end
                end
            end
        end
    end

    -- Filter by search text
    local filter = self.searchFilter or ""
    if filter ~= "" then
        local filtered = {}
        for _, item in ipairs(items) do
            if strlower(item.name):find(filter, 1, true) then
                tinsert(filtered, item)
            end
        end
        items = filtered
    end

    local ROW_H   = 26
    local LIST_W  = self.listFrame:GetWidth() or (FRAME_W - 16)
    local numItems = #items

    content:SetHeight(numItems * ROW_H)
    content:SetWidth(LIST_W)

    for i = 1, numItems do
        if not self.itemRows[i] then
            self.itemRows[i] = self:CreateBagRow(content, i)
        end
        self:PopulateBagRow(self.itemRows[i], items[i])
        self.itemRows[i]:Show()
    end
    for i = numItems + 1, #self.itemRows do
        self.itemRows[i]:Hide()
    end
end

function MainFrame:CreateBagRow(parent, index)
    local ROW_H = 26
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0,  0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.25)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT",   icon, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT",  row,  "RIGHT", -80, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    priceText:SetTextColor(1, 0.85, 0)
    row.priceText = priceText

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row:SetScript("OnMouseDown", function(self, button)
        if not self.itemID then return end
        local Lists = VRK:GetModule("Lists")
        if not Lists then return end

        if button == "RightButton" then
            if Lists:Contains("sell", self.itemID) then
                Lists:Remove("sell", self.itemID)
            else
                Lists:Remove("destroy", self.itemID)
                Lists:Remove("protect", self.itemID)
                Lists:Add("sell", self.itemLink)
            end
        elseif button == "LeftButton" then
            if Lists:Contains("destroy", self.itemID) then
                Lists:Remove("destroy", self.itemID)
            else
                Lists:Remove("sell", self.itemID)
                Lists:Remove("protect", self.itemID)
                Lists:Add("destroy", self.itemLink)
            end
        elseif button == "MiddleButton" then
            if Lists:Contains("protect", self.itemID) then
                Lists:Remove("protect", self.itemID)
            else
                Lists:Remove("sell", self.itemID)
                Lists:Remove("destroy", self.itemID)
                Lists:Add("protect", self.itemLink)
            end
        end

        self:UpdateRowState()
        MainFrame:RefreshPanes()
    end)

    return row
end

function MainFrame:PopulateBagRow(row, item)
    row.itemID   = item.itemID
    row.itemLink = item.link
    row.itemName = item.name
    row.bag      = item.bag
    row.slot     = item.slot
    row.quality  = item.quality

    row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    if item.vendorPrice and item.vendorPrice > 0 then
        row.priceText:SetText(GetCoinTextureString(item.vendorPrice * item.stackCount))
    else
        row.priceText:SetText("")
    end

    self:UpdateRowState(row)
end

function MainFrame:UpdateRowState(row)
    if not row or not row.itemID then return end
    local Lists = VRK:GetModule("Lists")
    local inSell    = Lists and Lists:Contains("sell",    row.itemID)
    local inDestroy = Lists and Lists:Contains("destroy", row.itemID)
    local inKeep    = Lists and Lists:Contains("protect", row.itemID)

    local qc = {[0]="9d9d9d",[1]="ffffff",[2]="1eff00",[3]="0070dd",[4]="a335ee",[5]="ff8000",[6]="e6cc80"}
    local q  = qc[row.quality] or "ffffff"

    local tag = ""
    if     inSell    then tag = "|cff00FF00[SELL]|r "
    elseif inDestroy then tag = "|cffFF4444[DEST]|r "
    elseif inKeep    then tag = "|cff44AAFF[KEEP]|r "
    end
    row.nameText:SetText(tag .. "|cff" .. q .. row.itemName .. "|r")
end

-- ── Panes ─────────────────────────────────────────────────────────────────────

function MainFrame:RefreshPanes()
    local Lists = VRK:GetModule("Lists")
    for _, pane in ipairs(self.panes or {}) do
        if pane then self:RefreshPane(pane, Lists) end
    end
end

function MainFrame:RefreshPane(pane, Lists)
    if not Lists then return end
    local all = Lists:GetAll(pane.key)
    local sorted = {}
    for id, data in pairs(all) do tinsert(sorted, { id, data }) end
    sort(sorted, function(a, b) return (a[2].name or "") < (b[2].name or "") end)

    local ROW_H = 22
    local W     = pane.scroll:GetWidth() or 200
    local n     = #sorted

    for i = 1, n do
        if not pane.rows[i] then pane.rows[i] = self:CreatePaneRow(pane.content, i) end
        self:PopulatePaneRow(pane.rows[i], sorted[i][1], sorted[i][2], pane.key)
        pane.rows[i]:Show()
    end
    for i = n + 1, #pane.rows do pane.rows[i]:Hide() end

    pane.content:SetHeight(math.max(1, n * ROW_H))
    pane.content:SetWidth(W)
    pane.countLabel:SetText(n .. " item" .. (n == 1 and "" or "s"))
end

function MainFrame:CreatePaneRow(parent, index)
    local ROW_H = 22
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0,  0)
    row:RegisterForClicks("LeftButtonUp")

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.3)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon

    local n = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    n:SetPoint("LEFT",   icon, "RIGHT", 4, 0)
    n:SetPoint("RIGHT",  row,  "RIGHT", -60, 0)
    n:SetJustifyH("LEFT")
    n:SetWordWrap(false)
    row.nameText = n

    local rm = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    rm:SetSize(50, 16)
    rm:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    rm:SetText("Remove")
    row.removeBtn = rm

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

function MainFrame:PopulatePaneRow(row, itemID, data, listKey)
    row.itemID  = itemID
    row.itemLink = data.link
    row.listKey  = listKey

    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(data.link or "")
    row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetText(data.name or "?")

    local lk, id = listKey, itemID
    row.removeBtn:SetScript("OnClick", function()
        local Lists = VRK:GetModule("Lists")
        if Lists then Lists:Remove(lk, id) end
        MainFrame:RefreshPanes()
    end)
end

-- ── Toggle / Position ─────────────────────────────────────────────────────────

function MainFrame:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RestorePosition()
        self.frame:Show()
        self:Refresh()
    end
end

function MainFrame:SavePosition()
    if not self.frame then return end
    local s = VRK:S()
    if not s.mainFrame then s.mainFrame = {} end
    local f  = self.frame
    local sc  = f:GetEffectiveScale()
    s.mainFrame.x = f:GetLeft()   * sc
    s.mainFrame.y = f:GetTop()    * sc
    s.mainFrame.w = f:GetWidth()
    s.mainFrame.h = f:GetHeight()
end

function MainFrame:RestorePosition()
    local f = self.frame
    local s = VRK:S().mainFrame
    if not s then return end
    if s.w and s.h then f:SetSize(s.w, s.h) end
    if s.x and s.y then
        local sc = f:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x / sc, s.y / sc)
    end
end

-- ── Profile Menu ──────────────────────────────────────────────────────────────

function MainFrame:ShowProfileMenu(btn)
    local Lists  = VRK:GetModule("Lists")
    local Export = VRK:GetModule("Export")

    local menu = _G["VRK_ProfileDropDown"] or CreateFrame("Frame", "VRK_ProfileDropDown", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(menu, function(frame, level)
        local active = Lists:GetActiveProfileName()

        -- Profiles section
        local t = { text = "Profile", isTitle = true, notCheckable = true }
        UIDropDownMenu_AddButton(t, level)

        for _, name in ipairs(Lists:GetAllProfileNames()) do
            local t = { text = name, checked = name == active, notCheckable = false,
                func = function()
                    Lists:SetActiveProfile(name)
                    self:RefreshProfileButton()
                    self:Refresh()
                end }
            UIDropDownMenu_AddButton(t, level)
        end

        -- Divider
        UIDropDownMenu_AddButton({ text = "", disabled = true, notCheckable = true }, level)

        -- New profile
        UIDropDownMenu_AddButton({
            text = "+ New Profile (copies Default)",
            notCheckable = true,
            func = function()
                local name = "Profile " .. date("%H:%M")
                Lists:CreateProfile(name)
                Lists:SetActiveProfile(name)
                self:RefreshProfileButton()
                self:Refresh()
                VRK:Print("Profile: |cffFFD700" .. name .. "|r")
            end
        }, level)

        -- Delete (not Default)
        if active ~= "Default" then
            UIDropDownMenu_AddButton({
                text = "Delete: " .. active,
                notCheckable = true,
                func = function()
                    Lists:DeleteProfile(active)
                    self:RefreshProfileButton()
                    self:Refresh()
                end
            }, level)
        end

        -- Divider
        UIDropDownMenu_AddButton({ text = "", disabled = true, notCheckable = true }, level)

        -- Export
        UIDropDownMenu_AddButton({
            text = "Export (show string)",
            notCheckable = true,
            func = function() Export:ShowPopup() end
        }, level)

        UIDropDownMenu_AddButton({
            text = "Import (paste string)",
            notCheckable = true,
            func = function()
                VRK:Print("Usage: /vrk import <VRK:v1:...>")
            end
        }, level)

    end, "MENU")

    CloseDropDownMenus()  -- close any other open menus first
    ToggleDropDownMenu(1, nil, menu, btn, 0, 0)
end

function MainFrame:RefreshProfileButton()
    local Lists = VRK:GetModule("Lists")
    if self.profileBtn then
        self.profileBtn:SetText(Lists:GetActiveProfileName())
    end
end
