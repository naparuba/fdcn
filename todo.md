# TODO — fdcn v4

Cases à cocher dérivées de **`review.md`** (qui porte les mesures et le pourquoi de
chaque ligne). Le combat a son propre document : **`combat.md`**.

Lancer la suite avant et après chaque lot :

```bash
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

Dernier état connu : **68 tests, 408 assertions, tout vert.**

---

## P0 — perte de données et angles morts critiques

- [x] **Confirmer avant d'effacer une partie.** ✅ 2026-08-11 — passe par
      `GenericConfirmationPopup`, ouverte via le nouveau `MenuPage.open_popup()`. Sans
      conteneur de popup, l'action ne fait **rien** plutôt que d'effacer en silence.
      → review §4.1
- [ ] **Tester `BookData`, en priorité `_check_cond_rec` (`:201`).** C'est lui qui
      décide quels chapitres sont accessibles : logique pure, aucun test. Cas à
      couvrir : `$or`, `$and`, `$end`, imbrication, condition absente, et le
      `return false` implicite en sortie de boucle. → review §1.3.1, §4.5
- [x] **Rejouer les stats après un retour en arrière.** ✅ 2026-08-11 — nouveau
      `Player.go_back_to()` qui dépile, renavigue et refait la couche « chapitres ».
      Les 4 sites qui enchaînaient à la main passent par lui. Bug confirmé réel
      (habileté 3 → 4 par aller-retour), verrouillé par un test vérifié comme échouant
      sans le correctif. → review §4.3
- [~] **Sauvegarder l'état du combat** — ⏸️ **écarté** (décision produit, 2026-08-11).
      Fermer l'app pendant un affrontement le perd, c'est assumé. ⚠️ À savoir : les pv
      déjà dépensés **restent** perdus (ils sont sauvegardés), donc reprendre un combat
      interrompu est désavantageux. → review §4.4

- [ ] 🔴 **Réparer la branche des fins dans `scripts/fdcn.py`, et NE PAS RECOMPILER
      avant.** `goto = [goto]` (introduit le 2026-08-10) rend `if isinstance(goto, int)`
      toujours faux : tout le bloc des fins est **inatteignable**, y compris l'unique
      `set_ending()` du dépôt et ses deux validations. Les json compilés datent du
      2026-08-09, donc **la veille** — ils sont corrects mais plus reproductibles.
      Recompiler viderait `endings` / `good-endings` / `bad-endings` et mettrait
      `computed.ending` à faux partout, **sans un seul message d'erreur**.
      → review §5ter.1

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
- [~] **Page À propos** : ✅ 2026-08-11 — `screens/about_menu.gd` branche **nouveau
      Billy** (avec confirmation), **rapport de bug** et **Twitter**. Restent les liens
      **auteur** et **wiki**, et la reconstruction en conteneurs (14 nœuds fixes).
      → review §2.1 E
- [ ] **Menu du haut : icônes de page et de Billy.** `$Pages` et `$Billys` sont
      masqués et `set_page()` n'est appelée par personne. **À faire en même temps que
      le passage en conteneurs** (P3), sinon elles se placeront de travers hors 540 px.
      → review §2.1 G, §3.1
- [x] **Griser le livre non chargé** dans la popup de sélection. ✅ 2026-08-11 —
      `gray.gdshader`, un matériau par couverture, repeint sur `book_changed`.
      → review §2.1 H

## P1bis — export / import d'une sauvegarde en zip

Chantier neuf, spec complète en **review §4bis**. À faire tôt : c'est le seul de P1 qui
soit **entièrement testable sans interface ni appareil** (le lanceur sandboxe déjà
`SaveManager.base_dir`).

- [ ] **Moteur d'archive**, découplé du transport : empaqueter les 7 clés × chaque livre
      + `parameters.json` + un `manifest.json`, avec `ZIPPacker` (**natif dans Godot
      4.7.1, vérifié** — pas de rar, format propriétaire sans encodeur).
      → review §4bis.2
- [ ] **Import atomique**, dans cet ordre strict : décompresser dans
      `user://import_tmp/` → tout valider (fichiers attendus, JSON qui parse,
      `save_version` connue et pas future) → **sauvegarder l'état actuel dans
      `user://backup-avant-import.zip`** → basculer → `Player.do_load()`.
      Un import à moitié appliqué donne une sauvegarde Frankenstein, pire qu'un import
      raté. → review §4bis.4
      - [ ] Rien à réimplémenter pour les vieilles archives : `prepare_save()` migre
            déjà et refuse déjà une version future.
      - [ ] Dépend de la confirmation avant écrasement — **même
            `GenericConfirmationPopup` que le premier point de P0**.
