-- ui/HistoryPanel.lua
HistoryPanel = {}
HistoryPanel.__index = HistoryPanel
VRK:RegisterModule("HistoryPanel", HistoryPanel)

local ACTION_COLOR = {
    SOLD      = "|cff00ff00SOLD     |r",
    DESTROYED = "|cffff0000DESTROYED|r",
    ROLLED    = "|cff00ccffROLLED   |r",
}

function HistoryPanel:New(parent)
    local obj = setmetatable({}, { __index = HistoryPanel })
    obj._rows = {}
    obj:Build(parent)
    return obj
end

function HistoryPanel:Build(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     8,  -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 36)
    self.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 1)
    scrollFrame:SetScrollChild(content)
    self.content = content

    scrollFrame:HookScript("OnSizeChanged", function(sf)
        if self.content then self.content:SetWidth(sf:GetWidth()) end
    end)

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
    clearBtn:SetText("Clear History")
    clearBtn:SetScript("OnClick", function()
        if VRK.db then VRK.db.char.history = {} end
        VRK:SendMessage("VRK_HISTORY_ADDED")
    end)

    self.countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.countLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 10)
    self.countLabel:SetTextColor(0.6, 0.6, 0.6)
end

function HistoryPanel:Refresh()
    local history = (VRK.db and VRK.db.char.history) or {}
    local ROW_H   = 18

    for i = #self._rows + 1, #history do
        local row = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -(i - 1) * ROW_H)
        row:SetJustifyH("LEFT")
        row:SetWidth(self.content:GetWidth() - 8)
        self._rows[i] = row
    end
    for i = #history + 1, #self._rows do
        self._rows[i]:SetText("")
    end

    for i, entry in ipairs(history) do
        local t   = date("%H:%M", entry.timestamp)
        local col = ACTION_COLOR[entry.action] or (entry.action .. "  ")
        local val = (entry.value and entry.value > 0)
            and ("  " .. GetCoinTextureString(entry.value))
            or ""
        self._rows[i]:SetText(
            string.format("[%s]  %s  %s%s", t, col, entry.link or "?", val)
        )
    end

    self.content:SetHeight(math.max(1, #history * ROW_H))
    if self.countLabel then
        self.countLabel:SetText(#history .. " / " .. (VRK:S().historyMaxEntries or 200))
    end
end
