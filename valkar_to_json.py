# -*- coding: utf-8 -*-
"""Convertit valkar/*.txt (livre 3) vers fdcn-3.json + fdcn-3.all_objects.json.

Perimetre actuel (arbre/Graphviz uniquement) : destinations (go, ok=, ko=, bad=,
sinon), conditions de saut "(OBJ)N" et fins ("FIN" -> good, provisoire).
Objets (+X / -X), stats (+N PV...), succes et definitions d'objets
(objets.txt) sont aussi convertis. Les jets de de et les clauses
conditionnelles (si ... =>, MOD:) ne le sont PAS : ils sont listes a la fin.
"""
import codecs
import glob
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(HERE, 'valkar')

MARKER = re.compile(r'\bgo\b|\b(?:ok|ko|bad)\s*=\s*(?:go\b)?|\bsinon\b|=>\s*go\b|\bsecret\b', re.I)

# --- stats -------------------------------------------------------------
STAT_KEYS = {
    'HABILETE': 'hab', 'PV': 'pv', 'ENDURANCE': 'end', 'PV MAX': 'pv_max',
    'IMPULSION': 'impulsion', 'CHANCE': 'chance', 'RICHESSE': 'richesse',
    'CHANCE MAX': 'chance_max', 'CHANE MAX': 'chance_max', 'LUCIDITE': 'lucidite',
    'EGO': 'ego', 'CRITIQUE': 'crit', 'CRITIQUES': 'crit', 'ADDRESSE': 'adr',
    'ADRESSE': 'adr', 'ARMURE': 'arm', 'DEGAT': 'deg', 'DEGATS': 'deg',
}

# Fautes de frappe des sources -> nom canonique (objets et conditions)
ALIASES = {
    'GRAPPES AMETHISTHES': "GRAPPE D'AMETHYSTES",
    'GRAPPES AMETHYSTES': "GRAPPE D'AMETHYSTES",
    'LETTRE RECOMMANDATION': 'LETTRE DE RECOMMANDATION',
    'OR FARFADET': 'OR DE FARFADET',
    'OR DE FARDADET': 'OR DE FARFADET',
    'MEDAILLON CERF': 'MEDAILLON DE CERF',
    'FAVEUR DE SERVILE': 'FAVEUR DE SERVILLE',
    'KIT CALLIGRAPHIE': 'KIT DE CALLIGRAPHIE',
    'BOUTEILLE HUILE UNIVERSELLE': 'HUILLE UNIVERSELLE',
    'BOUTEILLE HUILE UNIVERSELLLE': 'HUILLE UNIVERSELLE',
    'VALQUARDIE': 'SOLQUARDIE',
    'ELISIF': 'ELUSIF',
    'FONCTNIONNAIRE': 'FONCTIONNAIRE',
    'BELICISTE': 'BELLICISTE',
    'EDEELWEISS': 'EDELWEISS',
    'TROUSSEAU CLES ASYMETRIQUES': 'TROUSSEAU DE CLES ASYMETRIQUES',
    'RAT(BEAUFORT)': 'RAT BEAUFORT',
    'BELICITE': 'BELLICISTE',
    'TABLEAU ANCIEN': 'PORTRAIT ANCIEN',  # 739 retire l'objet donne par le saut (PORTRAIT ANCIEN)739
    'LANCE JOUTE': 'LANCE DE JOUTE',
    'DAGUE A ROUELES': 'DAGUE A ROUELLES',
    "GRAPPES D'HAMESTHISTES": "GRAPPE D'AMETHYSTES",
    'GUID TOURISTIQUE': 'GUIDE TOURISTIQUE',
    'HERBES DES FEES': 'HERBE DES FEES',
    'MEDAILLONS DE CERFS': 'MEDAILLON DE CERF',
    'OUVIER': 'OUVRIER',
    'PAIRE CHAUSSETTE': 'PAIRE DE CHAUSSETTES',
    'POUSSIERE DE DIAMAND': 'POUSSIERE DE DIAMANT',
    'TABLEAU DU TRIANGLE VOLANT': 'TABLEAU DE TRIANGLE VOLANT',
}
CLASSES = {'BELLICISTE', 'OUVRIER', 'FONCTIONNAIRE', 'ELUSIF'}

