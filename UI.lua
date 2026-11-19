-- ForeverBis : fenêtre des B.I.S (/fbis).
local ADDON, ns = ...

local GOLD = { 1, 0.82, 0 }
local ROW_H = 26
local W, H = 780, 770

local frame, rows, specButtons, checks
local viewLevel -- nil = niveau du personnage

local function Backdrop(f, alpha)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, alpha or 0.95)
    f:SetBackdropBorderColor(0.8, 0.65, 0.2, 0.9)
end

local function Text(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = fs:GetFont()
    fs:SetFont(font, size or 12, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Button(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h or 22)
    Backdrop(b, 0.9)
    b:SetBackdropColor(0.12, 0.12, 0.15, 1)
    b.text = Text(b, 12, 1, 0.82, 0)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.25, 0.2, 0.08, 1) end)
    b:SetScript("OnLeave", function(self)
        if self.selected then self:SetBackdropColor(0.35, 0.27, 0.05, 1)
        else self:SetBackdropColor(0.12, 0.12, 0.15, 1) end
    end)
    function b:SetSelected(v)
        self.selected = v
        if v then self:SetBackdropColor(0.35, 0.27, 0.05, 1) else self:SetBackdropColor(0.12, 0.12, 0.15, 1) end
    end
    return b
end

local function Check(parent, label, key, tip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    local t = Text(parent, 12, 0.9, 0.9, 0.9)
    t:SetPoint("LEFT", c, "RIGHT", 2, 0)
    t:SetText(label)
    c.label = t
    c:SetScript("OnClick", function(self)
        ForeverBisDB.options[key] = self:GetChecked() and true or false
        ns.InvalidateBis()
    end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(label, 1, 0.82, 0)
        GameTooltip:AddLine(tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", GameTooltip_Hide)
    c.key = key
    return c
end

local function ItemDisplay(id)
    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, _, _, _, _, _, _, icon = ns.Safe(GetInfo, id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local _, _, _, _, ic = ns.Safe(GetInstant, id)
        return "|cffaaaaaa" .. (ns.NAMES[id] or ("objet " .. id)) .. "|r", ic or 134400, nil
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local hex = color and color.hex or "|cffffffff"
    return hex .. name .. "|r", icon, link
end

local function ShowItemTooltip(self)
    if not self.itemId then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemId)
    local e = self.entry
    if e then
        local function altLines(title, list)
            if not list or #list == 0 then return end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(title, 1, 0.82, 0)
            for i, a in ipairs(list) do
                local name = ItemDisplay(a.id)
                local pct = e.score > 0 and (a.score / e.score * 100) or 0
                GameTooltip:AddDoubleLine(i .. ". " .. name, string.format("%.0f%%", pct), 1, 1, 1, 0.7, 0.7, 0.7)
                GameTooltip:AddLine("    " .. ns.SourceText(a.id, true), 1, 1, 1)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Source : " .. ns.SourceText(self.itemId), 1, 1, 1, true)
        altLines("Alternatives", e.alts)
        altLines("Meilleures armes à une main", e.altsMH)
        altLines("Meilleures armes à deux mains", e.alts2H)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Maj+clic : lien dans le chat", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function CreateRow(parent, i)
    local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * (ROW_H + 2))
    r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(i - 1) * (ROW_H + 2))
    r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    r:SetBackdropColor(1, 1, 1, i % 2 == 0 and 0.04 or 0.02)

    r.slot = Text(r, 12, 0.8, 0.8, 0.8)
    r.slot:SetPoint("LEFT", 6, 0)
    r.slot:SetWidth(90)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW_H - 4, ROW_H - 4)
    r.icon:SetPoint("LEFT", 100, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.name = Text(r, 12)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetWidth(240)

    r.source = Text(r, 11, 0.85, 0.85, 0.85)
    r.source:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.source:SetWidth(250)

    r.status = Text(r, 12)
    r.status:SetPoint("RIGHT", -8, 0)
    r.status:SetWidth(80)
    r.status:SetJustifyH("RIGHT")

    r:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 0.82, 0, 0.12)
        ShowItemTooltip(self)
    end)
    r:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, i % 2 == 0 and 0.04 or 0.02)
        GameTooltip:Hide()
    end)
    r:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick("CHATLINK") then
            local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
            if insert then insert(self.link) end
        end
    end)
    return r
end

local function CurrentLevel()
    return viewLevel or UnitLevel("player") or 1
end

