# TODO — fdcn v4

Cases à cocher dérivées de **`review.md`** §9, même numérotation **catégorie.rang**. Les
mesures et le *pourquoi* de chaque ligne sont dans la review ; le combat a son propre
document, **`combat.md`**.

**Ce fichier ne contient que ce qui reste à faire.** Ce qui est terminé en est retiré —
l'historique est dans `git log`.

Suite de tests, à ne lancer que sur demande :

```bash
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

⚠️ Dernier passage vert : **68 tests** — la suite en compte maintenant **91** (8 ajoutés sur
les pouvoirs de Billy, 15 sur la notation d'effet et les compteurs), et elle n'a plus tourné
depuis. Entre-temps ont été touchés : `CombatEngine` (3 règles corrigées), `Player`,
`BookData`, `PlayerStats`, `menu_page`, `top_menu`, `ChapterChoice`, et **l'arbre de 8
scènes** a changé. `test_scenes` valide justement les `$Chemin` des scripts contre leur
scène : la suite mérite un passage avant de continuer.

---

## 1 — Perte de données et angles morts critiques

- [ ] **1.1** 🔴 **Réparer la branche des fins de `scripts/fdcn.py`, et NE PAS RECOMPILER
      avant.** `goto = [goto]` rend `if isinstance(goto, int)` toujours faux : tout le bloc
      des fins est inatteignable, y compris l'unique `set_ending()` du dépôt et ses deux
      validations. Les json compilés datent de **la veille** de cette régression — ils sont
      corrects mais plus reproductibles. Recompiler viderait `endings` / `good-endings` /
      `bad-endings` **sans un seul message d'erreur**. → review §6.1
- [ ] **1.2** **Tester `BookData`, en priorité `_check_cond_rec`.** C'est lui qui décide
      quels chapitres sont accessibles : logique pure, aucun test. Couvrir `$or`, `$and`,
      `$end`, l'imbrication, et la condition absente. → review §2.2

## 2 — Export / import d'une sauvegarde en zip

À faire tôt : c'est le seul chantier de cette liste **entièrement testable sans interface
ni appareil**.

- [ ] **2.1** **Moteur d'archive** découplé du transport : 7 clés × chaque livre +
      `parameters.json` + `manifest.json`, avec `ZIPPacker` (**natif dans Godot 4.7.1,
      vérifié** — pas de rar, format propriétaire sans encodeur). → review §5.2
- [ ] **2.2** **Import atomique**, dans cet ordre strict : `user://import_tmp/` → tout
      valider → **sauvegarde de secours automatique** → bascule → `Player.do_load()`. Un
      import à moitié appliqué donne une sauvegarde Frankenstein, pire qu'un import raté.
      Les vieilles archives se migrent gratuitement (`prepare_save()`). → review §5.4
- [ ] **2.3** **Transport par plateforme** : `FileDialog` desktop d'abord ; **Android**
      (`user://` privé, scoped storage) et **HTML5** (IndexedDB, `JavaScriptBridge`) en
      chantiers séparés. → review §5.3
- [ ] **2.4** Tests : aller-retour complet, archive tronquée, archive de version future,
      archive d'un seul livre. → review §5.6

## 3 — Données de livre

- [ ] **3.1** **Corriger les orthographes à la source** : `critique`→`crit` (×5) et
      `pv_1_2_max`→`half_pv` dans `cdsi.json`, unifier `pv_1_4_max`/`1_4_pv_max` dans
      `fdcn.json`. ⚠️ **Vérifier d'abord dans le livre** si `half_pv` (moitié du *courant*)
      et `pv_1_2_max` (« max ») sont bien la même règle — les fusionner à tort serait une
      régression silencieuse. → review §4.2, §4.4
- [ ] **3.2** **Faire échouer `scripts/fdcn.py`** sur une clé de stat hors vocabulaire : il
      les collecte et les **imprime déjà**, il manque la liste de référence et un
      `sys.exit(2)`. → review §4.2
