-- ForeverBis : bouton de la minicarte (même modèle que ForeverEgo).
-- Clic gauche : ouvrir / fermer. Clic droit : B.I.S niveau 60. Glisser : déplacer.
local _, ns = ...

local LOGO = "Interface\\AddOns\\ForeverBis\\Media\\Logo"
local button

local function Settings()
    ForeverBisDB.minimap = ForeverBisDB.minimap or {}
    local s = ForeverBisDB.minimap
    if s.angle == nil then s.angle = 200 end
    if s.hide == nil then s.hide = false end
    return s
end

local function Place()
    local angle = math.rad(Settings().angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    if not button then return end
    if Settings().hide then button:Hide() else button:Show() end
end

function ns.CreateMinimapButton()
    if button or not Minimap then return end
    local b = CreateFrame("Button", "ForeverBisMinimapButton", Minimap)
    button = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 5, -4)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture(LOGO)
    icon:SetPoint("TOPLEFT", 7, -6)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if ns.ShowUI then ns.ShowUI(60) end
        elseif ns.ToggleUI then
            ns.ToggleUI()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            Settings().angle = math.deg(math.atan2(cy - my, cx - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff33ccffForeverBis|r")
        GameTooltip:AddLine("Clic gauche : ouvrir / fermer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : B.I.S niveau 60", 1, 1, 1)
        GameTooltip:AddLine("Glisser : déplacer le bouton", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Place()
    ns.UpdateMinimapButton()
end

function ns.ToggleMinimapButton()
    local s = Settings()
    s.hide = not s.hide
    if not s.hide and not button then ns.CreateMinimapButton() end
    ns.UpdateMinimapButton()
    return not s.hide
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if ForeverBisDB then ns.CreateMinimapButton() end
end)
