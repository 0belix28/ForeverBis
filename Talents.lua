-- ForeverBis : lecture des talents.
--   * la spé est déduite de la branche où tu as mis le plus de points ;
--   * double spé : chaque jeu de talents (config) garde sa propre spé, et un changement de
--     jeu de talents relance le calcul ;
--   * certains talents modifient la valeur des stats (toucher, % de stat, spécialisation d'arme...).
--
-- Forever n'a qu'un arbre de traits (C_Traits) découpé en trois branches. Chaque nœud indique
-- sa branche dans groupIDs. Les clients à onglets classiques (GetTalentTabInfo) sont aussi gérés.
local _, ns = ...


local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and issecretvalue(a) then return nil end
    return a, b, c, d, e, f
end

local function SpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then return Safe(C_Spell.GetSpellName, spellID) end
    return (Safe(GetSpellInfo, spellID))
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------
-- Clients à onglets classiques
local function ReadTabs()
    local nTabs = Safe(GetNumTalentTabs)
    if not nTabs or nTabs == 0 then return nil end
    local t = { points = {}, ranks = {}, list = {}, names = {}, total = 0 }
    for tab = 1, nTabs do
        local tabName, _, a3, _, a5 = Safe(GetTalentTabInfo, tab)
        local pts = tonumber(type(a3) == "number" and a3 or a5) or 0
        t.points[tab] = pts
        if type(tabName) == "string" and tabName ~= "" then t.names[tab] = tabName end
        t.total = t.total + pts
        for i = 1, (Safe(GetNumTalents, tab) or 0) do
            local name, _, _, _, rank = Safe(GetTalentInfo, tab, i)
            rank = tonumber(rank) or 0
            if name and rank > 0 then
                t.ranks[name:lower()] = rank
                t.list[#t.list + 1] = { name = name, rank = rank, branch = tab }
            end
        end
    end
    t.key = "g" .. tostring(Safe(GetActiveTalentGroup) or 1)
    return t
end

-- Forever : arbre de traits unique
local function ReadTraits()
    if not (C_ClassTalents and C_Traits and C_Traits.GetConfigInfo) then return nil end
    local cfgID = Safe(C_ClassTalents.GetActiveConfigID)
    if not cfgID then return nil end
    local cfg = Safe(C_Traits.GetConfigInfo, cfgID)
    local treeID = cfg and cfg.treeIDs and cfg.treeIDs[1]
    if not treeID then return nil end

    local branchOf, nBranches, names = {}, 0, {}
    local groups = C_Traits.GetGroupDisplayInfoByTreeID and Safe(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if type(groups) == "table" then
        table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
        for i, g in ipairs(groups) do
            if g.groupID then branchOf[g.groupID] = i end
            local n = g.displayName or g.name
            if type(n) == "string" and n ~= "" and not (issecretvalue and issecretvalue(n)) then names[i] = n end
        end
        nBranches = #groups
    end

    local t = { points = {}, ranks = {}, list = {}, names = names, total = 0, key = "c" .. cfgID }
    for i = 1, math.max(nBranches, 3) do t.points[i] = 0 end
    local nodes = Safe(C_Traits.GetTreeNodes, treeID)
    for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
        local ni = Safe(C_Traits.GetNodeInfo, cfgID, nodeID)
        local rank = type(ni) == "table" and tonumber(ni.ranksPurchased) or 0
        if rank > 0 then
            local branch
            for _, gid in ipairs(type(ni.groupIDs) == "table" and ni.groupIDs or {}) do
                if branchOf[gid] then branch = branchOf[gid] break end
            end
            if branch then t.points[branch] = (t.points[branch] or 0) + rank end
            t.total = t.total + rank
            local entryID = (ni.activeEntry and ni.activeEntry.entryID) or (ni.entryIDs and ni.entryIDs[1])
            local entry = entryID and Safe(C_Traits.GetEntryInfo, cfgID, entryID)
            local def = entry and entry.definitionID and Safe(C_Traits.GetDefinitionInfo, entry.definitionID)
            local name = def and (def.overrideName ~= "" and def.overrideName or nil)
            name = name or (def and SpellName(def.overriddenSpellID or def.spellID))
            if name then
                t.ranks[name:lower()] = (t.ranks[name:lower()] or 0) + rank
                t.list[#t.list + 1] = { name = name, rank = rank, branch = branch }
            end
        end
    end
    return t
end

local cache
function ns.Talents()
    if cache then return cache end
    local t = ReadTabs()
    if not t or t.total == 0 then
        local tr = ReadTraits()
        if tr and (tr.total > 0 or not t) then t = tr end
    end
    cache = t or { points = {}, ranks = {}, list = {}, names = {}, total = 0, key = "none" }
    return cache
end

function ns.InvalidateTalents()
    cache = nil
    ns.talentMods = nil
end

---------------------------------------------------------------------------
-- Talents qui changent la valeur des stats
---------------------------------------------------------------------------
-- Noms en anglais et en français (comparés en minuscules, sous-chaîne).
-- Chaque règle : classes concernées, mots-clés, effet (w = poids à modifier, r = rangs).
local function mul(w, k, f) if w[k] then w[k] = w[k] * f end end
local MELEE_CAP, SPELL_CAP = 9, 16

local RULES = {
    -- toucher apporté par les talents : le toucher des objets vaut moins (plafond atteint plus vite)
    { cls = { ROGUE = 1, WARRIOR = 1, PALADIN = 1 }, exact = { "précision", "precision" },
      label = "toucher +%d%%", per = 1, hit = "melee" },
    { cls = { HUNTER = 1 }, any = { "surefire", "tir assuré", "tir sûr" }, label = "toucher +%d%%", per = 1, hit = "melee" },
    { cls = { SHAMAN = 1 }, any = { "nature's guidance", "guide de la nature", "guidance de la nature" },
      label = "toucher +%d%% (mêlée et sorts)", per = 1, hit = "both" },
    { cls = { MAGE = 1 }, any = { "elemental precision", "précision élémentaire" }, label = "toucher des sorts +%d%%", per = 2, hit = "spell" },
    { cls = { MAGE = 1 }, spec = { arcane = 1 }, any = { "arcane focus", "focalisation des arcanes" }, label = "toucher des sorts +%d%%", per = 2, hit = "spell" },
    { cls = { WARLOCK = 1 }, spec = { affli = 1 }, any = { "suppression" }, label = "toucher des sorts +%d%%", per = 2, hit = "spell" },
    { cls = { PRIEST = 1 }, spec = { shadow = 1 }, any = { "shadow focus", "focalisation de l'ombre", "focalisation des ombres", "focalisation ombre" },
      label = "toucher des sorts +%d%%", per = 2, hit = "spell" },

    -- % de caractéristiques
    { cls = { HUNTER = 1 }, any = { "lightning reflexes", "réflexes" }, label = "agilité +%d%%", per = 3,
      fn = function(w, p) mul(w, "agi", 1 + p / 100) end },
    { cls = { PALADIN = 1 }, any = { "divine strength", "force divine" }, label = "force +%d%%", per = 2,
      fn = function(w, p) mul(w, "str", 1 + p / 100) end },
    { cls = { PALADIN = 1 }, any = { "divine intellect", "intelligence divine" }, label = "intelligence +%d%%", per = 2,
      fn = function(w, p) mul(w, "int", 1 + p / 100) end },
    { cls = { DRUID = 1 }, any = { "heart of the wild", "cœur sauvage", "coeur sauvage" }, label = "intelligence (+ force félin / endurance ours) +%d%%", per = 4,
      fn = function(w, p, spec)
          mul(w, "int", 1 + p / 100)
          if spec == "cat" then mul(w, "str", 1 + p / 100) elseif spec == "bear" then mul(w, "sta", 1 + p / 100) end
      end },
    { cls = { WARLOCK = 1 }, any = { "demonic embrace", "treinte démoniaque", "treinte demoniaque" }, label = "endurance +%d%%", per = 3,
      fn = function(w, p) mul(w, "sta", 1 + p / 100) end },
    { cls = { PRIEST = 1 }, any = { "mental strength", "force mentale" }, label = "intelligence (mana) +%d%%", per = 2,
      fn = function(w, p) mul(w, "int", 1 + p / 100) end },
    { cls = { PRIEST = 1 }, any = { "spiritual guidance", "direction spirituelle", "conseils spirituels", "guidance spirituelle" },
      label = "esprit -> puissance des sorts %d%%", per = 5,
      fn = function(w, p) w.spi = (w.spi or 0) + p / 100 * math.max(w.sp or 0, w.heal or 0) end },
    { cls = { MAGE = 1 }, any = { "arcane mind", "esprit des arcanes" }, label = "intelligence (mana) +%d%%", per = 2,
      fn = function(w, p) mul(w, "int", 1 + p / 100) end },
    { cls = { SHAMAN = 1 }, any = { "ancestral knowledge", "savoir ancestral", "connaissance ancestrale" }, label = "intelligence (mana) +%d%%", per = 1,
      fn = function(w, p) mul(w, "int", 1 + p / 100) end },

    -- spécialisations d'arme : préférence pour ce type d'arme
    { cls = { WARRIOR = 1, ROGUE = 1, PALADIN = 1, SHAMAN = 1, HUNTER = 1 }, spe = true, any = { "épée", "epee", "sword" }, weapon = { 7, 8 }, label = "épées +%d%%", per = 2 },
    { cls = { ROGUE = 1 }, spe = true, any = { "dague", "dagger" }, weapon = { 15 }, label = "dagues +%d%%", per = 2 },
    { cls = { WARRIOR = 1, ROGUE = 1, PALADIN = 1, SHAMAN = 1, DRUID = 1 }, spe = true, any = { "masse", "mace" }, weapon = { 4, 5 }, label = "masses +%d%%", per = 2 },
    { cls = { WARRIOR = 1, HUNTER = 1, SHAMAN = 1, PALADIN = 1 }, spe = true, any = { "hache", "axe" }, weapon = { 0, 1 }, label = "haches +%d%%", per = 2 },
    { cls = { WARRIOR = 1, HUNTER = 1, PALADIN = 1 }, spe = true, any = { "hast", "polearm" }, weapon = { 6 }, label = "armes d'hast +%d%%", per = 2 },
    { cls = { ROGUE = 1, WARRIOR = 1, SHAMAN = 1, DRUID = 1 }, spe = true, any = { "pugilat", "fist" }, weapon = { 13 }, label = "armes de pugilat +%d%%", per = 2 },
    { cls = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 }, spe = true, any = { "deux mains", "two-handed", "two handed" }, label = "armes à deux mains +%d%%", per = 2,
      fn = function(w, p) w.twoHand = (w.twoHand or 1) * (1 + p / 100) end },
    { cls = { WARRIOR = 1, ROGUE = 1, HUNTER = 1, SHAMAN = 1 }, spe = true, any = { "ambidext", "dual wield", "double arme" }, label = "main gauche +%d%%", per = 5,
      fn = function(w, p) mul(w, "ohdps", 1 + p / 100) end },
}

-- "spécialisation" / "specialization" (recherche simple : les accents font plusieurs octets)
local function IsSpecialization(name)
    return name:find("spécialis", 1, true) or name:find("specializ", 1, true) or name:find("specialis", 1, true)
end

local function Matches(rule, name)
    if rule.spe and not IsSpecialization(name) then return false end
    if rule.exact then
        for _, k in ipairs(rule.exact) do if name == k then return true end end
    end
    for _, k in ipairs(rule.any or {}) do
        if name:find(k, 1, true) then return true end
    end
    return false
end

-- -> liste des effets de talents actifs pour (classe, spé) : { {rule, rank, label} }
function ns.TalentMods(classFile, specKey)
    local id = classFile .. ":" .. specKey
    ns.talentMods = ns.talentMods or {}
    if ns.talentMods[id] then return ns.talentMods[id] end
    local t = ns.Talents()
    local out = {}
    for _, rule in ipairs(RULES) do
        if rule.cls[classFile] and (not rule.spec or rule.spec[specKey]) then
            local rank = 0
            for name, r in pairs(t.ranks) do
                if Matches(rule, name) then rank = rank + r end
            end
            if rank > 0 then
                out[#out + 1] = { rule = rule, rank = rank, pct = rank * rule.per, label = string.format(rule.label, rank * rule.per) }
            end
        end
    end
    ns.talentMods[id] = out
    return out
end

-- Applique les effets de talents à une table de poids (modifiée sur place).
function ns.ApplyTalentMods(w, classFile, specKey)
    local meleeHit, spellHit = 0, 0
    for _, m in ipairs(ns.TalentMods(classFile, specKey)) do
        local rule = m.rule
        if rule.hit == "melee" or rule.hit == "both" then meleeHit = meleeHit + m.pct end
        if rule.hit == "spell" or rule.hit == "both" then spellHit = spellHit + m.pct end
        if rule.weapon then
            w.wtype = w.wtype or {}
            for _, sub in ipairs(rule.weapon) do w.wtype[sub] = (w.wtype[sub] or 1) * (1 + m.pct / 100) end
        end
        if rule.fn then rule.fn(w, m.pct, specKey) end
    end
    if meleeHit > 0 then mul(w, "hit", math.max(0.2, 1 - meleeHit / MELEE_CAP)) end
    if spellHit > 0 then mul(w, "spellHit", math.max(0.2, 1 - spellHit / SPELL_CAP)) end
end

-- Signature des talents (pour les caches de calcul)
function ns.TalentSig()
    local t = ns.Talents()
    local parts = { t.key }
    for _, p in ipairs(t.points) do parts[#parts + 1] = p end
    return table.concat(parts, ".")
end

---------------------------------------------------------------------------
-- Spécialisation
---------------------------------------------------------------------------
-- -> branche dominante (index) ou nil (aucun point / égalité)
function ns.DominantBranch()
    local t = ns.Talents()
    local best, bestPts, tied = nil, 0, false
    for i, p in ipairs(t.points) do
        if p > bestPts then best, bestPts, tied = i, p, false
        elseif p == bestPts and p > 0 then tied = true end
    end
    if tied then return nil end
    return best
end

-- spés de calcul d'une branche (ex. félin / ours pour Combat farouche)
local function Variants(classFile, branch)
    local tree = ns.TREES[classFile] and branch and ns.TREES[classFile][branch]
    return tree and tree.specs
end

-- Nom d'une branche : celui du jeu si on l'a lu, sinon le nom français par défaut
function ns.TreeName(classFile, branch)
    local t = ns.Talents()
    local tree = ns.TREES[classFile] and ns.TREES[classFile][branch]
    return (t.names and t.names[branch]) or (tree and tree.name) or ("Branche " .. tostring(branch))
end

-- voleur : les spécialisations d'arme départagent dagues et épées / masses / pugilat
function ns.RogueWeaponPref()
    local t = ns.Talents()
    local dagger, other = 0, 0
    for name, r in pairs(t.ranks) do
        if IsSpecialization(name) then
            if name:find("dague", 1, true) or name:find("dagger", 1, true) then dagger = dagger + r
            elseif name:find("pée", 1, true) or name:find("sword", 1, true) or name:find("masse", 1, true)
                or name:find("mace", 1, true) or name:find("pugilat", 1, true) or name:find("fist", 1, true) then
                other = other + r
            end
        end
    end
    if dagger > other then return "dagger" elseif other > dagger then return "combat" end
    return nil
end

-- -> spé détectée par les talents (ou nil)
function ns.DetectSpec(classFile)
    local branch = ns.DominantBranch()
    local v = Variants(classFile, branch)
    if not v then return nil end
    if #v == 1 then return v[1] end
    local db = ForeverBisCharDB
    local chosen = db and db.variant and db.variant[classFile .. branch]
    for _, k in ipairs(v) do if k == chosen then return chosen end end
    return v[1]
end

-- -> spé à utiliser, mode ("auto" / "manuel"), spé détectée
function ns.ResolveSpec(classFile)
    local t = ns.Talents()
    local db = ForeverBisCharDB
    local manual = db and db.specByConfig and db.specByConfig[t.key]
    local detected = ns.DetectSpec(classFile)
    if manual and ns.GetSpec(classFile, manual) then return manual, "manuel", detected end
    return detected or ns.DEFAULT_SPEC[classFile], "auto", detected
end

-- Choix depuis la fenêtre. key = nil -> retour au mode automatique.
function ns.ChooseSpec(classFile, key)
    local db = ForeverBisCharDB
    local t = ns.Talents()
    db.specByConfig = db.specByConfig or {}
    db.variant = db.variant or {}
    if not key then
        db.specByConfig[t.key] = nil
    else
        local branch = ns.DominantBranch()
        local v = Variants(classFile, branch)
        local isVariant = false
        for _, k in ipairs(v or {}) do if k == key then isVariant = true end end
        if isVariant then
            -- même branche que les talents (ex. félin / ours) : on reste en automatique
            db.variant[classFile .. branch] = key
            db.specByConfig[t.key] = nil
        else
            db.specByConfig[t.key] = key
        end
    end
    ns.talentMods = nil
    ns.InvalidateBis()
end

-- Points par branche, ex. "31 / 20 / 0"
function ns.TalentPointsText()
    local t = ns.Talents()
    if t.total == 0 then return nil end
    local p = {}
    for i = 1, math.max(3, #t.points) do p[i] = t.points[i] or 0 end
    return table.concat(p, " / ")
end

-- Nom affiché d'une spé de calcul : nom de la branche dans le jeu (+ rôle pour félin / ours)
function ns.SpecDisplayName(classFile, specKey)
    local i = ns.TreeOf(classFile, specKey)
    if not i then
        local s = ns.GetSpec(classFile, specKey)
        return s and s.name or tostring(specKey)
    end
    local tree = ns.TREES[classFile][i]
    local name = ns.TreeName(classFile, i)
    if tree.variants then
        for j, k in ipairs(tree.specs) do
            if k == specKey then return name .. " (" .. tree.variants[j]:lower() .. ")" end
        end
    end
    return name
end
