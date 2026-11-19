// ForeverBis : génère Data/Items.lua et Data/Sources.lua.
// Usage (depuis le dossier AddOns) :  node ForeverBis/Tools/build-data.js
//
// Sources lues (déjà présentes dans Interface\AddOns) :
//   Polestar_ItemDB/Items.lua     stats Classic Era (tables du client Blizzard)
//   Polestar_ItemDB/Forever.lua   stats Forever + origine des objets de leveling (quêtes, drops, métiers)
//   ForeverDungeonJournal/Data/Dungeons.lua    loots des boss et récompenses des quêtes de donjon
//   ForeverDungeonJournal/Data/SharedLoot.lua  loots partagés entre plusieurs boss
// Relancer après une mise à jour de ces addons.

const fs = require("fs");
const path = require("path");

const ADDONS = path.resolve(__dirname, "..", "..");
const OUT = path.resolve(__dirname, "..", "Data");
const read = (p) => fs.readFileSync(path.join(ADDONS, p), "utf8");

// ---------------------------------------------------------------- mini parseur Lua (tables littérales)
function tokenize(src) {
  const t = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === "-" && src[i + 1] === "-") {
      const m = src.slice(i + 2).match(/^\[(=*)\[/);
      if (m) {
        const end = src.indexOf("]" + m[1] + "]", i);
        i = end < 0 ? n : end + m[1].length + 2;
      } else {
        const nl = src.indexOf("\n", i);
        i = nl < 0 ? n : nl;
      }
      continue;
    }
    if (/\s/.test(c)) { i++; continue; }
    if (c === '"' || c === "'") {
      let s = "";
      i++;
      while (i < n && src[i] !== c) {
        if (src[i] === "\\") {
          const e = src[i + 1];
          s += e === "n" ? "\n" : e === "t" ? "\t" : e;
          i += 2;
        } else s += src[i++];
      }
      i++;
      t.push({ k: "str", v: s });
      continue;
    }
    if (c === "[" && /^\[=*\[/.test(src.slice(i))) {
      const m = src.slice(i).match(/^\[(=*)\[/);
      const end = src.indexOf("]" + m[1] + "]", i);
      t.push({ k: "str", v: src.slice(i + m[0].length, end) });
      i = end + m[1].length + 2;
      continue;
    }
    const num = src.slice(i).match(/^(0x[0-9a-fA-F]+|\d+\.?\d*(e[+-]?\d+)?)/);
    if (num) { t.push({ k: "num", v: Number(num[0]) }); i += num[0].length; continue; }
    const id = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (id) { t.push({ k: "id", v: id[0] }); i += id[0].length; continue; }
    if (src.startsWith("..", i)) { t.push({ k: "op", v: ".." }); i += 2; continue; }
    t.push({ k: "op", v: c });
    i++;
  }
  return t;
}

function parseValueAt(tokens, pos, env) {
  let p = pos;
  function value() {
    const tk = tokens[p];
    let v;
    if (tk.k === "op" && tk.v === "{") v = table();
    else if (tk.k === "str" || tk.k === "num") { v = tk.v; p++; }
    else if (tk.k === "op" && tk.v === "-") { p++; v = -tokens[p].v; p++; }
    else if (tk.k === "id") {
      p++;
      if (tk.v === "true") v = true;
      else if (tk.v === "false") v = false;
      else if (tk.v === "nil") v = null;
      else {
        // identifiant (constante locale) ; on saute un éventuel accès a.b / appel f(...)
        v = env && tk.v in env ? env[tk.v] : null;
        while (tokens[p] && tokens[p].k === "op" && (tokens[p].v === "." || tokens[p].v === "(")) {
          if (tokens[p].v === ".") p += 2;
          else { let d = 0; do { if (tokens[p].v === "(") d++; if (tokens[p].v === ")") d--; p++; } while (d > 0); }
        }
      }
    } else throw new Error("token inattendu " + JSON.stringify(tk) + " @" + p);
    while (tokens[p] && tokens[p].k === "op" && tokens[p].v === "..") {
      p++;
      const r = value();
      v = String(v ?? "") + String(r ?? "");
    }
    return v;
  }
  function table() {
    p++; // {
    const arr = [];
    const obj = {};
    let isObj = false;
    while (!(tokens[p].k === "op" && tokens[p].v === "}")) {
      const tk = tokens[p];
      if (tk.k === "op" && tk.v === "[") {
        p++;
        const key = value();
        p++; // ]
        p++; // =
        obj[key] = value();
        isObj = true;
      } else if (tk.k === "id" && tokens[p + 1] && tokens[p + 1].k === "op" && tokens[p + 1].v === "=") {
        p += 2;
        obj[tk.v] = value();
        isObj = true;
      } else arr.push(value());
      if (tokens[p].k === "op" && (tokens[p].v === "," || tokens[p].v === ";")) p++;
    }
    p++; // }
    if (isObj) { arr.forEach((v, i) => (obj[i + 1] = v)); return obj; }
    return arr;
  }
  return { v: value(), p };
}

// ---------------------------------------------------------------- Polestar_ItemDB
const items = {}; // id -> "inv ilvl req q class sub tokens"
function loadItemStrings(file, fromLine, toLine) {
  const lines = read(file).split(/\r?\n/).slice(fromLine, toLine);
  for (const l of lines) {
    const m = l.match(/^\[(\d+)\]="([^"]*)",?$/);
    if (m) items[m[1]] = m[2];
  }
}
loadItemStrings("Polestar_ItemDB/Items.lua");

const forever = read("Polestar_ItemDB/Forever.lua");
const fLines = forever.split(/\r?\n/);
const levStart = fLines.findIndex((l) => l.startsWith("DB.RegisterLeveling"));
loadItemStrings("Polestar_ItemDB/Forever.lua", 0, levStart); // surcharge Forever
const overrideCount = fLines.slice(0, levStart).filter((l) => /^\[\d+\]=/.test(l)).length;

// partie RegisterLeveling : sous-tables professions / names / src / quests / npcs / zones
const levTokens = tokenize(fLines.slice(levStart).join("\n"));
let lp = levTokens.findIndex((t, i) => i > 0 && t.k === "op" && t.v === "{" && levTokens[i - 1].v === ",");
const lev = parseValueAt(levTokens, lp).v;
const profs = lev.professions;

const names = {}; // id -> nom anglais
for (const [id, n] of Object.entries(lev.names)) names[id] = n;

const sources = {}; // id -> Set de chaînes
function addSrc(id, ...parts) {
  id = String(id);
  const s = parts.map((x) => String(x ?? "").replace(/[;|]/g, ",")).join("|");
  (sources[id] = sources[id] || new Set()).add(s);
}

const SIDE = { 1: "A", 2: "H", 3: "B" };
const quests = {};
for (const [qid, s] of Object.entries(lev.quests)) {
  const [head, , , name] = s.split("|");
  const [level, req, side, zone, race, cls, dungeon] = head.split(" ").map(Number);
  quests[qid] = { level, req, side: SIDE[side] || "B", zone: lev.zones[zone] || "", cls, dungeon, name };
}
for (const [id, s] of Object.entries(lev.src)) {
  for (const tok of s.split(" ")) {
    let m;
    if ((m = tok.match(/^q(\d+)$/))) {
      const q = quests[m[1]];
      if (q) addSrc(id, "Q", q.name, q.level, q.side, q.zone, q.cls || 0, q.req || "", "");
    } else if ((m = tok.match(/^d(\d+)x(\d+)z(\d+)$/))) {
      const npc = m[1] === "0" ? "" : lev.npcs[m[1]] || "";
      addSrc(id, "W", npc, lev.zones[m[3]] || "", Number(m[2]) / 10);
    } else if ((m = tok.match(/^c(\d+)p(\d+)s(\d+)$/))) {
      addSrc(id, "C", profs[Number(m[2]) - 1] || "?", m[3]);
    }
  }
}

// ---------------------------------------------------------------- ForeverDungeonJournal
const fdj = read("ForeverDungeonJournal/Data/Dungeons.lua");
const fdjTokens = tokenize(fdj);
const dungeons = {};
for (let i = 0; i < fdjTokens.length - 4; i++) {
  const t = fdjTokens;
  // FDJ.DB = { ... } / FDJ.DB["X"] = { ... } / DB["X"] = { ... } (alias local)
  let j = -1;
  if (t[i].v === "FDJ" && t[i + 1].v === "." && t[i + 2].v === "DB") j = i + 3;
  else if (t[i].k === "id" && t[i].v === "DB" && !(i > 0 && t[i - 1].v === ".")) j = i + 1;
  if (j < 0) continue;
  if (t[j].v === "=" && t[j + 1].v === "{") {
    Object.assign(dungeons, parseValueAt(t, j + 1).v);
  } else if (t[j].v === "[" && t[j + 1].k === "str" && t[j + 2].v === "]" && t[j + 3].v === "=" && t[j + 4].v === "{") {
    dungeons[t[j + 1].v] = parseValueAt(t, j + 4).v;
  }
}
const FACTION = { Alliance: "A", Horde: "H" };
const asList = (x) => (Array.isArray(x) ? x : x ? Object.keys(x).filter((k) => /^\d+$/.test(k)).map((k) => x[k]) : []);
const dungeonLevels = {};
let fdjItems = 0;
for (const [dname, d] of Object.entries(dungeons)) {
  dungeonLevels[dname] = d.level || "";
  for (const b of asList(d.bosses)) {
    for (const l of asList(b.loot)) {
      const [id, name, slot] = Array.isArray(l) ? l : asList(l);
      if (!id || /Quest Item|Recipe|Pattern|Plans|Schematic|Formula|Blueprint|Book|Tome$/.test(slot || "")) continue;
      names[id] = names[id] || name;
      addSrc(id, "D", dname, b.trash ? "*" : b.name);
      fdjItems++;
    }
  }
  for (const q of asList(d.quests)) {
    for (const r of asList(q.rewardItems)) {
      const [id, name] = Array.isArray(r) ? r : asList(r);
      if (!id) continue;
      names[id] = names[id] || name;
      addSrc(id, "Q", q.name, q.level || "", FACTION[q.faction] || "B", dname, 0, q.requires || "", "J");
    }
  }
}
// loots partagés
const shared = read("ForeverDungeonJournal/Data/SharedLoot.lua");
const env = {};
for (const m of shared.matchAll(/^local ([A-Za-z_, ]+) = ("[^\n]+)$/gm)) {
  const keys = m[1].split(",").map((s) => s.trim());
  const vals = [...m[2].matchAll(/"([^"]*)"/g)].map((x) => x[1]);
  keys.forEach((k, i) => (env[k] = vals[i]));
}
const sTokens = tokenize(shared);
const si = sTokens.findIndex((t, i) => t.v === "SHARED" && sTokens[i + 1].v === "=");
if (si >= 0) {
  for (const e of asList(parseValueAt(sTokens, si + 2, env).v)) {
    const [id, name, where] = Array.isArray(e) ? e : asList(e);
    names[id] = names[id] || name;
    for (const d of Object.keys(where || {})) addSrc(id, "D", d, "+");
  }
}

// ---------------------------------------------------------------- écriture
const luaStr = (s) => '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, " ") + '"';
const byId = (a, b) => Number(a) - Number(b);
const today = new Date().toISOString().slice(0, 10);

let out = [
  "-- Généré par Tools/build-data.js le " + today + ". Ne pas modifier à la main : relancer le script.",
  "-- Stats : tables du client Classic Era (via Polestar_ItemDB/Items.lua) + surcharge Forever",
  "-- (Polestar_ItemDB/Forever.lua, données ForeverLevelingBiS, licence MIT, voir LICENSE-DATA.txt).",
  '-- Format : "<inv> <ilvl> <reqLvl> <qualité> <classe> <sous-classe> [<stat><n> ...] [dmin dmax speed] [cls<masque>] [uniq1]"',
  "local _, ns = ...",
  "ns.ITEMS = {",
];
const ids = Object.keys(items).sort(byId);
for (const id of ids) out.push(`[${id}]=${luaStr(items[id])},`);
out.push("}");
fs.writeFileSync(path.join(OUT, "Items.lua"), out.join("\n") + "\n");

out = [
  "-- Généré par Tools/build-data.js le " + today + ". Ne pas modifier à la main : relancer le script.",
  "-- Origine des objets : ForeverDungeonJournal (loots de boss, quêtes de donjon) et",
  "-- Polestar_ItemDB/Forever.lua (quêtes, drops, métiers ; données ForeverLevelingBiS, licence MIT).",
  "-- Sources séparées par ';' :",
  "--   D|donjon|boss   (boss '*' = trash, '+' = loot partagé)",
  "--   Q|quête|niveau|camp A/H/B|zone|masque de classe|niveau requis|J = quête de donjon (ForeverDungeonJournal)",
  "--   W|pnj|zone|%    C|métier|compétence",
  "local _, ns = ...",
  "ns.SOURCES = {",
];
const srcIds = Object.keys(sources).sort(byId);
for (const id of srcIds) out.push(`[${id}]=${luaStr([...sources[id]].join(";"))},`);
out.push("}", "ns.NAMES = {");
for (const id of Object.keys(names).sort(byId)) out.push(`[${id}]=${luaStr(names[id])},`);
out.push("}", "ns.DUNGEON_LEVELS = {");
for (const d of Object.keys(dungeonLevels).sort()) out.push(`[${luaStr(d)}]=${luaStr(dungeonLevels[d])},`);
out.push("}");
fs.writeFileSync(path.join(OUT, "Sources.lua"), out.join("\n") + "\n");

const missing = srcIds.filter((id) => !items[id]).length;
console.log(`objets avec stats : ${ids.length} (dont ${overrideCount} surcharges Forever)`);
console.log(`objets avec source : ${srcIds.length} (loots FDJ : ${fdjItems}), sans stats hors-ligne : ${missing} (lues en jeu)`);
console.log(`donjons : ${Object.keys(dungeons).length}`);
