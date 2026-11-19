# ForeverBis

**🇫🇷 Français** · [🇬🇧 English](#english)

**Tes B.I.S (Best in Slot) sur WoW Forever, calculés pour ton personnage : pendant le leveling et au niveau 60.**

ForeverBis regarde ta classe, ton niveau, ta faction et tes talents, puis te montre la meilleure pièce
que tu peux obtenir pour chaque emplacement. Il les signale aussi directement dans les bulles d'objets.

### Fonctionnalités
- **B.I.S de leveling et niveau 60** : à ton niveau actuel, à un niveau choisi (`/fbis 35`) ou au 60 (`/fbis 60`).
- **Adapté à ta spé** : la spé est détectée selon la branche de talents où tu as le plus de points.
  Les 3 branches portent les noms du jeu (ex. druide : Équilibre, Combat farouche, Restauration).
  Pour Combat farouche, tu choisis le rôle **Félin** ou **Ours**.
- **Double spé** : chaque jeu de talents garde sa spé, et les B.I.S sont recalculés quand tu changes de jeu.
- **Priorité des stats** : affichée dans la fenêtre (ex. Agilité > Force > Toucher > …).
  Elle évolue par tranche de 10 niveaux pendant le leveling, avec un mode Hardcore sur les royaumes hardcore.
- **Talents pris en compte** : le toucher apporté par les talents, les bonus en % de caractéristiques,
  les spécialisations d'arme (dagues, épées, haches…), l'ambidextrie et les armes à deux mains.
- **Uniquement ce que tu peux obtenir** : bonne faction, niveau atteint, armes que ta classe peut manier
  et matériau d'armure de ta classe (pas de tissu pour un druide).
- **Sources des objets** : donjon, boss, quête, métier…
- **Bulles d'objets** : indique si un objet est B.I.S pour ta spé, et à quel emplacement.
- **Bouton de minicarte** et compartiment d'addons.

### Commandes
| Commande | Effet |
|---|---|
| `/fbis` | Ouvrir / fermer la fenêtre |
| `/fbis 60` | B.I.S niveau 60 (ou `/fbis 35` pour un autre niveau) |
| `/fbis talents` | Spé détectée et talents pris en compte |
| `/fbis bulle` | Activer / désactiver les infos dans les bulles d'objets |
| `/fbis minimap` | Afficher / masquer le bouton de la minicarte |
| `/fbis aide` | Aide |

### Comment c'est calculé
Chaque objet reçoit un score : la somme de ses caractéristiques multipliées par la priorité des stats de ta spé.
Le meilleur score de chaque emplacement est ton B.I.S.
Ce n'est pas une simulation : les effets « Équipé : » spéciaux et les bonus de set ne sont pas comptés.
Les loots de boss de raid ne sont pas encore dans les données.

### Installation
Copie le dossier `ForeverBis` dans `World of Warcraft\_forever_\Interface\AddOns\`, puis relance le jeu.
Aucune dépendance.

### Données et crédits
- Priorités de stats pendant le leveling : base Forever de **RXPGuides**, sous licence
  [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (détails dans `LICENSE-DATA.txt`).
- Objets et loots : générés à partir de **Polestar_ItemDB** (dont les données **ForeverLevelingBiS**, licence MIT)
  et **ForeverDungeonJournal**.

---

<a id="english"></a>
## 🇬🇧 English

**Your B.I.S (Best in Slot) gear on WoW Forever, computed for your character: while leveling and at level 60.**

ForeverBis looks at your class, level, faction and talents. It then shows the best item you can get for each
slot, and flags those items right in the item tooltips.

> The in-game interface is in French.

### Features
- **Leveling and level 60 B.I.S**: at your current level, at any level you pick (`/fbis 35`) or at 60 (`/fbis 60`).
- **Spec-aware**: your spec is detected from the talent tree where you spent the most points.
  The 3 trees use the in-game names (e.g. druid: Balance, Feral Combat, Restoration).
  For Feral Combat, you pick the **Cat** or **Bear** role.
- **Dual spec**: each talent loadout keeps its own spec, and your B.I.S are recalculated when you switch.
- **Stat priority**: shown in the window (e.g. Agility > Strength > Hit > …).
  It changes every 10 levels while leveling, with a Hardcore mode on hardcore realms.
- **Talents taken into account**: hit from talents, % stat bonuses, weapon specializations
  (daggers, swords, axes…), dual wield and two-handed weapons.
- **Only what you can get**: right faction, level reached, weapons your class can use
  and your class's armor type (no cloth for a druid).
- **Item sources**: dungeon, boss, quest, profession…
- **Tooltips**: tells you if an item is B.I.S for your spec, and for which slot.
- **Minimap button** and addon compartment entry.

### Commands
| Command | Effect |
|---|---|
| `/fbis` | Open / close the window |
| `/fbis 60` | Level 60 B.I.S (or `/fbis 35` for another level) |
| `/fbis talents` | Detected spec and talents taken into account |
| `/fbis bulle` | Toggle tooltip info |
| `/fbis minimap` | Show / hide the minimap button |
| `/fbis aide` | Help |

### How it works
Each item gets a score: the sum of its stats multiplied by your spec's stat priority.
The highest score in each slot is your B.I.S.
This is not a simulation: special "Equip:" effects and set bonuses are not counted.
Raid boss loot is not in the data yet.

### Installation
Copy the `ForeverBis` folder into `World of Warcraft\_forever_\Interface\AddOns\`, then restart the game.
No dependencies.

### Data and credits
- Leveling stat priorities: **RXPGuides** Forever database, licensed under
  [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (see `LICENSE-DATA.txt`).
- Items and loot: generated from **Polestar_ItemDB** (including **ForeverLevelingBiS** data, MIT license)
  and **ForeverDungeonJournal**.
