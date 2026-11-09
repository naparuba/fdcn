# -*- coding: utf-8 -*-
"""Genere les pictos de succes du livre 3 : images/success/<ID>.svg (120x120, noir sur transparent).

Style : glyphes noirs pleins, traits epais aux bouts arrondis, details en "reserve" (trous
transparents) obtenus avec un masque SVG. Voir valkar/pictos.md pour la liste des idees.

Usage : python valkar/make_pictos.py [dossier_de_sortie]
"""
import math
import os
import sys

OUT_DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'images', 'success')


# ------------------------------------------------------------------ primitives
def _a(fill, w):
    s = ''
    if not fill:
        s += ' fill="none"'
    if w is not None:
        s += ' stroke-width="%s"' % w
    return s


def path(d, fill=True, w=None):
    return '<path d="%s"%s/>' % (d, _a(fill, w))


def circ(cx, cy, r, fill=True, w=None):
    return '<circle cx="%s" cy="%s" r="%s"%s/>' % (cx, cy, r, _a(fill, w))


def ell(cx, cy, rx, ry, fill=True, w=None):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s"%s/>' % (cx, cy, rx, ry, _a(fill, w))


def rect(x, y, w_, h, r=0, fill=True, w=None):
    return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"%s/>' % (x, y, w_, h, r, _a(fill, w))


def line(x1, y1, x2, y2, w=7):
    return '<line x1="%s" y1="%s" x2="%s" y2="%s" fill="none" stroke-width="%s"/>' % (x1, y1, x2, y2, w)


def poly(pts, fill=True, w=None):
    return '<polygon points="%s"%s/>' % (' '.join('%s,%s' % p for p in pts), _a(fill, w))


def rot(content, a, cx, cy):
    return '<g transform="rotate(%s %s %s)">%s</g>' % (a, cx, cy, content)


def T(content, tx, ty, s=1):
    return '<g transform="translate(%s %s) scale(%s)">%s</g>' % (tx, ty, s, content)


def star(cx, cy, R, r, n=5):
    pts = []
    for i in range(n * 2):
        ang = -math.pi / 2 + i * math.pi / n
        rad = R if i % 2 == 0 else r
        pts.append((round(cx + rad * math.cos(ang), 1), round(cy + rad * math.sin(ang), 1)))
    return poly(pts)


PROFILE = ('M30 40 Q40 18 66 22 Q86 28 84 52 L90 62 L84 66 L86 76 Q82 84 76 86 L76 104 H40 L40 84 Q24 74 30 40 Z')

HEART = 'M60 108 C10 72 4 44 28 30 C44 22 56 30 60 40 C64 30 76 22 92 30 C116 44 110 72 60 108 Z'

ICONS = {}


def icon(id_, body, holes='', extra=''):
    ICONS[id_] = (body, holes, extra)


# --------------------------------------------------------------------- les icones
icon('C-EST-CULTUREL',  # rose + beret
     ell(60, 30, 40, 15) + rect(56, 8, 8, 12, 3) + circ(60, 72, 22) + line(60, 92, 60, 114, 7)
     + path('M60 102 Q78 90 90 98 Q78 114 60 106 Z'),
     path('M50 70 Q60 60 70 70', False, 4) + path('M52 80 Q60 86 68 80', False, 4))

icon('DEMAIN-C-ETAIT-HIER',  # DeLorean
     path('M8 84 L14 64 L36 50 L84 46 L104 62 L112 70 V86 H8 Z') + circ(34, 88, 13) + circ(88, 88, 13),
     poly([(42, 56), (80, 54), (94, 64), (38, 64)]) + circ(34, 88, 5) + circ(88, 88, 5)
     + circ(34, 88, 17, False, 3) + circ(88, 88, 17, False, 3) + line(48, 76, 76, 76, 4))

icon('OH-NON-CA-RECOMMENCE',  # rocher de Sisyphe
     line(8, 100, 104, 36, 9) + circ(54, 48, 18),
     path('M46 42 L56 50 L52 60', False, 3))

