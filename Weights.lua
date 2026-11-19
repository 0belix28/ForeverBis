-- ForeverBis : poids des caractéristiques par classe et spécialisation.
--
-- Valeurs relatives (1 point de la stat principale ≈ 1). Elles servent à classer
-- les objets entre eux, pas à prédire des dégâts exacts.
--   str agi sta int spi armor ap rap        caractéristiques de base
--   crit hit                                 % de critique / toucher (physique)
--   spellCrit spellHit                       % de critique / toucher des sorts
--   sp heal spFire spFrost spShadow spArcane spNature spHoly   puissance des sorts / soins
--   mp5 hp5 defense dodge parry block blockValue
--   dps     DPS de l'arme en main droite (ou deux mains)
--   ohdps   DPS de l'arme en main gauche (ambidextrie)
--   rdps    DPS de l'arme à distance (arc, fusil, arbalète, armes de jet)
--   wand    DPS de la baguette
-- role : "melee", "ranged", "caster", "healer", "tank" (ajuste les poids pendant le leveling)
local _, ns = ...

ns.SPECS = {
    WARRIOR = {
        { key = "arms", name = "Armes", role = "melee",
          w = { str = 1, agi = 0.7, ap = 0.5, crit = 14, hit = 12, sta = 0.3, armor = 0.005, dps = 7, rdps = 0.3 } },
        { key = "fury", name = "Fureur", role = "melee",
          w = { str = 1, agi = 0.7, ap = 0.5, crit = 14, hit = 16, sta = 0.3, armor = 0.005, dps = 6, ohdps = 3, rdps = 0.3 } },
        { key = "prot", name = "Protection", role = "tank",
          w = { sta = 1, armor = 0.06, defense = 1.2, dodge = 12, parry = 11, block = 6, blockValue = 0.4,
                str = 0.5, agi = 0.6, hit = 6, ap = 0.2, crit = 3, dps = 1.5, hp5 = 1, rdps = 0.2 } },
    },
    PALADIN = {
        { key = "holy", name = "Sacré", role = "healer",
          w = { heal = 1, int = 0.9, mp5 = 2.2, spellCrit = 12, spi = 0.15, sta = 0.15, armor = 0.002 } },
        { key = "prot", name = "Protection", role = "tank",
          w = { sta = 1, armor = 0.05, defense = 1, dodge = 10, parry = 9, block = 6, blockValue = 0.4,
                sp = 0.6, spHoly = 0.6, int = 0.4, str = 0.3, agi = 0.4, hit = 4, spellHit = 3, mp5 = 1, dps = 1 } },
        { key = "ret", name = "Vindicte", role = "melee",
          w = { str = 1, agi = 0.6, ap = 0.5, crit = 12, hit = 12, int = 0.3, sta = 0.3, sp = 0.3, spHoly = 0.3,
                mp5 = 0.8, armor = 0.004, dps = 7 } },
    },
    HUNTER = {
        { key = "bm", name = "Maîtrise des bêtes", role = "ranged",
          w = { agi = 1, ap = 0.45, rap = 0.45, crit = 12, hit = 12, int = 0.3, mp5 = 1, sta = 0.3, spi = 0.1,
                str = 0.05, armor = 0.003, rdps = 9, dps = 0.6, ohdps = 0.3 } },
        { key = "mm", name = "Précision", role = "ranged",
          w = { agi = 1, ap = 0.45, rap = 0.45, crit = 13, hit = 13, int = 0.3, mp5 = 1, sta = 0.3, spi = 0.1,
                str = 0.05, armor = 0.003, rdps = 9.5, dps = 0.6, ohdps = 0.3 } },
        { key = "sv", name = "Survie", role = "ranged",
          w = { agi = 1.1, ap = 0.45, rap = 0.45, crit = 13, hit = 12, int = 0.3, mp5 = 0.9, sta = 0.3, spi = 0.1,
                str = 0.1, armor = 0.003, rdps = 9, dps = 0.8, ohdps = 0.4 } },
    },
    ROGUE = {
        { key = "assa", name = "Assassinat", role = "melee",
          w = { agi = 1, str = 0.5, ap = 0.5, crit = 15, hit = 15, sta = 0.3, armor = 0.003, dps = 6, ohdps = 3, rdps = 0.2 } },
        { key = "combat", name = "Combat", role = "melee",
          w = { agi = 1, str = 0.55, ap = 0.5, crit = 14, hit = 16, sta = 0.3, armor = 0.003, dps = 6, ohdps = 3, rdps = 0.2 } },
        { key = "sub", name = "Finesse", role = "melee",
          w = { agi = 1, str = 0.5, ap = 0.5, crit = 15, hit = 15, sta = 0.3, armor = 0.003, dps = 6, ohdps = 3, rdps = 0.2 } },
    },
    PRIEST = {
        { key = "disc", name = "Discipline", role = "healer",
          w = { heal = 1, int = 0.9, spi = 0.6, mp5 = 2.2, spellCrit = 6, sta = 0.15, armor = 0.002, wand = 0.5 } },
        { key = "holy", name = "Sacré", role = "healer",
          w = { heal = 1, int = 0.8, spi = 0.7, mp5 = 2.2, spellCrit = 7, sta = 0.15, armor = 0.002, wand = 0.5 } },
        { key = "shadow", name = "Ombre", role = "caster",
          w = { sp = 1, spShadow = 1, int = 0.4, spi = 0.4, spellHit = 12, spellCrit = 5, mp5 = 1, sta = 0.3,
                armor = 0.002, wand = 1.5 } },
    },
    SHAMAN = {
        { key = "ele", name = "Élémentaire", role = "caster",
          w = { sp = 1, spNature = 1, spFire = 0.3, spFrost = 0.2, int = 0.45, spellCrit = 10, spellHit = 12, mp5 = 1.5,
                sta = 0.25, spi = 0.1, armor = 0.002 } },
        { key = "enh", name = "Amélioration", role = "melee",
          w = { str = 1, agi = 0.6, ap = 0.5, crit = 12, hit = 12, int = 0.3, mp5 = 0.6, sta = 0.3, armor = 0.004, dps = 7 } },
        { key = "resto", name = "Restauration", role = "healer",
          w = { heal = 1, int = 0.8, mp5 = 2.4, spellCrit = 7, spi = 0.2, sta = 0.15, armor = 0.002 } },
    },
    MAGE = {
        { key = "arcane", name = "Arcanes", role = "caster",
          w = { sp = 1, spArcane = 0.6, spFrost = 0.5, spFire = 0.3, int = 0.6, spellCrit = 9, spellHit = 12, mp5 = 1.3,
                spi = 0.3, sta = 0.25, armor = 0.002, wand = 1.5 } },
        { key = "fire", name = "Feu", role = "caster",
          w = { sp = 1, spFire = 1, int = 0.5, spellCrit = 11, spellHit = 13, mp5 = 1, spi = 0.2, sta = 0.25,
                armor = 0.002, wand = 1.5 } },
        { key = "frost", name = "Givre", role = "caster",
          w = { sp = 1, spFrost = 1, int = 0.5, spellCrit = 8, spellHit = 13, mp5 = 1, spi = 0.25, sta = 0.3,
                armor = 0.002, wand = 1.5 } },
    },
    WARLOCK = {
        { key = "affli", name = "Affliction", role = "caster",
          w = { sp = 1, spShadow = 1, int = 0.3, sta = 0.45, spellHit = 13, spellCrit = 3, spi = 0.2, mp5 = 0.6,
                armor = 0.002, wand = 1.5 } },
        { key = "demo", name = "Démonologie", role = "caster",
          w = { sp = 1, spShadow = 0.9, spFire = 0.2, int = 0.35, sta = 0.55, spellHit = 12, spellCrit = 5, spi = 0.15,
                mp5 = 0.6, armor = 0.003, wand = 1.5 } },
        { key = "destru", name = "Destruction", role = "caster",
          w = { sp = 1, spShadow = 0.85, spFire = 0.4, int = 0.35, sta = 0.4, spellHit = 13, spellCrit = 9, spi = 0.15,
                mp5 = 0.6, armor = 0.002, wand = 1.5 } },
    },
    DRUID = {
        { key = "balance", name = "Équilibre", role = "caster",
          w = { sp = 1, spNature = 0.6, spArcane = 0.4, int = 0.45, spellCrit = 9, spellHit = 12, mp5 = 1.4,
                spi = 0.2, sta = 0.25, armor = 0.002 } },
        { key = "cat", name = "Combat farouche (félin)", role = "melee", formWeapons = true,
          w = { agi = 1, str = 1.1, ap = 0.5, crit = 14, hit = 14, sta = 0.35, armor = 0.01, int = 0.1 } },
        { key = "bear", name = "Combat farouche (ours)", role = "tank", formWeapons = true,
          w = { sta = 1, armor = 0.12, agi = 0.8, defense = 1, dodge = 12, str = 0.4, ap = 0.2, hit = 4, crit = 3, hp5 = 1 } },
        { key = "resto", name = "Restauration", role = "healer",
          w = { heal = 1, int = 0.7, spi = 0.7, mp5 = 2.2, spellCrit = 6, sta = 0.15, armor = 0.002 } },
    },
}

