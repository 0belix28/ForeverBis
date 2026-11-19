// ForeverBis : génère Data/StatWeights.lua (priorités de stats par classe, spé et tranche de niveau)
// à partir de la base Forever de RXPGuides (RXPGuides/DB/forever/StatWeights.lua).
// Licence des données : CC BY-NC-SA 4.0 (voir LICENSE-DATA.txt).
// Usage (depuis le dossier AddOns) :  node ForeverBis/Tools/build-weights.js
const fs = require("fs");
const path = require("path");

const ADDONS = path.resolve(__dirname, "..", "..");
const SRC = path.join(ADDONS, "RXPGuides", "DB", "forever", "StatWeights.lua");
const OUT = path.resolve(__dirname, "..", "Data", "StatWeights.lua");

const KEYS = {
  ITEM_MOD_STRENGTH_SHORT: "str", ITEM_MOD_AGILITY_SHORT: "agi", ITEM_MOD_INTELLECT_SHORT: "int",
  ITEM_MOD_STAMINA_SHORT: "sta", ITEM_MOD_SPIRIT_SHORT: "spi", ITEM_MOD_HEALTH_REGEN_SHORT: "hp5",
  ITEM_MOD_POWER_REGEN0_SHORT: "mp5", STAT_SPELLDAMAGE: "sp", ITEM_MOD_SPELL_HEALING_DONE: "heal",
  ITEM_MOD_HIT_SPELL_RATING_SHORT: "spellHit", ITEM_MOD_CRIT_SPELL_RATING_SHORT: "spellCrit",
  ITEM_MOD_ATTACK_POWER_SHORT: "ap", ITEM_MOD_DAMAGE_PER_SECOND_SHORT: "dps",
  ITEM_MOD_CR_SPEED_SHORT_2H: "speed2h", ITEM_MOD_CR_SPEED_SHORT_MH: "speedMh", ITEM_MOD_CR_SPEED_SHORT_OH: "speedOh",
  ITEM_MOD_HIT_RATING_SHORT: "hit", ITEM_MOD_CRIT_RATING_SHORT: "crit",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT_RANGED: "rdps", ITEM_MOD_CR_SPEED_SHORT_RANGED: "speedRanged",
  ITEM_MOD_RANGED_ATTACK_POWER_SHORT: "rap", RESISTANCE0_NAME: "armor",
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT: "defense", ITEM_MOD_DODGE_RATING_SHORT: "dodge", ITEM_MOD_PARRY_RATING_SHORT: "parry",
  STAT_SPELLDAMAGE_ARCANE: "spArcane", STAT_SPELLDAMAGE_FIRE: "spFire", STAT_SPELLDAMAGE_NATURE: "spNature",
  STAT_SPELLDAMAGE_FROST: "spFrost", STAT_SPELLDAMAGE_SHADOW: "spShadow",
};
// spé RXP -> clés de spé ForeverBis ("*" = toutes les spés de la classe sauf tank / soigneur)
const SPECS = {
  DRUID: { "Feral Combat": ["cat"], Balance: ["balance"] },
  MAGE: { Frost: ["frost"], Fire: ["fire"], Arcane: ["arcane"] },
  PALADIN: { Retribution: ["ret"] },
  PRIEST: { Discipline: ["disc", "holy"], Shadow: ["shadow"] },
  SHAMAN: { Enhancement: ["enh"], Elemental: ["ele"] },
  WARLOCK: { Affliction: ["affli", "demo"], Destruction: ["destru"] },
  HUNTER: { "": ["bm", "mm", "sv"] },
  ROGUE: { "": ["assa", "combat", "sub"] },
  WARRIOR: { "": ["arms", "fury"] },
};

const src = fs.readFileSync(SRC, "utf8");
const out = {}; // class -> spec -> kind -> [ {min, max, w} ]
let n = 0;
const blockRe = /\n    \['([^']+)'\] = \{([\s\S]*?)\n    \},/g;
let m;
while ((m = blockRe.exec(src))) {
  const body = m[2];
  const field = (k) => { const r = body.match(new RegExp(`\\['${k}'\\] = "?([^",]*)"?,`)); return r ? r[1] : null; };
  const cls = (field("Class") || "").toUpperCase();
  const spec = (field("Spec") || "").trim();
  const kind = (field("Kind") || "").toLowerCase();
  const targets = SPECS[cls] && SPECS[cls][spec];
  if (!targets) continue; // ex. Mage "AOE"
  const w = {};
  for (const r of body.matchAll(/\['([A-Z0-9_]+)'\] = (-?[\d.]+),/g)) {
    const key = KEYS[r[1]];
    const v = parseFloat(r[2]);
    if (key && v !== 0) w[key] = v;
  }
  const entry = { min: +field("MIN_LEVEL"), max: +field("MAX_LEVEL"), w };
  for (const t of targets) {
    out[cls] ??= {}; out[cls][t] ??= {}; out[cls][t][kind] ??= [];
    out[cls][t][kind].push(entry);
  }
  n++;
}

const lua = [];
lua.push("-- Généré par Tools/build-weights.js le " + new Date().toISOString().slice(0, 10) + ". Ne pas modifier à la main : relancer le script.");
lua.push("-- Priorités de stats pendant le leveling (poids en « équivalent puissance d'attaque » / puissance des sorts),");
lua.push("-- par classe, spécialisation et tranche de niveau. Source : base Forever de RXPGuides,");
lua.push("-- licence CC BY-NC-SA 4.0 (voir LICENSE-DATA.txt). Ce fichier est sous la même licence.");
lua.push("-- Le toucher et le critique sont en %, comme sur les objets.");
lua.push("local _, ns = ...");
lua.push("ns.LEVEL_WEIGHTS = {");
const fmt = (v) => String(Math.round(v * 1000) / 1000);
for (const cls of Object.keys(out).sort()) {
  lua.push(`    ${cls} = {`);
  for (const spec of Object.keys(out[cls]).sort()) {
    lua.push(`        ${spec} = {`);
    for (const kind of Object.keys(out[cls][spec]).sort()) {
      lua.push(`            ${kind} = {`);
      for (const e of out[cls][spec][kind].sort((a, b) => a.min - b.min)) {
        const ws = Object.keys(e.w).map((k) => `${k} = ${fmt(e.w[k])}`).join(", ");
        lua.push(`                { ${e.min}, ${e.max}, { ${ws} } },`);
      }
      lua.push("            },");
    }
    lua.push("        },");
  }
  lua.push("    },");
}
lua.push("}");
fs.writeFileSync(OUT, lua.join("\n") + "\n");
console.log(`${n} profils RXP lus -> ${path.relative(ADDONS, OUT)}`);
