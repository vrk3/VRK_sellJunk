-- modules/Export.lua
local Export = {}
VRK:RegisterModule("Export", Export)

-- Serialize all lists to VRK:v1:sell:id,id|destroy:id|protect:id
function Export:Serialize()
    local Lists = VRK:GetModule("Lists")
    local parts = {}

    for _, listName in ipairs({ "sell", "destroy", "protect" }) do
        local ids = {}
        for itemID, _ in pairs(Lists:GetAll(listName)) do
            table.insert(ids, tostring(itemID))
        end
        if #ids > 0 then
            table.sort(ids)
            table.insert(parts, listName .. ":" .. table.concat(ids, ","))
        end
    end

    return "VRK:v1:" .. (#parts > 0 and table.concat(parts, "|") or "")
end

-- Parse and merge a VRK:v1: string into current lists
function Export:Deserialize(str)
    if type(str) ~= "string" or not str:match("^VRK:v1:") then
        VRK:Print("Invalid import string. Expected: VRK:v1:sell:id,id|destroy:id|protect:id")
        return
    end

    local Lists   = VRK:GetModule("Lists")
    local payload = str:sub(8)
    if payload == "" then
        VRK:Print("Import string is empty.")
        return
    end

    local imported = 0
    for segment in (payload .. "|"):gmatch("([^|]+)|") do
        local listName, idStr = segment:match("^(%a+):(.+)$")
        if listName and idStr
            and (listName == "sell" or listName == "destroy" or listName == "protect")
        then
            for idPart in (idStr .. ","):gmatch("([^,]+),") do
                local itemID = tonumber(idPart)
                if itemID then
                    local fakeLink = "item:" .. itemID .. ":0:0:0:0:0:0:0"
                    local db = Lists:GetDB()
                    if not db[listName][itemID] then
                        db[listName][itemID] = {
                            name    = GetItemInfo(fakeLink) or ("Item #" .. itemID),
                            link    = fakeLink,
                            addedAt = time(),
                        }
                        imported = imported + 1
                    end
                end
            end
        end
    end

    VRK:SendMessage("VRK_LIST_CHANGED", "all")
    VRK:Print("Imported " .. imported .. " items.")
end

-- Show a popup EditBox with the serialized string, pre-selected for copy
function Export:ShowPopup()
    local str = self:Serialize()

    if Export._popup and Export._popup:IsShown() then
        Export._popup.editBox:SetText(str)
        Export._popup.editBox:HighlightText()
        return
    end

    local frame = CreateFrame("Frame", "VRK_ExportPopup", UIParent)
    frame:SetSize(600, 180)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        tile     = true,
        tileSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

    local titleText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("TOP", frame, "TOP", 0, -8)
    titleText:SetText("|cffFFD700VRK Export|r — Ctrl+A, Ctrl+C to copy")

    local editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetPoint("TOPLEFT",     frame, "TOPLEFT",     12, -30)
    editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 40)
    editBox:SetMultiLine(false)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetMaxLetters(0)
    editBox:SetText(str)
    editBox:HighlightText()
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.editBox = editBox

    local bg = editBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(editBox)
    bg:SetTexture(0, 0, 0, 0.6)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    Export._popup = frame
    frame:Show()
end