icon('BILLY-LA-RACAILLE',  # casquette retournee + chaine
     path('M16 62 Q16 22 58 22 Q96 22 98 62 Z') + path('M96 56 L116 58 L116 68 L92 68 Z') + circ(58, 20, 5)
     + circ(28, 94, 10, False, 6) + circ(60, 100, 10, False, 6) + circ(92, 94, 10, False, 6),
     path('M58 26 Q44 44 46 60', False, 3))

icon('JE-PRENDS-LA-SUCCESSION-PERE',  # trone couronne au bord du gouffre
     rect(36, 30, 44, 34, 6) + poly([(34, 30), (38, 8), (50, 20), (58, 6), (66, 20), (78, 8), (82, 30)])
     + rect(28, 60, 60, 12, 4) + rect(32, 72, 9, 26) + rect(75, 72, 9, 26)
     + rect(6, 98, 66, 10, 4) + line(84, 104, 96, 102, 6) + line(102, 108, 112, 106, 5),
     rect(46, 40, 24, 16, 3))

icon('PETER-PAN',  # chapeau a plume
     poly([(34, 72), (58, 26), (86, 72)]) + ell(60, 74, 46, 10) + path('M80 58 Q106 52 112 14 Q86 24 80 58 Z'),
     line(42, 60, 78, 60, 4) + path('M84 52 Q100 40 108 20', False, 2.5))

icon('LA-CHIMIE-AMUSANTE',  # fiole qui deborde
     path('M46 24 H74 V52 L100 98 Q106 112 92 112 H28 Q14 112 20 98 L46 52 Z') + rect(42, 18, 36, 8, 3)
     + circ(52, 9, 4.5) + circ(68, 7, 3.5),
     line(33, 86, 88, 86, 5) + circ(54, 100, 5) + circ(72, 98, 4) + circ(60, 40, 4))

icon('YO-HO-VIVE-LA-PIRATERIE',  # tete de mort + os croises
     circ(60, 46, 28) + rect(46, 62, 28, 18, 4) + line(18, 82, 102, 106, 8) + line(102, 82, 18, 106, 8)
     + circ(14, 80, 7) + circ(22, 88, 6) + circ(106, 80, 7) + circ(98, 88, 6)
     + circ(14, 108, 7) + circ(22, 100, 6) + circ(106, 108, 7) + circ(98, 100, 6),
     circ(50, 46, 7) + circ(70, 46, 7) + poly([(60, 54), (56, 62), (64, 62)])
     + line(54, 68, 54, 78, 3) + line(60, 68, 60, 78, 3) + line(66, 68, 66, 78, 3))

icon('NOUVEAU-RECORD',  # chronometre
     circ(60, 68, 36, False, 9) + rect(50, 10, 20, 10, 3) + rect(56, 18, 8, 12, 2) + line(94, 30, 102, 22, 8)
     + line(60, 68, 60, 44, 6) + line(60, 68, 78, 78, 6) + circ(60, 68, 5))

icon('RAM-INSUFFISANTE',  # barrette de RAM
     rect(8, 38, 104, 44, 4) + ''.join(rect(14 + i * 11.6, 86, 7, 14) for i in range(9)),
     ''.join(rect(18 + i * 22, 46, 18, 26, 2) for i in range(4)) + rect(54, 80, 12, 6, 1))

_shoe = path('M-26 -34 V14 Q-26 40 0 40 Q26 40 26 14 V-34', False, 12)
_nails = ''.join(circ(sx * 26, y, 3) for sx in (-1, 1) for y in (-16, 2))
icon('DEUX-LONGUEURS-D-AVANCES',  # deux fers a cheval
     T(_shoe, 31, 62, 0.75) + T(_shoe, 89, 62, 0.75), T(_nails, 31, 62, 0.75) + T(_nails, 89, 62, 0.75))

icon('DOCTEUR-MABOULE',  # stethoscope
     path('M34 16 V48 Q34 74 60 74 Q86 74 86 48 V16', False, 7) + circ(34, 12, 6) + circ(86, 12, 6)
     + line(60, 74, 60, 88, 7) + circ(60, 100, 14),
     circ(60, 100, 6) + path('M60 100 m0 0 a2 2 0 1 1 3 3', False, 2))

