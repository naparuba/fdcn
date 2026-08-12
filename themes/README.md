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

Deux écritures du même gris traînent dans les scènes : `Color(0.92549, 0.929412, 0.94902, 1)`
et `Color(0.9254902, 0.92941177, 0.9490196, 1)` (`AventureMenu.tscn`). Même couleur,
précision différente — à unifier lors de l'action 5.1.

## Le style principal, et les variations

Le **socle** s'applique sans rien demander : `default_font`, `default_font_size`, la
couleur de texte des `Label`, l'habillage des `Button`, la carte des `PanelContainer`.

Les **variations** sont les styles secondaires. On les pose sur un nœud avec une seule
ligne, et la couleur reste ici :

```gdscript
theme_type_variation = &"TitreHeader"
```

| variation | base | ce que c'est |
|---|---|---|
| `TitreHeader` | `Label` | titre blanc posé sur un en-tête navy |
| `TexteAccent` | `Label` | `#00c2aa` |
| `TexteAtenue` | `Label` | `#666b70`, texte secondaire |
| `TexteAppuye` | `Label` | `#4a4f54` |
| `TexteAlerte` | `Label` | `#ff6b00` |
| `Carte` | `Panel` | carte blanche, rayon 2 |
| `Fond` | `Panel` | fond d'application |
| `EnTete` | `PanelContainer` | bandeau navy |
| `Encart` | `PanelContainer` | encart gris, rayon 2 |
| `SwitchOui` / `SwitchNon` | `CheckButton` | vert/rouge, texte blanc — pilotés par `ui/yes_no_switch.gd` |

C'est ce mécanisme qui a retiré **450 surcharges de style**, ramenées à 41 (review §8.3) :
la scène ne déclare plus qu'un rôle. **99 variations** sont posées dans les 30 scènes.

## Ce qui n'est volontairement pas défini

**`Panel/styles/panel`.** Les 41 `Panel` de l'app se répartissent en 38 qui portent leur
propre stylebox et 3 qui s'appuient sur le défaut de Godot — dont les **deux bandes de
navigation** (`ui/NavButon.tscn`), qui n'ont qu'un `Polygon2D` par-dessus. Un fond par
défaut sur `Panel` leur peindrait un bloc visible sur toute la hauteur de l'écran, des
deux côtés. La carte blanche est donc portée par `PanelContainer` ; un `Panel` qui la
veut prend la variation `Carte`.

**Les `constants/separation` des conteneurs.** L'app utilise 6, 8, 4, 2, 12 et 0 selon
l'endroit ; Godot vaut 4 par défaut. Imposer une valeur déplacerait la mise en page des
20 conteneurs qui n'en déclarent aucune, sans rien gagner.

**Les `constants/shadow_offset_*`.** 55 `Label` les mettent à 0 pour éteindre une ombre
héritée de Godot 3. En Godot 4 `font_shadow_color` est déjà transparent, donc ces
165 lignes ne font rien. Le thème pose explicitement `font_shadow_color` transparent pour
qu'on puisse les supprimer sans y réfléchir.

## ⚠️ Pourquoi le thème pointe sur le `.ttf` et pas sur `amon_font.tres`

```
default_font = res://fonts/RobotoCondensed-Regular.ttf
default_font_size = 16
```

**`fonts/amon_font.tres` ne porte aucune police.** Il déclare `size = 25` et
`font_data = ...`, qui sont des **noms de propriétés Godot 3** : le `FontFile` de Godot 4
ne les expose pas. La preuve est dans l'historique du fichier — quand l'éditeur Godot 4 a
réécrit cette ressource (commit `eabcbbc`), il a produit `fixed_size` et des entrées
`cache/*`, **sans aucun `font_data`**. Les deux propriétés actuelles ont été remises à la
main ensuite (`f31b957`).

Ce n'est pas cosmétique, et ça s'est vu tout de suite : **une police vide mesure 0.**

1. `get_string_size()` renvoie une largeur nulle ;
2. `Button.get_minimum_size()` dimensionne donc le bouton **comme si son texte était large
   de 0 px** ;
3. mais le *dessin* passe par la substitution système et produit bien des glyphes ;
4. ils sont envoyés dans une boîte trop petite → **le texte est rogné au premier
   caractère**. « Oui » s'affichait « O », ce qui se lit « 0 ».

Les `Label` ne le montraient pas : ils ont presque tous des ancres ou une taille minimale
explicite, donc leur largeur ne dépend pas de la mesure du texte. Les boutons, eux, se
dimensionnent sur leur contenu — d'où un symptôme visible seulement sur eux.

Le thème utilise donc la police **réellement importée**. Cela ne touche que les nœuds qui
n'avaient aucune police à eux ; les **104 surcharges** qui référencent encore
`amon_font.tres` ou une de ses coquilles gardent leur situation d'avant, mesure nulle
comprise. Elles ne sont plus utilisées par personne :
les 104 surcharges qui les citaient sont parties avec le repli, et les deux `.tres` ont
rejoint `archive/src/`. Voir `review.md` §8.5.

`default_font_size = 16` vaut le défaut de Godot : c'est la taille effective actuelle,
écrite explicitement. `amon_font.tres` prétend 25, sans effet.
