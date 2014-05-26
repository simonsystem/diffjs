exporting = (c) => if module? then module.exports = c else @diffjs = c
exporting (math) ->

    {   Node
        OperatorNode
        ParamsNode
        ConstantNode
        SymbolNode
        AssignmentNode
        FunctionNode
        UnitNode } = math.expression.node
    
    operators = 
        add: "+"
        multiply: "*" 
        subtract: "-"
        divide: "/"
        pow: "^"
        unary: "-"


    op = (fn) -> (args...) -> new OperatorNode operators[fn], fn,  args
    pm = (fn) -> (args...) -> new ParamsNode (new SymbolNode fn), args
    
    # shorthands
    add = op "add"
    subtract = op "subtract"
    mult = op "multiply"
    div = op "divide"
    pow = op "pow"
    neg = op "unary"
    sin = pm "sin"
    cos = pm "cos"
    exp = (x) -> pow (new SymbolNode "e"), x
    ln = pm "ln"
    
    cnst = (x) -> new ConstantNode "number", x.toString()
    
    obda = (l) -> [l.slice(), l.slice().reverse()]
     
    optimize = (expr) -> expr.optimize()
            
    optimizeFn = (fn, params) ->
        if fn in ["add", "multiply"]
            for [a, b] in obda params
                if a instanceof ConstantNode
                    # neutral element
                    if fn == "add" and a.value == "0"
                        return b
                    if fn == "multiply" and a.value == "1"
                        return b
                    # multiply by 0
                    if fn == "multiply" and a.value == "0"
                        return cnst 0
                    # constant calculations (balanced tree)
                    if b instanceof ConstantNode
                        return cnst math[fn] parseInt(a.value), parseInt(b.value)
                    # disbalanced tree
                    if b instanceof OperatorNode and b.fn == fn
                        for [c, d] in obda b.params.map optimize
                            if c instanceof ConstantNode
                                val = cnst math[fn] parseInt(a.value), parseInt(c.value)
                                return op(fn) val, d
        if fn == "subtract"
            [a, b] = params
            if a instanceof ConstantNode
                # (0-X)
                if a.value == "0"
                    return neg b
            if b instanceof ConstantNode
                # (X-0)
                if b.value == "0"
                    return a
                if a instanceof ConstantNode
                    return cnst math.subtract parseInt(a.value), parseInt(b.value)
        if fn == "divide"
            [a, b] = params
            # multiply by 0
            if a instanceof ConstantNode
                if a.value == "0"
                    return cnst 0 
            # divide by 0
            if b instanceof ConstantNode
                if b.value == "0"
                    return new SymbolNode "Infinity"         
        if fn == "pow"
            [a, b] = params
            # base 
            if a instanceof ConstantNode
                if a.value == "0"
                    return cnst 0
                if a.value == "1"
                    return cnst 1
            # exponent
            if b instanceof ConstantNode
                if b.value == "0"
                    return cnst 1
                if b.value == "1"
                    return a
                # constant calculations
                if a instanceof ConstantNode
                    return cnst math.pow parseInt(a.value), parseInt(b.value)
                # power rules
                if a instanceof OperatorNode and a.fn == fn
                    [c, d] = a.params.map optimize
                    if d instanceof ConstantNode
                        return pow c, cnst math.multiply parseInt(d.value), parseInt(b.value)
                             
    
    OperatorNode::optimize = ->
        params = @params.map optimize
        optimizeFn(@fn, params) ? op(@fn) params...
    ParamsNode::optimize = ->
        params = @params.map optimize
        optimizeFn(@object.name, params) ? pm(@object.name) params...
    ConstantNode::optimize = -> cnst @value
    SymbolNode::optimize = -> new SymbolNode @name
    AssignmentNode::optimize = -> new AssignmentNode @name, optimize @expr
    FunctionNode::optimize = -> new FunctionNode @name, @args, optimize @expr
    UnitNode::optimize = -> optimize mult @value, new SymbolNode @unit
    
    
    diff = (expr, symbol="x") -> expr.diff(symbol)
    
    # differentiation rule for multiplication
    multiplyRule = (f, g, s) -> add(mult(f.diff(s), g), mult(f, g.diff(s)))  
    # differentiation rule for division
    divideRule = (f, g, s) ->
        div(
            subtract(mult(f.diff(s), g), mult(f, g.diff(s))),
            pow(g, cnst(2)))
    # differentiation rules for functions
    diffFn = (fn, params, s) ->
        [first, ..., last] = params
        if fn == "sin"
            return mult first.diff(s), cos first
        if fn == "cos"
            return mult first.diff(s), neg sin first
        if fn == "ln"
            return div first.diff(s), first
        if fn == "add"
            return add first.diff(s), last.diff(s)
        if fn == "subtract"
            return subtract first.diff(s), last.diff(s)
        if fn == "unary"
            return neg first.diff(s)
        if fn == "multiply"
            return multiplyRule first, last, s
        if fn == "divide"
            return divideRule first, last, s
        if fn == "pow"
            if first instanceof ConstantNode
                return exp(mult last, ln first).diff(s)
            if first instanceof SymbolNode and first.name == "e"
                return mult exp(last), last.diff(s)
            if last instanceof ConstantNode
                ex = parseInt(last.value)
                df = first.diff(s)
                return mult df, mult cnst(ex), pow first, cnst(ex - 1)
        throw "Error: not implemented"
    
    FunctionNode::diff = (s="x") -> new FunctionNode "d" + @name, @args, @expr.diff s
    AssignmentNode::diff = (s="x") -> new AssignmentNode @name, @expr.diff s
    ConstantNode::diff = (s="x") -> cnst 0
    SymbolNode::diff = (s="x") -> if @name == s then cnst 1 else cnst 0
    UnitNode::diff = (s="x") ->  mult(@value, new SymbolNode(@unit)).diff(s)
    OperatorNode::diff = (s="x") -> diffFn @fn, @params, s
    ParamsNode::diff = (s="x") -> diffFn @object.name, @params, s
    
    return math


  