- [ ] **Transport, par plateforme** (le zip est le problème facile, sortir du bac à
      sable est le vrai) : `FileDialog` sur desktop d'abord ; **Android** (`user://` est
      privé, scoped storage API 30+) et **HTML5** (IndexedDB, téléchargement via
      `JavaScriptBridge`, import via `<input type=file>`) en chantiers séparés.
      → review §4bis.3
- [ ] Poser l'entrée dans la page **À propos**, qui est déjà à construire : une scène
      au lieu de deux. → review §4bis.5
- [ ] Tests : aller-retour complet, archive tronquée, archive de version future,
      archive d'un seul livre. → review §4bis.6

## P2 — données de livre mal exploitées

- [ ] **Registre des livres** (`books/books.json` ou scan de `books/*/`) : `{nom, titre,
      couverture}`. Aujourd'hui il n'en existe **aucun**, et la popup de sélection *est*
      la liste — une méthode et un `TextureButton` codés en dur par livre. Le registre
      rend `BookSelection` piloté par les données et ramène l'ajout d'un livre à
      « déposer un dossier, compiler, ajouter une ligne ». → review §2bis.6
- [ ] Trancher **`images/dieux/<n>` → `dieux/<nom>/`** *avant* d'écrire la page Lore,
      sinon elle héritera d'une numérotation que le reste du dépôt a abandonnée.
      → review §2bis.5

- [ ] **Corriger les orthographes à la source** (c'est un défaut de saisie, pas de
      moteur) : `critique`→`crit` (×5) et `pv_1_2_max`→`half_pv` dans `cdsi.json`,
      unifier `pv_1_4_max`/`1_4_pv_max` dans `fdcn.json`. Vérifié : le compilateur
      recopie les clés telles quelles, ce sont bien les sources qui divergent.
      → review §4ter.2bis
- [ ] **Faire échouer `scripts/fdcn.py` sur une clé de stat hors vocabulaire.** Il les
      collecte et les **imprime déjà** (`:374`, via `node.get_all_stats_keys()`) — il
      manque juste la liste de référence et un `sys.exit(2)`, comme il en fait déjà un
      ailleurs. `critique` était listé à chaque compilation de cdsi, noyé dans les traces.
      → review §4ter.2bis
- [ ] **Notation d'effet** au lieu d'un mot-clé par règle. Une valeur **numérique** garde
      le sens additif actuel (aucune migration des ~200 entrées chiffrées) ; une **chaîne**
      porte l'opérateur puis une expression sur `max` (le plafond) et `moi` (la valeur
      courante) : `"pv": "= max/4"`, `"pv": "= moi/2"`, `"pv": "- max/2"`,
      `"chance": "= max"`. **Absorbe 6 mots-clés existants** (16 occurrences) :
      `max_pv`, `max_chance`, `half_pv`, `pv_1_4_max`, `1_4_pv_max`, `pv_1_2_max`.
      → review §4ter.2quater
      - [ ] ⚠️ **À vérifier dans le livre AVANT d'unifier les orthographes** : `half_pv`
            (fdcn ch323) fait aujourd'hui `pv /= 2`, soit la moitié du **courant**, alors
            que `pv_1_2_max` (cdsi ch249) dit « max ». Si ce sont deux règles différentes,
            les fusionner serait une régression silencieuse.
- [ ] **`pv_win_plus_1` → `pv_gain`** : un modificateur de gain (« gagner 1 pv en donne
      2 »), pas un effet ponctuel. Un `_gain_bonus` par ressource, **dans la couche
      chapitres** (donc remis à zéro et rejoué comme `pv_max_bonus`), appliqué dans
      `add_pv()` **uniquement sur un delta positif** — un bonus de gain ne doit pas
      amortir les dégâts — et **jamais sur une affectation**, sinon « pv au plein »
      devient « au plein + 1 ». → review §4ter.2sexies
- [ ] **`arc_et_couteau`** : rien à faire côté condition ni objets — vérifié, l'arbre
      `$and` sur ARC + COUTEAU s'évalue déjà correctement et les deux objets existent.
      Seul **l'effet** manque, et il n'est dans aucune donnée. → mettre la clé dans
      `ignorees` pour éteindre l'avertissement, en gardant la trace du trou.
      → review §4ter.2quinquies