-- Spécialisation par défaut (la plus jouée en leveling).
-- Les 3 branches de talents de chaque classe (dans l'ordre du jeu) -> spés de calcul.
-- Le nom affiché est celui de la branche dans le jeu ; celui-ci sert si le jeu ne le donne pas.
-- Combat farouche a deux variantes de calcul : félin (dégâts) et ours (tank).
ns.TREES = {
    WARRIOR = { { name = "Armes", specs = { "arms" } }, { name = "Fureur", specs = { "fury" } }, { name = "Protection", specs = { "prot" } } },
    PALADIN = { { name = "Sacré", specs = { "holy" } }, { name = "Protection", specs = { "prot" } }, { name = "Vindicte", specs = { "ret" } } },
    HUNTER  = { { name = "Maîtrise des bêtes", specs = { "bm" } }, { name = "Précision", specs = { "mm" } }, { name = "Survie", specs = { "sv" } } },
    ROGUE   = { { name = "Assassinat", specs = { "assa" } }, { name = "Combat", specs = { "combat" } }, { name = "Finesse", specs = { "sub" } } },
    PRIEST  = { { name = "Discipline", specs = { "disc" } }, { name = "Sacré", specs = { "holy" } }, { name = "Ombre", specs = { "shadow" } } },
    SHAMAN  = { { name = "Élémentaire", specs = { "ele" } }, { name = "Amélioration", specs = { "enh" } }, { name = "Restauration", specs = { "resto" } } },
    MAGE    = { { name = "Arcanes", specs = { "arcane" } }, { name = "Feu", specs = { "fire" } }, { name = "Givre", specs = { "frost" } } },
    WARLOCK = { { name = "Affliction", specs = { "affli" } }, { name = "Démonologie", specs = { "demo" } }, { name = "Destruction", specs = { "destru" } } },
    DRUID   = { { name = "Équilibre", specs = { "balance" } }, { name = "Combat farouche", specs = { "cat", "bear" }, variants = { "Félin", "Ours" } },
                { name = "Restauration", specs = { "resto" } } },
}

-- -> index de branche d'une spé de calcul
function ns.TreeOf(classFile, specKey)
    for i, t in ipairs(ns.TREES[classFile] or {}) do
        for _, k in ipairs(t.specs) do if k == specKey then return i end end
    end
    return nil
end

ns.DEFAULT_SPEC = {
    WARRIOR = "arms", PALADIN = "ret", HUNTER = "bm", ROGUE = "combat", PRIEST = "shadow",
    SHAMAN = "enh", MAGE = "frost", WARLOCK = "affli", DRUID = "cat",
}

-- Pendant le leveling (< 60) : le toucher compte moins (monstres de ton niveau),
-- l'endurance, l'armure et l'esprit (régénération entre les combats) comptent plus.
local LEVELING_MULT = { hit = 0.5, spellHit = 0.5, sta = 1.6, armor = 1.5, mp5 = 0.8, defense = 0.6 }

local cache = {}
local WAND_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true }

