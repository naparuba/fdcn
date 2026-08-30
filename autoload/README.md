# autoload/ — les singletons

Dix autoloads, déclarés dans cet ordre dans `project.godot` :

| ordre | nom du singleton | fichier | rôle en une ligne |
|---|---|---|---|
| 1 | `Sounder` | `sounder.gd` (+ `sounder.tscn`) | lecteur de son unique, avec cache |
| 2 | `Utils` | `utils.gd` | fonctions sans propriétaire (chargement de texture, lecture JSON, jet de dé, …) |
| 3 | `BookData` | `book_data.gd` | données du livre **courant**, plus le registre de tous les livres |
| 4 | `AppParameters` | `app_parameters.gd` | réglages du joueur, et **quel** livre il a ouvert |
| 5 | `SaveManager` | `save_manager.gd` | lecture/écriture JSON des sauvegardes dans `user://`, versionnage |
| 6 | `SaveArchive` | `save_archive.gd` | empaqueter/réappliquer une sauvegarde complète en zip |
| 7 | `PlayerStats` | `player_stats.gd` | les 7 stats du Billy, en couches (base/objets/chapitres) |
| 8 | `Inventory` | `inventory.gd` | ce que porte le Billy, et le type de Billy qui en découle |
| 9 | `Player` | `player.gd` | chapitre courant, historiques de visite, point d'entrée de la navigation |
| 10 | `CombatEngine` | `combat_engine.gd` | les règles d'un affrontement, sans aucune interface |
| — | `Narrator` | `narrator.gd` | décide *quand* jouer un son (`Sounder` sait *comment*) |

Cette table ne remplace pas l'en-tête de chaque fichier — chacun documente déjà son propre
fonctionnement en détail (`## ...` en tête de script). Ce qui manquait, et que ce README
couvre, c'est **comment ils s'articulent entre eux**.

⚠️ **`class_name` et le cache de classes.** `CombatEngine` s'appuie sur deux classes
utilitaires qui ne sont PAS des autoloads (`CombatTable`, `CombatAssaultResolver` — voir
`combat_table.gd`/`combat_assault_resolver.gd`, `VirtualListPool` dans `ui/` suit le même
principe) : chacune se déclare avec `class_name` et s'instancie normalement (`.new()`), sans
entrée dans `project.godot`. Godot les résout par un cache (`.godot/
global_script_class_cache.cfg`, gitignoré) reconstruit à l'ouverture de l'éditeur — **pas**
par un simple `godot --headless -s ...`. Sur un dépôt tout juste cloné (`.godot/` absent ou
périmé), un script qui référence l'une de ces classes échoue à la compilation
("Identifier ... not declared") tant qu'un `godot --headless --editor --quit --path .` n'a
pas tourné une fois — le même geste que pour régénérer les `.import` d'assets (voir
`todo.md`/l'historique de `git log`).

## Pourquoi l'ordre compte

Godot appelle les `_ready()` des autoloads dans l'ordre de la liste ci-dessus, et rien
n'empêche l'un de s'appuyer sur un autre déjà prêt :

- **`BookData` avant `AppParameters`** : `AppParameters._ready()` demande à `BookData` le
  livre à ouvrir (dernier livre choisi, ou le premier du registre) — il doit déjà être
  chargé.
- **`Sounder` avant `AppParameters`** : `AppParameters` applique le réglage « son » pendant
  son propre `_ready()`, ce qui suppose `Sounder` déjà prêt à recevoir la consigne
  (`sounder.gd` le rappelle explicitement, faute de garantie du moteur).
- **`Player` après `BookData`/`AppParameters`/`SaveManager`** : changer de livre recharge la
  sauvegarde du nouveau, ce qui suppose les trois déjà en place.

Un nouvel autoload qui lit un des singletons ci-dessus dans son propre `_ready()` doit être
ajouté **après** lui dans `project.godot`, jamais avant.

## Qui orchestre quoi

`Player` ne stocke pas grand-chose lui-même : il **orchestre** les autres au fil de la
navigation.

```
AppParameters.set_book_name()
  └─ BookData doit déjà connaître le nouveau livre (ordre imposé, voir set_book_name())
  └─ book_changed.emit()
       ├─ Player recharge la sauvegarde du nouveau livre
       ├─ Narrator joue l'intro du livre (books/<nom>/audio/intro.mp3, s'il existe)
       └─ les écrans abonnés (succès, chapitres, …) se rechargent

Player.go_to_node()
  └─ met à jour le chapitre courant, les deux historiques de visite
  └─ chapter_changed.emit()
       ├─ Narrator joue la narration du chapitre (books/<nom>/audio/<n>.mp3, si présent)
       └─ les écrans abonnés se rafraîchissent
  └─ délègue à Inventory (objets gagnés/perdus) et PlayerStats (stats du chapitre)

SaveArchive.import_from()
  └─ écrit les fichiers sur le disque via les chemins de SaveManager
  └─ AppParameters.reload() — relit les réglages, dont le livre à ouvrir
  └─ Player.do_load() — relit la partie du livre maintenant ouvert
     (l'ordre est imposé : les réglages disent quel livre, avant de relire sa partie)
```

`CombatEngine` est la seule exception délibérée à ce schéma : c'est un moteur de règles pur,
sans dépendance aux autres autoloads ni bouton d'orchestration — `screens/aventure_menu/
Combat.tscn` l'interroge, il ne pousse rien vers personne. Spec complète dans `review-combat.md`.

## Signaux à connaître avant d'en ajouter un

Trois signaux globaux couvrent l'essentiel des rafraîchissements d'écran ; un nouvel écran
qui affiche une donnée dépendant du livre ou du chapitre s'y abonne au lieu de se faire
notifier par un chemin dédié :

- `AppParameters.book_changed` — le livre ouvert a changé
- `AppParameters.settings_changed` — un réglage a changé (son, spoils, type de Billy, …) ;
  volontairement grossier, part aussi pour ce qui ne regarde qu'un sous-ensemble d'écrans
- `Player.chapter_changed` — le chapitre courant a changé