- [ ] **Vocabulaire de stats déclaré par livre** — `books/<nom>/<nom>.vocabulaire.json`
      avec **deux** listes : `compteurs` (clé + libellé affiché) et `ignorees` (les trous
      assumés). Pas de liste d'alias : les orthographes se corrigent à la source, les
      entretenir dans le moteur serait entretenir la faute.
      Mesuré : chaque livre a **un compteur commun (`richesse`) + deux qui lui sont
      propres** — `gloire`/`info` pour fdcn, `rancune`/`respect` pour cdsi, zéro
      croisement. Donc `PlayerStats` perd ses 3 variables en dur pour un dictionnaire,
      et la feuille de stats **génère** ses lignes depuis le livre courant.
      ⚠️ Piège : toute clé inconnue n'est **pas** un compteur — `critique` est une stat
      en couches mal orthographiée, la traiter en compteur donnerait « Critique : 5 » au
      lieu de +5 dégâts critiques. Prépare le 3ᵉ livre. → review §4ter
- [ ] Implémenter `rancune` / `respect` (cdsi) — devient trivial une fois le vocabulaire
      en place : deux entrées de `compteurs`. → review §4ter
- [x] `richesse` et `gloire` ont leur ligne dans la feuille de stats. ✅ 2026-08-11 —
      sans ventilation (ce sont des compteurs, pas des stats en couches). **`nb_infos`
      volontairement laissé masqué.** ⚠️ Lignes **en dur** : « Gloire » affichera 0 pour
      toujours sur cdsi, qui ne l'utilise jamais — corrigé par le vocabulaire par livre.
      → review §4.7, §4ter.1
- [ ] ~~Trancher les 4 clés ignorées~~ → absorbé par le vocabulaire par livre : elles
      deviennent sa liste `ignorees`. → review §4ter
- [ ] Combats à plusieurs ennemis : `chapter_data._get_combat()` renvoie `combat[0]`,
      donc la `TROLESSE` de fdcn ch276 n'existe pas pour l'app. → review §4.8
- [ ] Photo d'annulation prise par `Player.go_to_node()` **avant** d'appliquer les
      effets du chapitre. Offrirait un « annuler l'arrivée » pour tout chapitre, pas
      seulement les combats. → review §4.2

## P3 — style et flex

- [ ] **Créer un thème global `themes/fdcn.tres`** et le déclarer dans `project.godot`
      (`gui/theme/custom`). Il n'en existe **aucun** aujourd'hui : le look de l'app vient
      de **563 `theme_override_*` posés nœud par nœud** dans 31 scènes. C'est pour ça que
      la popup de confirmation « ne suit pas le style » — c'est le seul widget qui n'en a
      presque pas, donc le seul qui montre le thème par défaut de Godot.
      **À faire AVANT le reste de P3** : les scènes à repasser en conteneurs traînent
      chacune leur habillage, et avec le thème en place la réécriture les **supprime** au
      lieu de les recopier. → review §5bis
      - [ ] entrées évidentes : les 2 polices (135 surcharges), la couleur de texte
            (85×), le trio anti-ombre (**55 `Label` ne font que désactiver un défaut de
            Godot**), l'accent `#00c2aa` (27×), le bleu nuit `#313b47` (14×), le gris
            `#e9eaec` (14×).
      - [ ] purger les surcharges scène par scène ensuite, en commençant par
            `GenericConfirmationPopup` — et la convertir depuis le **format Godot 3**
            (`format=2`, `theme_override_fonts/normal_font`).
      - [ ] supprimer `themes/side_buttons_background_style.tres`, référencé par
            personne, dont la couleur est recopiée 14 fois ailleurs.
- [x] **`ui/top_menu.tscn` → conteneurs.** ✅ 2026-08-11 — 0 nœud fixe, 20 conteneurs.
      Les `Sprite2D` sont devenus des `TextureRect` (un `Node2D` ne peut **pas** être
      positionné par un conteneur), les `Block*` des `PanelContainer`. 🔴 Deux styleboxes
      **partagées** séparées au passage : `OptionsBtn` avec `BlockMain`, `BlockOptions`
      avec `BlockDebrouillard` — or `set_page()`/`set_billy()` les **mutent**, donc
      choisir une page recolorait le bouton d'options. → review §3.1
- [ ] ⚠️ Avant l'action « dé-masquer `$Pages`/`$Billys` » : tout afficher demande ~780 px
      de large pour 540 disponibles. Trancher (spoils/son dans la popup ? icônes plus
      petites ?). → review §3.1
- [ ] `entities/ChapterChoice.tscn` → conteneurs (8 nœuds fixes, 52 offsets, zéro
      conteneur — et instanciée ~15× dans la liste virtualisée). → review §3
