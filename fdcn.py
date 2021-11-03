# -*- coding: utf-8 -*-

import graphviz
import json
import sys
import codecs

display_graph = graphviz.Digraph('G', filename='graph/fdcn_full', format='png', engine='dot')

with codecs.open('fdcn-1.json', 'r', 'utf8') as f:
    book_data = json.loads(f.read())

node_created = set()


class ENDINGS:
    GOOD = 1
    BAD = 2


class Graph(object):
    def __init__(self):
        self._nodes = {}
    
    
    def create_node(self, nid):
        nid = int(nid)
        node = Node(nid)
        self._nodes[nid] = node
        # print(' - %s created' % nid)
    
    
    def get_node(self, node_id):
        # type: (int) -> Node
        return self._nodes[node_id]
    
    
    def add_nodes_to_display_graph(self, display_graph):
        for node in self._nodes.values():
            node.add_node_to_display_graph(display_graph)
    
    
    def add_edges_to_display_graph(self, arc_graphs):
        for node in self._nodes.values():
            node.add_edges_to_display_graph(arc_graphs)


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
            'id'          : self._id,
            'ending'      : ending,
            'success'     : self._success,
            'sons'        : son_ids,
            'chapter'     : self._arc,
            'arc'         : self._sub_arc,
            'is_combat'   : self._combat is not None,
            'label'       : self._label,
            'secret'      : self._secret,
            'secret_jumps': self._secret_jumps,
            'ending_id': self._ending_id,
            'ending_txt': self._ending_txt,
            'ending_type' : self._ending,
        }
    
    
    def get_label(self):
        if self._label:
            return '<%s-<FONT COLOR="blue" POINT-SIZE="20">%s</FONT> >' % (self._id, self._label)
        if self._secret:
            return '<<B><FONT COLOR="orange" POINT-SIZE="20">%s</FONT></B>>' % (self._id)
        if self._combat:
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
        self._combat = True
    
    
    def set_secret(self):
        self._secret = True
    
    
    def is_secret(self):
        return self._secret
    
    
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
            graph.node(node_id_string, shape='ellipse', style='solid', color=border_color, penwidth=penwidth, fillcolor='white', label=self.get_label())
            
            # And also add the visual ending node
            node_id_string = "end-from-%s" % self._id
            graph.node(node_id_string, shape='doubleoctagon', style='filled', color=border_color, penwidth=penwidth, fillcolor=self._get_ending_color(), label='End (%s)' % self._id)
        else:  # classic node
            node_id_string = '%s' % self._id
            graph.node(node_id_string, color=border_color, penwidth=penwidth, shape='ellipse', style='solid', fillcolor='white', label=self.get_label())
    
    
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


node_graph = Graph()
for node_id_str in book_data.keys():
    node_graph.create_node(node_id_str)

for idx, n in book_data.items():
    idx = int(idx)
    
    node = node_graph.get_node(idx)
    
    # Get the success entry if any
    success = n.get('success', None)
    if success:
        node.set_sucess(success)
    
    # Get the combat entry if any
    combat = n.get('combat', None)
    if combat is not None:
        node.set_combat(combat)
    
    # Get the combat entry if any
    secret = n.get('secret', False)
    if secret:
        node.set_secret()
    
    # Get the label if any
    label = n.get('label', None)
    if label:
        node.set_label(label)
    
    secret_jumps = n.get('secret_jumps', None)
    if secret_jumps is not None:
        node.set_secret_jumps(secret_jumps)
    
    goto = n['goto']
    
    gotos = []
    if isinstance(goto, int):
        if goto == 608:
            ending = n.get('ending', None)
            if ending is None:
                print('ERROR: node %s is an end without ending' % idx)
                sys.exit(2)
            _ending = {'good': ENDINGS.GOOD, 'bad': ENDINGS.BAD}.get(ending, None)
            if _ending is None:
                print('ERROR: node %s have an unknown ending string: %s' % (idx, ending))
                sys.exit(2)
            node.set_ending(_ending)
            ending_id = n.get('ending_id', None)
            if ending_id:
                node.set_ending_id(ending_id)
                node.set_ending_txt(n.get('ending_txt'))
        else:
            son = node_graph.get_node(goto)
            node.add_son(son)
    else:  # list
        for dest_idx in goto:
            son = node_graph.get_node(dest_idx)
            node.add_son(son)
        # gotos = [dest_idx for dest_idx in goto]
    
    # for dest_idx in gotos:
    #    display_graph.edge('%s' % idx, dest_idx)

# g.edge('Hello', 'World')