- [ ] **3.3** **Migrer les 16 occurrences des 6 mots-clés vers la notation d'effet** :
      `max_pv` ×10 et `max_chance` ×2 → `"= max"`, `half_pv` → `"= moi/2"`, et les trois
      orthographes du quart / de la moitié une fois **3.1** tranché. Le moteur accepte déjà
      la notation ; en attendant, `PlayerStats._LEGACY_EFFECTS` sert les vieux mots-clés par
      le même évaluateur, et cette table disparaît avec eux. ⚠️ Toucher **`<nom>.json` et
      `<nom>-compilated-data.json`** ensemble, ou attendre **1.1** pour recompiler.
      → review §4.4
- [ ] **3.4** **`pv_gain`** : modificateur de gain dans la couche chapitres, **delta positif
      seulement** (un bonus de gain ne doit pas amortir les dégâts) et **jamais sur une
      affectation** (sinon « pv au plein » dépasse le plafond). → review §4.5
- [ ] **3.5** **Compléter le vocabulaire par livre avec `ignorees`** : les `compteurs` sont
      faits (`<nom>.vocabulaire.json`, `PlayerStats._compteurs`, lignes de la feuille de
      stats générées), il reste à y déplacer `PlayerStats._CHAPTER_UNMANAGED_KEYS`. Dépend
      des « règles ponctuelles » — **§4.3, à trancher d'abord**. Pas de liste d'alias :
      les orthographes se corrigent à la source (**3.1**). → review §4.6
- [ ] **3.6** **Registre des livres** (`books/books.json` ou scan de `books/*/`) : rend
      `BookSelection` piloté par les données et ramène l'ajout d'un livre à « déposer un
      dossier, compiler, ajouter une ligne ». → review §3.6
- [ ] **3.7** Renommer **`images/dieux/<n>/` → `images/dieux/<nom>/`** (et les sons
      correspondants). **Tranché le 2026-08-12** : c'est le dernier vestige de
      l'identification par numéro, dont tout le reste de l'app est déjà sorti. À faire
      *avant* la page Lore (2.1), qui va chercher ces dossiers. → review §3.5

## 4 — Compilateur Python (`scripts/`)

Ne rien recompiler avant **1.1**.

- [ ] **4.1** **Des niveaux de log** (`--verbose`) : 66 `print()` noient les validations
      utiles (secrets à deux entrées, fin sans type, objets sans chapitre). C'est ce qui a
      laissé passer `critique`. → review §6.2
- [ ] **4.2** **Découper `fdcn.py`** : 405 lignes à plat, **aucune fonction** hors
      `load_json_file`, **40 variables globales**. Le graphviz est la moitié du fichier et
      l'app ne s'en sert pas — candidat évident à l'extraction. → review §6.2
- [ ] **4.3** Sortir la présentation graphviz de `node.py` (`get_label()` renvoie du HTML
      coloré depuis le modèle de données). → review §6.2
- [ ] **4.4** Nettoyer : code commenté laissé en place, deux commentaires « Get the combat
      entry if any » d'affilée, annotations de type en commentaire Python 2,
      `get_all_stats_keys()` qui imprime. → review §6.2
- [ ] **4.5** Le cas particulier `goto == 608 and book_number == 1` devra être contourné par
      un 3ᵉ livre. → review §3.3

## 5 — Tests et hygiène

- [ ] **5.1** **`test_case.gd` doit savoir `await`.** C'est ce qui bloque *tous* les tests
      d'interface et de mise en page — dont la classe de bug « lignes qui se chevauchent »,
      aujourd'hui invisible. → review §2.2

- [ ] **5.2** Tester `ui/menu_page.gd` (navigation bloquée quand une popup est ouverte) et
      `ui/top_menu.gd`. → review §2.2

- [ ] **5.3** Décider la fin de vie d'`archive/` — et poser son `.gdignore` — une fois la
      parité atteinte. **Pas avant** : le `.gdignore` rendrait `archive/src/main.tscn`
      impossible à ouvrir dans l'éditeur, or c'est le plan des pages Lore et À propos qu'il
      reste à porter. → review §8.1, §8.2
- [ ] **5.4** **Passage piloté par les données sur `images/` et `sounds/`** : croiser les
      668 images avec les objets, succès et fins des deux livres. Les noms sont construits à
      l'exécution (`images/items/%s.svg`…), aucune analyse statique ne peut conclure.
      Seul orphelin déjà identifié : `images/fight.png`. → review §8.2
