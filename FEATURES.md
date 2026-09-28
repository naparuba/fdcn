# Inventaire des fonctionnalités — FDCN/CDSI

Basé sur l'analyse du code de l'application Godot 3.6 (GDScript) et du pipeline de compilation de contenu (Python).

---

## 1. Navigation & écrans (Swiper)

5 pages accessibles par swipe tactile ou clic sur le bandeau supérieur :
- **Main** : chapitre courant, choix, breadcrumb, jauges de progression
- **Chapitres** : liste complète scrollable de tous les chapitres, avec raccourcis de saut par centaine (1/100/200/300/400/500/600)
- **Succès** : liste des succès/réussites avec icônes obtenu/verrouillé
- **Lore** : fiches personnages/dieux illustrées avec narration audio, différentes par livre
- **À propos** : crédits, liens externes, bouton reset

Navigation additionnelle : bouton retour contextuel (`left_backer.gd`, va à la page précédente ou recule dans l'histoire), breadcrumb cliquable (5 derniers chapitres visités, `bread.gd`).

## 2. Récit et choix

- **Choix de chapitre** (`ChapterChoice.gd`) : liste des embranchements possibles depuis le nœud courant, avec indicateurs visuels — déjà vu (session), déjà vu (tous les temps), combat, fin, succès, secret — et sauts conditionnels (activé/désactivé selon objets/type de Billy possédés, avec texte de condition affiché)
- **Écran de fin** (`EndingChoice.gd`) : bonne/mauvaise fin colorée différemment, bouton "Nouveau Billy" (relance) et "Oups" (retour)
- **Combat** : affichage stats ennemi (nom, PV, habileté, dégâts, armure, bonus Pyro) vs stats joueur, dé à lancer (1-6, sprite SVG)

## 3. Écran Options (3 onglets)

- **Équipement** : cocher/décocher des objets (max 3 utiles), sélecteur visuel de type de Billy (grisé si non actif)
- **Stats** : lecture des stats courantes avec décomposition (base/items/chapitres)
- **Sélection de livre** : bascule FDCN ↔ CDSI

## 4. Popups & notifications

- **Popup succès débloqué** (`SuccessPopup.gd`) : animation 5s (fondu 2s + plateau + fondu sortant), son dédié
- **Popup objet gagné/perdu** (`ItemPopup.gd`) : notification auto-disparaissante après 3s, couleur selon gain/perte
- **Popup de confirmation reset** (`GenericConfirmationPopup.gd`) : avant de relancer une partie

## 5. Indicateurs de progression

- Jauge circulaire de complétion globale (X/606 ou X/691 chapitres)
- Barre de progression par acte et par sous-arc (%)
- Affichage du numéro de chapitre courant, du nom de l'acte/sous-arc

## 6. Paramètres persistants (bandeau supérieur, synchronisés sur les 5 pages)

- **Spoils** (ON/OFF) : cache les indicateurs (combat/fin/succès/secret/label) et le contenu des secrets jamais vus
- **Son** (ON/OFF) : coupe toute lecture audio
- **Type de Billy** et **livre courant** : aussi persistés

## 7. Audio

- Son d'intro au démarrage (différent par livre)
- Sons spéciaux sur certains chapitres (FDCN : nœuds 27/193/216/338 ; aucun pour CDSI)
- Narration audio des fiches de lore (par personnage/dieu, par livre)
- Son de déblocage de succès
- Son au changement de type de Billy

## 8. Liens externes

Bug report (GitHub issues), Twitter de l'auteur, wiki "plus de lore", Twitter de l'illustratrice.

## 9. Mécaniques joueur — personnage

- **Type de Billy** (guerrier/prudent/paysan/débrouillard/pégu) déterminé par la composition d'objets possédés (≥2 armes → guerrier, ≥2 équipements → prudent, ≥2 outils → paysan, 1 de chaque → débrouillard, sinon pégu), chacun avec bonus/malus de stats propres
- **Stats** : END/ADR/HAB/CHAMAX/DEG/ARM/CRIT (permanentes, cumulées base+items+chapitres) + PV/CHA/GLOIRE/RICHESSE/NB_INFOS (dynamiques) — 20 types de modificateurs de stats de chapitre gérés (`_apply_chapter_stat`)
- **Inventaire** : catégories ARME/EQUIPEMENT/OUTIL/EVENEMENT/BILLY, limite de 3 objets utiles, acquisition/retrait via chapitre ou via Options, expulsion auto en cas de surcharge

## 10. Progression et sauvegarde

- 3 historiques distincts : chapitre courant, session (partie en cours, reset au nouveau Billy), "tous les temps" (jamais reset)
- Navigation arrière (pile LIFO) et saut direct
- 4 fichiers de sauvegarde par livre (ancien format `.save` binaire + migration vers JSON)
- Migration automatique des anciennes sauvegardes mono-livre, heuristique de reconstitution d'inventaire (`guess_after_migration`) si sauvegarde absente

## 11. Multi-livre (FDCN=1, CDSI=2)

Isolation complète des données et sauvegardes par livre, bascule via l'écran Options, rechargement complet du contexte (chapitres, objets, sons, lore).

## 12. Secrets / spoils (côté données)

Un nœud secret ou atteint par un saut secret n'est montré en détail que si spoils activés ou déjà vu au moins une fois.

## 13. Succès

Déclenchés à la première visite d'un chapitre marqué succès ; table chapitre→succès précompilée pour lookup rapide.

## 14. Conditions

Expressions `$and`/`$or`/`$end` évaluées récursivement contre les objets possédés + type de Billy, pour les sauts conditionnels ET les bonus de stats conditionnels.

## 15. Pipeline de contenu (Python) — modèle et compilation

- **Modèle de nœud** : goto, conditions, secret_jumps, aquire/remove, stats/stats_cond, combat, success, label, ending/ending_id/ending_txt
- **Parseur de conditions** : notation infixe `&`/`|`/`()` → AST → JSON + texte lisible
- **Arcs/actes** : tagging par propagation récursive depuis un point de départ
- **Sous-arcs** : automatiques (avec arrêts, limite de 60 niveaux) ou manuels (liste explicite)
- **Validation de cohérence objets** : tout objet utilisé doit être déclaré et vice-versa ; pas de retrait sans acquisition
- **Génération de graphe visuel** (graphviz) : couleurs par type (fin bonne/mauvaise, succès), regroupement en clusters par arc/sous-arc
- **11 fichiers de sortie compilés** par livre (data, all-objects, combats, endings×3, secrets, success×2, nodes-by-chapter, nodes-by-sub-arc)

**Chiffres livre 1** : ~606 chapitres, 60 objets, 45 combats, 19 fins, 23 secrets, 51 succès, 8 arcs principaux, 11 sous-arcs auto + 1 manuel.
