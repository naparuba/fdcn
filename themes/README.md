# `themes/fdcn.tres` — le thème global

Déclaré dans `project.godot` :

```ini
[gui]
theme/custom="res://themes/fdcn.tres"
```

Le format `.tres` ne garantit pas les commentaires, et l'éditeur de thème de Godot
réécrit le fichier quand on l'y ouvre — d'où ce document à côté plutôt que dedans.

## La palette n'invente rien

Toutes les valeurs du thème sont **relevées dans les scènes existantes**, à la virgule
près. Rien n'a été harmonisé « au jugé » : le but était que l'app garde exactement les
mêmes couleurs, le thème ne fait que centraliser ce qui était recopié à la main.

Mesuré le 2026-08-11 sur les 30 scènes vivantes :

| rôle | hex | `Color(...)` | occurrences |
|---|---|---|---|
| en-tête (navy) | `#313b47` | `0.192157, 0.231373, 0.278431` | 12 |
| carte | `#ffffff` | `1, 1, 1` | 17 |
| fond d'application | `#ecedf2` | `0.92549, 0.929412, 0.94902` | 9 |
| encart / neutre | `#e9eaec` | `0.913725, 0.917647, 0.92549` | 16 |
| encart sombre | `#e0e2e5` | `0.878431, 0.886275, 0.898039` | 2 |
| accent — le **oui** | `#00c2aa` | `0, 0.760784, 0.666667` | 16 |
| rouge — le **non** | `#f45858` | `0.956863, 0.345098, 0.345098` | 1 |
| jaune (fuite) | `#e2b007` | `0.886275, 0.690196, 0.027451` | 2 |
| texte | `#000000` | `0, 0, 0` | 79 |
| texte atténué | `#666b70` | `0.4, 0.42, 0.44` | 9 |
| texte appuyé | `#4a4f54` | `0.290196, 0.309804, 0.329412` | 5 |
| texte désactivé | `#999fa3` | `0.6, 0.62, 0.64` | 2 |
| alerte | `#ff6b00` | `1, 0.419608, 0` | 3 |

`#00c2aa` contre rouge n'est pas un choix arbitraire pour les interrupteurs :
`entities/ChapterChoice.gd` s'en sert **déjà** comme couple acquis/absent — accent pour
« déjà vu », « fin atteinte », « succès », « secret trouvé », rouge pour le refus. Les
switches oui/non reprennent le vocabulaire visuel en place.

Les deux écritures du même gris qui traînaient (`0.92549…` et `0.9254902…` dans
`AventureMenu.tscn`, un écart de 2·10⁻⁷) sont unifiées : les deux nœuds prennent la
variation `Fond`.

## Le style principal, et les variations

Le **socle** s'applique sans rien demander : `default_font`, `default_font_size`, la
couleur de texte des `Label`, l'habillage des `Button`, la carte des `PanelContainer`.

Les **variations** sont les styles secondaires. On les pose sur un nœud avec une seule
ligne, et la couleur reste ici :

```gdscript
theme_type_variation = &"TitreHeader"
```

| variation | base | ce que c'est | usages |
|---|---|---|---|
| `TitreHeader` | `Label` | titre blanc, posé sur un en-tête navy | 16 |
| `TexteAccent` | `Label` | `#00c2aa` | 15 |
| `TexteAtenue` | `Label` | `#666b70`, texte secondaire | 10 |
| `TexteAppuye` | `Label` | `#4a4f54` | 5 |
| `TexteAlerte` | `Label` | `#ff6b00` | 3 |
| `Carte` | `Panel` | blanc plein | 14 |
| `EnTete` | `Panel` | bandeau navy | 12 |
| `Pastille` | `Panel` | `#ecedf2`, rayon 2 — les boîtes cliquables | 8 |
| `Ligne` | `Panel` | blanc + bordure basse de 2 — les rangées de liste | 5 |
| `Fond` | `Panel` | fond d'application `#ecedf2` | 4 |
| `Encart` | `Panel` | `#e9eaec`, rayon 2 | 3 |
| `EncartPlat` | `Panel` | `#e9eaec` sans rayon | 2 |
| `Voile` | `Panel` | `#1e242b` à 59 % — le voile des surcouches | 2 |
| `SwitchOui` / `SwitchNon` | `CheckButton` | vert/rouge, texte blanc — posées par `ui/yes_no_switch.gd` à l'exécution | 2 |

