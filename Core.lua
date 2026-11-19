-- ForeverBis : calcule les B.I.S (Best in Slot) du personnage, au niveau actuel
-- (leveling) et au niveau 60, et les signale dans les bulles d'objets.
--
-- Données : Data/Items.lua (stats) et Data/Sources.lua (où trouver chaque objet),
-- générées par Tools/build-data.js. Les objets Forever absents de ces fichiers
-- sont lus en jeu (C_Item.GetItemStats) puis gardés dans ForeverBisDB.cache.
local ADDON, ns = ...

local DEFAULTS = {
    tooltip = true,      -- lignes ForeverBis dans les bulles d'objets
    tooltipUpgrade = true, -- comparaison avec l'objet équipé
    unsourced = false,   -- objets sans source connue (raids, BoE mondiaux, PvP...)
    crafts = true,       -- objets d'artisanat
    rareDrops = false,   -- drops mondiaux < 5 %
    raids = false,       -- contenu de raid (Onyxia, ZG, AQ, Naxx...)
    pvp = false,         -- récompenses de champs de bataille
    minQuality = 2,      -- 1 = blanc, 2 = vert, 3 = bleu, 4 = violet
}

local PREFIX = "|cff33ccffForeverBis|r : "
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t "
ns.STAR = STAR
function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

function ns.Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return (get and get(ADDON, "Version")) or "?"
end

local function Safe(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and issecretvalue(a) then return nil end
    return a, b, c, d, e, f, g, h, i, j, k, l, m, n
end
ns.Safe = Safe

---------------------------------------------------------------------------
-- Emplacements
---------------------------------------------------------------------------
-- type d'inventaire -> groupe
local INV_GROUP = {
    [1] = "HEAD", [2] = "NECK", [3] = "SHOULDER", [5] = "CHEST", [20] = "CHEST", [6] = "WAIST", [7] = "LEGS",
    [8] = "FEET", [9] = "WRIST", [10] = "HANDS", [11] = "FINGER", [12] = "TRINKET", [16] = "BACK",
    [13] = "ONEHAND", [21] = "MAINHAND", [17] = "TWOHAND", [22] = "OFFHANDW", [14] = "SHIELD", [23] = "HOLDABLE",
    [15] = "RANGED", [25] = "RANGED", [26] = "RANGED", [28] = "RANGED",
}
ns.INV_GROUP = INV_GROUP

local EQUIPLOC_INV = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 20,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_CLOAK = 16, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
    INVTYPE_RANGED = 15, INVTYPE_2HWEAPON = 17, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
    INVTYPE_HOLDABLE = 23, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28,
}

-- Emplacements affichés, dans l'ordre de la fenêtre. group = groupe d'objets qui y vont.
ns.SLOTS = {
    { id = 1,  global = "HEADSLOT",          fr = "Tête" },
    { id = 2,  global = "NECKSLOT",          fr = "Cou" },
    { id = 3,  global = "SHOULDERSLOT",      fr = "Épaules" },
    { id = 15, global = "BACKSLOT",          fr = "Dos" },
    { id = 5,  global = "CHESTSLOT",         fr = "Torse" },
    { id = 9,  global = "WRISTSLOT",         fr = "Poignets" },
    { id = 10, global = "HANDSSLOT",         fr = "Mains" },
    { id = 6,  global = "WAISTSLOT",         fr = "Taille" },
    { id = 7,  global = "LEGSSLOT",          fr = "Jambes" },
    { id = 8,  global = "FEETSLOT",          fr = "Pieds" },
    { id = 11, global = "FINGER0SLOT",       fr = "Doigt 1", suffix = " 1" },
    { id = 12, global = "FINGER1SLOT",       fr = "Doigt 2", suffix = " 2" },
    { id = 13, global = "TRINKET0SLOT",      fr = "Bijou 1", suffix = " 1" },
    { id = 14, global = "TRINKET1SLOT",      fr = "Bijou 2", suffix = " 2" },
    { id = 16, global = "MAINHANDSLOT",      fr = "Main droite" },
    { id = 17, global = "SECONDARYHANDSLOT", fr = "Main gauche" },
    { id = 18, global = "RANGEDSLOT",        fr = "Distance" },
}
local GROUP_SLOT = {
    HEAD = 1, NECK = 2, SHOULDER = 3, BACK = 15, CHEST = 5, WRIST = 9, HANDS = 10, WAIST = 6, LEGS = 7, FEET = 8,
    FINGER = 11, TRINKET = 13, ONEHAND = 16, MAINHAND = 16, TWOHAND = 16, OFFHANDW = 17, SHIELD = 17,
    HOLDABLE = 17, RANGED = 18,
}
ns.GROUP_SLOT = GROUP_SLOT

