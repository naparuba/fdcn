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

⚠️ Dernier passage vert : **68 tests** — la suite en compte maintenant **146**, et elle n'a
plus tourné depuis. Se sont ajoutés : les pouvoirs de Billy (8), la notation d'effet et les
compteurs (14), le registre et le rangement des livres (10), **`BookData` et son évaluateur
de conditions** (13), **l'archive de sauvegarde** (13), et les **deux premiers tests
d'interface** — `menu_page` et `top_menu` (15), qui exercent enfin un `_ready()`.

⚠️ **Le lanceur est devenu asynchrone** (`await`) : `test/all.gd` et `test/all.tscn`
l'attendent désormais. Les dix autoloads ont tous été relus, et `archive/` a reçu son
`.gdignore` — la suite mérite vraiment un passage avant de continuer.

✅ **Générateur et données remis d'équerre** (2026-08-13). `fdcn.py` est devenu
`scripts/generator.py`, il lit **toute** sa source dans `scripts/src/<nom>/` et n'écrit plus
que ce que l'app ouvre. Les json des livres sont passés de **1 340 à 388 Ko** dans la
journée, à contenu strictement identique pour l'app — vérifié clé par clé sur les
1 297 chapitres. Les deux README (`scripts/`, `books/`) décrivent l'état actuel.

⚠️ **Contrat à ne pas casser** : `Node.NEUTRES` (générateur) et les `.get(clé, défaut)` de
`entities/chapter_data.gd` (app) doivent lister les **mêmes 17 clés avec les mêmes valeurs**.
Une clé absente veut dire « rien à signaler ». `test_book_data.gd` le vérifie.

⚠️ **Godot va réimporter au prochain démarrage de l'éditeur** : le contenu des livres a
changé de place (`books/<nom>/data|img|audio/`, et la source dans `scripts/src/`), et
24 assets orphelins sont partis dans `archive/unuzed/assets/`. Les **images de livre** ont
emporté leur `.import`, donc leur **uid est intact** ; les **6 mp3** ont perdu le leur
(aucune scène ne les référençait), Godot le régénérera.

---

## 1 — Perte de données et angles morts critiques

- [ ] **1.4** **Relire les 85 combats des deux livres contre le livre papier.** Deux fautes
      trouvées le 2026-08-13 rien qu'en en vérifiant un : **fdcn ch276** portait les deux
      adversaires de ch274 (`GUARDES CORROMPUS` + `TROLESSE`) au lieu de **MORTELLE**
      (hab 12, pv 26), et **ch274** un bouche-trou `XXXX` avec tous ses chiffres à 1, qui
      partait tel quel dans l'application. Aucun outil ne peut les attraper : le compilateur
      recopie le bloc `combat` sans le regarder, et les chiffres sont plausibles. Un balayage
      automatique n'a trouvé **aucun autre** bouche-trou évident, mais ça ne dit rien des
      chiffres faux.