function ns.RefreshUI()
    if not (frame and frame:IsShown()) then return end
    local ctx = ns.Context()
    local level = CurrentLevel()
    local res = ns.ComputeBis(level, ctx.spec)
    local spec = ns.GetSpec(ctx.class, ctx.spec)
    local cname = UnitClass("player")

    local pts = ns.TalentPointsText()
    local mode = ctx.specMode == "manuel" and "spé choisie à la main"
        or (pts and ("talents " .. pts) or "aucun talent : spé par défaut")
    frame.sub:SetText(string.format("%s %s - %s  |cff888888(%s, %s)|r", cname or "", ns.SpecDisplayName(ctx.class, ctx.spec),
        level >= 60 and "|cffffcc00Niveau 60|r" or ("Niveau " .. level), ctx.faction or "", mode))
    frame.levelText:SetText(level)
    frame.btnNow:SetSelected(viewLevel == nil)
    frame.btn60:SetSelected(viewLevel == 60 and (UnitLevel("player") or 1) < 60)

    local curTree = ns.TreeOf(ctx.class, ctx.spec)
    for _, b in ipairs(specButtons) do
        b.text:SetText(ns.TreeName(ctx.class, b.tree))
        b:SetWidth(b.text:GetStringWidth() + 20)
        b:SetSelected(b.tree == curTree)
    end
    local showVariants = false
    for _, b in ipairs(frame.variantButtons) do
        b:SetShown(b.tree == curTree)
        b:SetSelected(b.key == ctx.spec)
        if b.tree == curTree then showVariants = true end
    end
    frame.variantLbl:SetShown(showVariants)
    frame.btnAuto:SetSelected(ctx.specMode == "auto")

    local w, src = ns.GetWeights(ctx.class, ctx.spec, level)
    local list = w and ns.StatPriority(w, spec and spec.role) or {}
    local parts = {}
    for i = 1, math.min(7, #list) do parts[i] = list[i].label end
    frame.prio:SetText("|cffffd100Priorité des stats :|r " .. (#parts > 0 and table.concat(parts, " |cff888888>|r ") or "?")
        .. "  |cff888888(survoler)|r")
    frame.prioInfo = { list = list, src = src, specName = ns.SpecDisplayName(ctx.class, ctx.spec), level = level,
        points = ns.TalentPointsText(), mods = ns.TalentMods(ctx.class, ctx.spec) }
    for _, c in ipairs(checks) do c:SetChecked(ForeverBisDB.options[c.key]) end

    local nOk, nTotal = 0, 0
    for i, s in ipairs(ns.SLOTS) do
        local row = rows[i]
        local e = res[s.id]
        row.slot:SetText(ns.SlotName(s.id))
        row.entry = e
        if e then
            local name, icon, link = ItemDisplay(e.id)
            row.itemId, row.link = e.id, link
            row.icon:SetTexture(icon)
            row.icon:Show()
            row.name:SetText(name .. (e.note and ("  |cff888888(" .. e.note .. ")|r") or ""))
            row.source:SetText(ns.SourceText(e.id, true))
            nTotal = nTotal + 1
            if ns.IsEquipped(e.id) then
                row.status:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t |cff00ff00Équipé|r")
                nOk = nOk + 1
            else
                local r = ns.GetItem(e.id)
                local need = ns.ObtainLevel(e.id) or (r and r.req) or 0
                if need > (UnitLevel("player") or 1) then
                    row.status:SetText("|cffff9933niv. " .. need .. "|r")
                else
                    local cur = ns.EquippedScore(ns.INV_GROUP[r and r.inv or 0] or "HEAD", level)
                    if cur > 0 then
                        row.status:SetText(string.format("|cff66ff66+%.0f%%|r", math.max(0, (e.score - cur) / cur * 100)))
                    else
                        row.status:SetText("|cff66ff66à prendre|r")
                    end
                end
            end
        else
            row.itemId, row.link = nil, nil
            row.icon:Hide()
            if s.id == 17 and res[16] and res[16].note == "2M" then
                row.name:SetText("|cff888888(arme à deux mains)|r")
            else
                row.name:SetText("|cff888888-|r")
            end
            row.source:SetText("")
            row.status:SetText("")
        end
    end
    frame.summary:SetText(string.format("B.I.S équipés : |cff00ff00%d|r / %d", nOk, nTotal))
end

ns.OnBisChanged = function() ns.RefreshUI() end

local function Build()
    frame = CreateFrame("Frame", "ForeverBisFrame", UIParent, "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ForeverBisDB.point = { p, rp, x, y }
    end)
    Backdrop(frame)
    tinsert(UISpecialFrames, "ForeverBisFrame")
    if ForeverBisDB.point then
        local p = ForeverBisDB.point
        frame:ClearAllPoints()
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(44, 44)
    logo:SetPoint("TOPLEFT", 10, -8)
    logo:SetTexture("Interface\\AddOns\\ForeverBis\\Media\\Logo")
    local title = Text(frame, 20, GOLD[1], GOLD[2], GOLD[3])
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 6, -4)
    title:SetText("ForeverBis |cff888888v" .. ns.Version() .. "|r")

    frame.sub = Text(frame, 13, 0.9, 0.9, 0.9)
    frame.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- spécialisation
    local _, classFile = UnitClass("player")
    specButtons = {}
    local lbl = Text(frame, 12, 0.8, 0.8, 0.8)
    lbl:SetPoint("TOPLEFT", 14, -62)
    lbl:SetText("Spécialisation :")
    frame.btnAuto = Button(frame, "Auto (talents)", 10, 22, function()
        ns.ChooseSpec(classFile, nil)
    end)
    frame.btnAuto:SetWidth(frame.btnAuto.text:GetStringWidth() + 20)
    frame.btnAuto:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    frame.btnAuto:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Spécialisation automatique", 1, 0.82, 0)
        GameTooltip:AddLine("La spé suit la branche de talents où tu as mis le plus de points, et change toute seule quand tu changes de jeu de talents (double spé).", 1, 1, 1, true)
        GameTooltip:AddLine("Cliquer sur une spé la force pour ce jeu de talents seulement.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    frame.btnAuto:HookScript("OnLeave", GameTooltip_Hide)
    -- une bouton par branche de talents (nom du jeu), comme la fenêtre des talents
    local prev = frame.btnAuto
    for i, tree in ipairs(ns.TREES[classFile] or {}) do
        local b = Button(frame, tree.name, 10, 22, function()
            if i == ns.DominantBranch() then
                ns.ChooseSpec(classFile, nil) -- la branche de tes talents : mode automatique
            else
                local cur = ns.Context().spec
                local keep = ns.TreeOf(classFile, cur) == i and cur or tree.specs[1]
                ns.ChooseSpec(classFile, keep)
            end
        end)
        b:SetWidth(b.text:GetStringWidth() + 20)
        b.tree = i
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        prev = b
        specButtons[#specButtons + 1] = b
    end

    -- variantes de calcul d'une branche (Combat farouche : félin ou ours)
    frame.variantButtons = {}
    frame.variantLbl = Text(frame, 12, 0.8, 0.8, 0.8)
    frame.variantLbl:SetPoint("LEFT", prev, "RIGHT", 14, 0)
    frame.variantLbl:SetText("Rôle :")
    local vprev = frame.variantLbl
    for i, tree in ipairs(ns.TREES[classFile] or {}) do
        for j, key in ipairs(tree.variants and tree.specs or {}) do
            local b = Button(frame, tree.variants[j], 10, 22, function() ns.ChooseSpec(classFile, key) end)
            b:SetWidth(b.text:GetStringWidth() + 20)
            b:SetPoint("LEFT", vprev, "RIGHT", vprev == frame.variantLbl and 6 or 4, 0)
            b.key, b.tree = key, i
            vprev = b
            frame.variantButtons[#frame.variantButtons + 1] = b
        end
    end

    -- priorité des stats (survol : détail des poids, origine, talents pris en compte)
    local prio = CreateFrame("Frame", nil, frame)
    prio:SetPoint("TOPLEFT", 14, -118)
    prio:SetPoint("TOPRIGHT", -14, -118)
    prio:SetHeight(16)
    prio:EnableMouse(true)
    frame.prio = Text(prio, 12, 0.9, 0.9, 0.9)
    frame.prio:SetPoint("LEFT")
    frame.prio:SetPoint("RIGHT")
    prio:SetScript("OnEnter", function(self)
        local info = frame.prioInfo
        if not info then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Priorité des stats - " .. info.specName .. ", niveau " .. info.level, 1, 0.82, 0)
        GameTooltip:AddLine("Valeur d'un point de chaque stat (le toucher et le critique sont en %).", 0.7, 0.7, 0.7, true)
        for i, p in ipairs(info.list) do
            GameTooltip:AddDoubleLine(i .. ". " .. p.label, string.format("%.2f", p.value), 1, 1, 1, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Poids : " .. (info.src or "?"), 0.6, 0.8, 1, true)
        GameTooltip:AddLine("Talents : " .. (info.points or "aucun point"), 0.6, 0.8, 1)
        if #info.mods > 0 then
            for _, m in ipairs(info.mods) do GameTooltip:AddLine("  pris en compte : " .. m.label, 0.6, 1, 0.6) end
        end
        GameTooltip:Show()
    end)
    prio:SetScript("OnLeave", GameTooltip_Hide)

    -- niveau
    local lvlLbl = Text(frame, 12, 0.8, 0.8, 0.8)
    lvlLbl:SetPoint("TOPLEFT", 14, -94)
    lvlLbl:SetText("B.I.S pour le niveau :")
    local minus = Button(frame, "<", 24, 22, function()
        viewLevel = math.max(1, CurrentLevel() - 1)
        ns.RefreshUI()
    end)
    minus:SetPoint("LEFT", lvlLbl, "RIGHT", 8, 0)
    frame.levelText = Text(frame, 14, 1, 1, 1)
    frame.levelText:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    frame.levelText:SetWidth(24)
    frame.levelText:SetJustifyH("CENTER")
    local plus = Button(frame, ">", 24, 22, function()
        viewLevel = math.min(60, CurrentLevel() + 1)
        ns.RefreshUI()
    end)
    plus:SetPoint("LEFT", frame.levelText, "RIGHT", 6, 0)
    frame.btnNow = Button(frame, "Mon niveau", 100, 22, function()
        viewLevel = nil
        ns.RefreshUI()
    end)
    frame.btnNow:SetPoint("LEFT", plus, "RIGHT", 12, 0)
    frame.btn60 = Button(frame, "Niveau 60 (fin de jeu)", 160, 22, function()
        viewLevel = 60
        ns.RefreshUI()
    end)
    frame.btn60:SetPoint("LEFT", frame.btnNow, "RIGHT", 4, 0)

    -- en-têtes
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", 10, -150)
    list:SetPoint("TOPRIGHT", -10, -150)
    list:SetHeight(#ns.SLOTS * (ROW_H + 2))
    local function header(text, x)
        local h = Text(frame, 11, GOLD[1], GOLD[2], GOLD[3])
        h:SetPoint("BOTTOMLEFT", list, "TOPLEFT", x, 4)
        h:SetText(text)
    end
    header("Emplacement", 6)
    header("Objet B.I.S", 100)
    header("Où l'obtenir", 374)
    local hs = Text(frame, 11, GOLD[1], GOLD[2], GOLD[3])
    hs:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", -8, 4)
    hs:SetText("Statut")

    rows = {}
    for i = 1, #ns.SLOTS do rows[i] = CreateRow(list, i) end

    frame.summary = Text(frame, 12, 0.9, 0.9, 0.9)
    frame.summary:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 6, -8)

    -- options
    checks = {}
    local opts = {
        { "Artisanat", "crafts", "Inclure les objets fabriqués par les métiers." },
        { "Drops rares (< 5 %)", "rareDrops", "Inclure les objets qui tombent rarement sur des monstres du monde." },
        { "Raids", "raids", "Inclure le stuff de raid obtenu par quête, drop ou métier (Onyxia, Zul'Gurub, Ahn'Qiraj, Naxxramas...). Les loots de boss de raid ne sont pas dans les données." },
        { "JcJ", "pvp", "Inclure les récompenses des champs de bataille (Alterac, Goulet, Arathi)." },
        { "Sans source connue", "unsourced", "Inclure les objets dont l'origine n'est pas connue sur Forever (raids, BoE mondiaux, PvP...). Certains peuvent ne pas exister sur Forever." },
        { "Infos dans les bulles", "tooltip", "Afficher B.I.S dans la bulle des objets (sacs, butin, hôtel des ventes, liens...)." },
        { "Comparer à l'équipé", "tooltipUpgrade", "Afficher dans la bulle le gain ou la perte par rapport à l'objet porté." },
    }
    for i, o in ipairs(opts) do
        local c = Check(frame, o[1], o[2], o[3])
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        c:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14 + col * 190, 40 - row * 26)
        checks[#checks + 1] = c
    end

    -- qualité minimale
    local q = Button(frame, "", 140, 22, function(self)
        local v = ForeverBisDB.options.minQuality + 1
        if v > 4 then v = 1 end
        ForeverBisDB.options.minQuality = v
        ns.InvalidateBis()
    end)
    q:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 72)
    local QN = { [1] = "|cffffffffBlanc|r", [2] = "|cff1eff00Vert|r", [3] = "|cff0070ddBleu|r", [4] = "|cffa335eeÉpique|r" }
    local origRefresh = ns.RefreshUI
    ns.RefreshUI = function()
        q.text:SetText("Qualité min. : " .. (QN[ForeverBisDB.options.minQuality] or "?"))
        origRefresh()
    end

    local note = Text(frame, 10, 0.55, 0.55, 0.55)
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 74)
    note:SetWidth(W - 190)
    note:SetWordWrap(true)
    note:SetText("Classement par poids de caractéristiques selon la spécialisation. Survole un objet pour voir sa source et les alternatives.")
end

function ns.ShowUI(level)
    if not frame then Build() end
    viewLevel = level and math.max(1, math.min(60, level)) or nil
    frame:Show()
    ns.RefreshUI()
end

function ns.ToggleUI()
    if frame and frame:IsShown() then frame:Hide() else ns.ShowUI() end
end
