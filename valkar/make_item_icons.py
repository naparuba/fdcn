# -*- coding: utf-8 -*-
"""Genere les icones d'objets du livre 3 : images/items/<NOM DE L'OBJET>.svg (120x120).

Meme style que les pictos de succes (valkar/make_pictos.py) : glyphes noirs pleins, traits
epais, details en reserve (masque). Le nom du fichier est exactement le nom de l'objet.

Usage : python valkar/make_item_icons.py [dossier_de_sortie]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_pictos import path, circ, ell, rect, line, poly, rot, T, star, HEART  # noqa: E402

OUT_DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'images', 'items')

ICONS = {}


def icon(name, body, holes='', extra=''):
    ICONS[name] = (body, holes, extra)


def sword(blade_top=4, blade_bottom=62, grip_end=92, pommel=98, wide=7):
    """Epee verticale (pointe en haut), pour rot()."""
    return (poly([(60, blade_top), (60 + wide, blade_bottom), (60 - wide, blade_bottom)])
            + rect(38, blade_bottom, 44, 8, 3) + rect(56, blade_bottom + 8, 8, grip_end - blade_bottom - 8)
            + circ(60, pommel, 6))


def banner(emblem_holes):
    return (line(24, 8, 24, 114, 6) + path('M28 14 H106 V76 L67 62 L28 76 Z'), emblem_holes)


def key(x, top, length, head=8):
    return (line(x, top, x, top + length, 6) + circ(x, top - 2, head, False, 5)
            + line(x, top + length, x + 10, top + length, 5) + line(x, top + length - 12, x + 8, top + length - 12, 5))


# ---------------------------------------------------------------- armes, protections
icon('ARC PHASMIQUE',
     path('M34 8 Q104 60 34 112', False, 8) + line(34, 8, 34, 112, 3) + line(12, 60, 92, 60, 5)
     + poly([(102, 60), (86, 51), (86, 69)]) + star(22, 24, 11, 4, 4))
icon('EPEE BATARDE 1 MAIN', rot(sword(), 30, 60, 60))
icon('EPEE BATARDE 2 MAINS', rot(sword(2, 54, 108, 112), 30, 60, 60),
     rot(line(54, 70, 66, 70, 3) + line(54, 80, 66, 80, 3) + line(54, 90, 66, 90, 3) + line(54, 100, 66, 100, 3), 30, 60, 60))
icon('EPEE EN ACIER ARKADIE', rot(sword(), 30, 60, 60) + star(98, 22, 13, 5, 4))
icon('FLEURET',
     rot(line(60, 6, 60, 76, 5) + path('M38 80 Q60 104 82 80 Z') + line(60, 92, 60, 110, 8), 25, 60, 60))
icon('LANCE DE JOUTE',
     rot(line(60, 4, 60, 116, 7) + poly([(60, 2), (69, 24), (51, 24)]) + path('M36 90 Q60 60 84 90 Z'), 40, 60, 60))
icon('LANCE MEDIOCRE',
     rot(path('M60 116 L60 52 Q62 42 56 36', False, 7) + poly([(52, 36), (62, 12), (70, 40)]), 35, 60, 60),
     rot(path('M58 84 L64 78', False, 3), 35, 60, 60))
icon('DAGUE A ROUELLES',
     rot(poly([(60, 4), (69, 62), (51, 62)]) + rect(40, 62, 40, 8, 3) + rect(56, 70, 8, 16)
         + star(60, 100, 14, 5, 8), 30, 60, 60))
icon('RAPIERE-ARBALETE',
     path('M8 40 Q60 6 112 40', False, 8) + line(8, 40, 112, 40, 3) + rect(54, 40, 12, 70, 4)
     + poly([(60, 2), (67, 44), (53, 44)]))
icon('FLECHES EN ACIER ARKADIE',
     ''.join(rot(line(60, 12, 60, 112, 5) + poly([(60, 2), (69, 22), (51, 22)])
                 + poly([(60, 104), (72, 114), (60, 112), (48, 114)]), a, 60, 112) for a in (-24, 0, 24)))
icon('PEAUFINAGE DE VOTRE ARME',
     rect(12, 78, 96, 26, 5) + poly([(22, 72), (98, 44), (102, 54), (28, 80)]) + star(100, 30, 11, 4, 4)
     + line(80, 24, 90, 12, 4) + line(108, 38, 116, 28, 4),
     line(26, 90, 94, 90, 3))
icon('BOUCLIER', circ(60, 60, 46), circ(60, 60, 22, False, 6) + circ(60, 60, 6))
icon('BOUCLIER EN DIAMANT',
     path('M20 12 H100 V56 Q100 94 60 112 Q20 94 20 56 Z'),
     poly([(60, 30), (84, 56), (60, 88), (36, 56)]))
icon('ARMURE COMPOSITE',
     path('M22 20 L46 12 Q60 26 74 12 L98 20 L108 56 L92 62 V108 H28 V62 L12 56 Z'),
     line(60, 38, 60, 100, 4) + circ(38, 50, 3) + circ(82, 50, 3))
icon('BRASSARDS',
     T(rot(path('M14 14 H40 L46 104 H8 Z'), 12, 27, 59), 10, 0, 1) + T(rot(path('M80 14 H106 L112 104 H74 Z'), -12, 93, 59), -10, 0, 1),
     T(rot(line(16, 36, 38, 36, 4) + line(14, 58, 40, 58, 4) + line(12, 80, 42, 80, 4), 12, 27, 59), 10, 0, 1)
     + T(rot(line(82, 36, 104, 36, 4) + line(80, 58, 106, 58, 4) + line(78, 80, 108, 80, 4), -12, 93, 59), -10, 0, 1))
icon('PROTEGE-GENOUX',
     rect(24, 12, 72, 96, 34),
     line(24, 36, 96, 36, 4) + line(24, 84, 96, 84, 4) + circ(60, 60, 16, False, 6) + circ(60, 60, 5))
icon('CHAINE METALLIQUE',
     rot(ell(32, 32, 24, 12, False, 8), 45, 32, 32) + rot(ell(60, 60, 24, 12, False, 8), -45, 60, 60)
     + rot(ell(88, 88, 24, 12, False, 8), 45, 88, 88))
icon('CASSEROLE ORNEE',
     path('M20 48 H100 V92 Q100 104 88 104 H32 Q20 104 20 92 Z') + rect(16, 40, 88, 10, 4) + circ(60, 30, 8)
     + rect(4, 58, 18, 8, 4) + rect(98, 58, 18, 8, 4),
     star(60, 76, 14, 6))
icon('MARTEAU', rot(rect(22, 16, 76, 32, 5) + rect(54, 46, 12, 68, 4), 25, 60, 60), rot(line(34, 26, 86, 26, 3), 25, 60, 60))
icon('PETIT MARTEAU', T(rot(rect(30, 20, 60, 26, 5) + rect(55, 44, 10, 56, 4), 25, 60, 60), 12, 14, 0.8))
icon('BECHE',
     line(60, 8, 60, 68, 8) + rect(44, 6, 32, 10, 4) + path('M36 64 H84 V80 Q84 108 60 114 Q36 108 36 80 Z'))
icon('CANNE', path('M70 114 V42 Q70 12 46 14 Q30 16 32 34', False, 10))
icon('LAME CLE A MOLETTE',
     rot(rect(50, 38, 14, 78, 6) + circ(57, 34, 22), 35, 57, 60) , rot(rect(52, 6, 10, 28), 35, 57, 60))
icon('LONGUE-VUE',
     rot(poly([(8, 52), (40, 50), (40, 70), (8, 68)]) + poly([(40, 46), (74, 42), (74, 78), (40, 74)])
         + poly([(74, 36), (112, 28), (112, 92), (74, 84)]), -20, 60, 60),
     rot(ell(110, 60, 3, 22), -20, 60, 60))
icon('BOMBES AVEUGLANTES',
     circ(52, 72, 34) + path('M70 44 Q82 30 92 32', False, 6) + star(100, 26, 15, 6, 8)
     + line(106, 4, 106, 10, 4) + line(118, 18, 112, 22, 4),
     path('M32 60 Q36 48 48 46', False, 5))
icon('BRIQUET IMPOSSIBLE',
     rect(36, 52, 48, 58, 8) + rect(42, 38, 36, 16, 3) + path('M60 4 Q82 24 70 38 Q60 44 50 38 Q38 24 60 4 Z'),
     line(36, 86, 84, 86, 4))

# ------------------------------------------------------------- classes, pays, evenements
icon('BELLICISTE', rot(sword(), 45, 60, 60) + rot(sword(), -45, 60, 60))
icon('ELUSIF',
     path('M60 8 Q92 14 92 52 L106 110 H14 L28 52 Q28 14 60 8 Z'),
     ell(60, 46, 17, 21), circ(54, 46, 3.5) + circ(66, 46, 3.5))
icon('FONCTIONNAIRE',
     rect(46, 6, 28, 34, 14) + rect(52, 38, 16, 28) + rect(24, 64, 72, 16, 4) + line(12, 100, 108, 100, 8))
icon('OUVRIER',
     circ(60, 60, 32) + ''.join(rot(rect(52, 10, 16, 22, 3), a, 60, 60) for a in range(0, 360, 45)),
     circ(60, 60, 13))
b, h = banner(line(67, 26, 67, 56, 5) + line(55, 38, 79, 38, 5))
icon('ARKADIE', b, h)
b, h = banner(path('M55 56 V40 Q55 26 67 26 Q79 26 79 40 V56 Z'))
icon('SOLQUARDIE', b, h)
b, h = banner(circ(60, 48, 7) + line(66, 48, 66, 24, 4) + path('M66 24 Q80 28 78 38', False, 4))
icon('VALOISIE', b, h)
icon('CENTAURESSE',
     path('M34 22 V66 Q34 104 60 104 Q86 104 86 66 V22', False, 14),
     circ(34, 40, 3) + circ(34, 58, 3) + circ(86, 40, 3) + circ(86, 58, 3))
icon('VICTIMUS',  # un chevalier : heaume de croise (fente en T) a panache
     path('M24 108 V52 Q24 16 60 16 Q96 16 96 52 V108 Z') + rect(18, 100, 84, 12, 4)
     + path('M60 16 Q54 -2 78 2 Q98 8 90 34', False, 8),
     rect(28, 44, 64, 10, 3) + rect(55, 54, 10, 40, 3))

# ------------------------------------------------------------------- objets divers
icon('ACTE DE PROPRIETE',
     rect(26, 8, 68, 100, 6),
     line(38, 28, 82, 28, 5) + line(38, 42, 82, 42, 5) + line(38, 56, 70, 56, 5) + circ(74, 88, 11))
icon('AMULETTE TRIBALE',
     path('M22 8 Q60 72 98 8', False, 5) + poly([(60, 60), (86, 86), (60, 114), (34, 86)]),
     line(60, 72, 60, 102, 4) + line(46, 86, 74, 86, 4))
icon('TALISMAN TRIBAL',
     circ(60, 62, 40) + path('M44 22 Q60 -2 76 22', False, 5),
     circ(46, 54, 6) + circ(74, 54, 6) + path('M40 80 L50 72 L60 80 L70 72 L80 80', False, 4))
icon('ECUSSON ECUREUIL',
     path('M18 12 H102 V56 Q102 94 60 112 Q18 94 18 56 Z'),
     ell(70, 72, 11, 17) + circ(62, 50, 8) + path('M52 92 Q34 70 52 56 Q60 46 52 34', False, 7))
icon('EDELWEISS',
     ''.join(rot(ell(60, 26, 8, 20), a, 60, 60) for a in range(0, 360, 45)) + circ(60, 60, 12),
     circ(60, 60, 5))
icon('ESSENCE DE GLUCOSIUM',
     path('M48 22 H72 V48 Q96 60 96 84 Q96 110 60 110 Q24 110 24 84 Q24 60 48 48 Z') + rect(46, 10, 28, 14, 3),
     poly([(46, 80), (60, 72), (74, 80), (74, 96), (60, 104), (46, 96)]))
icon('FAVEUR DE SERVILLE',
     path('M60 50 Q18 18 16 54 Q22 74 60 56 Z') + path('M60 50 Q102 18 104 54 Q98 74 60 56 Z') + circ(60, 54, 10)
     + poly([(52, 62), (36, 112), (54, 98), (58, 66)]) + poly([(68, 62), (84, 112), (66, 98), (62, 66)]))
icon('FLUTE RIGOLOTE',
     rot(rect(8, 50, 104, 18, 9), -25, 60, 60) + circ(98, 24, 6) + line(104, 24, 104, 6, 4),
     rot(circ(30, 59, 3.5) + circ(48, 59, 3.5) + circ(66, 59, 3.5) + circ(84, 59, 3.5), -25, 60, 60))
icon("GRAPPE D'AMETHYSTES",
     ''.join(circ(x, y, 12) for x, y in ((38, 46), (60, 46), (82, 46), (49, 68), (71, 68), (60, 90)))
     + line(60, 34, 60, 14, 5) + path('M60 18 Q82 4 98 16 Q84 32 60 18 Z'),
     path('M33 42 Q36 36 42 36', False, 3) + path('M55 42 Q58 36 64 36', False, 3))
icon('HERBE DES FEES',
     path('M60 112 Q54 70 60 18', False, 5)
     + rot(ell(44, 84, 7, 16), -50, 44, 84) + rot(ell(76, 70, 7, 16), 50, 76, 70)
     + rot(ell(44, 54, 7, 16), -50, 44, 54) + rot(ell(76, 40, 7, 16), 50, 76, 40) + star(94, 18, 12, 4, 4))
icon('HUILLE UNIVERSELLE',
     rect(26, 56, 52, 50, 6) + rect(40, 46, 24, 12, 3) + path('M78 64 L110 38', False, 8)
     + path('M14 70 Q-2 76 12 94', False, 6) + path('M110 54 Q102 68 110 74 Q118 68 110 54 Z'),
     path('M52 70 Q42 84 52 92 Q62 84 52 70 Z'))
icon('KIT DE CALLIGRAPHIE',
     path('M24 72 H72 V104 Q72 110 66 110 H30 Q24 110 24 104 Z') + rect(34, 60, 28, 14, 2)
     + path('M112 6 Q58 28 50 66 Q80 52 112 6 Z') + line(52, 66, 44, 94, 4),
     line(32, 86, 64, 86, 4))
icon('MASQUE DISSIDENT',
     path('M10 28 Q60 4 110 28 Q106 80 78 98 Q60 108 42 98 Q14 80 10 28 Z'),
     path('M24 42 Q42 36 52 50 Q40 62 26 56 Z') + path('M96 42 Q78 36 68 50 Q80 62 94 56 Z')
     + path('M46 84 Q60 94 74 84', False, 4))
icon('MEDAILLON DE CERF',
     circ(60, 72, 34) + path('M36 52 Q60 -6 84 52', False, 5),
     path('M60 96 V64 M60 80 L44 62 L42 50 M44 62 L34 62 M60 80 L76 62 L78 50 M76 62 L86 62', False, 4))
icon('OR DE FARFADET',
     path('M18 104 L32 72 L56 68 L64 104 Z') + path('M50 104 L64 58 L92 62 L106 104 Z')
     + path('M34 72 L54 42 L76 48 L66 66 Z') + star(98, 22, 13, 5, 4))
_sock = path('M20 8 H48 V58 L72 70 Q86 80 76 96 Q66 110 44 102 L20 92 Z')
icon('PAIRE DE CHAUSSETTES', _sock + T(_sock, 44, 6, 0.85), line(20, 22, 48, 22, 4) + T(line(20, 22, 48, 22, 5), 44, 6, 0.85))
icon('PIECE ENSORCELEE',
     circ(60, 60, 44) + star(100, 14, 11, 4, 4) + star(16, 104, 8, 3, 4),
     circ(60, 60, 33, False, 5) + star(60, 60, 20, 8))
icon('PLAQUES MEMORIELLES',
     rect(8, 34, 30, 74, 4) + rect(45, 20, 30, 88, 4) + rect(82, 38, 30, 70, 4),
     line(16, 52, 30, 52, 3) + line(16, 64, 30, 64, 3) + line(53, 38, 67, 38, 3) + line(53, 50, 67, 50, 3)
     + line(53, 62, 67, 62, 3) + line(90, 56, 104, 56, 3) + line(90, 68, 104, 68, 3))
icon('PLUME COLOREE',
     path('M98 8 Q30 18 20 102 Q50 72 62 60 Q86 44 98 8 Z'),
     path('M26 106 Q60 62 94 14', False, 3))
icon('PLUME DE SIMURGH',
     path('M98 8 Q30 18 20 102 Q50 72 62 60 Q86 44 98 8 Z') + star(24, 22, 11, 4, 4) + star(100, 98, 9, 3, 4),
     path('M26 106 Q60 62 94 14', False, 3) + circ(70, 40, 5))
icon('POMME OR',
     circ(44, 74, 28) + circ(76, 74, 28) + ell(60, 92, 26, 18) + path('M62 42 Q72 14 98 20 Q90 46 62 42 Z')
     + star(100, 22, 0.1, 0.05, 4) + star(18, 28, 9, 3, 4) + star(104, 100, 8, 3, 4),
     circ(60, 46, 7) + path('M36 64 Q38 54 48 52', False, 5))
icon('PORTE-CLEF',
     circ(60, 28, 20, False, 7) + key(36, 62, 38) + key(84, 62, 38))
icon('PORTRAIT ANCIEN',
     rect(16, 8, 88, 104, 6, False, 10) + circ(60, 48, 16) + path('M30 100 Q30 70 60 70 Q90 70 90 100 Z'))
icon('POTION DE DISCORDANCE ETHNIQUE',
     path('M48 14 H72 V44 L96 94 Q102 108 88 108 H32 Q18 108 24 94 L48 44 Z') + rect(46, 6, 28, 12, 3),
     poly([(64, 60), (48, 86), (60, 84), (54, 104), (74, 76), (62, 78)]))
icon('POUDRE DE DEINTEGRATION',
     path('M44 30 H76 L72 46 Q104 56 100 92 Q96 110 60 110 Q24 110 20 92 Q16 56 48 46 Z') + rect(42, 24, 36, 8, 3)
     + circ(98, 20, 4) + circ(110, 38, 3) + circ(84, 10, 3),
     path('M44 80 Q60 66 76 80 Q60 92 44 80', False, 4))
icon('POUSSIERE DE DIAMANT',
     poly([(30, 36), (90, 36), (110, 58), (60, 110), (10, 58)]) + star(104, 16, 11, 4, 4),
     path('M30 36 L42 58 L60 110 M90 36 L78 58 L60 110 M42 58 L60 36 L78 58 M10 58 H110', False, 3))
icon('PYROBARBARE-BOOSTE',
     path('M60 6 Q96 40 82 70 Q60 92 38 70 Q24 40 60 6 Z') + path('M30 104 L60 84 L90 104', False, 8),
     path('M60 34 Q74 50 66 62 Q60 68 54 62 Q48 50 60 34 Z'))
icon('RAPPORT DE STAGE',
     rect(24, 14, 72, 96, 6) + path('M86 4 V44 Q86 54 78 54 Q70 54 70 44 V16', False, 5),
     line(36, 66, 84, 66, 5) + line(36, 80, 84, 80, 5) + line(36, 94, 66, 94, 5))
icon('RAT BEAUFORT',
     ell(52, 78, 32, 20) + poly([(76, 64), (114, 78), (76, 94)]) + circ(66, 58, 10) + path('M22 82 Q2 72 8 50', False, 5),
     circ(92, 78, 3))
icon('REGIME RICHE EN PRETEINES',
     path('M20 56 Q18 14 62 20 Q94 26 90 58 Q86 84 56 84 Q28 84 20 56 Z') + line(74, 72, 100, 100, 9)
     + circ(106, 98, 8) + circ(96, 110, 8),
     path('M34 40 Q40 28 54 28', False, 5))
icon('SIFFLET ETRANGE',
     rect(14, 50, 72, 36, 16) + path('M86 56 H112 V78 H86 Z') + circ(34, 44, 12, False, 6) + circ(100, 30, 5)
     + circ(110, 18, 4),
     circ(56, 68, 9))
icon('SOLIA AIDE',
     rect(30, 62, 60, 46, 14) + rect(30, 38, 12, 34, 6) + rect(46, 30, 12, 42, 6) + rect(62, 32, 12, 40, 6)
     + rect(78, 40, 12, 32, 6) + poly([(32, 92), (10, 70), (20, 62), (40, 78)]) + T(path(HEART), 40, -2, 0.3))
icon('SOLIA PERDUE',
     circ(60, 40, 20, False, 6) + path('M24 110 Q24 70 60 70 Q96 70 96 110', False, 6)
     + path('M52 38 Q52 30 60 30 Q68 30 68 38 Q68 44 60 48 V52', False, 5) + circ(60, 58, 2.5))
icon('SOUVENIR PRECIEUX',
     T(path(HEART), 6, 12, 0.9) + path('M42 24 Q60 -6 78 24', False, 5),
     T(path(HEART, False, 5), 33, 42, 0.5))
icon('TABLEAU DE TRIANGLE VOLANT',
     rect(14, 16, 92, 88, 4, False, 9) + poly([(48, 80), (68, 40), (88, 80)])
     + line(22, 56, 36, 56, 4) + line(24, 68, 40, 68, 4))
icon('TROPHEE DE PHASME',
     line(14, 74, 96, 46, 8) + line(36, 66, 24, 106, 4) + line(58, 58, 52, 106, 4) + line(80, 50, 96, 100, 4)
     + circ(102, 42, 8) + path('M106 36 Q114 22 118 12', False, 3) + path('M100 34 Q96 20 98 10', False, 3))
icon('TROUSSEAU DE CLES ASYMETRIQUES',
     circ(60, 24, 18, False, 6) + key(32, 54, 54, 7) + key(60, 54, 36, 9) + key(90, 54, 24, 6))


# Cape d'invisibilite : contour en pointilles (raw, stroke-dasharray)
icon('CAPE INVISIBILITE',
     '<path d="M60 8 Q92 14 92 52 L106 110 H14 L28 52 Q28 14 60 8 Z" fill="none" stroke-width="7" stroke-dasharray="12 9"/>'
     + ell(60, 46, 14, 18, False, 5),
     '', circ(54, 46, 3.5) + circ(66, 46, 3.5))


def svg(name):
    body, holes, extra = ICONS[name]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">\n'
        '<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="120" height="120">'
        '<rect width="120" height="120" fill="#fff" stroke="none"/>'
        '<g fill="#000" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">%s</g>'
        '</mask></defs>\n'
        '<g fill="#000" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">\n'
        '<g mask="url(#m)">%s</g>\n%s\n</g>\n</svg>\n' % (holes, body, extra))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else OUT_DEFAULT
    os.makedirs(out, exist_ok=True)
    for name in ICONS:
        with open(os.path.join(out, name + '.svg'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(svg(name))
    print('%d icones ecrites dans %s' % (len(ICONS), os.path.abspath(out)))


if __name__ == '__main__':
    main()
