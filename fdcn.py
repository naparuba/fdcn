import graphviz
import json

display_graph = graphviz.Digraph('G', filename='graph/fdcn', format='png')

with open('fdcn-1.json', 'r') as f:
    book_data = json.loads(f.read())

print(book_data)

node_created = set()

class ENDINGS:
    GOOD = 1
    BAD  = 2

class Graph(object):
    def __init__(self):
        self._nodes = {}
        
    def create_node(self, nid):
        nid = int(nid)
        node = Node(nid)
        self._nodes[nid] = node
        print(' - %s created' % nid)
    
    
    def set_ending_node(self, nid, from_node_id,ending):
        from_node = self._nodes[from_node_id]
        node = self._nodes[nid]
        node.set_ending(from_node, ending)


    def set_chapter_start(self, node_id):
        pass


    def get_node(self,node_id):
        return self._nodes[node_id]

class Node(object):
    def __init__(self, nid):
        _id = int(nid)
        self._id = _id
        
        self._ending = None
        self._from_node_ending = None
        
        self._is_chapter_start = False
        
        
    def get_id(self):
        return self._id
        
    def set_ending(self, from_node, ending):
        self._from_node_ending = from_node
        self._ending = ending


    def add_to_display_graph(self, display_graph):
        if self._is_chapter_start:
            node_string = '%s' % self._id
            display_graph.attr('node', shape='doubleoctagon', style='filled', color='lightgrey', fillcolor='green')
            display_graph.node(node_string)
            print('NEW NODE (END): %s' % node_string)
        elif self._ending is not None:
            node_string = "end-from-%s" % self._from_node_ending.get_id()
            display_graph.attr('node', shape='doubleoctagon', style='filled', color='lightgrey', fillcolor='yellow')
            display_graph.node(node_string)
            print('NEW NODE (END): %s' % node_string)
        else:  # classic node
            node_string = '%s' % self._id
            display_graph.attr('node', shape='ellipse', style='solid', fillcolor='white')
            display_graph.node(node_string)


node_graph = Graph()
for node_id_str in book_data.keys():
    node_graph.create_node(node_id_str)




def create_node(idx, end_from_idx=''):
    #return
    idx = '%s' % idx
    # print('.. creating %s (%s)' % (idx, type(idx)))
    # do not create node two times
    if idx in node_created and idx != '608':
        # print('ALREADY FOUNDED')
        return
    node_created.add(idx)
    # print('NODE CREATED: %s (%s)' % (node_created, len(node_created)))
    if int(idx) % 100 == 0:
        print('100 aine %s' % type(idx))
        display_graph.attr('node', shape='doubleoctagon', style='filled', color='lightgrey', fillcolor='green')
        display_graph.node('%s' % idx)
        print('NEW NODE (100): %s' % idx)
    elif int(idx) == 608:
        n_id = "fin-%s" % end_from_idx
        display_graph.attr('node', shape='doubleoctagon', style='filled', color='lightgrey', fillcolor='yellow')
        display_graph.node(n_id)
        print('NEW NODE (END): %s' % n_id)
    else:
        display_graph.attr('node', shape='ellipse', style='solid', fillcolor='white')
        display_graph.node('%s' % idx)
        print('NEW NODE      : %s' % idx)


for idx, n in book_data.items():
    idx = int(idx)
    print('Node: %s' % idx)
    
    create_node(idx)
    
    node = node_graph.get_node(idx)
    
    goto = n['goto']
    if goto == 0:  # not finish
        print('SKIPPING not finished: %s' % idx)
        continue
        
    gotos = []
    if isinstance(goto, int):
        if goto == 608:
            create_node(608, '%s' % idx)
            goto = "fin-%s" % idx
            # g.attr('node', shape='doubleoctagon', style='filled', color='lightgrey', fillcolor='yellow')
            # g.node(goto)
            # g.attr('node', shape='ellipse', style='solid', fillcolor='white')
        
        gotos.append('%s' % goto)
    else:  # list
        gotos = ['%s' % s for s in goto]
    
    for dest_idx in gotos:
        if not dest_idx.startswith('fin-'):
            create_node(dest_idx)
        display_graph.edge('%s' % idx, dest_idx)

# g.edge('Hello', 'World')

print('Rendering')
display_graph.render()
# g.view()
