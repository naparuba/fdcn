# Règles spéciales de combat — Tome 1 (La Forteresse du Chaudron Noir)

Catalogue de tous les combats du livre 1 (45 au total, cf `fdcn-1-compilated-combats.json`).
But : lister les règles spéciales propres à CHAQUE combat (régénération, immunité à
certaines plages de dégâts, fuite forcée, debuff temporaire, esquive/critique adverse...)
avant de chercher à généraliser quoi que ce soit dans `combat.gd` — on verra les vraies
règles génériques émerger une fois la liste remplie, plutôt que d'en deviner à l'avance.

Colonnes Hab/PV/Arm/Deg/Pyro = données déjà dans `fdcn-1-compilated-data.json` (le combat
"standard", cf Table des Situations). La colonne "Règle spéciale" est à remplir au fur et
à mesure (lecture du livre physique, wiki, ou aide complémentaire) — vide = pas encore
vérifié, PAS "aucune règle spéciale". "Pyro-Barbare +N" reprend la valeur déjà présente
dans la colonne Pyro ; répété ici uniquement quand le texte du livre le mentionne
explicitement pour éviter toute ambiguïté.

Source : dictée directe du livre physique par l'utilisateur (2026-07-10), sauf 317 (Guide
détaillé, complété/corrigé ensuite par la dictée).

## Architecture retenue (2026-07-10) : Modificateurs composables, pas de sous-classes

Décision (cf discussion dédiée) : plutôt qu'une sous-classe de `Combat` par nœud, chaque
règle spéciale est un petit objet `Modificateur` (`combat_modificateurs.gd`) attaché à un
combat via `opts.modificateurs`, appelé à des points d'accroche fixes dans
`Combat.play_turn()`/`is_over()`/`get_winner()`. Les mêmes classes se réutilisent sur
plusieurs nœuds avec des paramètres différents (ex: `EsquiveAdverseSurDe` couvre 173, 175,
320, 321, 574 avec juste un prédicat différent).

**Statut (2026-07-10) : tests écrits AVANT l'implémentation (TDD demandé explicitement).**
`combat_modificateurs.gd` ne contient que des squelettes (méthodes présentes, logique pas
codée) ; `test/unit/test_combat_regles_speciales_tome1.gd` couvre ~30 nœuds avec plusieurs
variations pour les plus complexes (97, 475/607, 346, 534, 240, 320) — 54 tests, rouge
intentionnel (16 passent par coïncidence sur les cas "négatifs", 38 échouent comme attendu).
Prochaine étape : remplir `combat_modificateurs.gd` pour de vrai.

**Ce qui n'a besoin d'AUCUN nouveau code (côté APPELANT, valeur calculée puis passée
directement à `Combat.new()`)** : tout malus/bonus FIXE pour toute la durée du combat --
`-1/-2 Adresse` (19, 74, 320 partiel, 339, 387), Habileté divisée par 2 une fois pour toutes
avec arrondi/plancher (58, 317), plancher d'Habileté (133), override de dégâts par arme vs
squelettes (36, 76, 155, 349 -- Arc/Morgenstern/Massue), neutralisation d'Armure (286),
mise à zéro de `deg_billy`/`critique_billy` pour un combat précis (162 alternative, 306,
534 partiel). Rejouer un même combat deux fois (133) ou chaîner deux instances `Combat`
avec l'état qui persiste entre elles (475→607) est une question d'orchestration côté
appelant (main.gd, plus tard), pas de `combat.gd`.

**Écart trouvé en écrivant les tests, pas encore couvert par un Modificateur dédié** : les
nœuds 306 ("à chaque tour, l'adversaire perd 1 point d'Habileté", inconditionnel) et 346
("à chaque tour après le premier, -1 Habileté adverse") décroissent par NUMÉRO DE TOUR, pas
par dégâts cumulés infligés -- une mécanique différente de
`HabiliteAdverseDegressiveParDegatsCumules` (76/155/231/370/518, qui suit les dégâts). Le
test de 346 contourne ça en superposant deux modificateurs plutôt que d'avoir la bonne
classe dédiée. À corriger : ajouter un `HabiliteAdverseDecroissanteParTour` avant
d'implémenter 306/346 pour de vrai.

