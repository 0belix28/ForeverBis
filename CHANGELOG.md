# ForeverBis - Historique des versions

Format des versions : **0.X.Y**
- **X** : mise à jour majeure (nouvelle fonctionnalité importante)
- **Y** : mise à jour mineure (correction, petit ajout)
- Passage en **1.0.0** quand l'addon sera terminé et stable.

Le numéro de version se change à un seul endroit : la ligne `## Version:` de `ForeverBis.toc`.

---

## 0.2.1 - Les 3 spés du jeu
- Les spés sont maintenant exactement les **3 branches de talents** de ta classe, avec les noms lus dans le jeu
  (ex. druide : Équilibre, Combat farouche, Restauration ; voleur : Assassinat, Combat, Finesse ; prêtre : Discipline, Sacré, Ombre).
- Combat farouche : choix du **rôle** félin (dégâts) ou ours (tank) à côté des spés ; il reste en automatique.
- Voleur : dagues ou épées / masses décidé par tes talents de spécialisation d'arme, quelle que soit la branche.
- Priorités de stats RXPGuides du prêtre Discipline / Sacré : elles n'étaient pas lues (espace en trop dans le nom de la spé).

## 0.2.0 - Talents et priorité des stats
- **Spécialisation automatique** depuis tes talents : la branche où tu as mis le plus de points donne la spé
  (arbre de traits de Forever, et onglets de talents classiques).
- **Double spé** : chaque jeu de talents garde sa propre spé ; changer de jeu de talents recalcule les B.I.S et l'annonce dans le chat.
- Bouton « Auto (talents) » ; cliquer une spé la force pour le jeu de talents actif seulement.
  Félin / ours et dagues / épées restent en automatique (variantes de la même branche).
- **Priorité des stats** par classe, spé et tranche de 10 niveaux, issue de la base Forever de RXPGuides
  (Data/StatWeights.lua, généré par Tools/build-weights.js). Hardcore / Speedrun selon le royaume.
  Au niveau 60 et pour les tanks / soigneurs sans données RXPGuides : poids de ForeverBis.
- Ligne « Priorité des stats » dans la fenêtre ; au survol : valeur de chaque stat, origine des poids, talents pris en compte.
- **Talents pris en compte** : toucher des talents (Précision, Précision élémentaire, Suppression...), % de stats
  (Cœur sauvage, Réflexes, Force divine...), spécialisations d'arme, ambidextrie, armes à deux mains.
  Voleur : la spécialisation Dague / Épée choisit entre dagues et épées.
- Vitesse d'arme prise en compte (ex. main gauche rapide pour le voleur).
- `/fbis talents` : spé détectée et talents reconnus (`/fbis debug` puis `/fbis talents` : liste de tous les talents lus).

## 0.1.3 - Matériau d'armure par classe
- Les pièces d'armure (tête, épaules, torse, poignets, mains, taille, jambes, pieds) ne sont choisies que dans le matériau principal de ta classe : tissu (mage, prêtre, démoniste), cuir (voleur, druide ; chasseur et chaman avant 40), mailles (chasseur et chaman dès 40 ; guerrier et paladin avant 40), plaques (guerrier et paladin dès 40).
- S'il n'existe aucune pièce de ce matériau pour un emplacement à ton niveau (ex. juste après 40), on prend le matériau juste en dessous.
- Bulles d'objets : « Matériau non optimisé pour ta classe » sur une pièce d'un matériau inférieur.
- Les capes, bijoux, anneaux et colliers ne sont pas concernés.

## 0.1.2 - Bouton de la minicarte
- Ajout d'un vrai bouton autour de la minicarte (avec le logo), comme ForeverEgo : il apparaît aussi dans les barres qui regroupent les boutons de minicarte.
- Clic gauche : ouvrir / fermer. Clic droit : B.I.S niveau 60. Glisser : déplacer.
- `/fbis minimap` : afficher / masquer le bouton.

## 0.1.1 - Icône

- Logo de l'addon (bouclier bleu et étoile dorée) : `Media/Logo.tga`, affiché dans le compartiment d'addons
  de la minicarte, la liste des addons et l'en-tête de la fenêtre `/fbis`.
- `Tools/build-logo.js` régénère le logo (`node ForeverBis/Tools/build-logo.js`).

## 0.1.0 - Première version

- Fenêtre `/fbis` : le B.I.S de chaque emplacement (tête → distance) pour **ton** personnage
  (classe, faction, spécialisation choisie), avec l'endroit où l'obtenir et le statut
  (✓ Équipé, +X % par rapport à l'équipé, niveau requis).
- Choix du niveau : ton niveau actuel (leveling), n'importe quel niveau avec `<` `>`, ou **Niveau 60 (fin de jeu)**.
- Spécialisation au choix (mémorisée par personnage), poids de caractéristiques propres à chaque spé,
  ajustés pendant le leveling (endurance / esprit plus utiles, toucher moins utile).
- Armes : compare deux mains contre main droite + main gauche (bouclier, objet tenu, ambidextrie selon la classe).
- Bulles d'objets : **★ B.I.S actuel**, **★ B.I.S au niveau X**, **★ B.I.S niveau 60** ou « Pas ton B.I.S »,
  plus le gain / la perte par rapport à l'objet porté.
- Sources : donjons et quêtes de donjon de ForeverDungeonJournal (y compris les donjons propres à Forever),
  quêtes, drops et métiers de Polestar_ItemDB (stats Forever). Les objets Forever sans stats hors-ligne sont lus en jeu.
- Options : artisanat, drops rares, raids, JcJ, objets sans source connue, qualité minimale, infos dans les bulles.
- Message au passage de niveau quand un meilleur B.I.S est disponible.