function ns.SlotName(slotId)
    for _, s in ipairs(ns.SLOTS) do
        if s.id == slotId then
            local g = _G[s.global]
            if type(g) == "string" and g ~= "" then
                if s.suffix and not g:find("%d") then return g .. s.suffix end
                return g
            end
            return s.fr
        end
    end
    return "?"
end

---------------------------------------------------------------------------
-- Ce que chaque classe peut porter (Classic)
---------------------------------------------------------------------------
-- armure (classe d'objet 4) : sous-classe -> niveau minimum
local ARMOR = {
    WARRIOR = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    PALADIN = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 },
    HUNTER  = { [0] = 1, [1] = 1, [2] = 1, [3] = 40 },
    ROGUE   = { [0] = 1, [1] = 1, [2] = 1 },
    PRIEST  = { [0] = 1, [1] = 1 },
    SHAMAN  = { [0] = 1, [1] = 1, [2] = 1, [3] = 40, [6] = 1, [9] = 1 },
    MAGE    = { [0] = 1, [1] = 1 },
    WARLOCK = { [0] = 1, [1] = 1 },
    DRUID   = { [0] = 1, [1] = 1, [2] = 1, [8] = 1 },
}
-- armes (classe d'objet 2) : 0 hache 1M, 1 hache 2M, 2 arc, 3 fusil, 4 masse 1M, 5 masse 2M, 6 arme d'hast,
-- 7 épée 1M, 8 épée 2M, 10 bâton, 13 arme de pugilat, 15 dague, 16 arme de jet, 18 arbalète, 19 baguette
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPON = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = set(4, 10, 15, 19),
    SHAMAN  = set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID   = set(4, 5, 10, 13, 15),
}
-- ambidextrie : niveau où la classe l'apprend
local DUAL_WIELD = { WARRIOR = 20, ROGUE = 10, HUNTER = 20 }
local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local function CanUse(r, classFile, level)
    if not r then return false end
    if r.allow and r.allow > 0 then
        local cid = CLASS_ID[classFile]
        if not cid or bit.band(r.allow, bit.lshift(1, cid - 1)) == 0 then return false end
    end
    if r.class == 4 then
        local min = ARMOR[classFile] and ARMOR[classFile][r.sub]
        return min ~= nil and level >= min
    elseif r.class == 2 then
        return WEAPON[classFile] and WEAPON[classFile][r.sub] or false
    end
    return false
end
ns.CanUse = CanUse

-- Matériau principal : la meilleure armure (1 tissu, 2 cuir, 3 mailles, 4 plaques) que la classe
-- peut porter à ce niveau. Les pièces d'un matériau inférieur ne sont pas optimisées pour la classe.
local ARMOR_GROUPS = { HEAD = true, SHOULDER = true, CHEST = true, WRIST = true, HANDS = true, WAIST = true, LEGS = true, FEET = true }
local MAT_NAME = { [1] = "tissu", [2] = "cuir", [3] = "mailles", [4] = "plaques" }
ns.MAT_NAME = MAT_NAME
function ns.MainArmor(classFile, level)
    local t = ARMOR[classFile]
    if not t then return 1 end
    for mat = 4, 1, -1 do
        if t[mat] and level >= t[mat] then return mat end
    end
    return 1
end
-- -> matériau de la pièce (1..4) si c'est une pièce d'armure soumise à la règle, sinon nil
local function ArmorMat(r)
    if r and r.class == 4 and r.sub >= 1 and r.sub <= 4 and ARMOR_GROUPS[INV_GROUP[r.inv]] then return r.sub end
    return nil
end
ns.ArmorMat = ArmorMat

---------------------------------------------------------------------------
-- Objets
---------------------------------------------------------------------------
local ALIAS = { mpr = "mp5", hpr = "hp5" }
local parsed = {}

local function ParseString(id, s)
    local inv, ilvl, req, q, cls, sub, rest = s:match("^(%d+) (%d+) (%d+) (%d+) (%d+) (%d+)%s*(.*)$")
    if not inv then return false end
    local r = {
        id = id, inv = tonumber(inv), ilvl = tonumber(ilvl), req = tonumber(req), q = tonumber(q),
        class = tonumber(cls), sub = tonumber(sub), stats = {}, allow = 0,
    }
    local dmin, dmax, speed = 0, 0, nil
    for tok, num in rest:gmatch("(%a+)(%-?%d+)") do
        local key, n = tok, tonumber(num)
        if key == "dmin" then dmin = dmin + n
        elseif key == "dmax" then dmax = dmax + n
        elseif key == "speed" then speed = n
        elseif key == "cls" then r.allow = n
        elseif key == "uniq" then r.unique = true
        else
            key = ALIAS[key] or key
            r.stats[key] = (r.stats[key] or 0) + n
        end
    end
    if speed and speed > 0 and dmax > 0 then
        r.dps = ((dmin + dmax) / 2) / (speed / 1000)
        r.speed = speed / 1000
    end
    return r
end