arcs = [(1, 'Plante-Citrouille'),
        (100, 'Lenonia'),
        (193, 'Cathedrale'),
        (216, 'Tour des mages'),
        (323, 'Prison'),
        (300, 'Invasion'),
        (400, 'Forteresse'),
        (500, 'Virilus')
        ]
# (arc_name, Start of sub, name, stops)
sub_arcs = [
    ('Invasion', 148, 'Quartier boulanger', [496, 285]),
    ('Invasion', 283, 'Tour des mages', [183, 95, 285]),
    
    ('Forteresse', 553, 'Thermes', [551, 80, 561]),
    ('Forteresse', 462, 'Bagarre', [457]),
    ('Forteresse', 376, 'Cuisine', [457, 340]),
    ('Forteresse', 583, 'Cachots', [461, 186]),
    ('Forteresse', 425, 'Catacombes', [80]),
    ('Forteresse', 266, 'Laboratoire', [80]),
    ('Forteresse', 569, 'Mortelle', [447, 186]),
    ('Forteresse', 226, 'Funeste', [461]),
    ('Forteresse', 340, 'Entrepôt', [184, 520, 218, 400]),
]

manual_sub_arcs = {
    'Couloirs': [184, 10, 447, 581, 461, 520, 80, 400, 457],
}

# Tag nodes with arc, from lower to higher so we don't rewrite them
for arc_start, arc_name in reversed(arcs):
    print('Tagging arc: %s (%s)' % (arc_start, arc_name))
    arc_node_start = node_graph.get_node(arc_start)  # type: Node
    arc_node_start.set_in_arc(arc_name)

for arc_name, sub_arc_start, sub_arc_name, sub_arc_stops in sub_arcs:
    node_start = node_graph.get_node(sub_arc_start)
    node_start.set_in_sub_arc(sub_arc_name, sub_arc_stops, 0)

for sub_arc_name, node_ids in manual_sub_arcs.items():
    print('Sub arc (manual): %s => %s' % (sub_arc_name, node_ids))
    for node_id in node_ids:
        node = node_graph.get_node(node_id)
        node.set_in_sub_arc_not_recursive(sub_arc_name)

arc_graphs = {None: []}
for _, arc_name in arcs:
    arc_graphs[arc_name] = []

print('Adding nodes to display graph:')
node_graph.add_nodes_to_display_graph(display_graph)
print('Adding edges to display graph:')
node_graph.add_edges_to_display_graph(arc_graphs)

# Now put nodes into graphs and clusters
for arc_name, arc_edges in arc_graphs.items():
    print('Arc %s => size=%s' % (arc_name, len(arc_edges)))
    if arc_name is None:
        for start, end in arc_edges:
            display_graph.edge(start, end)
    else:
        with display_graph.subgraph(name='cluster_%s' % arc_name) as cluster:
            sub_arc_edges = {}
            for edges in arc_edges[:]:
                edge_start_node = node_graph.get_node(int(edges[0]))  # type: Node
                edge_start_sub_arc = edge_start_node.get_sub_arc()
                try:
                    end_id = int(edges[1])
                except ValueError:  # not a classic node, skip this
                    continue
                edge_end_node = node_graph.get_node(end_id)  # type: Node
                
                # Maybe the two nodes are not in the same sub_arc, so don't link them here
                if edge_end_node.get_sub_arc() != edge_start_sub_arc:
                    print('%s => skipping not related edge: %s' % (sub_arc_name, edges))
                    continue
                if edge_start_sub_arc is not None:
                    if edge_start_sub_arc not in sub_arc_edges:
                        sub_arc_edges[edge_start_sub_arc] = []
                    sub_arc_edges[edge_start_sub_arc].append(edges)
                    arc_edges.remove(edges)
            print('%s => sub arcs= %s' % (arc_name, sub_arc_edges))
            for sub_arc_name, sub_arc_edges in sub_arc_edges.items():
                with cluster.subgraph(name='cluster_%s' % sub_arc_name) as sub_cluster:
                    print('SUB-ARC=[%s] nb jumps:%s' % (sub_arc_name, len(sub_arc_edges)))
                    # Now put the edges in the global cluster, not in a sub arcs
                    sub_cluster.attr(style='filled', color='grey')
                    sub_cluster.edges(sub_arc_edges)
                    sub_cluster.attr(label=sub_arc_name)
                    sub_cluster.attr(fontsize="72", fontcolor='red')
            
            # Now put the edges in the global cluster, not in a sub arcs
            cluster.attr(style='filled', color='lightgrey')
            cluster.edges(arc_edges)
            cluster.attr(label=arc_name)
            cluster.attr(fontsize="72", fontcolor='red')