-- Mode de jeu pour les poids de leveling : "hardcore" sur un royaume hardcore, sinon "speedrun".
local function Kind()
    local hc = C_GameRules and C_GameRules.IsHardcoreActive and select(2, pcall(C_GameRules.IsHardcoreActive))
    return hc == true and "hardcore" or "speedrun"
end

-- -> profil de leveling (Data/StatWeights.lua) pour ce niveau, ou nil
local function LevelProfile(classFile, specKey, level)
    if level >= 60 or not ns.LEVEL_WEIGHTS then return nil end
    local bySpec = ns.LEVEL_WEIGHTS[classFile] and ns.LEVEL_WEIGHTS[classFile][specKey]
    local kind = Kind()
    local list = bySpec and (bySpec[kind] or bySpec.speedrun)
    for _, e in ipairs(list or {}) do
        if level >= e[1] and level <= e[2] then return e, kind end
    end
    return nil
end

-- -> table de poids pour (classe, spec, niveau), et texte d'origine des poids
function ns.GetWeights(classFile, specKey, level)
    local spec = ns.GetSpec(classFile, specKey)
    if not spec then return nil end
    local prof, kind = LevelProfile(classFile, specKey, level)
    local id = table.concat({ classFile, specKey, prof and (prof[1] .. "-" .. prof[2]) or (level >= 60 and "60" or "lvl"),
        ns.TalentSig and ns.TalentSig() or "" }, ":")
    if cache[id] then return cache[id], cache[id .. "#src"] end
    local w, src = {}, nil
    if prof then
        for k, v in pairs(prof[3]) do w[k] = v end
        -- main gauche : la moitié des dégâts de la main droite
        if w.dps and not w.ohdps then w.ohdps = w.dps * 0.5 end
        if WAND_CLASSES[classFile] and w.rdps then w.wand, w.rdps = w.rdps, nil end
        src = string.format("RXPGuides Forever, niveaux %d-%d (%s)", prof[1], prof[2], kind == "hardcore" and "Hardcore" or "Speedrun")
    else
        for k, v in pairs(spec.w) do w[k] = v end
        if level < 60 then
            for k, m in pairs(LEVELING_MULT) do
                if w[k] then w[k] = w[k] * m end
            end
            w.sta = math.max(w.sta or 0, 0.4)
            if spec.role == "caster" or spec.role == "healer" then
                w.spi = math.max((w.spi or 0) * 2, 0.35)
            end
            src = "ForeverBis (leveling)"
        else
            src = "ForeverBis (niveau 60, pré-raid)"
        end
    end
    if ns.ApplyTalentMods then ns.ApplyTalentMods(w, classFile, specKey) end
    -- voleur avec la spécialisation Dague : dague en main droite (Attaque sournoise, Embuscade...)
    if classFile == "ROGUE" and ns.RogueWeaponPref and ns.RogueWeaponPref() == "dagger" then w.daggerMH = true end
    cache[id], cache[id .. "#src"] = w, src
    return w, src