-- Stats lues sur le client (objets Forever absents des données hors-ligne).
local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi", RESISTANCE0_NAME = "armor",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit", ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_HEALTH_REGEN_SHORT = "hp5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block", ITEM_MOD_SHIELD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
}

-- -> enregistrement construit depuis le client, ou nil si l'objet n'est pas encore chargé
local function FromClient(id, link)
    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, ilink, quality, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = Safe(GetInfo, link or id)
    if not name then return nil end
    local inv = EQUIPLOC_INV[equipLoc or ""]
    if not inv then return false end
    local r = { id = id, inv = inv, ilvl = ilvl or 0, req = reqLevel or 0, q = quality or 1,
                class = classID, sub = subclassID, stats = {}, allow = 0, client = true }
    local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local stats = Safe(GetStats, link or ilink)
    if type(stats) == "table" then
        for k, v in pairs(stats) do
            if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
                r.dps = v
            elseif k == "ITEM_MOD_SPELL_POWER_SHORT" then
                r.stats.sp = (r.stats.sp or 0) + v
                r.stats.heal = (r.stats.heal or 0) + v
            elseif STAT_KEYS[k] then
                local key = STAT_KEYS[k]
                r.stats[key] = (r.stats[key] or 0) + v
            end
        end
    end
    return r
end

-- -> enregistrement de l'objet (stats, niveau requis...) ou nil
function ns.GetItem(id)
    if not id then return nil end
    local r = parsed[id]
    if r ~= nil then return r or nil end
    local s = ns.ITEMS[id]
    if s then
        r = ParseString(id, s)
    elseif ForeverBisDB and ForeverBisDB.cache[id] then
        r = ForeverBisDB.cache[id]
    else
        r = FromClient(id)
        if r == nil then return nil end -- pas encore chargé : on réessaiera
        if r and ns.SOURCES[id] and ForeverBisDB then ForeverBisDB.cache[id] = r end
    end
    parsed[id] = r or false
    return r or nil
end