SUCCESS_RE = re.compile(r'\+?\s*(?:SUCC?ES+S?|succes)\s*:?\s*"([^"]*)"', re.I)


def canon(name):
    name = re.sub(r'\s+', ' ', name.strip().upper().replace('’', "'").replace('_', ' '))
    return ALIASES.get(name, name)


def slug(txt):
    t = unicodedata.normalize('NFD', txt).encode('ascii', 'ignore').decode()
    return re.sub(r'[^A-Za-z0-9]+', '-', t).strip('-').upper()


def split_top(body):
    """Decoupe sur les virgules hors parentheses."""
    out, depth, cur = [], 0, ''
    for ch in body:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return [c.strip() for c in out if c.strip()]


def parse_effects(body):
    """-> (stats, aquire, remove, success_txt, non_convertis)."""
    stats, aquire, remove, unhandled = {}, [], [], []
    success = None
    m = SUCCESS_RE.search(body)
    if m:
        success = m.group(1)
        body = body[:m.start()] + body[m.end():]
    body = re.sub(r'"[^"]*"', '""', body)
    for cl in split_top(body):
        u = cl.upper()
        if re.match(r'^(GO|SECRET|FIN)\b', u) or re.match(r'^[:]?\s*GO\b', u):
            continue
        if re.match(r'^(\d+|\(.*\)\s*\d+(\s*,.*)?)$', cl):
            continue  # continuation d'une liste de destinations
        if re.match(r'^(JET|\(JET|\(JRET|OK\s*=|KO\s*=|BAD\s*=|DE\s*:|SINON|SI |MOD:|\(GO|\(\()', u) or '=>' in u:
            unhandled.append(cl)
            continue
        if re.fullmatch(r'SET (PV MAX|MAX PV)', u):
            stats['max_pv'] = True
            continue
        mm = re.fullmatch(r'([+-])\s*(\d+)\s*(.+)', cl)
        if not mm:
            mm2 = re.fullmatch(r'(PV MAX|CHANCE[_ ]MAX)\s*\+\s*(\d+)', u)
            if mm2:
                mm = ('+', mm2.group(2), mm2.group(1).replace('_', ' '))
            else:
                mm = None
        if mm:
            sign, n, name = (mm[0], mm[1], mm[2]) if isinstance(mm, tuple) else mm.groups()
            name = re.sub(r'\s+', ' ', name.strip().upper())
            key = STAT_KEYS.get(name)
            if key is None:
                unhandled.append(cl)
                continue
            v = int(n) * (1 if sign == '+' else -1)
            stats[key] = stats.get(key, 0) + v
            continue
        mm = re.fullmatch(r'([+-])\s*(.+)', cl)
        if mm:
            name = canon(mm.group(2))
            lst = aquire if mm.group(1) == '+' else remove
            if name not in lst:
                lst.append(name)
            continue
        unhandled.append(cl)
    return stats, aquire, remove, success, unhandled


