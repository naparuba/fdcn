# TODO — fdcn v4

Cases à cocher dérivées de **`review.md`** §10, même numérotation **catégorie.rang**. Les
mesures et le *pourquoi* de chaque ligne sont dans la review ; le combat a son propre
document, **`combat.md`**.

**Ce fichier ne contient que ce qui reste à faire.** Ce qui est terminé en est retiré —
l'historique est dans `git log`.

Suite de tests, à ne lancer que sur demande :

```bash
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

⚠️ Dernier passage vert : **68 tests** — la suite en compte maintenant **146**, et elle n'a
plus tourné depuis. Se sont ajoutés : les pouvoirs de Billy (8), la notation d'effet et les
compteurs (14), le registre et le rangement des livres (10), **`BookData` et son évaluateur
de conditions** (13), **l'archive de sauvegarde** (13), et les **deux premiers tests
d'interface** — `menu_page` et `top_menu` (15), qui exercent enfin un `_ready()`.

⚠️ **Le lanceur est devenu asynchrone** (`await`) : `test/all.gd` et `test/all.tscn`
l'attendent désormais. Les dix autoloads ont tous été relus — la suite mérite vraiment un
passage avant de continuer.

✅ **`archive/` et `sample.json` supprimés** (2026-08-21). La parité avec l'ancienne app
étant atteinte, la copie de référence (`archive/src/`, `archive/unuzed/`, dont les 24 assets
orphelins ci-dessous) n'avait plus d'usage ; `sample.json` n'était référencé nulle part. Les
`print()` de trace pure (clics, boutons, ouverture/fermeture de popup) ont aussi été retirés
des scripts hors tests — ne restent que ceux qui signalent un événement ou une anomalie
(convention de review.md §1.2).

✅ **Générateur et données remis d'équerre** (2026-08-13). `fdcn.py` est devenu
`scripts/generator.py`, il lit **toute** sa source dans `scripts/src/<nom>/` et n'écrit plus
que ce que l'app ouvre. Les json des livres sont passés de **1 340 à 388 Ko** dans la
journée, à contenu strictement identique pour l'app — vérifié clé par clé sur les
1 297 chapitres. Les deux README (`scripts/`, `books/`) décrivent l'état actuel.

⚠️ **Contrat à ne pas casser** : `Node.NEUTRES` (générateur) et les `.get(clé, défaut)` de
`entities/chapter_data.gd` (app) doivent lister les **mêmes 17 clés avec les mêmes valeurs**.
Une clé absente veut dire « rien à signaler ». `test_book_data.gd` le vérifie.

⚠️ **Godot va réimporter au prochain démarrage de l'éditeur** : le contenu des livres a
changé de place (`books/<nom>/data|img|audio/`, et la source dans `scripts/src/`). Les 24
assets orphelins repérés à cette occasion ont fini dans `archive/unuzed/assets/`, supprimé
depuis (voir ci-dessus). Les **images de livre** ont
emporté leur `.import`, donc leur **uid est intact** ; les **6 mp3** ont perdu le leur
(aucune scène ne les référençait), Godot le régénérera.

---

✅ **Les deux règles transcrites de mémoire, vérifiées** (2026-08-22). **cdsi ch176**
("Nouvelle-Nouvelle-Azur") ne fait que donner le `TONIQUE MYSTERIEUX` : le
`"stats": {"pv_max": true}` qui trainait dessus était erroné et a été retiré. **cdsi ch249**
("Le Palais") redonne bien la moitié des pv en soin, pas une remise à plat : `"pv": "= max/2"`
est devenu `"pv": "+ max/2"`. Source et données recompilées (`scripts/src/cdsi/cdsi.json`,
`books/cdsi/data/`).

## 2 — Export / import d'une sauvegarde en zip

À faire tôt : c'est le seul chantier de cette liste **entièrement testable sans interface
ni appareil**.

- [ ] **2.3** **Vérifier l'export / import sur un vrai téléphone.** Le code est écrit et ne
      demande **aucune permission** : il passe par le sélecteur de documents du système
      (Storage Access Framework), que Godot 4.7.1 expose sous `FEATURE_NATIVE_DIALOG_FILE`
      — vérifié dans le binaire, `_MIME` compris, d'où le filtre `application/zip` au lieu
      de `*.zip`. Ce qui reste à constater sur appareil, et **seulement là** :
      - le sélecteur s'ouvre bien à l'export **et** à l'import ;
      - le chemin rendu par le système est lisible par `FileAccess` (l'export le vérifie
        déjà et le dit s'il ne l'est pas) ;
      - l'archive est visible depuis Téléchargements / Drive une fois écrite.
      Si le SAF ne rendait pas un chemin utilisable, le repli est déjà là : écriture dans
      le dossier de l'app et reprise de la dernière archive locale. → review §5.3

## 3 — Données de livre

**Plan d'ensemble : review §3.7.** Les quatre lignes ci-dessous sont ses étapes, dans
l'ordre — la 3.2 d'abord, parce que c'est elle qui rend les suivantes sûres.

- [ ] **3.2** **Le générateur doit refuser ce qu'il ne comprend pas** — étape 1 du plan,
      aucun changement de format :
      - **clé de chapitre inconnue** → erreur (aurait attrapé le `cond` de cdsi) ;
      - **clé de stat hors vocabulaire** → erreur : il les collecte et les **imprime déjà**,
        il manque la liste de référence et un `sys.exit(2)` (aurait attrapé `critique`) ;
      - **`success` inconnu** → erreur au lieu d'une trace Python ;
      - **expression malformée** → message, au lieu du code 2 muet ;
      - **`&` et `|` mélangés sans parenthèses** → refus, au lieu d'un arbre faux en silence.
      ⚠️ **Et rattraper les données, qui ont pris de l'avance le 2026-08-13** : ne plus
      écrire les 5 sorties que personne ne lit (supprimées — le compilateur ne touche plus à
      `archive/`, lui-même supprimé du dépôt le 2026-08-21), ne plus écrire les **trois
      copies enrichies** — `-compilated-success-chapters`, `-compilated-success` et
      `-compilated-all-objects` — qui répétaient des valeurs de `<nom>.all_success.json` et
      `<nom>.all_objects.json` (supprimées : l'app lit les fichiers de l'auteur et les
      complète au chargement), ne plus recopier la source dans
      `-compilated-data.json` et l'écrire **à plat** (déjà fait dans les données ;
      `chapter_data.gd` accepte les deux formes en attendant).
      → review §3.7 *Plan*, §4.2
- [ ] **3.8** **Un seul fichier de tables par livre** (`<nom>.livre.json`) — étape 2. Les
      six fichiers sont déjà réunis dans `scripts/src/<nom>/` (2026-08-13) ; reste à les
      fondre et surtout à passer **à des champs nommés**. Aujourd'hui un sous-arc est un
      tableau positionnel de 4 champs (`["Invasion", 148, "…", [496, 285, 353]]`) où
      intervertir deux valeurs ne produit aucune erreur. ⚠️ **Ne pas** déplacer l'acte dans
      le chapitre : 8 lignes couvrent 606 chapitres par propagation. → review §3.7 *Plan*
- [ ] **3.13** **Le pipeline visé : `src/` → `gen/` → `books/`.** La moitié est faite
      (2026-08-13 : tout ce qui s'écrit à la main est dans `scripts/src/<nom>/`, et le
      compilateur y recopie les objets et succès vers `books/`). Reste à écrire :
      - le compilateur **produit dans `scripts/gen/<nom>/data/`**, puis **copie** vers
        `books/<nom>/data/` — une étape de génération, une étape de livraison, chacune
        vérifiable séparément ;
      - `books/<nom>/data/` devient **entièrement généré**, donc jetable et regénérable ;
      - ⚠️ à décider en même temps : `gen/` est-il commité, ou seulement `books/` ? Deux
        copies commitées du même contenu se contrediraient à la première compilation
        oubliée. Mon avis : `gen/` dans le `.gitignore`, `books/` commité — c'est lui que
        l'app embarque.
      ⚠️ **Un seul point d'entrée existe déjà** : `python3 scripts/generator.py --book <nom>`.
      `node.py`, `graph.py`, `condition_node.py`, `endings.py`, et depuis 2026-08-22
      `graph_render.py` et `logger.py`, ne se lancent pas, ce sont des modules qu'il importe.
      Les fondre en un fichier irait **contre 4.2 et 4.3** (réglés le 2026-08-22), qui ont au
      contraire découpé `generator.py` en fonctions et sorti la présentation graphviz de
      `Node` — à trancher.
- [ ] **3.9** **Squelette de livre** : `--nouveau <nom>` crée le dossier, deux fichiers
      valides et l'entrée du registre — un livre neuf part de quelque chose **qui compile**.
      → review §3.7 *Plan*
✅ **3.11 fait** (2026-08-22) : `books/README.md` a sa section « Remplir un livre à la
main » — format de chaque clé de chapitre avec un exemple réel tiré de `fdcn.json`, le
langage des conditions et ses trois pièges, la propagation des actes (8 déclarations
couvrent les 606 chapitres de fdcn, 10 les 691 de cdsi — mesuré, pas la « 19 » approximative
d'avant), et une liste de vérification avant la première compilation. ⚠️ Décrit le format
**actuel** (6 fichiers) : à revoir quand 3.8 fondra tout en `<nom>.livre.json`.

✅ **3.10 fait** (2026-08-22) : un objet cité **uniquement** dans un `stats_cond` compte
désormais comme utilisé (`Node.get_all_stats_cond_tokens()`), ne fait plus échouer la
compilation à tort — aucun des deux livres n'avait de cas réel, recompilation identique
octet pour octet.

- [ ] **3.4** **`pv_gain`** : modificateur de gain dans la couche chapitres, **delta positif
      seulement** (un bonus de gain ne doit pas amortir les dégâts) et **jamais sur une
      affectation** (sinon « pv au plein » dépasse le plafond). → review §4.5
- [ ] **3.5** **Compléter les déclarations du livre avec `ignorees`** : les `compteurs` sont
      faits (`books/<nom>/data/compteurs.json`, `PlayerStats._compteurs`, lignes de la
      feuille de stats générées), il reste à y déplacer
      `PlayerStats._CHAPTER_UNMANAGED_KEYS`. Dépend des « règles ponctuelles » — **§4.3, à
      trancher d'abord**. Pas de liste d'alias : les orthographes se corrigent à la source
      (**3.1**). → review §4.6
- [ ] **3.6** **Réunir les 3 sorties compilées en un seul fichier** — étape 3 du plan. Le
      poids, lui, est réglé (2026-08-13 : plus de source recopiée, puis plus de valeurs
      neutres — **391 → 149 Ko** pour fdcn, 442 → 173 pour cdsi). Reste que `BookData` ouvre
      cinq fichiers là où un suffirait. → review §3.6, §3.7 *Plan*
✅ **3.7 fait** (2026-08-22) : `images/dieux/1|2` et `sounds/dieux/1|2` renommés en
`dieux/fdcn/` et `dieux/cdsi/`, `entities/LoreEntry.gd` prend `book_name` au lieu de
`book_number`.

## 4 — Compilateur Python (`scripts/`)

Les deux livres ont été recompilés le 2026-08-12, branche des fins réparée : fdcn inchangé
(19 fins), **cdsi a gagné les 16 siennes**. `graphviz` est désormais facultatif — sans lui,
tous les json sortent, seul le png de relecture manque.

✅ **4.1 à 4.4 réglés** (2026-08-22) — recompilation des deux livres vérifiée **octet pour
octet identique** avant/après, `--verbose` et `--book <numéro>` testés :

- **4.1** `--verbose` sépare la trace par nœud/arc de ce qui compte (résumé, avertissement,
  erreur) : silencieux, un run de fdcn passe de 2 050 à 56 lignes. `scripts/logger.py`
  (`trace()` / `info()`).
- **4.2** `generator.py` découpé en fonctions — `lire_les_noeuds()` / `taguer_les_arcs()` /
  `construire_le_graphe()` / `ecrire_les_json()`, plus `main()` — plus une seule variable
  globale mutée en cours de script.
- **4.3** La présentation graphviz (`get_label()`, couleurs, ajout au graphe) a quitté
  `Node` pour `scripts/graph_render.py` : le modèle de données ne sait plus rien de
  graphviz, `graph.py` délègue.
- **4.4** Code mort retiré : `node_created` (inutile), les accesseurs jamais appelés
  (`have_combat`, `is_good_ending`, `is_bad_ending`, `have_ending`, `get_ending_id` —
  bien les vestiges des accumulateurs supprimés le 2026-08-13), tout le code commenté de
  `condition_node.py` et `graph.py`, les annotations de type en commentaire Python 2
  (`# type: ...`) devenues de vraies annotations, `get_all_stats_keys()` qui imprimait à
  chaque appel. Au passage : le `print` « skipping not related edge » affichait un
  `sub_arc_name` hérité de la boucle précédente (déjà repéré dans `scripts/README.md`) —
  corrigé pour référencer le bon arc.