- [ ] **1.1** **Vérifier dans le livre les deux règles transcrites de mémoire**
      (2026-08-12) : `pv_1_2_max` de **cdsi ch249**, devenu `"pv": "= max/2"` — la clé dit
      « max » mais `half_pv` disait « courant », et rien dans les données ne tranche ; et
      **cdsi ch176** qui écrit `"pv_max": true`, soit *+1 de plafond* alors que l'auteur
      voulait probablement « pv au plein » (`"pv": "= max"`). Les deux ne faisaient
      **rien du tout** avant, toute lecture fidèle est déjà un gain. → review §4.4

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
      écrire les 5 sorties que personne ne lit (supprimées, et le dossier `archive/` avec —
      le compilateur le recrée aujourd'hui pour ne pas échouer en pleine écriture), ne plus
      écrire les **trois
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
      `node.py`, `graph.py`, `condition_node.py` et `endings.py` ne se lancent pas, ce sont
      des modules qu'il importe. Les fondre en un fichier irait **contre 4.2**, qui demande
      au contraire de découper les 475 lignes à plat de `generator.py` — à trancher.
- [ ] **3.9** **Squelette de livre** : `--nouveau <nom>` crée le dossier, deux fichiers
      valides et l'entrée du registre — un livre neuf part de quelque chose **qui compile**.
      → review §3.7 *Plan*
- [ ] **3.11** **Écrire le mode d'emploi d'un livre ajouté à la main.** `books/README.md`
      dit *quels* fichiers déposer, jamais *comment les remplir* : il manque le format de
      chaque clé de chapitre avec un exemple réel, le langage des conditions et ses trois
      pièges, la propagation des actes (19 déclarations couvrent 606 chapitres), et une
      liste de vérification avant la première compilation. Aujourd'hui la seule source
      complète est `scripts/README.md`, écrite pour qui touche au compilateur — pas pour
      qui saisit un livre. **À reprendre après 3.8**, sinon la moitié sera déjà périmée.
- [ ] **3.10** Corriger l'angle mort de la validation des objets : un objet cité
      **uniquement** dans un `stats_cond` compte comme « déclaré mais pas utilisé » et fait
      échouer la compilation à tort. → review §3.7 *Plan*
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
- [ ] **3.7** Renommer **`images/dieux/<n>/` → `images/dieux/<nom>/`** (et les sons
      correspondants). **Tranché le 2026-08-12** : c'est le dernier vestige de
      l'identification par numéro, dont tout le reste de l'app est déjà sorti. À faire
      *avant* la page Lore (2.1), qui va chercher ces dossiers. → review §3.5

## 4 — Compilateur Python (`scripts/`)

Les deux livres ont été recompilés le 2026-08-12, branche des fins réparée : fdcn inchangé
(19 fins), **cdsi a gagné les 16 siennes**. `graphviz` est désormais facultatif — sans lui,
tous les json sortent, seul le png de relecture manque.

- [ ] **4.1** **Des niveaux de log** (`--verbose`) : 66 `print()` noient les validations
      utiles (secrets à deux entrées, fin sans type, objets sans chapitre). C'est ce qui a
      laissé passer `critique`. → review §6.2
- [ ] **4.2** **Découper `generator.py`** : 476 lignes à plat, **aucune fonction** hors
      `load_json_file`, **40 variables globales**. Le graphviz est la moitié du fichier et
      l'app ne s'en sert pas — candidat évident à l'extraction. → review §6.2
- [ ] **4.3** Sortir la présentation graphviz de `node.py` (`get_label()` renvoie du HTML
      coloré depuis le modèle de données). → review §6.2
- [ ] **4.4** Nettoyer : code commenté laissé en place, deux commentaires « Get the combat
      entry if any » d'affilée, annotations de type en commentaire Python 2,
      `get_all_stats_keys()` qui imprime. Les accumulateurs devenus morts avec les sorties
      supprimées (`all_combats`, `all_endings`, `all_secrets`…) ont déjà été retirés le
      2026-08-13, et `node.py` garde probablement les méthodes qui les servaient
      (`have_combat()`, `is_good_ending()`…) — à vérifier. → review §6.2

## 5 — Tests et hygiène

- [ ] **5.5** **14 objets n'ont aucune icône** et affichent donc « ? » dans l'inventaire
      (mesuré le 2026-08-12, en croisant les objets des deux livres avec `images/items/`) :
      - **fdcn** : `MEDAILLON DE RUNIR`, `PETIT MEDAILLON` ;
      - **cdsi** : 4 vrais objets (`AILERON AERODYNAMIQUE INSTALLE`, `DISQUES CLOUTES
        INSTALLES`, `RETROVISEUR INSTALLE`, `SECRET DU DOUBLE INFINI`) et 8 `EVENEMENT`
        (`UNE REUSSITE`, `SOUFFLE DANS LA CORNE`…).
      Deux réponses possibles, à trancher : dessiner les icônes manquantes, ou donner une
      icône générique par catégorie — les `EVENEMENT` ne sont pas des objets qu'on porte.
      → review §8.3
