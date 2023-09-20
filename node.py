import sys

from condition_node import ConditionNodeFactory
from endings import ENDINGS

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
    
    
    def have_combat(self):
        return self._combat is not None
    
    
    def have_ending(self):
        return self._ending is not None
    
    
    def get_ending_id(self):
        return self._ending_id
    
    
    def is_good_ending(self):
        return self._ending == ENDINGS.GOOD
    
    
    def is_bad_ending(self):
        return self._ending == ENDINGS.BAD
    
    
    def get_computed(self):
        son_ids = [son.get_id() for son in self._sons]
        son_ids.sort()  # try to always have the same result
        
        ending = False
        if self._ending is not None:
            ending = True
        
        return {
            'id':                   self._id,
            'ending':               ending,
            'success':              self._success,
            'sons':                 son_ids,
            'chapter':              self._arc,
            'arc':                  self._sub_arc,
            'is_combat':            self._combat is not None,
            'combat':               self._combat,
            'label':                self._label,
            'secret':               self._secret,
            'secret_jumps':         self._secret_jumps,
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
    
    
    def get_label(self):
        if self._label:
            return '<%s-<FONT COLOR="blue" POINT-SIZE="20">%s</FONT> >' % (self._id, self._label)
        if self._secret:
            return '<<B><FONT COLOR="orange" POINT-SIZE="20">%s</FONT></B>>' % (self._id)
        if self._combat is not None:
            return '<<B><FONT COLOR="red" POINT-SIZE="20">%s</FONT></B>>' % (self._id)
        return '%s' % self._id
    
    
    def set_label(self, label):
        print(' [%s] Set label= %s' % (self._id, label))
        self._label = label  # '<%s-<FONT COLOR="blue" POINT-SIZE="20">%s</FONT> >' % (self._id, label)
    
    
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
        if r:
            print('NODE: %s stats keys: %s' % (self.get_id(), r))
        return r
    
    
    # Parse the jump condition, and produce 2 things:
    # * dict output, for easy comparision
    # * display text about the rule
    def parse_conditions(self):
        if self._conditions_raw == "":
            self._conditions = {}
            return
        # print('\n\n\n%s Condition raw: %s' % (self.get_id(), self._conditions_raw))
        r_tree = {}
        r_txt = {}
        sons_ids = ['%s' % son.get_id() for son in self._sons]
        for (k, expr) in self._conditions_raw.items():
            # First assert the condition IS in the sons ^^
            if k not in sons_ids:
                print('[%s] The condition: %s is not in our sons %s' % (self.get_id(), k, ', '.join(sons_ids)))
                sys.exit(2)
            facto = ConditionNodeFactory()
            _condition = facto.parse_expr(expr)
            # print('\n\n**********************\nCONDITION: %s :: %s => %s\n*****' % (k, expr, _condition))
            self._conditions_objs[k] = _condition
            r_tree[k] = _condition.to_json()
            r_txt[k] = expr.replace('(', '( ').replace(')', ' )').replace('&', ' et ').replace('|', ' ou ').strip()
        
        self._conditions = r_tree
        self._conditions_txts = r_txt
    
    
    def set_stats(self, stats):
        self._stats = stats
    
    
    def set_stats_cond(self, stats_con):
        self._stats_cond_raw = stats_con
    
    
    # Parse the jump condition, and produce 2 things:
    # * dict output, for easy comparision
    # * display text about the rule
    def parse_stats_conditions(self):
        if not self._stats_cond_raw:
            self._stats_cond = []
            return
        # print('\n\n\n%s Stats Condition raw: %s' % (self.get_id(), self._stats_cond_raw))
        r_lst = []
        for (expr, stats) in self._stats_cond_raw.items():
            facto = ConditionNodeFactory()
            _condition = facto.parse_expr(expr)
            # print('\n\n**********************\nCONDITION: %s :: %s => %s\n*****' % (k, expr, _condition))
            j = _condition.to_json()
            txt = expr.replace('(', '( ').replace(')', ' )').replace('&', ' et ').replace('|', ' ou ').strip()
            r_lst.append({'condition': j, 'stats': stats, 'txt': txt})
            # print('%s => %s / %s' % (expr, j, txt))
        self._stats_cond = r_lst
    
    
    def get_all_conditions_token(self):
        lst = set()
        for (k, cond) in self._conditions_objs.items():
            objs = cond.get_all_tokens()
            lst |= objs
        return lst
    
    
    def _get_ending_color(self):
        return {ENDINGS.GOOD: 'darkseagreen1', ENDINGS.BAD: 'crimson'}.get(self._ending)  # we are sure it's one of this value
    
    
    def _get_border_color(self):
        if self._success is not None:
            return 'gold'
        return 'black'
    
    
    def _get_penwidth(self):
        if self._success is not None:
            return '3.0'
        return '1.0'
    
    
    def add_son(self, son):
        self._sons.append(son)
    
    
    def get_sons(self):
        return self._sons
    
    
    def add_node_to_display_graph(self, display_graph):
        graph = display_graph
        
        border_color = self._get_border_color()
        penwidth = self._get_penwidth()
        
        if self._ending is not None:
            # First myself
            node_id_string = '%s' % self._id
            graph.node(node_id_string, shape='ellipse', style='solid', color=border_color, penwidth=penwidth,
                       fillcolor='white', label=self.get_label())
            
            # And also add the visual ending node
            node_id_string = "end-from-%s" % self._id
            graph.node(node_id_string, shape='doubleoctagon', style='filled', color=border_color, penwidth=penwidth,
                       fillcolor=self._get_ending_color(), label='End (%s)' % self._id)
        else:  # classic node
            node_id_string = '%s' % self._id
            graph.node(node_id_string, color=border_color, penwidth=penwidth, shape='ellipse', style='solid',
                       fillcolor='white', label=self.get_label())
    
    
    def _get_graph_from_nodes(self, other, arc_graphs):
        # type (Node, Any) -> None
        if self._arc is None or other.get_arc() is None:
            return arc_graphs[None]
        if self._arc == other.get_arc():
            graph = arc_graphs[self._arc]
            # print(' %s && %s == %s' % (self.get_id(), other.get_id(), self._arc))
            return graph
        return arc_graphs[None]
    
    
    def add_edges_to_display_graph(self, arc_graphs):
        node_string = '%s' % self._id
        
        if self._ending is not None:
            # And also add the visual ending node
            end_node_string = "end-from-%s" % self._id
            _graph = self._get_graph_from_nodes(self, arc_graphs)  # Lie: it's us, so we will be in our arc
            _graph.append((node_string, end_node_string))
        else:  # classic node
            for son in self._sons:
                son_string = '%s' % son.get_id()
                _graph = self._get_graph_from_nodes(son, arc_graphs)
                _graph.append((node_string, son_string))
    
    
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
        if nb > 50:
            err = '[%s] The sub arc is too big, seems NOT normal (%s)' % (sub_arc, nb)
            raise Exception(err)
        # Maybe we did reach the stop point, then... stop! ^^
        if self._id in sub_arc_stops:
            print('[%s] SUB-ARC: Stopping propagation at %s' % (sub_arc, self._id))
            return nb
        print('[%s] tagging %s' % (sub_arc, self._id))
        self._sub_arc = sub_arc
        nb += 1
        for son in self._sons:  # type: Node
            nb = son.set_in_sub_arc(sub_arc, sub_arc_stops, nb)
        return nb
    
    
    def set_in_sub_arc_not_recursive(self, sub_arc):
        # Loop stop
        if self._sub_arc is not None:
            return
        print('[%s] Manually tagging %s' % (sub_arc, self._id))
        self._sub_arc = sub_arc
    
    
    def get_sub_arc(self):
        return self._sub_arc