## 5 — Tests et hygiène

✅ **5.5 tranché** (2026-08-22) : icône générique plutôt que du dessin. Les 14 objets sans
illustration (`MEDAILLON DE RUNIR`, `PETIT MEDAILLON` pour fdcn ; 4 objets + 8 `EVENEMENT`
pour cdsi) affichent désormais le même `question.svg` que les objets non découverts, dans
l'inventaire (`entities/Item.gd`) et le toast (`popups/ItemPopup.gd`).

## 6 — Code GDScript (revue de propreté du 2026-08-22)

✅ **Catégorie 6 soldée** (2026-08-23) — détail des 6 points :

- ✅ **6.1** Les 4 signaux jamais connectés supprimés : `chapter_selected`
  (`breadcrumb.gd`), `chapter_chosen`/`new_billy_requested`/`previous_chapter_requested`
  (`choice_next_chapiter.gd`) — déclarations et `.emit()` retirés, le vrai appel
  (`Player.go_to_node()` etc.) qui se faisait déjà en direct juste avant est inchangé.
  Vérifié qu'aucun test ne s'y connectait.
- ✅ **6.2** `self.` retiré partout où il ne sert à rien (8 fichiers réels : `Item.gd` 29×,
  `chapter_data.gd` 28×, `ChapterChoice.gd` 27×, `success_item.gd` 20×, `ItemPopup.gd` 16×,
  `bread.gd` 14×, `EndingChoice.gd` 5×, `LoreEntry.gd` 3× — les autres fichiers listés dans
  l'ancienne revue ne portaient le mot que dans des commentaires, pas du code réel). 3
  setters (`ChapterChoice.gd`/`EndingChoice.gd`/`bread.gd:set_main`,
  `EndingChoice.gd:set_ending_type`) prenaient un paramètre du même nom que le champ qu'il
  alimentait — `self.` y était réellement nécessaire ; réglé en renommant le paramètre
  (`main_obj`, `new_ending_type`, `new_main`) plutôt qu'en gardant `self.`.
- ✅ **6.3** `max()`/`min()` → `maxi()`/`mini()` sur les sites entiers
  (`succes_menu.gd`, `chapitres_menu.gd`), mais → `minf()`/`maxf()` dans `nav_buton.gd` où
  les valeurs sont des `float` (composantes de `Vector2`) — `mini()`/`maxi()` les auraient
  tronquées en entier, une régression que la convention telle qu'écrite ne distinguait pas.
  `len()` → `.size()` (`global_completion.gd`, `breadcrumb.gd`). Balayage complet du dépôt
  refait après coup : plus aucune occurrence hors `test/`.
- ✅ **6.4** Les 3 autoloads en PascalCase renommés en snake_case :
  `BookData.gd`→`book_data.gd`, `Sounder.gd`/`.tscn`→`sounder.gd`/`.tscn`,
  `Parameters.gd`→`app_parameters.gd` (aligné sur l'alias `AppParameters`, qui ne
  correspondait à aucun des deux anciens noms). **Décision prise** : seuls les noms de
  *fichiers* et `project.godot` changent — les noms de singleton (`BookData`,
  `AppParameters`, `Sounder`) restent inchangés, ils sont indépendants du nom de fichier en
  Godot et sont utilisés tels quels dans des dizaines de scripts ; les renommer aurait un
  rayon d'effet sans rapport avec le gain.
- ✅ **6.5** Pool de liste virtualisée factorisé dans `ui/virtual_list_pool.gd`
  (`class_name VirtualListPool`) : `succes_menu.gd` et `chapitres_menu.gd` délèguent
  `_ensure_pool()`/`_refresh_rows()` à une instance commune, ne gardant que ce qui leur est
  propre (quel objet afficher, et pour `chapitres_menu.gd` son test additionnel « la ligne
  a-t-elle changé de chapitre »). Comportement vérifié ligne à ligne contre l'original — pas
  rejoué dans l'éditeur (indisponible ici), **à valider visuellement sur les deux écrans**
  avant de considérer ce point clos pour de bon.
- ✅ **6.6** Les références obsolètes `§5bis`/`§5ter` dans `succes_menu.gd` corrigées : la
  première pointe maintenant vers l'en-tête de `chapitres_menu.gd` (qui documente le motif
  en clair), la seconde vers `review §3.5` (où vit la mesure des 416 px).

