import sys

import logger
from condition_node import ConditionNodeFactory, MalformedExpressionError

class Node(object):
    def __init__(self, nid):
        _id = int(nid)
        self._id = _id

        self._ending = None
        self._ending_id = None
        self._ending_txt = None
        self._success = None

        self._sons = []

        self._arc = None
        self._sub_arc = None
        self._combat = None

        self._label = None

        self._secret = False

        self._secret_jumps = []

        self._conditions_raw = ""
        self._conditions = None
        self._conditions_objs = {}
        self._conditions_txts = {}

        self._aquire = []
        self._remove = []

        self._stats = {}
        self._stats_cond_raw = None
        self._stats_cond = []
        self._stats_cond_objs = []


    # Chaque cle exportee, avec sa valeur NEUTRE. Une valeur neutre n'est pas ecrite : sur
    # fdcn, 9 538 des 12 120 cles ne disaient rien d'autre que « rien a signaler », soit
    # 61 % du fichier. `chapter_data.gd` applique exactement les memes defauts a la lecture
    # -- les deux listes doivent rester d'accord, c'est le seul point de vigilance.
    #
    # `id` n'y figure pas : il est toujours ecrit. `ending` et `is_combat` ont disparu :
    # c'etaient des booleens derives de `ending_type` et `combat`, verifies identiques sur
    # les 1 297 chapitres des deux livres. L'app les recalcule.
    NEUTRES = {
        'sons': [],
        'chapter': None,
        'arc': None,
        'combat': None,
        'label': None,
        'secret': False,
        'secret_jumps': [],
        'success': None,
        'ending_id': None,
        'ending_txt': None,
        'ending_type': None,
        'jump_conditions': {},
        'jump_conditions_txts': {},
        'aquire': [],
        'remove': [],
        'stats': {},
        'stats_cond': [],
    }


    def get_computed(self):
        son_ids = [son.get_id() for son in self._sons]
        son_ids.sort()  # try to always have the same result

        valeurs = {
            'sons':                 son_ids,
            # PAS un copier-coller inversé : le JSON compilé et `entities/chapter_data.gd`
            # appellent "chapter" ce que le Python et review.md appellent un ACTE (self._arc),
            # et "arc" ce qu'ils appellent un SOUS-ARC (self._sub_arc). Les deux vocabulaires
            # ne coïncident pas pour ce champ -- ne PAS "corriger" en échangeant les deux.
            'chapter':              self._arc,
            'arc':                  self._sub_arc,
            'combat':               self._combat,
            'label':                self._label,
            'secret':               self._secret,
            'secret_jumps':         self._secret_jumps,
            'success':              self._success,
            'ending_id':            self._ending_id,
            'ending_txt':           self._ending_txt,
            'ending_type':          self._ending,
            'jump_conditions':      self._conditions,
            'jump_conditions_txts': self._conditions_txts,
            'aquire':               self._aquire,
            'remove':               self._remove,
            'stats':                self._stats,
            'stats_cond':           self._stats_cond,
        }

        computed = {'id': self._id}
        for cle, valeur in valeurs.items():
            if valeur != self.NEUTRES[cle]:
                computed[cle] = valeur
        return computed


    def set_label(self, label):
        logger.trace(' [%s] Set label= %s' % (self._id, label))
        self._label = label


    # Some jumps are secret, but the distant chapter is NOT a secret
    def set_secret_jumps(self, secret_jumps):
        self._secret_jumps = secret_jumps


    def get_id(self):
        return self._id


    def get_arc(self):
        return self._arc


    def set_aquire(self, aquire):
        self._aquire = aquire


    def get_aquire(self):
        return self._aquire


    def set_remove(self, remove):
        self._remove = remove


    def get_remove(self):
        return self._remove


    def set_ending(self, ending):
        self._ending = ending


    def set_ending_id(self, ending_id):
        self._ending_id = ending_id


    def set_ending_txt(self, ending_txt):
        self._ending_txt = ending_txt


    def set_sucess(self, success):
        self._success = success


    def get_success(self):
        return self._success


    def set_combat(self, combat):
        self._combat = combat


    def set_secret(self):
        self._secret = True


    def is_secret(self):
        return self._secret


    def set_conditions(self, conditions):
        self._conditions_raw = conditions


    def get_all_stats_keys(self):
        r = set()
        for k in self._stats.keys():
            r.add(k)
        for _stat_cond in self._stats_cond:
            _stats = _stat_cond.get('stats', {})
            for k in _stats:
                r.add(k)
        return r


    # Parse the jump condition, and produce 2 things:
    # * dict output, for easy comparision
    # * display text about the rule
    def parse_conditions(self):
        if self._conditions_raw == "":
            self._conditions = {}
            return
        r_tree = {}
        r_txt = {}
        sons_ids = ['%s' % son.get_id() for son in self._sons]
        for (k, expr) in self._conditions_raw.items():
            # First assert the condition IS in the sons ^^
            if k not in sons_ids:
                print('[%s] The condition: %s is not in our sons %s' % (self.get_id(), k, ', '.join(sons_ids)))
                sys.exit(2)
            facto = ConditionNodeFactory()
            try:
                _condition = facto.parse_expr(expr)
            except MalformedExpressionError as e:
                print('ERROR: node %s, jump condition to %s: %s' % (self._id, k, e))
                sys.exit(2)
            self._conditions_objs[k] = _condition
            r_tree[k] = _condition.to_json()
            r_txt[k] = expr.replace('(', '( ').replace(')', ' )').replace('&', ' et ').replace('|', ' ou ').strip()

        self._conditions = r_tree
        self._conditions_txts = r_txt


    def set_stats(self, stats):
        self._stats = stats


    def set_stats_cond(self, stats_con):
        self._stats_cond_raw = stats_con

    def get_all_possibles_goto(self, goto: list) -> list:
        goto = set(goto)
        logger.trace(f'CONDITION RAWS: {self._conditions_raw}')
        if self._conditions_raw:
            for k in self._conditions_raw.keys():
                logger.trace(f'get_all_possibles_goto:: condition={k}')
                try:
                    k = int(k)
                except ValueError:
                    print('ERROR: node %s, invalid condition jump key: %s' % (self._id, k))
                    sys.exit(2)
                goto.add(k)

        for k in self._secret_jumps:
            goto.add(k)

        goto = list(goto)
        return goto


    # Parse the jump condition, and produce 2 things:
    # * dict output, for easy comparision
    # * display text about the rule
    def parse_stats_conditions(self):
        if not self._stats_cond_raw:
            self._stats_cond = []
            self._stats_cond_objs = []
            return
        r_lst = []
        r_objs = []
        for (expr, stats) in self._stats_cond_raw.items():
            facto = ConditionNodeFactory()
            try:
                _condition = facto.parse_expr(expr)
            except MalformedExpressionError as e:
                print('ERROR: node %s, stats_cond %s: %s' % (self._id, expr, e))
                sys.exit(2)
            j = _condition.to_json()
            txt = expr.replace('(', '( ').replace(')', ' )').replace('&', ' et ').replace('|', ' ou ').strip()
            r_lst.append({'condition': j, 'stats': stats, 'txt': txt})
            r_objs.append(_condition)
        self._stats_cond = r_lst
        self._stats_cond_objs = r_objs


    def get_all_conditions_token(self):
        lst = set()
        for (k, cond) in self._conditions_objs.items():
            objs = cond.get_all_tokens()
            lst |= objs
        return lst


    ## Les objets/pseudo-objets (types de Billy) cites dans un `stats_cond` : un angle mort
    ## de la validation avant le 2026-08-22 (todo 3.10), qui ne regardait que les conditions
    ## de saut et faisait donc echouer a tort la compilation d'un objet cite uniquement ici.
    def get_all_stats_cond_tokens(self):
        lst = set()
        for cond in self._stats_cond_objs:
            lst |= cond.get_all_tokens()
        return lst


    def add_son(self, son):
        self._sons.append(son)


    def get_sons(self):
        return self._sons


    def set_in_arc(self, arc_name):
        # Already set, drop recursive loop
        if self._arc is not None:
            return
        self._arc = arc_name
        for son in self._sons:
            son.set_in_arc(arc_name)


    def set_in_sub_arc(self, sub_arc, sub_arc_stops, nb):
        # Loop stop
        if self._sub_arc is not None:
            return nb
        if nb > 60:
            err = '[%s] The sub arc is too big, seems NOT normal (%s)' % (sub_arc, nb)
            raise Exception(err)
        # Maybe we did reach the stop point, then... stop! ^^
        if self._id in sub_arc_stops:
            logger.trace('[%s] SUB-ARC: Stopping propagation at %s' % (sub_arc, self._id))
            return nb
        logger.trace('[%s] tagging %s' % (sub_arc, self._id))
        self._sub_arc = sub_arc
        nb += 1
        for son in self._sons:  # type: Node
            nb = son.set_in_sub_arc(sub_arc, sub_arc_stops, nb)
        return nb


    def set_in_sub_arc_not_recursive(self, sub_arc):
        # Loop stop
        if self._sub_arc is not None:
            return
        logger.trace('[%s] Manually tagging %s' % (sub_arc, self._id))
        self._sub_arc = sub_arc


    def get_sub_arc(self):
        return self._sub_arc