icon('SKIP-SKIP-SKIP',  # >>|
     poly([(14, 28), (54, 60), (14, 92)]) + poly([(52, 28), (92, 60), (52, 92)]) + rect(98, 28, 10, 64, 3))

icon('MAXXIMUM-OVERDRIVE',  # camion de face
     rect(22, 28, 76, 58, 8) + rect(12, 82, 18, 24, 5) + rect(90, 82, 18, 24, 5) + rect(34, 16, 10, 8, 2)
     + rect(55, 16, 10, 8, 2) + rect(76, 16, 10, 8, 2),
     rect(30, 36, 60, 22, 4) + circ(36, 72, 6) + circ(84, 72, 6) + path('M46 70 Q60 84 74 70', False, 5))

icon('L-INTENTION-QUI-COMPTE',  # tete de profil + bulle de pensee
     T(path(PROFILE), 4, 20, 0.8) + circ(80, 22, 13) + circ(98, 30, 10) + circ(68, 30, 10) + rect(68, 24, 32, 16, 6)
     + circ(72, 50, 4) + circ(66, 42, 3),
     T(circ(66, 52, 4), 4, 20, 0.8) + circ(80, 26, 3) + circ(92, 30, 3))

icon('BOUH-CLIER',  # bouclier + fantome
     path('M20 16 H100 V58 Q100 94 60 112 Q20 94 20 58 Z'),
     path('M44 86 V52 Q44 34 60 34 Q76 34 76 52 V86 L68 78 L60 86 L52 78 Z'),
     circ(54, 54, 3.5) + circ(66, 54, 3.5))

icon('BILLY-OU-LA-VIE-SAUVAGE',  # tente + drapeau
     poly([(8, 100), (60, 28), (112, 100)]) + line(4, 106, 116, 106, 6) + line(60, 28, 60, 10, 5)
     + poly([(60, 10), (78, 15), (60, 21)]),
     poly([(46, 100), (60, 70), (74, 100)]))

icon('IT-S-FREE-REAL-ESTATE',  # maison + zero
     path('M10 62 L60 16 L110 62 H96 V108 H24 V62 Z') + rect(84, 20, 12, 26),
     path('M60 68 m-11 0 a11 16 0 1 0 22 0 a11 16 0 1 0 -22 0', False, 6))

icon('GNOLOCAUSTE-NUCLEAIRE',  # champignon atomique + cornes
     circ(36, 46, 18) + circ(60, 36, 22) + circ(84, 46, 18) + ell(60, 56, 34, 10)
     + path('M50 58 Q58 82 38 110 H82 Q62 82 70 58 Z')
     + path('M22 34 Q6 28 8 10', False, 6) + path('M98 34 Q114 28 112 10', False, 6),
     path('M44 42 Q52 32 62 40', False, 4))

icon('RANDOM-BULLSHIT-GO',  # micro
     circ(60, 38, 22) + rect(50, 56, 20, 50, 6) + path('M22 22 Q8 42 22 62', False, 5)
     + path('M98 22 Q112 42 98 62', False, 5),
     line(44, 38, 76, 38, 3) + line(60, 20, 60, 56, 3) + line(50, 74, 70, 74, 3))

icon('FONTE-DES-GLACES',  # glacon qui fond
     rect(22, 12, 76, 62, 12) + line(40, 76, 40, 100, 10) + line(76, 76, 76, 106, 10) + circ(58, 102, 6),
     path('M32 26 H52', False, 5) + line(32, 36, 32, 44, 5))

_arrow = poly([(32, 8), (50, 10), (40, 26)])
icon('QUESTION-DE-TIMING',  # horloge + fleches circulaires
     circ(60, 60, 30, False, 8) + line(60, 60, 60, 40, 6) + line(60, 60, 76, 66, 6)
     + path('M12 60 A48 48 0 0 1 36 18', False, 6) + _arrow
     + rot(path('M12 60 A48 48 0 0 1 36 18', False, 6) + _arrow, 180, 60, 60))