## 7 — Documentation (revue de propreté du 2026-08-22)

- [ ] **7.1** **Le `README.md` racine ne mentionne jamais cdsi** — ne décrit que « La
      Forteresse du Chaudron Noir » alors que l'app embarque deux livres et que
      `docs/playstore/` a déjà des captures cdsi. Le trou le plus visible de cette liste.
      → review §9.2
- [ ] **7.2** **`autoload/` n'a pas de README** malgré 10 singletons couplés
      (BookData, Player, PlayerStats, Inventory, SaveManager, SaveArchive, CombatEngine,
      Parameters, Sounder, Utils) — chaque fichier est bien documenté seul, rien n'explique
      qui fait quoi entre eux. → review §9.2
- [ ] **7.3** **`entities/Item.gd` et `ui/top_menu.gd` sous-documentés** (~10 % et ~2 % de
      lignes en `##`, les plus bas de leur dossier) malgré une logique non triviale
      (repli d'icône, mise en surbrillance de page/Billy). → review §9.2
- [ ] **7.4** **`combat.md` (2026-08-10) potentiellement désynchronisé** : prescrit 3
      fichiers de test séparés (`test_combat_table.gd`, `test_combat_engine.gd`,
      `test_combat_fuite.gd`, §3.8), le système livré n'en a qu'un (`test_combat.gd`,
      544 lignes). À relire pour voir si c'est le doc ou l'implémentation qui a dérivé.
      → review §9.2

## 8 — Tests, angles morts (revue de propreté du 2026-08-22)

Au-delà du chiffre déjà connu (26/39 scripts sans test, dont 24 d'interface, §2 ci-dessus) :

- [ ] **8.1** **`entities/LoreEntry.gd` : zéro test.** `_chemin_image()`/`_chemin_son()` sont
      de la pure construction de chaîne (facile à tester sans arbre de scène), et viennent de
      changer (**3.7**, `book_number` → `book_name`) — le renommage n'est vérifié que par
      « ça compile ». → review §9.3
- [ ] **8.2** **`autoload/sounder.gd` : zéro test**, seul autoload dans ce cas
      (`set_enabled`/`is_enabled`/`play`/`play_path`/`stop`). → review §9.3
- [ ] **8.3** **`entities/Item.gd`, `popups/ItemPopup.gd` : zéro test** — le repli
      `question.svg` (**5.5**) et le chargement svg→png→repli ne sont vérifiés par rien.
      → review §9.3
- [ ] **8.4** **`screens/aventure_menu.gd` : zéro test**, probablement le contrôleur le plus
      complexe de l'app (combat, choix, fil d'Ariane). → review §9.3

## 9 — Assets (revue de propreté du 2026-08-22)

✅ **9.1 fait** (2026-08-23) : les 16 images de `images/endings/` ne correspondaient à aucun
`ending_id` mais à des `success` déjà illustrés dans `images/success/` — vérifié au hash
(sha256), 15 sur 16 différaient bel et bien de leur homonyme, `FLEURS.png` seul étant un
doublon identique. Vérification des dimensions : les 15 différentes sont toutes en
**128×128** contre du **40×40** partout ailleurs dans `images/success/` — pas des brouillons
concurrents, mais des **redessins haute résolution** jamais intégrés. `images/success/<nom>.png`
mis à jour avec la version 128×128 pour les 15 (`ARSENE`, `BULIAAA`, `METAAAL`, `HONNEUR`,
`TU-QUOQUE-BILLY`, `PERSONNEL`, `VIVANT`, `CERCLE-VICIEUX`, `INNOCENT`, `SEYMOUR`, `SABOT`,
`ESCALADED-QUICKLY`, `TRAVAIL-TERMINE`, `ROI-LICHE`, `MEMOIRE-HONOREE`), `.import` d'origine
conservé (même chemin/uid, Godot réimportera). Les 16 fichiers de `images/endings/` supprimés.
⚠️ **Reste à vérifier dans l'éditeur** : que les 15 icônes réimportent correctement en
128×128 sans régression visuelle (pas testable hors Godot).
- [ ] **9.2** **11 fins nommées sur 14 sans image** : les 10 de cdsi, plus `TRICHE` (fdcn) —
      seules `SOUFLE`, `TULIPES`, `VIGNES` (fdcn) en ont une. Silencieux
      (`push_warning` dans `Utils.load_external_texture`), pas un crash, mais l'écran de fin
      de cdsi n'a jamais eu d'illustration. **Vérifié sur le projet source** (2026-08-23,
      `naparuba/fdcn`, 5 branches) : `images/endings/` y a le même mélange qu'ici avant
      nettoyage (préexistant, pas introduit par ce refacto), et `MIRROIRS-OVERLOAD`,
      `SOUFFLER`, `VALKAR`, `TRICHE` n'ont **aucune** image nulle part chez l'auteur non plus
      (les 7 autres fins cdsi ont un repli via leur icône de succès, comme en local). À
      trancher en connaissance de cause : dessiner, ou assumer l'absence. → review §9.4
