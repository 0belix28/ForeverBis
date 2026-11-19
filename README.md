# ForeverBis

Affiche tes **B.I.S** (Best in Slot) sur WoW Forever, pour le personnage connecté :
pendant le leveling (à ton niveau) et au niveau 60.

## Commandes
- `/fbis` : ouvrir / fermer la fenêtre (aussi depuis le compartiment d'addons de la minicarte)
- `/fbis 60` : ouvrir directement les B.I.S niveau 60 (ou `/fbis 35` pour un autre niveau)
- `/fbis bulle` : activer / désactiver les infos dans les bulles d'objets
- `/fbis talents` : spécialisation détectée et talents pris en compte
- `/fbis minimap` : afficher / masquer le bouton de la minicarte
- `/fbis aide`

## Comment c'est calculé
Chaque objet que ta classe peut porter et que tu peux obtenir (bonne faction, niveau atteint, matériau d'armure de
ta classe) reçoit un score : somme de ses caractéristiques × la **priorité des stats** de ta spécialisation.
Le meilleur score de chaque emplacement est ton B.I.S. Ce n'est pas une simulation : les effets « Équipé : »
spéciaux et les bonus de set ne sont pas comptés.

- **Spécialisation** : déduite de la branche de talents où tu as mis le plus de points. Double spé : chaque jeu de
  talents garde sa spé, et un changement de jeu de talents recalcule les B.I.S. Un clic sur une spé dans la fenêtre
  la force pour le jeu de talents actif ; « Auto (talents) » revient à la détection.
- **Priorité des stats** : pendant le leveling, poids par tranche de 10 niveaux de la base Forever de RXPGuides
  (mode Hardcore sur un royaume hardcore, sinon Speedrun). Au niveau 60, et pour les spés sans données RXPGuides
  (tanks, soigneurs paladin / chaman / druide), poids de `Weights.lua`.
- **Talents** : les talents reconnus ajustent les poids (toucher apporté par les talents, % de caractéristiques,
  spécialisations d'arme, ambidextrie, armes à deux mains). Liste dans `Talents.lua` (noms anglais et français).

## Données
- `Data/Items.lua`, `Data/Sources.lua` : générés par `Tools/build-data.js` à partir de **Polestar_ItemDB**
  (stats Classic + Forever) et **ForeverDungeonJournal** (loots et quêtes de donjon).
  Après une mise à jour de ces addons : `node ForeverBis/Tools/build-data.js` depuis le dossier AddOns.
- `Data/StatWeights.lua` : généré par `Tools/build-weights.js` à partir de **RXPGuides** (licence CC BY-NC-SA 4.0,
  voir `LICENSE-DATA.txt`) : `node ForeverBis/Tools/build-weights.js` depuis le dossier AddOns.
- Les objets Forever absents de ces données sont lus en jeu et gardés dans `ForeverBisDB`.
- Les loots de boss de raid ne sont pas dans les données : l'option « Raids » n'ajoute que le stuff de raid obtenu
  par quête, drop ou métier.