def read_objects():
    """objets.txt -> {NOM: (categorie ou None, {stat: valeur})}

    Format : "NOM [CATEGORIE]: +1 HABILETE, -1 ADDRESSE" (categorie optionnelle).
    """
    out = {}
    path = os.path.join(SRC_DIR, 'objets.txt')
    with codecs.open(path, 'r', 'utf8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or ':' not in line:
                continue
            head, rest = line.split(':', 1)
            mc = re.fullmatch(r'(.*?)\s*(?:\[\s*(\w+)\s*\])?\s*', head)
            name, cat = mc.group(1), (mc.group(2).upper() if mc.group(2) else None)
            st = {}
            for part in rest.split(','):
                mm = re.fullmatch(r'\s*([+-])\s*(\d+)\s*(.+?)\s*', part)
                if not mm:
                    print('ATTENTION objets.txt: stat illisible %r (%s)' % (part, name))
                    continue
                key = STAT_KEYS.get(re.sub(r'\s+', ' ', mm.group(3).upper()))
                if key is None:
                    print('ATTENTION objets.txt: stat inconnue %r (%s)' % (mm.group(3), name))
                    continue
                st[key] = st.get(key, 0) + int(mm.group(2)) * (1 if mm.group(1) == '+' else -1)
            if 'chance_max' in st:  # cote objet, l'appli nomme ce bonus 'cha' (cf player.gd)
                st['cha'] = st.pop('chance_max')
            out[canon(name)] = (cat, st)
    return out


def read_chapters():
    raw = {}
    for path in sorted(glob.glob(os.path.join(SRC_DIR, '[0-9]*.txt'))):
        with codecs.open(path, 'r', 'utf8') as f:
            for ln, line in enumerate(f, 1):
                s = line.strip()
                if not s:
                    continue
                m = re.match(r'^(\d+)\s*:?\s*(.*)$', s)
                if not m:
                    print('ERREUR: ligne illisible %s:%d: %s' % (os.path.basename(path), ln, s))
                    sys.exit(2)
                n = int(m.group(1))
                if n in raw:
                    print('ERREUR: chapitre %d en double (%s:%d)' % (n, os.path.basename(path), ln))
                    sys.exit(2)
                raw[n] = m.group(2)
    return raw


def match_paren(s, i):
    """s[i] == '(' -> index de la ')' correspondante, ou -1."""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == '(':
            depth += 1
        elif s[j] == ')':
            depth -= 1
            if depth == 0:
                return j
    return -1


def parse_item(s, i):
    """Un element de liste de destinations : '[(COND)] N'. -> (cond, n, fin) ou None."""
    n = len(s)
    while i < n and s[i] == ' ':
        i += 1
    cond = None
    if i < n and s[i] == '(':
        j = match_paren(s, i)
        if j < 0:
            return None
        cond = s[i + 1:j]
        i = j + 1
        while i < n and s[i] == ' ':
            i += 1
    m = re.match(r'\d+', s[i:])
    if not m:
        return None
    return cond, int(m.group(0)), i + m.end()


def normalize_cond(cond):
    cond = re.sub(r'\b([A-Z]+)\(([^()]*)\)', r'\1 \2', cond)  # RAT(BEAUFORT) -> RAT BEAUFORT
    cond = cond.replace('_', ' ')
    for bad in sorted(ALIASES, key=len, reverse=True):
        if '(' in bad:
            continue
        cond = re.sub(r'(?<![A-Z])%s(?![A-Z])' % re.escape(bad), ALIASES[bad], cond)
    cond = re.sub(r'\s*(>=|<=|==|<|>)\s*', r'\1', cond)  # IMPULSION >=3 -> IMPULSION>=3
    return re.sub(r'\s+', ' ', cond).strip()


def parse_chapter(body):
    """-> (destinations, {dest: condition}, est_fin, sauts_secrets).

    Un saut secret s'ecrit "secret N" (ex: "234: go 378, secret 432") : valide,
    mais cache tant que le joueur ne l'a pas decouvert.
    """
    clean = re.sub(r'"[^"]*"', '""', body)  # les titres de succes peuvent contenir des virgules
    dests = []
    conds = {}
    unconditional = set()
    secrets = []
    for mk in MARKER.finditer(clean):
        is_secret = mk.group(0).lower() == 'secret'
        pos = mk.end()
        while True:
            item = parse_item(clean, pos)
            if item is None:
                break
            cond, dest, pos = item
            if dest not in dests:
                dests.append(dest)
            if is_secret and dest not in secrets:
                secrets.append(dest)
            if cond is None:
                unconditional.add(dest)
            else:
                conds.setdefault(dest, []).append(normalize_cond(cond))
            m = re.match(r'\s*,', clean[pos:])
            if not m:
                break
            pos += m.end()
    final = {}
    for dest, lst in conds.items():
        if dest in unconditional:
            continue
        lst = sorted(set(lst))
        final[str(dest)] = lst[0] if len(lst) == 1 else '|'.join('(%s)' % c for c in lst)
    est_fin = re.search(r'\bFIN\b', clean) is not None
    return dests, final, est_fin, sorted(secrets)


def cond_tokens(cond):
    return {t.strip() for t in re.split(r'[()|&]', cond) if t.strip()}


def main():
    raw = read_chapters()
    obj_defs = read_objects()
    book = {}
    tokens = set()
    used_items = set()
    successes = {}
    unhandled_all = {}
    for n in sorted(raw):
        dests, conds, est_fin, secrets = parse_chapter(raw[n])
        stats, aquire, remove, success, unhandled = parse_effects(raw[n])
        entry = {}
        if est_fin:
            entry['ending'] = 'good'  # provisoire : a revalider avec l'auteur
        else:
            entry['goto'] = dests
        if secrets:
            entry['secret_jumps'] = secrets
        if conds:
            entry['conditions'] = conds
            for c in conds.values():
                tokens |= cond_tokens(c)
        if stats:
            entry['stats'] = stats
        if aquire:
            entry['aquire'] = aquire
        if remove:
            entry['remove'] = remove
        used_items |= set(aquire) | set(remove)
        if success:
            sid = slug(success)
            entry['success'] = sid
            successes[sid] = {'id': sid, 'label': success, 'txt': ''}
        if unhandled:
            unhandled_all[n] = unhandled
        book[str(n)] = entry

    with codecs.open(os.path.join(HERE, 'fdcn-3.json'), 'w', 'utf8') as f:
        f.write(json.dumps(book, indent=2, ensure_ascii=False))

    objs = {}
    for t in sorted(tokens | used_items | set(obj_defs)):
        if re.search(r'[<>=]', t):
            objs[t] = {'category': 'OBJET'}  # seuil de stat, comme avant
            continue
        if t in CLASSES:
            objs[t] = {'category': 'EVENEMENT'}
        elif t in obj_defs:
            cat, st = obj_defs[t]
            objs[t] = {'category': cat or 'OBJET', 'stats': st}
        else:
            objs[t] = {'category': 'OBJET'}
    with codecs.open(os.path.join(HERE, 'fdcn-3.all_objects.json'), 'w', 'utf8') as f:
        f.write(json.dumps(objs, indent=2, ensure_ascii=False))
    with codecs.open(os.path.join(HERE, 'all-success-3.json'), 'w', 'utf8') as f:
        f.write(json.dumps(list(successes.values()), indent=2, ensure_ascii=False))

    nb_cond = sum(1 for e in book.values() if 'conditions' in e)
    print('%d chapitres, %d avec conditions, %d jetons de condition' % (len(book), nb_cond, len(tokens)))
    print('stats: %d chapitres, aquire: %d, remove: %d, succes: %d, objets: %d (dont %d avec stats)' % (
        sum('stats' in e for e in book.values()), sum('aquire' in e for e in book.values()),
        sum('remove' in e for e in book.values()), len(successes), len(objs),
        sum('stats' in o for o in objs.values())))
    comp = sorted(t for t in tokens if re.search(r'[<>=]', t))
    print('jetons de type comparaison (stats, pas des objets):', comp)
    ends = [n for n, e in book.items() if 'ending' in e]
    print('fins:', ends)
    # jets de de, clauses conditionnelles et PYRO-BARBARE : ignores volontairement (cf valkar/TODO.md)
    skipped_re = re.compile(r'JET|JRET|OK\s*=|KO\s*=|BAD\s*=|DE\s*:|SINON|^SI |MOD:|=>|^\(GO|PYRO', re.I)
    unknown = {}
    for n, lst in unhandled_all.items():
        rest = [c for c in lst if not skipped_re.search(c)]
        if rest:
            unknown[n] = rest
    print('ignores volontairement (jets, conditionnels, PYRO-BARBARE): %d chapitres' % (len(unhandled_all) - len(unknown)))
    print('NON CONVERTIS ET INATTENDUS (%d chapitres):' % len(unknown))
    for n, lst in unknown.items():
        print('  %d: %s' % (n, ' | '.join(lst)))


if __name__ == '__main__':
    main()