print('Writing compilated data')
# Modify the book data with what we did compute

for node_id_str, node_data in book_data.items():
    node = node_graph.get_node(int(node_id_str))
    node_data['computed'] = node.get_computed()

new_book_data_string = json.dumps(book_data, indent=4, ensure_ascii=False, sort_keys=True)  # allow utf8
with codecs.open('fdcn-1-compilated-data.json', 'w', 'utf8') as f:
    f.write(new_book_data_string)

with codecs.open('all-success.json', 'r', 'utf8') as f:
    sucess_txt = json.loads(f.read())
    print('Success txt', sucess_txt)


def get_success_txt(_id):
    for success in sucess_txt:
        if success['id'] == _id:
            return success['label'], success['txt']
    raise Exception('Success: %s not found' % _id)


reverse_jumps = {}

all_combats = []
all_endings = []
good_endings = []
bad_endings = []
all_secrets = []
nodes_by_chapter = {}
nodes_by_sub_arc = {}
all_success = []
all_success_chapters = {}
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    if node.have_combat():
        all_combats.append(node.get_id())
    if node.have_ending():
        all_endings.append(node.get_id())
        if node.is_good_ending():
            good_endings.append(node.get_id())
        else:  # bad
            bad_endings.append(node.get_id())
    
    if node.is_secret():
        all_secrets.append(node.get_id())
    # Flag reverse jumps
    for son in node.get_sons():
        son_id = son.get_id()
        if son_id not in reverse_jumps:
            reverse_jumps[son_id] = []
        reverse_jumps[son_id].append(int(node_id_str))
    
    arc = node.get_arc()
    if arc:
        if arc not in nodes_by_chapter:
            nodes_by_chapter[arc] = []
        nodes_by_chapter[arc].append(int(node_id_str))
    
    sub_arc = node.get_sub_arc()
    if sub_arc:
        if sub_arc not in nodes_by_sub_arc:
            nodes_by_sub_arc[sub_arc] = []
        nodes_by_sub_arc[sub_arc].append(int(node_id_str))
    
    success = node.get_success()
    if success:
        label, txt = get_success_txt(success)
        print('%s have the success %s: %s:%s' % (node_id_str, success, label, txt))
        all_success.append({'id': success, 'chapter': int(node_id_str), 'label': label, 'txt': txt})
        all_success_chapters[int(node_id_str)] = success

# Check for secrets that should NOT be accessible by 2 ways
print('Checking for secret reverse jump:')
print('  - Must be one source')
print('  - or multiple but ALL are real secret jump')
print('    => if not, must use secret_jump key in .json, like fdcn1 234->76')

for node_id, froms in reverse_jumps.items():
    node = node_graph.get_node(node_id)
    prefix = 'OK: ' if node.is_secret() else ''
    if not node.is_secret():
        continue
    if len(froms) != 1:
        prefix = '!!! WARNING => '
    print('%s%3d <- %s' % (prefix, node_id, ', '.join(['%s' % i for i in froms])))

with codecs.open('fdcn-1-compilated-combats.json', 'w', 'utf8') as f:
    f.write(json.dumps(all_combats, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-endings.json', 'w', 'utf8') as f:
    f.write(json.dumps(all_endings, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-good-endings.json', 'w', 'utf8') as f:
    f.write(json.dumps(good_endings, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-bad-endings.json', 'w', 'utf8') as f:
    f.write(json.dumps(bad_endings, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-secrets.json', 'w', 'utf8') as f:
    f.write(json.dumps(all_secrets, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-nodes-by-chapter.json', 'w', 'utf8') as f:
    f.write(json.dumps(nodes_by_chapter, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-nodes-by-sub-arc.json', 'w', 'utf8') as f:
    f.write(json.dumps(nodes_by_sub_arc, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-success.json', 'w', 'utf8') as f:
    f.write(json.dumps(all_success, indent=4, ensure_ascii=False, sort_keys=True))

with codecs.open('fdcn-1-compilated-success-chapters.json', 'w', 'utf8') as f:
    f.write(json.dumps(all_success_chapters, indent=4, ensure_ascii=False, sort_keys=True))

# Get the node positions
# json_string = display_graph.pipe(format='json').decode()
# json_dict = json.loads(json_string)
# for obj in json_dict['objects']:
#     if 'pos' not in obj:  # do not get cluster, we don't care here
#         continue
#     print('OBJ: %s' % obj)
#     print(obj['name'], '\t', obj['pos'])



print('Rendering')
#display_graph.render(filename='hello.gv', view=True)#format='json')
display_graph.render(format='png')