def _flake():
    g = ''
    for a in (0, 60, 120):
        g += ('<g transform="translate(60 60) rotate(%s)">' % a + line(-50, 0, 50, 0, 6)
              + ''.join(line(sx * 32, 0, sx * 44, sy * 12, 5) for sx in (-1, 1) for sy in (-1, 1)) + '</g>')
    return g + circ(60, 60, 9)


icon('MISTER-FREEZE', _flake())

icon('PEDAGOGIE-TRADITIONNELLE',  # bonnet d'ane + regle
     poly([(60, 6), (98, 80), (22, 80)]) + rect(10, 92, 100, 16, 3),
     line(34, 66, 86, 66, 5) + line(44, 46, 76, 46, 5) + ''.join(line(x, 92, x, 100, 3) for x in range(24, 110, 16)))

icon('NOPE',  # main "stop"
     rect(30, 52, 60, 52, 16) + rect(30, 16, 12, 48, 6) + rect(46, 8, 12, 56, 6) + rect(62, 12, 12, 52, 6)
     + rect(78, 24, 12, 40, 6) + poly([(32, 88), (8, 64), (18, 54), (38, 72)]))

icon('NIER-NIER-ET-TOUJOURS-NIER',  # sens interdit + fleche retournee
     circ(60, 60, 46, False, 9) + line(28, 92, 92, 28, 9)
     + path('M40 44 Q40 30 56 30 H72', False, 6) + poly([(70, 20), (86, 30), (70, 40)]))

icon('THE-ART-OF-THE-DEAL',  # cravate
     poly([(26, 10), (50, 14), (44, 34)]) + poly([(94, 10), (70, 14), (76, 34)])
     + poly([(50, 14), (70, 14), (66, 32), (54, 32)]) + poly([(54, 32), (66, 32), (80, 100), (60, 114), (40, 100)]),
     line(50, 62, 70, 50, 4) + line(46, 80, 74, 66, 4))

icon('RULES-OF-NATURE',  # katana + pasteque
     path('M12 66 A48 48 0 0 0 108 66 Z') + line(26, 22, 112, 58, 6) + line(22, 30, 30, 12, 7)
     + line(26, 22, 8, 14, 9),
     path('M24 66 A36 36 0 0 0 96 66', False, 4) + ell(46, 80, 3.5, 6) + ell(60, 88, 3.5, 6) + ell(74, 80, 3.5, 6))

icon('UNIVERSAL-BUZZ',  # abeille
     ell(66, 72, 28, 20) + circ(32, 72, 14) + poly([(92, 66), (114, 72), (92, 78)])
     + rot(ell(54, 42, 10, 22), -25, 54, 42) + rot(ell(76, 42, 10, 22), 25, 76, 42)
     + path('M28 60 Q24 48 16 44', False, 4),
     line(58, 54, 58, 90, 5) + line(72, 54, 72, 90, 5) + line(86, 58, 86, 86, 4))

icon('REPOUSSER-L-INELUCTABLE',  # faux
     path('M92 18 Q50 6 18 40 Q56 24 88 32 Z') + line(90, 22, 50, 112, 7))

icon('DE-L-AUTRE-COTE-DU-MIRROIR',  # miroir + vagues
     ell(60, 48, 30, 38, False, 9) + line(60, 86, 60, 104, 7) + line(38, 112, 82, 112, 7)
     + path('M42 44 Q50 36 60 44 T78 44', False, 5) + path('M42 60 Q50 52 60 60 T78 60', False, 5))

icon('TOILE-DE-MAITRE',  # chevalet
     line(60, 8, 28, 112, 7) + line(60, 8, 92, 112, 7) + line(36, 94, 84, 94, 6) + rect(28, 24, 64, 52, 3),
     poly([(36, 68), (52, 44), (62, 58), (70, 50), (84, 68)]) + circ(78, 38, 5))

icon('POTION-DE-DETRITUS',  # poubelle + bulles
     path('M30 46 H90 L84 108 H36 Z') + rect(24, 34, 72, 10, 3) + rect(48, 24, 24, 10, 3)
     + circ(44, 12, 5, False, 4) + circ(76, 9, 4, False, 4),
     line(48, 56, 50, 98, 4) + line(60, 56, 60, 98, 4) + line(72, 56, 70, 98, 4))

