# TODO — fdcn v4

Cases à cocher dérivées de **`review.md`** §10, même numérotation **catégorie.rang**. Les
mesures et le *pourquoi* de chaque ligne sont dans la review ; le combat a son propre
document, **`review-combat.md`** ; les pistes de refactor GDScript non urgentes sont dans
**`review-code.md`**.

**Ce fichier ne contient que ce qui reste à faire.** Ce qui est terminé en est retiré —
l'historique est dans `git log`.

Suite de tests, à ne lancer que sur demande :

```bash
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

✅ **Suite relancée le 2026-08-29 : 760/760.** Le lanceur avait un vrai bug (`_appeler()`
coupait "appeler" et "attendre" en deux lignes, ce que Godot 4 ne supporte pas pour un appel
dynamique — corrigé). Deux bugs applicatifs trouvés au passage et corrigés : `BookData`/
`chapter_data.gd` comparaient des identifiants JSON (`float`) à des listes d'entiers
(`26.0 in [26]` vaut faux), ce qui pouvait geler une barre de progression d'acte à 0 % même
visité — `get_acte_completion()`/`get_sons()`/`get_secret_jumps()` castent maintenant en
`int()`.

⚠️ **Contrat à ne pas casser** : `Node.NEUTRES` (générateur) et les `.get(clé, défaut)` de
`entities/chapter_data.gd` (app) doivent lister les **mêmes clés avec les mêmes valeurs**.
Une clé absente veut dire « rien à signaler ». `test_book_data.gd` le vérifie.

## 2 — Export / import d'une sauvegarde en zip

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

**Plan d'ensemble : review §3.7.** Les lignes ci-dessous sont ses étapes, dans l'ordre.

✅ **3.2 fait (2026-08-29)** — étape 1 du plan, le générateur refuse maintenant ce qu'il ne
comprend pas : clé de chapitre inconnue, clé de stat hors vocabulaire, `success` inconnu,
expression malformée, `&`/`|` mélangés sans parenthèses. Les 4 fautes réelles du tableau
§3.7 sont vérifiées rejetées (testé en les réinjectant une par une) ; les deux livres
recompilent à l'identique (aucun diff dans `books/`). Détail dans `git log`.

✅ **3.4 fait (2026-08-29)** — `pv_gain`/`chance_gain` : modificateur de gain dans la couche
chapitres, delta positif seulement, jamais sur une affectation. fdcn ch126 (PAYSAN) s'écrit
maintenant `"pv_gain": 1` au lieu de `pv_win_plus_1`. 5 tests dans `test_stats_effects.gd`.

✅ **3.5 fait (2026-08-29)** — `ignorees` dans `compteurs.json` (fdcn déclare
`arc_et_couteau`), lu par `BookData.is_ignored()` comme `is_counter()` lit `compteurs`.
`PlayerStats._CHAPTER_UNMANAGED_KEYS` a disparu — la déclaration vit dans le livre.

✅ **3.6 fait (2026-08-29)** — étape 3 du plan : `<nom>-compilated.json` remplace les 5
fichiers de `books/<nom>/data/` (3 calculés + 2 tables recopiées) par un seul, à 5 clés.
Bonus : l'écriture ne se fait plus qu'une fois, à la fin, une fois tout validé — plus de
dossier à moitié à jour sur un refus. `books/README.md`/`scripts/README.md` mis à jour.

✅ **3.8 fait (2026-08-29)** — étape 2 du plan : les 5 tables (`arcs`, `sub_arcs`,
`manual_sub_arcs`, `all_objects`, `all_success`) plus `compteurs`/`ignorees` (venu de
`books/<nom>/data/compteurs.json`, cf. décision prise avec l'utilisateur d'inclure ce
fichier dans la fusion) sont réunies dans `scripts/src/<nom>/<nom>.livre.json`, à champs
nommés — un sous-arc est maintenant `{"acte", "depart", "nom", "fins"}`, plus un tableau
positionnel. L'acte n'a **pas** été déplacé dans le chapitre (8 lignes couvrent toujours
606 chapitres par propagation). `books/README.md`/`scripts/README.md` mis à jour.

- [ ] **3.9** **Squelette de livre** : `--nouveau <nom>` crée le dossier, deux fichiers
      valides et l'entrée du registre — un livre neuf part de quelque chose **qui compile**.
      → review §3.7
- [ ] **3.13** **Le pipeline visé : `src/` → `gen/` → `books/`.** La moitié est faite
      (tout ce qui s'écrit à la main est dans `scripts/src/<nom>/`, et le compilateur y
      recopie les objets et succès vers `books/`). Reste à écrire :
      - le compilateur **produit dans `scripts/gen/<nom>/data/`**, puis **copie** vers
        `books/<nom>/data/` — une étape de génération, une étape de livraison, chacune
        vérifiable séparément ;
      - `books/<nom>/data/` devient **entièrement généré**, donc jetable et regénérable ;
      - ⚠️ à décider en même temps : `gen/` est-il commité, ou seulement `books/` ? Deux
        copies commitées du même contenu se contrediraient à la première compilation
        oubliée. Avis : `gen/` dans le `.gitignore`, `books/` commité — c'est lui que
        l'app embarque.
      → review §3.7

## 8 — Tests, angles morts

Au-delà du chiffre déjà connu (scripts d'interface sans aucun test, review §2.1) :

- [ ] **8.1** **`entities/LoreEntry.gd` : zéro test.** `_chemin_image()`/`_chemin_son()` sont
      de la pure construction de chaîne (facile à tester sans arbre de scène), et ont
      changé récemment (`book_number` → `book_name`) — le renommage n'est vérifié que par
      « ça compile ». → review §8.3
- [ ] **8.2** **`autoload/sounder.gd` : zéro test**, seul autoload dans ce cas
      (`set_enabled`/`is_enabled`/`play`/`play_path`/`stop`). → review §8.3
- [ ] **8.3** **`entities/Item.gd`, `popups/ItemPopup.gd` : zéro test** — le repli
      svg→png→`question.svg` et le chargement de texture ne sont vérifiés par rien.
      → review §8.3
- [ ] **8.4** **`screens/aventure_menu.gd` : zéro test**, probablement le contrôleur le plus
      complexe de l'app (combat, choix, fil d'Ariane). → review §8.3

## 9 — Assets

- [ ] **9.2** **11 fins nommées sur 14 sans image** : les 10 de cdsi, plus `TRICHE` (fdcn) —
      seules `SOUFLE`, `TULIPES`, `VIGNES` (fdcn) en ont une. Silencieux
      (`push_warning` dans `Utils.load_external_texture`), pas un crash, mais l'écran de fin
      de cdsi n'a jamais eu d'illustration. **Vérifié sur le projet source** (`naparuba/fdcn`,
      5 branches) : le même trou existe chez l'auteur original, sur `MIRROIRS-OVERLOAD`,
      `SOUFFLER`, `VALKAR` et `TRICHE` — gap hérité, pas introduit par ce refacto. À
      trancher en connaissance de cause : dessiner, ou assumer l'absence. → review §8.4