- [~] `EndingChoice`, `ui/left_backer`, `ui/right_nexter` → **bloqués par la géométrie
      manuelle** (polygones + rotations), pas par du travail de conversion. Ils attendent
      la décision sur les polygones ci-dessous. Idem `ChapterChoice` (6 polygones,
      6 rotations) et `bread`/`NavButon`. → review §3.1bis
- [x] `GenericConfirmationPopup` → conteneurs. ✅ 2026-08-11 — boîte centrée par un
      `CenterContainer` avec voile sombre, au lieu d'un offset fixe (16, 256) qui la posait
      de travers hors 540 px.
- [ ] `ItemPopup` et `SuccessPopup` → conteneurs, **avec** leur branchement (P1) : les
      animations de `SuccessPopup` ciblent des chemins de nœuds et des `scale`, les
      restructurer casse les pistes. → review §3.1bis
- [ ] ⚠️ 5 scènes encore au **format Godot 3** (`left_backer`, `EndingChoice`, `LoreEntry`,
      `ItemPopup`, `SuccessPopup`), dont 3 utilisent l'API `align`/`valign` des `Label`
      **qui n'existe plus en Godot 4** : leur alignement est silencieusement perdu.
      → review §3.1bis
- [ ] `ui/gauge` : passer de `Node2D` à `Control`, rayon déduit de `size`, supprimer
      le contournement `GaugeSizer`.
- [ ] Trancher la politique des widgets à polygones (`bread`, `NavButon`, rubans) :
      atomes de taille fixe, ou points recalculés depuis `size` dans `_draw()` ?
      → review §3.2
- [ ] Insets de `MenuPage` (nav 50 px, haut 48 px) → constantes de thème.

## P3bis — compilateur Python (`scripts/`)

Review complète en **review §5ter**. Ne pas recompiler un livre avant le premier point
de P0.

- [ ] **Valider le vocabulaire de stats et sortir en erreur** sur une clé inconnue. Le
      script les collecte et les imprime déjà (`fdcn.py:374`). → review §4ter.2bis
- [ ] **Des niveaux de log** (`--verbose`) : 66 `print()` noient les validations utiles
      (secrets à deux entrées, fin sans type, objets sans chapitre). C'est ce qui a laissé
      passer `critique`. → review §5ter.2
- [ ] **Découper `fdcn.py`** : 405 lignes à plat, **aucune fonction** hors
      `load_json_file`, **40 variables globales** mutées au fil du fichier. Au minimum
      `lire_les_noeuds()` / `taguer_les_arcs()` / `construire_le_graphe()` /
      `ecrire_les_json()`. Le graphviz est le candidat évident à l'extraction : c'est la
      moitié du fichier et l'app ne s'en sert pas. → review §5ter.2
- [ ] **Sortir la présentation graphviz de `node.py`** — `get_label()` renvoie du HTML
      coloré depuis le modèle de données. → review §5ter.2
- [ ] Nettoyer : code commenté laissé en place, deux commentaires « Get the combat entry
      if any » d'affilée dont un sur le bloc `secret`, annotations de type en commentaire
      Python 2, `get_all_stats_keys()` qui imprime. → review §5ter.2
- [ ] Le cas particulier `goto == 608 and book_number == 1` (fdcn) devra être contourné
      par un 3ᵉ livre. → review §2bis.3

## P4 — tests et hygiène

- [ ] **`test_case.gd` doit savoir `await`.** C'est ce qui bloque *tous* les tests
      d'interface et de mise en page — dont la classe de bug « lignes qui se
      chevauchent », aujourd'hui invisible pour la suite. → review §1.3.3-4
- [ ] Libérer les nœuds instanciés par les tests : **608 objets fuités** à la sortie,
      ce bruit masquerait une vraie fuite. → review §1.3.5
- [ ] Tester `ui/menu_page.gd` (navigation bloquée quand une popup est ouverte) et
      `ui/top_menu.gd`. → review §1.3.2
- [x] **Épingler le livre dans le bac à sable des tests.** ✅ 2026-08-11 — la suite
      héritait du livre choisi dans l'app ; 54 assertions ont basculé le jour du passage
      à cdsi. `SANDBOX_BOOK = "fdcn"` dans `test_runner.gd`. → review §1.3
- [ ] `entities/LoreEntry.tscn` pèse **2,7 Mo** : externaliser les ressources
      embarquées. → review §5.1
- [x] **`graph/` sorti du projet Godot.** ✅ 2026-08-11 — 11 Mo de sorties graphviz
      importées par Godot pour rien (aucun code ne les référence). Déplacé dans
      `scripts/graph/`, `.import` supprimés, et un `scripts/.gdignore` fait ignorer tout
      l'outillage python à Godot.
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