icon('PAR-DELA-L-ARMURE',  # casque de chevalier
     path('M22 110 V54 Q22 16 60 16 Q98 16 98 54 V110 H78 V92 H42 V110 Z') + rect(54, 4, 12, 14, 3),
     rect(30, 48, 60, 9, 3) + circ(70, 72, 3) + circ(80, 72, 3) + circ(70, 82, 3) + circ(80, 82, 3))

icon('LA-DEUXIEME-EST-OFFERTE',  # deux coeurs
     T(path(HEART), 0, -4, 0.8) + T(path(HEART), 72, 66, 0.4))

icon('BOOM-HEADSHOT',  # viseur + casque
     circ(60, 60, 40, False, 6) + line(60, 4, 60, 34, 6) + line(60, 86, 60, 116, 6) + line(4, 60, 34, 60, 6)
     + line(86, 60, 116, 60, 6) + path('M42 70 Q42 44 60 44 Q78 44 78 70 Z') + rect(38, 68, 44, 6, 2),
     circ(60, 58, 4))

icon('ENFERMES-ICI-AVEC-MOI',  # cellule + visages
     rect(14, 14, 92, 92, 6, False, 8) + line(36, 14, 36, 106, 6) + line(60, 14, 60, 106, 6)
     + line(84, 14, 84, 106, 6) + circ(48, 90, 8) + circ(72, 90, 8) + circ(96, 90, 8) + circ(24, 90, 8))

icon('EXPANSION-DU-DOMAINE',  # domaine (cercles) + doigts croises
     circ(60, 60, 52, False, 5) + circ(60, 60, 40, False, 3) + rot(rect(53, 34, 14, 52, 7), 30, 60, 60)
     + rot(rect(53, 34, 14, 52, 7), -30, 60, 60),
     circ(60, 60, 3))

icon('CA-PLANE-POUR-MOI',  # avion en papier
     poly([(8, 58), (112, 12), (74, 108), (56, 74)]),
     line(112, 12, 58, 72, 3) + line(56, 74, 52, 96, 3))

icon('PASSAGE-DE-PERMIS',  # permis de conduire
     rect(8, 26, 104, 68, 8),
     rect(18, 38, 28, 34, 3) + line(58, 42, 100, 42, 5) + line(58, 56, 100, 56, 5) + line(58, 70, 86, 70, 5))

icon('LA-MEILLEURE-TIMELINE',  # ligne du temps a branches + etoile
     path('M8 70 H46 L84 38', False, 7) + path('M46 70 L84 102', False, 7) + star(98, 30, 17, 7.5)
     + circ(96, 104, 8),
     '')

icon('FLAMBEE-DE-CHAMPIGNONS',  # champignon + flammes
     path('M12 60 Q12 12 60 12 Q108 12 108 60 Z') + rect(42, 58, 36, 30, 8)
     + path('M22 114 Q12 98 26 84 Q28 96 36 92 Q46 102 38 114 Z')
     + path('M78 114 Q72 100 84 88 Q88 98 94 94 Q106 104 98 114 Z'),
     circ(36, 38, 6) + circ(64, 28, 6) + circ(86, 44, 5))

icon('MANIFESTEMENT-PACIFISTE',  # drapeau blanc + signe paix
     line(24, 10, 24, 112, 8) + path('M28 16 Q52 6 72 18 T112 20 V64 Q94 72 72 62 T28 64 Z'),
     circ(70, 42, 15, False, 4) + line(70, 27, 70, 57, 4) + line(70, 42, 59, 53, 4) + line(70, 42, 81, 53, 4))

icon('THERAPIE-CABARDIENNE',  # divan + piece
     rect(22, 42, 76, 28, 10) + rect(14, 64, 92, 26, 8) + rect(8, 52, 18, 40, 8) + rect(94, 52, 18, 40, 8)
     + rect(22, 90, 8, 16, 2) + rect(90, 90, 8, 16, 2) + circ(92, 20, 15),
     circ(92, 20, 7) + line(60, 44, 60, 62, 3))

