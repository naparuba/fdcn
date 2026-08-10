import sys

class ConditionNode(object):
    def __init__(self):
        self.operator = None
        self.sons = []
        self.value = ''
    
    
    def __str__(self):
        if self.operator is None:
            return '<ConditionNode UNKNOWN>'
        if self.operator == 'or':
            return '<OR: %s>' % ', '.join(str(son) for son in self.sons)
        if self.operator == 'and':
            return '<AND: %s>' % ', '.join(str(son) for son in self.sons)
        if self.operator == 'simple':
            return '<END: %s>' % self.value
        return 'WHAT???'
    
    
    def get_all_tokens(self, lst=None):
        if lst is None:  # first one: create the list
            lst = set()
        if self.operator == 'simple':
            lst.add(self.value)
        for son in self.sons:
            son.get_all_tokens(lst=lst)
        return lst
    
    def to_json(self):
        if self.operator == 'or':
            return {'$or': [s.to_json() for s in self.sons]}
        if self.operator == 'and':
            return {'$and': [s.to_json() for s in self.sons]}
        if self.operator == 'simple':
            return {'$end': self.value}
        else:
            raise Exception('<ConditionNode UNKNOWN>')


class ConditionNodeFactory(object):
    
    def parse_expr_complex(self, expr):
        n = ConditionNode()
        
        stacked_par = 0  # level of parenthese
        stack = ''
        in_par = False
        for c in expr:
            if c == '|':
                # If we are in parenthese, just stack it
                if in_par:
                    stack += c
                else:  # real cut
                    n.operator = 'or'
                    stack = stack.strip()
                    if stack != '':
                        o = self.parse_expr(stack)
                        n.sons.append(o)
                        # print('EXPR OR => %s' % o)
                    stack = ''
            elif c == '&':
                # If we are in parenthese, just stack it
                if in_par:
                    stack += c
                else:  # real cut
                    n.operator = 'and'
                    stack = stack.strip()
                    if stack != '':
                        o = self.parse_expr(stack)
                        n.sons.append(o)
                        # print('EXPR AND => %s' % o)
                    stack = ''
            
            elif c == '(':
                stacked_par += 1
                # print "INCREASING STACK TO", stacked_par
                
                in_par = True
                stack = stack.strip()
                # Maybe we just start a par, but we got some things in tmp
                # that should not be good in fact !
                if stacked_par == 1 and stack != '':
                    # print('BAD EXPRESSION: %s' % expr)
                    sys.exit(2)
                
                # If we are already in a par, add this (
                # but not if it's the first one so
                if stacked_par > 1:
                    stack += c
                    o = self.parse_expr(stack)
                    # print "1( I've %s got new sons" % pattern , o
                    n.sons.append(o)
            
            elif c == ')':
                # print "Need closeing a sub expression?", tmp
                stacked_par -= 1
                
                if stacked_par < 0:
                    # print('ERROR: too much ) in %s' % expr)
                    sys.exit(2)
                
                if stacked_par == 0:
                    # print "THIS is closing a sub compress expression", tmp
                    stack = stack.strip()
                    o = self.parse_expr(stack)
                    n.sons.append(o)
                    # print('EXPR: %s => %s' % (expr, o))
                    in_par = False
                    # OK now clean the tmp so we start clean
                    stack = ''
                    continue
                
                # ok here we are still in a huge par, we just close one sub one
                stack += c
            # Maybe it's a classic character, if so, continue
            else:
                stack += c
        
        stack = stack.strip()
        if stack:
            # print('RES:EXPR=%s => %s' % (expr, stack))
            o = self.parse_expr(stack)
            n.sons.append(o)
            # print('EXPR: %s => %s' % (stack, o))
        
        return n
    
    
    def parse_expr_simple(self, expr):
        # print('SIMPLE: %s' % expr.strip())
        n = ConditionNode()
        n.operator = 'simple'
        n.value = expr
        return n
    
    
    def parse_expr(self, expr):
        # print('START: parse: %s' % expr)
        if '|' in expr or '&' in expr or '(' in expr or ')' in expr:
            return self.parse_expr_complex(expr)
        else:
            return self.parse_expr_simple(expr)
