-- ui/DragDropWindow.lua
local DragDropWindow = {}
VRK:RegisterModule("DragDropWindow", DragDropWindow)

local WINDOW_W, WINDOW_H = 600, 400
local MIN_W, MIN_H = 420, 280
local MAX_W, MAX_H = 900, 600
local SECTION_COUNT = 3

local SECTION_CONFIG = {
    { name = "Sell",         listName = "sell",    color = { 0,   1,   0,   0.15 }, headerColor = { 0,   0.7, 0   } },
    { name = "Destroy",      listName = "destroy", color = { 1,   0,   0,   0.15 }, headerColor = { 0.8, 0,   0   } },
    { name = "Always Keep",  listName = "protect", color = { 0,   0.5, 1,   0.15 }, headerColor = { 0,   0.4, 0.8 } },
}

-- ── Public ─────────────────────────────────────────────────────────────────────

function DragDropWindow:OnLoad()
    -- module only, no events to register
end

function DragDropWindow:Toggle()
    if not self.frame then
        self:Create()
        self:RestorePosition()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:RefreshAll()
    end
end

-- ── Create ───────────────────────────────────────────────────────────────────

function DragDropWindow:Create()
    local frame = CreateFrame("Frame", "VRK_DragDropWindow", UIParent)
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetMinResize(MIN_W, MIN_H)
    frame:SetMaxResize(MAX_W, MAX_H)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        tile     = true,
        tileSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.15, 0.98)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.3)

    frame:SetScript("OnSizeChanged", function(self, w, h)
        DragDropWindow:OnResize(w, h)
    end)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function(self)
        self:GetParent():StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function(self)
        local p = self:GetParent()
        p:StopMovingOrSizing()
        DragDropWindow:SavePosition()
    end)

    -- Visual separator under title bar
    local titleSep = titleBar:CreateTexture(nil, "BOTTOM")
    titleSep:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    titleSep:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    titleSep:SetHeight(1)
    titleSep:SetColorTexture(0.5, 0.4, 0.2)

    -- Invisible full-drag overlay on the frame itself (for dragging by clicking anywhere on body)
    local dragOverlay = CreateFrame("Frame", nil, frame)
    dragOverlay:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 4)
    dragOverlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    dragOverlay:EnableMouse(true)
    dragOverlay:RegisterForDrag("LeftButton")
    dragOverlay:SetScript("OnDragStart", function(self)
        self:GetParent():StartMoving()
    end)
    dragOverlay:SetScript("OnDragStop", function(self)
        local p = self:GetParent()
        p:StopMovingOrSizing()
        DragDropWindow:SavePosition()
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("LEFT",   titleBar, "LEFT", 8, 0)
    titleText:SetPoint("RIGHT",  titleBar, "RIGHT", -60, 0)
    titleText:SetText("|cffFFD700VRK|r — Drag Items Here")
    titleText:SetFontObject("GameFontNormal")

    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Resize handle (bottom-right corner)
    local rhandle = CreateFrame("Button", nil, frame)
    rhandle:SetSize(16, 16)
    rhandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, -2)
    rhandle:EnableMouse(true)
    rhandle:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollBarButton-Up")
    rhandle:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    rhandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        DragDropWindow:SavePosition()
    end)

    -- Three sections
    self.sections = {}
    local innerW = WINDOW_W - 16
    local sectionW = (innerW - 12) / SECTION_COUNT

    for i, config in ipairs(SECTION_CONFIG) do
        local section = self:CreateSection(frame, config, i, sectionW)
        self.sections[i] = section
    end

    self:LayoutSections()
    self.frame = frame
end

-- ── Section ──────────────────────────────────────────────────────────────────

function DragDropWindow:CreateSection(parent, config, index, width)
    local section = CreateFrame("Frame", nil, parent)
    section:SetWidth(width)
    section.config = config
    section.listName = config.listName

    section:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\UI-Silver-Button-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    section:SetBackdropColor(unpack(config.color))
    section:SetBackdropBorderColor(unpack(config.headerColor))

    -- Colored header strip
    local header = section:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT",   section, "TOPLEFT")
    header:SetPoint("TOPRIGHT",  section, "TOPRIGHT")
    header:SetHeight(22)
    header:SetColorTexture(unpack(config.headerColor))

    local headerText = section:CreateFontString(nil, "BORDER")
    headerText:SetPoint("CENTER", header, "CENTER", 0, 0)
    headerText:SetText(config.name)
    headerText:SetFontObject("GameFontNormal")

    -- Drag receive
    section:EnableMouse(true)
    section:RegisterForDrag("LeftButton")
    section:SetScript("OnReceiveDrag", function(self)
        DragDropWindow:OnDrop(self)
    end)
    section:SetScript("OnEnter", function(self)
        DragDropWindow:OnDragEnter(self)
    end)
    section:SetScript("OnLeave", function(self)
        DragDropWindow:OnDragLeave(self)
    end)

    -- Scrollable content
    local scrollFrame = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",   section, "TOPLEFT",   6, -26)
    scrollFrame:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -24, 30)
    section.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 1)
    scrollFrame:SetScrollChild(content)
    section.content = content
    section.rows = {}

    -- Keep content width synced with scrollFrame
    scrollFrame:HookScript("OnSizeChanged", function(sf)
        if content then content:SetWidth(sf:GetWidth()) end
    end)

    -- Bottom bar: count + clear
    local bottom = CreateFrame("Frame", nil, section)
    bottom:SetPoint("BOTTOMLEFT",  section, "BOTTOMLEFT",  4, 4)
    bottom:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -4, 4)
    bottom:SetHeight(22)

    local countLabel = bottom:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("LEFT",   bottom, "LEFT",   2, 0)
    countLabel:SetTextColor(0.8, 0.8, 0.8)
    countLabel:SetText("0 items")
    section.countLabel = countLabel

    local clearBtn = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
    clearBtn:SetSize(55, 18)
    clearBtn:SetPoint("RIGHT", bottom, "RIGHT", -2, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        local Lists = VRK:GetModule("Lists")
        if Lists then Lists:Clear(config.listName) end
        DragDropWindow:RefreshSection(index)
    end)
    section.clearBtn = clearBtn

    return section