end

function ns.ClearWeightCache() wipe(cache) end

-- Libellés des stats, pour l'ordre de priorité
local STAT_LABELS = {
    dps = "DPS de l'arme", rdps = "DPS à distance", wand = "DPS baguette",
    hit = "Toucher %", crit = "Critique %", spellHit = "Toucher des sorts %", spellCrit = "Critique des sorts %",
    str = "Force", agi = "Agilité", sta = "Endurance", int = "Intelligence", spi = "Esprit",
    ap = "Puissance d'attaque", rap = "PA à distance", sp = "Puissance des sorts", heal = "Soins",
    spFire = "Dégâts de feu", spFrost = "Dégâts de givre", spShadow = "Dégâts d'ombre", spArcane = "Dégâts des arcanes",
    spNature = "Dégâts de nature", spHoly = "Dégâts du sacré",
    mp5 = "Mana / 5 s", hp5 = "Vie / 5 s", defense = "Défense", dodge = "Esquive %", parry = "Parade %",
    block = "Blocage %", blockValue = "Valeur de blocage", armor = "Armure",
}
ns.STAT_LABELS = STAT_LABELS

local DEFENSIVE = { dodge = true, parry = true, defense = true, block = true, blockValue = true }

-- -> liste triée { {key, label, value} } des stats qui comptent pour ces poids
-- (esquive / parade / défense / blocage seulement pour un tank)
function ns.StatPriority(w, role)
    local list = {}
    local sp = w.sp or 0
    for k, v in pairs(w) do
        local label = STAT_LABELS[k]
        -- dégâts d'une école : seulement s'ils valent plus que la puissance des sorts générale
        local school = k:match("^sp%u")
        if label and type(v) == "number" and v > 0 and (not school or v > sp + 0.001)
            and (role == "tank" or not DEFENSIVE[k]) then
            list[#list + 1] = { key = k, label = label, value = v }
        end
    end
    table.sort(list, function(a, b) return a.value > b.value end)
    return list
end

function ns.GetSpec(classFile, specKey)
    for _, s in ipairs(ns.SPECS[classFile] or {}) do
        if s.key == specKey then return s end
    end
    return nil
end
