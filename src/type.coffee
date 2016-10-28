isArray = require("util").isArray

list2obj = (list)->
  obj = undefined
  if list.length == 0
    obj = {}
  else
    [key, val, rest...] = list
    obj = list2obj rest
    obj[key] = val
  obj

applySubst= (impl) -> (s, path0=[]) ->
  i = path0.indexOf this
  if i!=-1
    r=recursive i
    path0[i]._refs ?= []
    path0[i]._refs.push r
    return r
  path = [this,path0...]
  replacement = impl.call this, s, path
  refs = @_refs?.slice() ? []
  delete @_refs
  ref.target=replacement for ref in refs
  replacement
    

constructPlain = (build, spec)->
  throw Error "missing value! (TODO: helpful error messages)" unless spec?
  build spec

expand = (impl) -> (t) ->
  if t.structure() == "recursive"
    throw new Error "dangling recursive reference" if not t.target?
    impl t.target
  else 
    impl t

opaque = do ->
  t=
    constructValue: constructPlain
    structure: -> 'opaque'
    describe: -> ['opaque']
    applySubst: ->this
    contains: (v)-> v?
    includes: expand (t)->not t.contains null
  -> t
scalar = do ->
  scalarTypes =
    any:
      constructValue: constructPlain
      applySubst: ->this
      describe: ->['scalar','any']
      structure: -> 'scalar'
      contains: (v)->
        (typeof v) in ["string", "boolean", "number"]
      includes: expand (t)-> t in [
        scalar "string"
        scalar "boolean"
        scalar "number"
        scalar "any"
        bottom() 
      ]
    string:
      constructValue: constructPlain
      applySubst: ->this
      describe: -> ['scalar','string']
      structure: ->'scalar'
      contains: (v)->typeof v is "string"
      includes: expand (t)-> t in [(scalar "string"), bottom() ]
    number:
      constructValue: constructPlain
      applySubst: ->this
      describe: -> ['scalar','number']
      structure: -> 'scalar'
      contains: (v)->typeof v is "number"
      includes: expand (t)-> t in [(scalar "number"), bottom() ]
    boolean:
      constructValue: constructPlain
      applySubst: ->this
      describe: -> ['scalar','boolean']
      structure: -> 'scalar'
      contains: (v)->typeof v is "boolean"
      includes: expand (t)-> t in [(scalar "boolean"), bottom() ]
  (kind="any")->scalarTypes[kind]


document = (attrs)->
  constructValue:(build,spec)->
    constructPlain build, if isArray spec then list2obj spec else spec
  structure: -> 'doc'
  attrs:attrs
  applySubst: applySubst (s, path)->
    attrs_ = {}
    attrs_[key] = val.applySubst s, path for key,val of attrs
    document attrs_
    
  describe: ()->
    d = {}
    d[key] = value.describe() for key,value of attrs
    ['document', d]
  contains: (obj)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for name, type of attrs
      value = obj[name]
      return false if value is undefined
      return false unless type.contains value
    true
  includes: expand (t)->
    return true if t.structure() is "bottom"
    return false unless t.structure() is "doc"
    for name, type0 of attrs
      type1 = t.attrs[name]
      return false unless type1?
      return false unless type0.includes type1
    true

describeNested = ()-> 
  nested = @nestedType.describe()
  [@structure(), nested...]

dict = (nestedType)->
  constructValue: (build, spec0)->
    spec = if isArray spec0 then list2obj spec0 else spec0
    d = {}
    d[key] = nestedType.constructValue build, value for key,value of spec
    d
  describe: describeNested
  structure: ->'dict'
  nestedType:nestedType
  applySubst: applySubst (s,path)->
    dict @nestedType.applySubst s,path
  contains: (obj)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for _,value of obj
      return false unless nestedType.contains value
    true
  includes: expand (t) ->
    return true if t.structure() is "bottom"
    return false unless t.structure() is "dict"
    nestedType.includes t.nestedType
list = (nestedType)->
  constructValue: (build, spec)->
    (nestedType.constructValue build, value for value in spec)
  structure: -> 'list'
  describe: describeNested
  nestedType:nestedType
  applySubst: applySubst (s,path)->
    list @nestedType.applySubst s,path
  contains: (obj)->
    return false unless obj?
    return false unless isArray obj
    for _,value of obj
      return false unless nestedType.contains value
    true
  includes: expand (t) ->
    return true if t.structure() is "bottom"
    return false unless t.structure() is "list"
    nestedType.includes t.nestedType
optional = (nestedType)->
  constructValue: (build, spec)->
    if spec? then nestedType.constructValue build, spec else null
  nestedType: nestedType
  structure: -> 'optional'
  describe: describeNested
  applySubst: applySubst (s,path)->
    optional @nestedType.applySubst s,path
  contains: (v)->
    v is null or nestedType.contains v
  includes: expand (t)->
    switch t.structure()
      when "bottom" then true
      when "optional" then nestedType.includes t.nestedType
      when "nil" then true
      else nestedType.includes t
nil = do ->
  n=
    constructValue: -> null
    structure:-> 'nil'
    describe: ->['nil']
    applySubst: ->this
    contains: (v)-> v is null
    includes: expand (t)->
      switch t.structure()
        when "bottom" then true
        when "nil" then true
        when "optional" then t.nestedType.structure() is "nil"
        else false
  -> n
bottom = do ->
  b=
    structure: ->'bottom'
    describe: ->['bottom']
    applySubst: ->this
    contains: -> false
    includes: expand (t)-> t is b
  -> b
ref = (symbol)->
  structure: ()-> 'ref'
  symbol: symbol
  describe: ()->['ref', symbol]
  applySubst: applySubst (s,path)->
    t = s symbol
    if t? then t.applySubst s, path else this
  constructValue: ->
    throw new Error "unresolved symbol #{symbol}"
  contains: (v)->
    throw new Error "unresolved symbol #{symbol}"
  includes: expand (t)->
    throw new Error "unresolved symbol #{symbol}"
recursive = (depth)->
  structure: -> "recursive"
  describe: -> ['recursive', depth]
  applySubst: -> this
  target:null
  depth:->depth
  constructValue:(build, spec)->
    if not @target?
      throw new Error "dangling recursive reference"
    @target.constructValue build, spec
  contains:(v)->
    if not @target?
      throw new Error "dangling recursive reference"
    @target.contains v
  includes:(t)->
    if not @target?
      throw new Error "dangling recursive reference"
    if t.structure() == "recursive"
      #if both are recursion markers, we can assume that everything is fine:
      #we would not have gotten here otherwise.
      return true
    else
      # otherwise we "expand" another instance
      @target.includes t
      
module.exports =
  construct:(description)->
    if description.length > 0
      [head, tail...] = description
      if typeof head is "string" and @hasOwnProperty head+'T'
        constructor = this[head+'T']
        arg = @construct tail
        constructor.call this, arg
      else if tail.length > 0
        throw new Error "too many arguments: #{tail}"
      else
        head


  opaqueT:opaque
  scalarT:scalar
  documentT:document
  dictT:dict
  listT:list
  optionalT:optional
  nilT:nil
  bottomT:bottom
  refT:ref