C'est ce mécanisme qui a ramené les surcharges de style de **570 à 41** : la scène ne
déclare plus qu'un rôle. **101 variations** sont posées dans les scènes et les scripts.

⚠️ **Les variations de panneau n'ont aucune marge de contenu, et c'est délibéré.** Elles ont
été définies pour être *exactement* les styleboxes qu'elles remplacent. Leur donner du
rembourrage aurait ajouté de l'espace à 50 endroits d'un coup. Une scène qui veut de la marge
met un `MarginContainer` — c'est l'idiome de l'app.

⚠️ **`base_type = &"Panel"` marche aussi pour un `PanelContainer"`** : la variation est
consultée avant la classe du nœud, et les deux types lisent le même item `panel`.

## Ce qui n'est volontairement pas défini

**`Panel/styles/panel`.** Les deux **bandes de navigation** (`ui/NavButon.tscn`) n'ont qu'un
`Polygon2D` par-dessus et s'appuient sur le défaut de Godot. Un fond par défaut sur `Panel`
leur peindrait un bloc visible sur toute la hauteur de l'écran, des deux côtés. La carte
blanche est donc portée par `PanelContainer` ; un `Panel` qui la veut prend `Carte`.

**Les `constants/separation` des conteneurs.** L'app utilise 6, 8, 4, 2, 12 et 0 selon
l'endroit ; Godot vaut 4 par défaut. Imposer une valeur déplacerait la mise en page des
conteneurs qui n'en déclarent aucune, sans rien gagner. Les 85 `separation` et `margin_*`
qui restent dans les scènes sont de la **mise en page**, pas du style : elles ne partiront
jamais ici.

**Les 18 styleboxes que six scripts mutent en place.** Voir `review.md` §1.2 — les retirer
casserait la coloration des onglets, des blocs de Billy et de l'issue de combat.

## ⚠️ Pourquoi le thème pointe sur le `.ttf`, et pas sur un `.tres`

```
default_font = res://fonts/RobotoCondensed-Regular.ttf
default_font_size = 16
```

`fonts/amon_font.tres` **ne portait aucune police**. Il déclarait `size = 25` et
`font_data = …`, des **noms de propriétés Godot 3** que le `FontFile` de Godot 4 n'expose
pas. La preuve était dans l'historique du fichier : quand l'éditeur Godot 4 a réécrit cette
ressource (commit `eabcbbc`), il a produit `fixed_size` et des entrées `cache/*`, **sans
aucun `font_data`**.

Ce n'était pas cosmétique — **une police vide mesure 0** :

1. `get_string_size()` renvoie une largeur nulle ;
2. `Button.get_minimum_size()` dimensionne donc le bouton **comme si son texte était large
   de 0 px** ;
3. mais le *dessin* passe par la substitution système et produit bien des glyphes ;
4. envoyés dans une boîte trop petite, ils sont **rognés au premier caractère**. « Oui »
   s'affichait « O », ce qui se lit « 0 ».

Les `Label` ne le montraient pas : presque tous ont des ancres ou une taille minimale
explicite, donc leur largeur ne dépend pas de la mesure du texte. **Seuls les widgets qui se
dimensionnent sur leur contenu révélaient la panne** — les boutons.

**C'est réglé, et pas en réparant la police.** Les 104 surcharges qui la citaient sont
parties avec le repli : chacun de ces nœuds prend maintenant la police du thème, la vraie.
`amon_font.tres` et `amon_font_small.tres` n'étaient plus lues que par l'archive → parties
dans `archive/src/`. `Pancis-Regular` (l'`.otf` **et** le `.ttf`), la police d'origine du
projet Godot 3, n'était référencée par rien → `archive/unuzed/`. `fonts/` ne contient plus
que RobotoCondensed.

`default_font_size = 16` vaut le défaut de Godot : c'est la taille effective, écrite
explicitement.