end

-- ── Drop handlers ─────────────────────────────────────────────────────────────

function DragDropWindow:OnDrop(section)
    local infoType, itemLink = GetCursorInfo()
    if infoType ~= "item" or not itemLink then return end
    local Lists = VRK:GetModule("Lists")
    if not Lists then return end
    local ok, err = Lists:Add(section.listName, itemLink)
    if ok then
        VRK:Print("Added to " .. section.config.name .. ": " .. itemLink)
    else
        VRK:Print(err)
    end
    local sectionIndex
    for i, s in ipairs(self.sections) do
        if s == section then sectionIndex = i; break end
    end
    if sectionIndex then self:RefreshSection(sectionIndex) end
end

function DragDropWindow:OnDragEnter(section)
    section:SetBackdropBorderColor(1, 1, 1, 0.8)
end

function DragDropWindow:OnDragLeave(section)
    local c = section.config.headerColor
    section:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

-- ── Layout ────────────────────────────────────────────────────────────────────

function DragDropWindow:LayoutSections()
    if not self.frame then return end
    local innerW = self.frame:GetWidth() - 16
    local totalH  = self.frame:GetHeight() - 60
    local sectionW = (innerW - 12) / SECTION_COUNT
    for i, section in ipairs(self.sections) do
        local x = (i - 1) * (sectionW + 6) + 6
        section:ClearAllPoints()
        section:SetSize(sectionW, totalH)
        section:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -36)
    end
end

function DragDropWindow:OnResize(w, h)
    self:LayoutSections()
end

function DragDropWindow:SavePosition()
    if not self.frame then return end
    local s = VRK:S()
    if not s.dragDropWindow then s.dragDropWindow = {} end
    local f = self.frame
    local scale = f:GetEffectiveScale()
    s.dragDropWindow.x = f:GetLeft()   * scale
    s.dragDropWindow.y = f:GetTop()    * scale
    s.dragDropWindow.w = f:GetWidth()
    s.dragDropWindow.h = f:GetHeight()
end

function DragDropWindow:RestorePosition()
    local f = self.frame
    local s = VRK:S().dragDropWindow
    if s then
        if s.w and s.h then f:SetSize(s.w, s.h) end
        if s.x and s.y then
            local scale = f:GetEffectiveScale()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x / scale, s.y / scale)
        end
    end
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

function DragDropWindow:RefreshSection(index)
    local section = self.sections[index]
    if not section then return end
    local Lists = VRK:GetModule("Lists")
    if not Lists then return end
    local items = Lists:GetAll(section.listName)
    local sorted = {}
    for itemID, data in pairs(items) do
        table.insert(sorted, { itemID = itemID, data = data })
    end
    table.sort(sorted, function(a, b) return (a.data.name or "") < (b.data.name or "") end)

    for i = #section.rows + 1, #sorted do
        section.rows[i] = self:CreateRow(section.content, i, section)
    end
    for i = #sorted + 1, #section.rows do
        section.rows[i]:Hide()
    end
    for i, entry in ipairs(sorted) do
        self:PopulateRow(section.rows[i], entry.itemID, entry.data)
        section.rows[i]:Show()
    end
    local contentW = section.scrollFrame:GetWidth() or 200
    section.content:SetHeight(math.max(1, #sorted * 20))
    section.content:SetWidth(contentW)
    section.countLabel:SetText(#sorted .. " item" .. (#sorted == 1 and "" or "s"))
end

function DragDropWindow:RefreshAll()
    for i = 1, SECTION_COUNT do
        self:RefreshSection(i)
    end
end

-- ── Row ───────────────────────────────────────────────────────────────────────

function DragDropWindow:CreateRow(parent, index, section)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth() or 100, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * 20)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.3)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT",   icon,   "RIGHT", 4, 0)
    nameText:SetPoint("RIGHT",  row,    "RIGHT", -2, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.itemID then
            local Lists = VRK:GetModule("Lists")
            if Lists then Lists:Remove(section.listName, self.itemID) end
            local sectionIndex
            for i, s in ipairs(DragDropWindow.sections) do
                if s == section then sectionIndex = i; break end
            end
            if sectionIndex then DragDropWindow:RefreshSection(sectionIndex) end
        end
    end)

    return row
end

function DragDropWindow:PopulateRow(row, itemID, data)
    row.itemID   = itemID
    row.itemLink = data.link
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(data.link or "")
    row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetText(data.name or GetItemInfo(data.link or "") or ("Item #" .. itemID))
end