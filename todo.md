# TODO — fdcn v4

Cases à cocher dérivées de **`review.md`** (qui porte les mesures et le pourquoi de
chaque ligne). Le combat a son propre document : **`combat.md`**.

Lancer la suite avant et après chaque lot :

```bash
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

Dernier état connu : **66 tests, 396 assertions, tout vert.**

---

## P0 — perte de données et angles morts critiques

- [ ] **Confirmer avant d'effacer une partie.** `choice_next_chapiter.launch_new_billy()`
      détruit historique + inventaire + stats sur un simple clic.
      `popups/GenericConfirmationPopup.gd` existe déjà et n'a aucun appelant.
      → review §4.1
- [ ] **Tester `BookData`, en priorité `_check_cond_rec` (`:201`).** C'est lui qui
      décide quels chapitres sont accessibles : logique pure, aucun test. Cas à
      couvrir : `$or`, `$and`, `$end`, imbrication, condition absente, et le
      `return false` implicite en sortie de boucle. → review §1.3.1, §4.5
- [ ] **Rejouer les stats après un retour en arrière.** `jump_back()` dépile le
      chapitre, donc `go_to_node()` le croit neuf et réapplique ses stats.
      `Player.rebuild_chapter_stats()` existe — l'appeler depuis `ui/left_backer.gd`
      et `screens/aventure_menu/breadcrumb.gd`. → review §4.3
- [ ] **Sauvegarder l'état du combat** (`SaveManager.KEY_COMBAT` : chapitre, pv de
      l'ennemi, tour). Fermer l'app au milieu d'un affrontement le perd aujourd'hui.
      → `combat.md` étape 7

## P1 — parité avec l'archive (rien de tout ça ne marche actuellement)

- [ ] **Le son, en entier.** Aucun appel à `Sounder.play()` dans le code vivant :
      pas d'intro de livre, pas de narration de chapitre, pas de son au changement de
      Billy. `Sounder` et l'interrupteur son fonctionnent, il n'y a personne au bout.
      → review §2.1 A
- [ ] **Popup d'objet gagné / perdu.** `Player.go_to_node()` renvoie déjà
      `[gagnés, perdus]`, personne ne consomme la paire. → review §2.1 B
      - [ ] au passage : repli svg→png dans `ItemPopup.gd`, comme `entities/Item.gd`
            (sinon les objets en PNG s'affichent vides) → review §4.9
- [ ] **Popup de nouveau succès** + son jingle. → review §2.1 C
- [ ] **Page Lore** : `screens/LoreMenu.tscn` n'a aucun script. La reconstruire en
      conteneurs par la même occasion (7 nœuds à position fixe aujourd'hui).
      `entities/LoreEntry.gd` existe et sait jouer un son. → review §2.1 D
- [ ] **Page À propos** : aucun script non plus. Boutons rapport de bug, Twitter,
      wiki, auteur, nouveau Billy. À reconstruire en conteneurs (14 nœuds fixes).
      → review §2.1 E
- [ ] **Menu du haut : icônes de page et de Billy.** `$Pages` et `$Billys` sont
      masqués et `set_page()` n'est appelée par personne. **À faire en même temps que
      le passage en conteneurs** (P3), sinon elles se placeront de travers hors 540 px.
      → review §2.1 G, §3.1
- [ ] **Griser le livre non sélectionné** dans la popup de sélection. Le shader
      `gray.gdshader` est déjà utilisé pour les portraits de Billy. → review §2.1 H

## P2 — données de livre mal exploitées

- [ ] Alias manquants : `critique` → `crit`, `pv_1_2_max` → `half_pv`. → review §4.6
- [ ] `rancune` (18 chapitres cdsi) et `respect` (14) sont **jetés** par le `_:` de
      `apply_chapter_stat`. Décider : deux compteurs, ou un axe signé ? par livre, ou
      partagés ? → review §4.6
- [ ] `richesse`, `gloire`, `nb_infos` sont accumulés et sauvegardés mais **affichés
      nulle part**. → review §4.7
- [ ] Trancher les 4 clés ignorées : `1_4_pv_max`, `arc_et_couteau`, `pv_1_4_max`,
      `pv_win_plus_1` — implémenter ou retirer formellement. → review §4.10
- [ ] Combats à plusieurs ennemis : `chapter_data._get_combat()` renvoie `combat[0]`,
      donc la `TROLESSE` de fdcn ch276 n'existe pas pour l'app. → review §4.8
- [ ] Photo d'annulation prise par `Player.go_to_node()` **avant** d'appliquer les
      effets du chapitre. Offrirait un « annuler l'arrivée » pour tout chapitre, pas
      seulement les combats. → review §4.2

## P3 — flex

- [ ] **`ui/top_menu.tscn` → conteneurs.** 19 nœuds à position fixe, 73 offsets, et
      elle est instanciée **sur les 5 pages**. Le chantier le plus rentable du lot.
      → review §3.1
- [ ] `entities/ChapterChoice.tscn` → conteneurs (8 nœuds fixes, 52 offsets, zéro
      conteneur — et instanciée ~15× dans la liste virtualisée). → review §3
- [ ] `EndingChoice`, `ui/left_backer`, `ui/right_nexter` → conteneurs.
- [ ] Les 3 popups (`ItemPopup`, `SuccessPopup`, `GenericConfirmationPopup`) →
      conteneurs. À faire avec P1, puisqu'on y touchera de toute façon.
- [ ] `ui/gauge` : passer de `Node2D` à `Control`, rayon déduit de `size`, supprimer
      le contournement `GaugeSizer`.
- [ ] Trancher la politique des widgets à polygones (`bread`, `NavButon`, rubans) :
      atomes de taille fixe, ou points recalculés depuis `size` dans `_draw()` ?
      → review §3.2
- [ ] Insets de `MenuPage` (nav 50 px, haut 48 px) → constantes de thème.

## P4 — tests et hygiène

- [ ] **`test_case.gd` doit savoir `await`.** C'est ce qui bloque *tous* les tests
      d'interface et de mise en page — dont la classe de bug « lignes qui se
      chevauchent », aujourd'hui invisible pour la suite. → review §1.3.3-4
- [ ] Libérer les nœuds instanciés par les tests : **608 objets fuités** à la sortie,
      ce bruit masquerait une vraie fuite. → review §1.3.5
- [ ] Tester `ui/menu_page.gd` (navigation bloquée quand une popup est ouverte) et
      `ui/top_menu.gd`. → review §1.3.2
- [ ] `entities/LoreEntry.tscn` pèse **2,7 Mo** : externaliser les ressources
      embarquées. → review §5.1
- [ ] Purger les clés Godot 3 de `project.godot` (`[rendering] GLES2`,
      `vram_compression/import_etc`). → review §5.2
- [ ] Supprimer `shaders/shader_grey.tres` (`ShaderMaterial` vide, format Godot 3,
      référencé par personne). → review §5.3
- [ ] Unifier les 3 variantes de décoration de ligne (`ChapterChoice` ×2,
      `success_item`). → review §5.6
- [ ] Helper `_set(clé, valeur)` pour les 4 setters de `Parameters.gd`. → review §5.7
- [ ] Sortir `MIGRATION_GUESS` d'`autoload/inventory.gd` vers `books/<nom>/` : c'est
      du contenu de livre. → review §5.8
- [ ] `chapter_data.gd` : `Node` → `RefCounted`, et libérer les instances au
      changement de livre. → review §5.9
- [ ] Décider la fin de vie d'`archive/` — une fois P1 terminé, elle n'est plus la
      source de vérité de rien. → review §5.5