icon('PARADIS-PERDU',  # pomme croquee
     circ(60, 72, 36) + path('M62 36 Q70 14 96 18 Q88 40 62 36 Z') + line(60, 36, 55, 18, 6),
     circ(98, 54, 15))

icon('PROMETHEE-IRRESPONSABLE',  # torche
     path('M60 6 Q94 40 80 64 Q60 80 40 64 Q26 40 60 6 Z') + path('M40 72 H80 L74 88 H46 Z') + rect(54, 88, 12, 24, 4),
     path('M60 34 Q74 50 66 60 Q60 66 54 60 Q48 50 60 34 Z'))

icon('MEMOIRE-MUSCULAIRE',  # haltere
     rect(30, 52, 60, 16, 4) + rect(16, 30, 16, 60, 5) + rect(88, 30, 16, 60, 5) + rect(6, 42, 10, 36, 3)
     + rect(104, 42, 10, 36, 3))

icon('LE-PETIT-PRINCE',  # rose sous cloche
     path('M30 104 V52 Q30 14 60 14 Q90 14 90 52 V104', False, 7) + rect(20, 102, 80, 10, 3) + circ(60, 8, 5)
     + circ(60, 48, 14) + line(60, 60, 60, 100, 5) + path('M60 86 Q44 78 40 88 Q50 96 60 90')
     + path('M60 76 Q76 68 80 78 Q70 86 60 80'),
     path('M55 46 Q60 40 65 46', False, 3))

icon('SOUVENIRS-EN-TROP',  # tete de profil qui deborde de souvenirs
     T(path(PROFILE), 6, 20, 0.8) + rot(rect(60, 6, 22, 18, 2), 15, 71, 15) + rot(rect(88, 26, 18, 16, 2), -10, 97, 34)
     + rot(rect(30, 2, 18, 16, 2), -12, 39, 10) + circ(90, 56, 3.5) + circ(76, 40, 3),
     T(circ(66, 52, 4), 6, 20, 0.8))

icon('DEVOIR-DE-MEMOIRE',  # dossier + tampon
     rect(10, 36, 100, 68, 8) + path('M10 38 V28 Q10 22 16 22 H46 L56 38 Z'),
     circ(60, 72, 16, False, 5) + path('M52 72 L58 79 L70 64', False, 5))

icon('SOUVENIRS-D-AVENIR',  # casque de chantier + horloge
     path('M16 78 Q16 30 60 30 Q104 30 104 78 Z') + rect(8, 76, 104, 12, 5) + rect(52, 18, 16, 16, 4),
     circ(60, 60, 14, False, 4) + line(60, 60, 60, 50, 3) + line(60, 60, 68, 64, 3))

icon('REDRESSAGE-DE-MANCHE',  # manche tordu + fleches
     path('M22 106 Q22 62 60 62 Q98 62 98 22', False, 12) + poly([(46, 16), (74, 16), (60, 40)])
     + poly([(46, 108), (74, 108), (60, 84)]))

icon('YEET-LE-YETI',  # yeti + balle
     circ(60, 52, 34) + path('M14 112 Q14 88 60 88 Q106 88 106 112 Z') + circ(30, 40, 12) + circ(90, 40, 12),
     ell(60, 58, 22, 24),
     circ(51, 54, 4) + circ(69, 54, 4) + path('M50 68 Q60 76 70 68', False, 4)
     + circ(104, 14, 7, False, 4) + line(80, 16, 94, 14, 4))

icon('UN-JOUR-SANS-FIN',  # calendrier + infini
     rect(12, 26, 96, 82, 10) + line(36, 10, 36, 32, 8) + line(84, 10, 84, 32, 8),
     path('M60 72 C50 56 26 56 26 72 C26 88 50 88 60 72 C70 56 94 56 94 72 C94 88 70 88 60 72', False, 8))


# ------------------------------------------------------------------------- SVG
def svg(id_):
    body, holes, extra = ICONS[id_]
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
    for id_ in ICONS:
        with open(os.path.join(out, id_ + '.svg'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(svg(id_))
    print('%d pictos ecrits dans %s' % (len(ICONS), os.path.abspath(out)))


if __name__ == '__main__':
    main()