-- Objets à charger depuis le client (sources connues mais pas de stats hors-ligne)
local pending = {}
local function RequestMissing()
    local n = 0
    for id in pairs(ns.SOURCES) do
        if not ns.ITEMS[id] and not ForeverBisDB.cache[id] and parsed[id] == nil then
            if not ns.GetItem(id) then
                pending[id] = true
                n = n + 1
                if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
            end
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------
local srcCache = {}
-- -> liste { kind, a, b, c, d, e }
function ns.Sources(id)
    local c = srcCache[id]
    if c then return c end
    c = {}
    local s = ns.SOURCES[id]
    if s then
        for part in s:gmatch("[^;]+") do
            local f = {}
            for field in (part .. "|"):gmatch("([^|]*)|") do f[#f + 1] = field end
            c[#c + 1] = f
        end
    end
    srcCache[id] = c
    return c
end

-- Au-delà de ce niveau d'objet, une quête / un drop hors journal de donjon est
-- considéré comme du contenu de raid (Onyxia, ZG, AQ, Naxx...).
local RAID_ILVL = 63
-- Quêtes de champ de bataille (récompenses JcJ)
local PVP_ZONES = { ["Alterac Valley"] = true, ["Alterac Mountains"] = true, ["Warsong Gulch"] = true,
    ["Arathi Basin"] = true, ["Ashenvale"] = false }

-- -> true si la source est accessible au personnage avec les options choisies
local function SourceValid(f, ctx, r)
    local kind = f[1]
    local o = ctx.opts
    if kind == "Q" then
        local side = f[4]
        if side == "A" and ctx.faction == "Horde" then return false end
        if side == "H" and ctx.faction == "Alliance" then return false end
        local mask = tonumber(f[6]) or 0
        if mask > 0 then
            local cid = CLASS_ID[ctx.class]
            if not cid or bit.band(mask, bit.lshift(1, cid - 1)) == 0 then return false end
        end
        if f[8] ~= "J" then
            local qlvl = tonumber(f[3]) or 0
            if not o.pvp and PVP_ZONES[f[5]] and qlvl >= 51 then return false end
            if not o.raids and r and r.ilvl > RAID_ILVL then return false end
        end
        return true
    elseif kind == "C" then
        if not o.crafts then return false end
        if not o.raids and r and r.ilvl > RAID_ILVL then return false end
        return true
    elseif kind == "W" then
        if not o.raids and r and r.ilvl > RAID_ILVL then return false end
        if o.rareDrops then return true end
        return (tonumber(f[4]) or 0) >= 5
    end
    return true
end

-- Niveau à partir duquel la source est réaliste
local function SourceLevel(f)
    local kind = f[1]
    if kind == "Q" then
        local qlvl, req = tonumber(f[3]) or 0, tonumber(f[7]) or 0
        return math.max(req, qlvl - 2)
    elseif kind == "D" then
        local lv = ns.DUNGEON_LEVELS[f[2]]
        return lv and tonumber(lv:match("^(%d+)")) or 0
    end
    return 0
end

-- -> niveau à partir duquel le personnage peut obtenir l'objet, ou nil s'il ne peut pas
local function ObtainLevel(id, ctx, r)
    local src = ns.Sources(id)
    if #src == 0 then
        if not ctx.opts.unsourced then return nil end
        -- l'objet existe-t-il dans le client Forever ?
        local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if Safe(GetInstant, id) == nil then return nil end
        return r.req
    end
    local best
    for _, f in ipairs(src) do
        if SourceValid(f, ctx, r) then
            local l = SourceLevel(f)
            if not best or l < best then best = l end
        end
    end
    if not best then return nil end
    return math.max(best, r.req)
end

-- Niveau effectif de l'objet pour le personnage (pour la bulle "B.I.S au niveau X")
function ns.ObtainLevel(id)
    local r = ns.GetItem(id)
    if not r then return nil end
    return ObtainLevel(id, ns.Context(), r)
end

local SOURCE_ORDER = { D = 1, Q = 2, C = 3, W = 4 }

-- -> texte de la meilleure source ("Donjon : ..."), pour l'affichage
function ns.SourceText(id, short)
    local best
    local ctx = ns.Context()
    for _, f in ipairs(ns.Sources(id)) do
        if SourceValid(f, ctx, ns.GetItem(id)) and (not best or SOURCE_ORDER[f[1]] < SOURCE_ORDER[best[1]]) then best = f end
    end
    if not best then
        if #ns.Sources(id) == 0 then return "|cff888888Source inconnue (raid, BoE, PvP ?)|r" end
        best = ns.Sources(id)[1]
    end
    local k = best[1]
    if k == "D" then
        local boss = best[3]
        if boss == "*" then boss = "trash" elseif boss == "+" then boss = "plusieurs boss" end
        local lv = ns.DUNGEON_LEVELS[best[2]]
        if short then return "|cffff9933" .. best[2] .. "|r - " .. boss end
        return "|cffff9933Donjon|r " .. best[2] .. (lv and lv ~= "" and (" (" .. lv .. ")") or "") .. " - " .. boss
    elseif k == "Q" then
        local lv = best[3] ~= "" and (" (niv. " .. best[3] .. ")") or ""
        local zone = best[5] ~= "" and (short and "" or (" - " .. best[5])) or ""
        return "|cffffd100Quête|r " .. best[2] .. lv .. zone
    elseif k == "C" then
        return "|cff66ccffArtisanat|r " .. best[2] .. " (" .. best[3] .. ")"
    elseif k == "W" then
        local who = best[2] ~= "" and best[2] or "monstres"
        return "|cffcc99ffDrop|r " .. who .. (best[3] ~= "" and (" - " .. best[3]) or "") .. " (" .. best[4] .. "%)"
    end
    return ""
end

---------------------------------------------------------------------------
-- Score
---------------------------------------------------------------------------
local function BaseScore(r, w)
    local s = 0
    for k, v in pairs(r.stats) do
        local x = w[k]
        if x then s = s + x * v end
    end
    return s
end

-- Vitesse d'arme (poids RXPGuides) : bonus ou malus par seconde d'écart avec une vitesse de référence,
-- limité à la moitié de la valeur du DPS de l'arme.
local REF_SPEED = { mh = 2.0, oh = 1.8, ["2h"] = 3.0, ranged = 2.5 }
local function SpeedTerm(r, weight, hand, dpsValue)
    if not (r.speed and weight and weight ~= 0) then return 0 end
    local v = (r.speed - REF_SPEED[hand]) * weight
    local cap = math.abs(dpsValue) * 0.5
    return math.max(-cap, math.min(cap, v))
end

-- hand : "mh", "oh", "2h" ou nil (le reste)
local function Score(r, w, spec, hand)
    local s = BaseScore(r, w)
    if r.dps then
        local g = INV_GROUP[r.inv]
        if g == "RANGED" then
            if r.class == 2 and r.sub == 19 then s = s + r.dps * (w.wand or 0)
            else
                local d = r.dps * (w.rdps or 0)
                s = s + d + SpeedTerm(r, w.speedRanged, "ranged", d)
            end
        elseif not spec.formWeapons then
            -- talents de spécialisation d'arme : bonus pour ce type d'arme
            local wt = w.wtype and w.wtype[r.sub] or 1
            if hand == "oh" then
                local d = r.dps * (w.ohdps or 0)
                s = s + (d + SpeedTerm(r, w.speedOh, "oh", d)) * wt
            else
                local k = w.dps or 0
                if (spec.daggerMH or w.daggerMH) and hand == "mh" and r.sub ~= 15 then k = k * 0.4 end
                local d = r.dps * k
                local h = hand == "2h" and "2h" or "mh"
                local add = d + SpeedTerm(r, h == "2h" and w.speed2h or w.speedMh, h, d)
                if hand == "2h" then add = add * (w.twoHand or 1) end
                s = s + add * wt
            end
        end
    end
    return s
end

local function HandFor(group)
    if group == "TWOHAND" then return "2h" end
    if group == "ONEHAND" or group == "MAINHAND" then return "mh" end
    if group == "OFFHANDW" then return "oh" end
    return nil
end

---------------------------------------------------------------------------
-- Contexte du personnage
---------------------------------------------------------------------------
function ns.Context()
    local _, classFile = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local spec, specMode, detected = ns.DEFAULT_SPEC[classFile], "auto", nil
    if ForeverBisCharDB and ns.ResolveSpec then spec, specMode, detected = ns.ResolveSpec(classFile) end
    return { class = classFile, faction = faction, spec = spec, specMode = specMode, detected = detected, opts = ForeverBisDB and ForeverBisDB.options or DEFAULTS,
             level = UnitLevel("player") or 1 }
end

---------------------------------------------------------------------------
-- Calcul des B.I.S
---------------------------------------------------------------------------
local allIds
local function AllIds()
    if allIds then return allIds end
    allIds = {}
    for id in pairs(ns.ITEMS) do allIds[#allIds + 1] = id end
    for id in pairs(ns.SOURCES) do
        if not ns.ITEMS[id] then allIds[#allIds + 1] = id end
    end
    return allIds
end

local bisCache = {}
local KEEP = 6

function ns.InvalidateBis()
    wipe(bisCache)
    if ns.OnBisChanged then ns.OnBisChanged() end
end

local function insertTop(list, id, score, max)
    local n = #list
    if n >= max and score <= list[n].score then return end
    local e = { id = id, score = score }
    local pos = n + 1
    for i = 1, n do
        if score > list[i].score then pos = i break end
    end
    table.insert(list, pos, e)
    if #list > max then list[#list] = nil end
end

-- -> { [slotId] = { id, score, alts = { {id, score}... }, note } }, ctx
function ns.ComputeBis(level, specKey)
    local ctx = ns.Context()
    level = math.max(1, math.min(60, level or ctx.level))
    specKey = specKey or ctx.spec
    local o = ctx.opts
    local key = table.concat({ level, specKey, ns.TalentSig and ns.TalentSig() or "", o.unsourced and 1 or 0, o.crafts and 1 or 0, o.rareDrops and 1 or 0, o.raids and 1 or 0, o.pvp and 1 or 0, o.minQuality }, ":")
    if bisCache[key] then return bisCache[key], ctx end

    local spec = ns.GetSpec(ctx.class, specKey)
    local w = spec and ns.GetWeights(ctx.class, specKey, level)
    if not w then return {}, ctx end

    local groups = {}
    local function add(group, id, score)
        local g = groups[group]
        if not g then g = {} groups[group] = g end
        if score > 0 then insertTop(g, id, score, KEEP + 2) end
    end
    local dwLevel = DUAL_WIELD[ctx.class]
    local canDW = dwLevel and level >= dwLevel

    for _, id in ipairs(AllIds()) do
        local r = ns.GetItem(id)
        if r and r.req <= level and r.q >= o.minQuality and r.q <= 5 then
            local group = INV_GROUP[r.inv]
            local need = group and CanUse(r, ctx.class, level) and ObtainLevel(id, ctx, r)
            if need and need <= level then
                if group == "ONEHAND" then
                    add("MH", id, Score(r, w, spec, "mh"))
                    if canDW then add("OH", id, Score(r, w, spec, "oh")) end
                elseif group == "MAINHAND" then
                    add("MH", id, Score(r, w, spec, "mh"))
                elseif group == "OFFHANDW" then
                    if canDW then add("OH", id, Score(r, w, spec, "oh")) end
                elseif group == "SHIELD" or group == "HOLDABLE" then
                    add("OH", id, Score(r, w, spec, nil))
                elseif group == "TWOHAND" then
                    add("2H", id, Score(r, w, spec, "2h"))
                else
                    local mat = ArmorMat(r)
                    add(mat and (group .. "#" .. mat) or group, id, Score(r, w, spec, HandFor(group)))
                end
            end
        end
    end

    -- armure : uniquement le matériau principal de la classe ; on ne descend d'un cran
    -- (ex. mailles au lieu de plaques juste après le niveau 40) que s'il n'existe rien dans ce matériau
    local mainMat = ns.MainArmor(ctx.class, level)
    for g in pairs(ARMOR_GROUPS) do
        for mat = mainMat, 1, -1 do
            local list = groups[g .. "#" .. mat]
            if list and #list > 0 then groups[g] = list break end
        end
    end

    local res = {}
    local function slot(slotId, list, first, note)
        if not list or not list[first] then return end
        local alts = {}
        for i = first + 1, #list do
            if #alts >= KEEP - 1 then break end
            alts[#alts + 1] = list[i]
        end
        res[slotId] = { id = list[first].id, score = list[first].score, alts = alts, note = note }
    end
    for _, g in ipairs({ "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "RANGED" }) do
        slot(GROUP_SLOT[g], groups[g], 1)
    end
    -- anneaux / bijoux : les deux meilleurs (noms différents : souvent "unique")
    for _, g in ipairs({ "FINGER", "TRINKET" }) do
        local list, seen, out = groups[g], {}, {}
        for _, e in ipairs(list or {}) do
            local n = ns.NAMES[e.id] or e.id
            if not seen[n] then seen[n] = true out[#out + 1] = e end
        end
        groups[g] = out
    end
    slot(11, groups.FINGER, 1); slot(12, groups.FINGER, 2)
    slot(13, groups.TRINKET, 1); slot(14, groups.TRINKET, 2)
    if res[12] then res[11].alts = res[12].alts end
    if res[14] then res[13].alts = res[14].alts end

    -- armes : deux mains contre main droite + main gauche
    local mh, oh, two = groups.MH, groups.OH, groups["2H"]
    local mhBest = mh and mh[1]
    local ohBest
    if oh then
        for _, e in ipairs(oh) do
            if not mhBest or e.id ~= mhBest.id then ohBest = e break end
        end
    end
    local combo = (mhBest and mhBest.score or 0) + (ohBest and ohBest.score or 0)
    local twoBest = two and two[1]
    if twoBest and (not mhBest or twoBest.score >= combo) then
        slot(16, two, 1, "2M")
        -- alternatives : les meilleures armes à une main
        if mh then
            res[16].altsMH = {}
            for i = 1, math.min(3, #mh) do res[16].altsMH[i] = mh[i] end
        end
    else
        slot(16, mh, 1)
        if ohBest then
            local list, first = oh, 1
            for i, e in ipairs(oh) do if e == ohBest then first = i break end end
            slot(17, list, first)
        end
        if res[16] and two then
            res[16].alts2H = {}
            for i = 1, math.min(3, #two) do res[16].alts2H[i] = two[i] end
        end
    end

    bisCache[key] = res
    return res, ctx
end

-- -> slotId si l'objet est un B.I.S à ce niveau, sinon nil
function ns.IsBis(id, level, specKey)
    local res = ns.ComputeBis(level, specKey)
    for slotId, e in pairs(res) do
        if e.id == id then return slotId end
    end
    return nil
end

-- Score d'un objet pour le personnage (nil si inutilisable)
function ns.ScoreItem(id, level, link)
    local ctx = ns.Context()
    local r = ns.GetItem(id)
    if not r then return nil end
    level = level or ctx.level
    local spec = ns.GetSpec(ctx.class, ctx.spec)
    local w = spec and ns.GetWeights(ctx.class, ctx.spec, level)
    if not w then return nil end
    local group = INV_GROUP[r.inv]
    if not group then return nil end
    return Score(r, w, spec, HandFor(group)), group, r
end

-- Score de ce qui est porté à la place de cet objet (le plus faible des deux anneaux / bijoux)
function ns.EquippedScore(group, level)
    local slots
    if group == "FINGER" then slots = { 11, 12 }
    elseif group == "TRINKET" then slots = { 13, 14 }
    elseif group == "TWOHAND" then slots = { 16 }
    else slots = { GROUP_SLOT[group] } end
    local worst, worstId
    for _, s in ipairs(slots) do
        local eid = GetInventoryItemID("player", s)
        local sc = 0
        if eid then sc = ns.ScoreItem(eid, level) or 0 end
        if group == "TWOHAND" then
            local oid = GetInventoryItemID("player", 17)
            if oid then sc = sc + (ns.ScoreItem(oid, level) or 0) end
        end
        if not worst or sc < worst then worst, worstId = sc, eid end
    end
    return worst or 0, worstId
end

-- L'objet est-il porté ?
function ns.IsEquipped(id)
    for s = 1, 19 do
        if GetInventoryItemID("player", s) == id then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Bulles d'objets
---------------------------------------------------------------------------
local function SpecName()
    local ctx = ns.Context()
    return ns.SpecDisplayName(ctx.class, ctx.spec)
end

local function AddTooltipLines(tt, id, link)
    if not (ForeverBisDB and ForeverBisDB.options.tooltip) then return end
    local r = ns.GetItem(id)
    if not r then return end
    local group = INV_GROUP[r.inv]
    if not group then return end
    local ctx = ns.Context()
    if not CanUse(r, ctx.class, 60) then return end

    local head = "|cff33ccffForeverBis|r |cff888888(" .. SpecName() .. ")|r"
    local lines = {}
    local now = ns.IsBis(id, ctx.level)
    if now then
        lines[#lines + 1] = { "|cff00ff96"..STAR.."B.I.S actuel|r (niv. " .. ctx.level .. ")", ns.SlotName(now), 0, 1, 0.6 }
    else
        local need = ns.ObtainLevel(id) or r.req
        if need > ctx.level and need < 60 then
            local later = ns.IsBis(id, need)
            if later then
                lines[#lines + 1] = { "|cff66ccff"..STAR.."B.I.S au niveau " .. need .. "|r", ns.SlotName(later), 0.4, 0.8, 1 }
            end
        end
    end
    local at60 = ns.IsBis(id, 60)
    if at60 then
        lines[#lines + 1] = { "|cffffcc00"..STAR.."B.I.S niveau 60|r", ns.SlotName(at60), 1, 0.8, 0 }
    end
    if #lines == 0 then
        lines[#lines + 1] = { "|cff999999Pas ton B.I.S|r", nil }
    end
    local mat = ArmorMat(r)
    local mainNow = ns.MainArmor(ctx.class, ctx.level)
    if mat and mat < mainNow then
        lines[#lines + 1] = { "|cffff9933Matériau non optimisé pour ta classe|r", "à porter : " .. MAT_NAME[mainNow], 1, 0.6, 0.2 }
    end
    if ForeverBisDB.options.tooltipUpgrade and r.req <= ctx.level and not ns.IsEquipped(id) then
        local sc = ns.ScoreItem(id, ctx.level)
        local cur = ns.EquippedScore(group, ctx.level)
        if sc then
            local txt
            if cur <= 0 then
                txt = sc > 0 and "|cff00ff00amélioration (emplacement vide)|r" or nil
            else
                local pct = (sc - cur) / cur * 100
                if pct > 0.5 then txt = string.format("|cff00ff00+%.0f%% vs équipé|r", pct)
                elseif pct < -0.5 then txt = string.format("|cffff5555%.0f%% vs équipé|r", pct)
                else txt = "|cffccccccéquivalent à l'équipé|r" end
            end
            if txt then lines[#lines + 1] = { txt, nil } end
        end
    end

    tt:AddLine(" ")
    tt:AddLine(head)
    for _, l in ipairs(lines) do
        if l[2] then tt:AddDoubleLine(l[1], l[2], 1, 1, 1, 0.8, 0.8, 0.8)
        else tt:AddLine(l[1]) end
    end
end

local function OnTooltipItem(tt, data)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) then return end
    local id = data and data.id
    if issecretvalue and id and issecretvalue(id) then return end
    if not id and tt.GetItem then
        local _, link = Safe(tt.GetItem, tt)
        if link then id = tonumber(link:match("item:(%d+)")) end
    end
    if type(id) ~= "number" then return end
    local ok, err = pcall(AddTooltipLines, tt, id)
    if not ok and ForeverBisDB and ForeverBisDB.debug then ns.Print("erreur bulle : " .. tostring(err)) end
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
    elseif GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt) OnTooltipItem(tt, nil) end)
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", function(tt) OnTooltipItem(tt, nil) end) end
    end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------
local refreshQueued = false
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.5, function()
        refreshQueued = false
        if ns.RefreshUI then ns.RefreshUI() end
    end)
end
ns.QueueRefresh = QueueRefresh

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "ADDON_LOADED" and a1 == ADDON then
        ForeverBisDB = ForeverBisDB or {}
        ForeverBisDB.options = ForeverBisDB.options or {}
        for k, v in pairs(DEFAULTS) do
            if ForeverBisDB.options[k] == nil then ForeverBisDB.options[k] = v end
        end
        -- le cache des objets lus en jeu est vidé à chaque nouveau build du client
        local build = select(2, GetBuildInfo())
        if ForeverBisDB.cacheBuild ~= build then
            ForeverBisDB.cache = {}
            ForeverBisDB.cacheBuild = build
        end
        ForeverBisDB.cache = ForeverBisDB.cache or {}
        ForeverBisCharDB = ForeverBisCharDB or {}
        HookTooltips()
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, function()
            local n = RequestMissing()
            if n > 0 and ForeverBisDB.debug then ns.Print(n .. " objets Forever à charger depuis le client.") end
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        -- UnitLevel n'est pas encore à jour à cet instant
        C_Timer.After(1, function()
            ns.InvalidateBis()
            local lvl = tonumber(a1) or UnitLevel("player")
            local new, old = ns.ComputeBis(lvl), ns.ComputeBis(lvl - 1)
            local n = 0
            for slotId, e in pairs(new) do
                if (not old[slotId] or old[slotId].id ~= e.id) and not ns.IsEquipped(e.id) then n = n + 1 end
            end
            if n > 0 then
                ns.Print("niveau " .. lvl .. " : " .. n .. " nouveau(x) B.I.S disponible(s). |cffffd100/fbis|r pour voir.")
            end
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        QueueRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if a1 and pending[a1] then
            pending[a1] = nil
            parsed[a1] = nil
            if ns.GetItem(a1) then
                wipe(bisCache)
            end
        end
        QueueRefresh()
    end
end)

---------------------------------------------------------------------------
-- Talents : points dépensés, changement de jeu de talents (double spé)
---------------------------------------------------------------------------
local function SpecLabel(key)
    local _, classFile = UnitClass("player")
    return key and ns.SpecDisplayName(classFile, key) or "?"
end

local lastSpec, talentPending
local function OnTalentsChanged(quiet)
    ns.InvalidateTalents()
    ns.ClearWeightCache()
    wipe(bisCache)
    local ctx = ns.Context()
    if lastSpec and ctx.spec ~= lastSpec and not quiet then
        local pts = ns.TalentPointsText()
        ns.Print("spécialisation : |cffffd100" .. SpecLabel(ctx.spec) .. "|r"
            .. (ctx.specMode == "manuel" and " (choisie à la main)" or (pts and (" (talents " .. pts .. ")") or ""))
            .. ". B.I.S recalculés.")
    end
    lastSpec = ctx.spec
    if ns.OnBisChanged then ns.OnBisChanged() end
end
ns.OnTalentsChanged = OnTalentsChanged

local tev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
    "ACTIVE_COMBAT_CONFIG_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
    pcall(tev.RegisterEvent, tev, e)
end
tev:SetScript("OnEvent", function(_, event)
    if not ForeverBisCharDB then return end
    if talentPending then return end
    talentPending = true
    -- plusieurs événements arrivent d'un coup : on attend que l'arbre soit à jour
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 2 or 0.5, function()
        talentPending = false
        OnTalentsChanged(event == "PLAYER_ENTERING_WORLD" and lastSpec == nil)
    end)
end)

local function PrintTalents()
    local _, classFile = UnitClass("player")
    local t = ns.Talents()
    local ctx = ns.Context()
    ns.Print("talents : " .. (ns.TalentPointsText() or "aucun point") .. "  |cff888888(jeu de talents " .. tostring(t.key) .. ")|r")
    ns.Print("spécialisation : |cffffd100" .. SpecLabel(ctx.spec) .. "|r (" .. ctx.specMode
        .. (ctx.detected and ctx.detected ~= ctx.spec and (", talents = " .. SpecLabel(ctx.detected)) or "") .. ")")
    local mods = ns.TalentMods(classFile, ctx.spec)
    if #mods == 0 then
        ns.Print("aucun talent qui change la valeur des stats n'a été reconnu.")
    else
        for _, m in ipairs(mods) do ns.Print("  pris en compte : " .. m.label) end
    end
    if ForeverBisDB.debug then
        for _, e in ipairs(t.list) do ns.Print(string.format("  [%s] %s (%d)", tostring(e.branch or "?"), e.name, e.rank)) end
    else
        ns.Print("|cff888888(/fbis debug puis /fbis talents pour la liste complète des talents lus)|r")
    end
end

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------
SLASH_FOREVERBIS1 = "/fbis"
SLASH_FOREVERBIS2 = "/foreverbis"
SlashCmdList.FOREVERBIS = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "help" or msg == "aide" then
        ns.Print("v" .. ns.Version())
        ns.Print("|cffffd100/fbis|r : ouvrir / fermer la fenêtre des B.I.S")
        ns.Print("|cffffd100/fbis 60|r : ouvrir directement les B.I.S niveau 60")
        ns.Print("|cffffd100/fbis bulle|r : activer / désactiver les infos dans les bulles d'objets")
        ns.Print("|cffffd100/fbis minimap|r : afficher / masquer le bouton de la minicarte")
        ns.Print("|cffffd100/fbis talents|r : spé détectée et talents pris en compte")
    elseif msg == "bulle" or msg == "tooltip" then
        ForeverBisDB.options.tooltip = not ForeverBisDB.options.tooltip
        ns.Print("infos dans les bulles : " .. (ForeverBisDB.options.tooltip and "|cff00ff00activées|r" or "|cffff5555désactivées|r"))
    elseif msg == "minimap" or msg == "minicarte" then
        local shown = ns.ToggleMinimapButton and ns.ToggleMinimapButton()
        ns.Print("bouton de la minicarte : " .. (shown and "|cff00ff00affiché|r" or "|cffff5555masqué|r"))
    elseif msg == "talents" or msg == "spe" or msg == "spé" then
        PrintTalents()
    elseif msg == "debug" then
        ForeverBisDB.debug = not ForeverBisDB.debug
        ns.Print("debug : " .. tostring(ForeverBisDB.debug))
    elseif tonumber(msg) then
        if ns.ShowUI then ns.ShowUI(tonumber(msg)) end
    else
        if ns.ToggleUI then ns.ToggleUI() end
    end
end

function ForeverBis_Toggle()
    if ns.ToggleUI then ns.ToggleUI() end
end