| Nœud | Lieu/Arc | Ennemi | Hab | PV | Arm | Deg | Pyro | Règle spéciale |
|---|---|---|---|---|---|---|---|---|
| 14 |  | GUERRIERS ORCS | 5 | 8 | 0 | 0 | 4 | Rien de spécial. |
| 19 |  | GUARDES CORROMPUS | 8 | 12 | 1 | 0 | 4 | Pyro-Barbare +4. Malgré son aide, vous êtes en partie encerclé : **-1 ADRESSE** pour ce combat. |
| 36 |  | 2 SQUELETTES | 4 | 10 | 0 | 0 | 0 | Face aux squelettes, l'**ARC** a un malus de **-1 dégât**. La **MORGENSTERN** inflige **+2 dégâts** au lieu de +1. Pensez à vos pouvoirs de CHANCE. Si MASSACRE a été surpris grâce aux INFOS : **8 tours** pour vaincre ses sbires, sinon **5 tours**. Passé ce délai, ses renforts vous encerclent et vous achèvent. |
| 54 | Bagarre | ORC FAMILIER | 10 | 16 | 0 | 1 | 0 | Rien de spécial. |
| 58 | Bagarre | GNOLL SANGUINAIRE | 5 | 10 | 0 | 0 | 0 | Ce gnoll a la langue aussi acérée que sa lame : votre **HABILETE est divisée par 2** pour ce combat, **arrondie au SUPÉRIEUR**. |
| 74 |  | 5 BANDITS DE GRAND CHEMIN | 11 | 15 | 0 | 0 | 6 | Vous êtes encerclé : **-1 ADRESSE**. |
| 76 |  | 5 GUERRIERS SQUELETTES | 12 | 20 | 0 | 0 | 4 | Pyro-Barbare +4. Chaque squelette a **4 PV** ; tous les 4 PV retirés à l'adversaire, il **perd 1 HABILETE** (recalculer PV/Habileté adverses selon le nombre de squelettes restants). Squelettes **immunisés contre l'ARC** (impossible de l'équiper). **MORGENSTERN**/**Petite Massue** : **+2 dégâts** au lieu de +1. |
| 97 |  | MASSACRE | 12 | 20 | 0 | 1 | 4 | Pyro-Barbare +4. Tous les **3 tours**, Massacre invoque un trait de flamme qui fait perdre **3 PV** à la fin du tour, **après** application des dommages normaux (un PAYSAN subit donc quand même ces 3 PV, malgré son plafond). Esquivable comme une attaque normale si assez d'Adresse, **mais sans contre-attaque critique possible** sur cette esquive précise. Si surpris grâce aux INFOS : **8 tours** pour le vaincre, sinon **5 tours** ; passé ce délai, ses renforts vous encerclent et vous achèvent. |
| 114 | Quartier boulanger | ORC ESCLAVAGISTE | 10 | 10 | 0 | 0 | 4 | Pyro-Barbare +4. Le fouet de l'esclavagiste lui donne l'avantage : lors du calcul des dégâts, **retirez vos PV avant les siens**. Si vous mourrez tous les deux le même tour, **c'est lui qui reste debout** (votre attaque finale est annulée). |
| 133 |  | GUARDE CORROMPU (x2) | 4 | 7 | 0 | 1 | 0 | On dispute **deux fois le même combat** à la suite. **Habileté minimale de 4** pour ce combat (plancher, pas juste une valeur de base). |
| 155 |  | 5 GUERRIERS SQUELETTES | 12 | 20 | 0 | 0 | 2 | Pyro-Barbare +2. Même mécanique que le nœud 76 (4 PV/squelette, -1 Habileté adverse tous les 4 PV retirés, ARC immunisé/inéquipable, MORGENSTERN/Petite Massue +2 dégâts). En plus : le surnombre et le couloir étroit font perdre **1 ADRESSE** pour ce combat. |
| 162 |  | TROLESSE AFFAIBLIE | 11 | 12 | 0 | 1 | 4 | Pyro-Barbare +4. En cas de coup critique normal, votre **bonus de CRITIQUE ne s'applique pas**. Si une contre-attaque critique est déclenchée lors de la phase d'esquive, elle n'infligé que les **dégâts maximum de la situation** (sans le bonus Critique). |
| 173 |  | BANDIT A LA CAPE CRAMOISIE (ROUGE) | 6 | 10 | 0 | 0 | 0 | Sur un jet de **1 ou 2** durant la phase d'attaque, le bandit **esquive** votre coup (aucun dégât) et esquive aussi votre contre-attaque critique le cas échéant. |
| 175 |  | 3 ELFES NOIRES | 11 | 8 | 0 | 0 | 4 | Pyro-Barbare +4. Extrêmement agiles : si le dé de la phase d'attaque donne un résultat **PAIR**, elles **esquivent** (aucun dégât, y compris contre-attaque critique). |
| 231 |  | 4 HOMMES D'ARMES | 11 | 16 | 0 | 2 | 4 | Pyro-Barbare +4. Tous les 4 PV perdus par l'ennemi, il **perd 1 point d'Habileté**. |
| 232 |  | OGRE MAL EMBOUCHE | 10 | 20 | 0 | 1 | 4 | Pyro-Barbare +4. Dès que ses PV sont à **10 ou moins**, il **DOUBLE ses DEGATS** sur la Table des Situations. |
| 240 |  | GUEPE GEANTE | 8 | 10 | 0 | 0 | 0 | Sur un jet de **1, 2 ou 3** durant la phase d'attaque, la guêpe **esquive totalement** (et la contre-attaque critique éventuelle) — **SAUF** si équipé de la **LANCE** ou de l'**ARC**, auquel cas le combat se déroule normalement. Quand la créature atteint **3 PV ou moins**, le combat se termine. |
| 274 |  | XXXX | 1 | 1 | 1 | 1 | 1 | Rien de spécial (fixture de test interne au jeu, nom "XXXX" — probablement un placeholder narratif, pas un vrai combat rencontré normalement). |
| 276 | Mortelle | GUARDES CORROMPUS + TROLESSE | 6 | 8 | 0 | 0 | 0 | Grâce à ses multiples bras, la trolesse n'est **jamais prise de court** et **ne subit jamais de coup critique**. Si un coup critique est obtenu lors de la phase d'esquive, **aucun dégât n'est infligé** (esquive simple, pas de contre-attaque). |
| 286 |  | PLANTE CARNITREX | 13 | 18 | 0 | 0 | 7 | Pyro-Barbare +7. L'acide de la plante **annule votre Armure** si vous en avez. Entre chaque tour, les spores acides font **perdre automatiquement 1 PV**. Votre épaule blessée fait perdre **1 point d'HABILETE** pour ce combat. |
| 297 |  | 2 SERGENT D'ARME | 8 | 12 | 1 | 1 | 0 | Rien de spécial. |
| 306 |  | IVROGNE QUI DETESTE GIRAUD | 3 | 8 | 0 | 0 | 0 | Impossible d'utiliser armes/outils : combat avec l'**Habileté naturelle uniquement**. À chaque tour, l'adversaire **perd 1 point d'Habileté**. |
| 317 | Tour des mages | GNOLLS MOQUEURS | 6 | 15 | 0 | 0 | 0 | Les provocations perturbent votre Habileté : **divisée par 2**, arrondie au chiffre **INFÉRIEUR**, **plancher à 1** (ne peut pas descendre sous 1). |
| 320 | Funeste | FUNESTE | 8 | 12 | 0 | 0 | 4 | Pyro-Barbare +4. Funeste est très rapide : **-2 ADRESSE** pour ce combat. Si le résultat de la phase d'attaque est **IMPAIR**, Funeste **esquive** (y compris contre-attaque critique). Si le résultat est exactement **1**, en plus d'esquiver, sa propre contre-attaque lui donne **+2 dégâts** ce tour-là. |
| 321 |  | 2 ELFES NOIRES SURPRISES | 9 | 6 | 0 | 0 | 4 | Pyro-Barbare +4. Entrée spectaculaire : l'ennemi **n'attaque pas au premier tour**. Agiles : si le dé de la phase d'attaque donne un résultat **IMPAIR**, elles **esquivent** (aucun dégât, y compris contre-attaque critique). |
| 339 |  | ASMODIA | 20 | 27 | 0 | 0 | 10 | *(= "la vampiresse")* Pyro-Barbare +10. Très rapide : **-1 ADRESSE**. Si le dé de la phase d'attaque donne **1 ou 2**, elle **ne subit aucun dégât et régénère 1 PV**. Si le Petit Médaillon d'Atella ou le Médaillon de Runir est possédé, cette **régénération est annulée**. |
| 344 | Quartier boulanger | ORC ESCLAVAGISTE | 10 | 10 | 0 | 0 | 4 | Pyro-Barbare +4. En infligeant des dégâts, choisir entre blesser l'orc ou éliminer un des deux carcajous. Tant qu'un carcajou est vivant, faire un **jet d'Endurance à chaque tour comme un jet d'Adresse** (score d'Endurance à la place du score d'Adresse) : en cas d'échec, **pas d'attaque ce tour-là**. |
| 346 |  | BAGARRE GENERALE | 1 | 18 | 0 | 0 | 0 | Chaos total : à chaque tour, l'**Habileté adverse** est déterminée par **1 + 1d6×2** (relancée à chaque tour), puis jet de phase d'attaque normal. Le Pyro-Barbare aide indirectement : à chaque tour **après le premier**, l'adversaire **perd 1 point d'Habileté**. |
| 349 | Catacombes | MASSACRE | 13 | 18 | 0 | 1 | 4 | Pyro-Barbare +4. *(Massacre-squelette, cf nœud 97)* Il est **LENT** : n'attaque pas au premier tour. Sensible aux armes contondantes : **Petite Massue** ou **Morgenstern** infligent **+1 dégât supplémentaire**. L'**Arc** est inefficace : **-1 dégât**. |
| 350 |  | DRAGON ROUGE INFERIEUR | 15 | 40 | 0 | 1 | 3 | Pyro-Barbare **+3 seulement** (le tintement de son pagne le perturbe — bonus réduit par rapport à la normale). Bien inclure le dégât supplémentaire du dragon sur son attaque. Quand il arrive à **20 PV ou moins**, le combat se termine. |
| 370 |  | SOLDATS DE LA TAVERNE | 16 | 30 | 0 | 0 | 4 | Pyro-Barbare +4. Tous les 2 PV perdus par l'ennemi, il **perd 1 point d'Habileté**. Sous-nombre : **-3 ADRESSE**, mais **+1 Adresse regagné tous les 10 PV** perdus par l'ennemi. |
| 387 |  | 5 BANDITS DE GRAND CHEMIN | 11 | 15 | 0 | 0 | 6 | Pyro-Barbare +6. Vous êtes encerclé : **-1 ADRESSE**. Si le Jet de Chance est raté, les ennemis ont droit à **un tour d'attaque sans esquive ni riposte possible**. |
| 421 | Bagarre | CHAMPIONNE TROLLESSE | 11 | 20 | 0 | 1 | 0 | Vise la tête pendant que ses deux bras du bas gèrent le reste : **chaque fois que vous recevez des dégâts, -1 Habileté** pour ce combat (cumulatif). Si vos PV atteignent 0, **vous ne mourez pas** (pas de défaite létale sur ce combat). |
| 422 | Quartier boulanger | ORC ESCLAVAGISTE | 10 | 10 | 0 | 0 | 4 | Pyro-Barbare +4. *(même fouet qu'au nœud 114 : retirez vos PV avant les siens)* Si vous mourrez tous les deux le même tour, cette fois **c'est vous qui perdez** (inverse du nœud 114). |
| 462 | Bagarre | GOBELIN FOU | 2 | 6 | 0 | 0 | 0 | Ce gobelin est possédé : quand ses PV atteignent 0, il **joue un tour supplémentaire** et attaque une dernière fois avant de vraiment mourir. |
| 475 |  | VIRILUS | 30 | 40 | 1 | 1 | 5 | *(Combat final, 1ère phase)* Pas de fuite possible. La règle de **DOMINATION est inactive**, et **pas de victoire/défaite automatique** via les points de Chance. Pyro-Barbare **+5** (hache enflammée). Le Gant de Virilus donne un avantage magique : chaque tour, lancez un **dé supplémentaire** en plus des phases d'attaque/esquive : **1-2-3** → perte automatique de **1 PV** avant même la phase d'attaque ; **4-5** → **-1 dégât** infligé ce tour ; **6** → **+2 Habileté** ce tour. Sauf indication contraire, Virilus est **insensible aux coups critiques** (aucun dégât de contre-attaque critique). Bien appliquer tous les effets d'objets. Le combat se termine quand l'adversaire atteint **20 PV ou moins**. |
| 483 |  | MENDIANT FOU A LIER | 3 | 8 | 0 | 0 | 0 | Chaque coup reçu fait perdre **1 point de CHANCE**, même si l'attaque ne fait aucun dégât. Cet effet est **esquivable**. |
| 518 |  | SOLDATS DE LA TAVERNE | 16 | 30 | 0 | 0 | 4 | Pyro-Barbare +4. *(identique au nœud 370)* Tous les 2 PV perdus par l'ennemi, il perd 1 point d'Habileté. Sous-nombre : **-3 ADRESSE**, **+1 Adresse regagné tous les 10 PV** ennemis perdus. |
| 534 |  | PANTHERE INVOQUEE | 8 | 9 | 0 | 0 | 0 | Intangible : **ignore votre Armure, vos bonus de Dégâts** (Dégâts Guerrier, Morgenstern, etc.) **et vos coups critiques**. En contrepartie, elle inflige **-3 dégâts** au premier tour, malus qui **remonte de +1 par tour** jusqu'à atteindre 0 (dégâts pleins à partir du 4ᵉ tour). |
| 545 | Tour des mages | SCORPION GEANT | 6 | 20 | 3 | 0 | 4 | Pyro-Barbare +4. Rien d'autre de spécial. |
| 555 |  | OGRE | 10 | 20 | 0 | 1 | 4 | Pyro-Barbare +4. Dès que ses PV passent sous **10 (inclus)**, les dégâts qu'il inflige (Table des Situations) sont **doublés**. |
| 574 | Thermes | ELFES NOIRES NUES | 7 | 10 | 0 | 1 | 3 | Pyro-Barbare +3 *(le "-1 Habileté du Pyro-Barbare, distrait" est déjà appliqué dans ce +3 — pas un malus actif séparé à recalculer)*. Les adversaires se battent nues : **-1 ADRESSE** pour le joueur. Très agiles : sur un jet de **1** en phase d'attaque, elles gagnent **+3 dégâts** ce tour ; sur un jet de **6**, elles **esquivent totalement** (y compris contre-attaque critique). |
| 575 |  | GNOLL ENDORMI | 6 | 12 | 0 | 0 | 4 | L'ennemi a un malus de **-2 Habileté durant le premier tour uniquement** (surprise, il dort). |
| 576 | Laboratoire | CHAMAN FOU | 6 | 15 | 0 | 1 | 4 | Pyro-Barbare +4. L'adversaire enfle à vue d'œil. À la fin du **3ᵉ tour**, il **explose** : perte de **10 PV**, **non esquivable et non affecté par l'Armure**. Un **PAYSAN** ne subit que **3 PV** (son plafond habituel s'applique). Un **PRUDENT** ne subit que **5 PV** (protégé en partie par la force du Pyro-Barbare). |
| 607 |  | VIRILUS | 24 | 20 | 1 | 1 | 0 | *(Combat final, 2ᵉ phase — suite du nœud 475)* Règle de **DOMINATION inactive**, **pas de victoire/défaite automatique**. Virilus est blessé et sa gemme brisée : **plus de magie** (le jet supplémentaire du Gant, cf nœud 475, ne s'applique plus). **Tous les effets infligés en phase 1 (nœud 475) sont conservés.** Si l'armée de squelettes a été détruite (cf stratégie GUERRIER, Morgenstern) : Virilus **perd 10 points d'Habileté** — **ne pas cumuler** si ce malus a déjà été appliqué en phase 1. **Victoire si : 8 tours survécus OU le combat est remporté** (condition de victoire double, pas juste PV adverses à 0). |
