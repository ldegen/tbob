isArray = require("util").isArray
merge = require "./merge"
list2obj = require "./list2obj"
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
    
augmentCx = require "./build-context"
constructPlain = (build, spec, cx)->
  augmented = augmentCx cx
  unless spec?
    throw new Error "expected something of type #{JSON.stringify @describe()}, but got '#{spec}'"
  build spec, augmented

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


document = (attrs,meta=null)->
  constructValue:(build,spec0={}, cx)->
    spec = if isArray spec0 then list2obj spec0 else spec0
    constructPlain.call this, build, spec, augmentCx cx
  structure: -> 'doc'
  attrs:attrs
  _meta: meta
  meta: (path...)->
    node = this
    parent = null
    lastAttr = null
    for attrName,i in path
      parent = node
      if parent.structure() isnt "doc"
        throw new Error "Cannot traverse a non-document type.\n  Path: #{path[...i]}\n  Starting from: #{@describe()}"
      node = node.attrs[attrName]
      lastAttr = attrName
      if not node?
        throw new Error "Failed to resolve attribute #{attrName}\n  Path:#{path[..i]}\n  Starting from: #{@describe()}"
      node = node.nestedType while node.nestedType?
    merge {}, node._meta?.self, parent?._meta?.attributes?[lastAttr]

  metaTree: ()->
    tree=
      _self: meta?.self
    for attrName, attrType of attrs
      attrType = attrType.nestedType while attrType.nestedType?
      if attrType.structure() is "doc"
        subTree = attrType.metaTree()
        if subTree?._self? or subTree?._attrs?
          tree._attrs ?= {} 
          tree._attrs[attrName] = subTree
    for attrName, attrMeta of (meta?.attributes ? {})
      tree._attrs ?= {}
      tree._attrs[attrName] ?= {}
      tree._attrs[attrName]._self ?= {}
      tree._attrs[attrName]._self = merge tree._attrs[attrName]._self, attrMeta
    tree
        
  applySubst: applySubst (s, path)->
    attrs_ = {}
    attrs_[key] = val.applySubst s, path for key,val of attrs
    document attrs_,meta
    
  describe: ()->
    d = {}
    d[key] = value.describe() for key,value of attrs
    if meta? then ['document',d,meta] else ['document', d]
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
  constructValue: (build, spec0={}, cx)->
    spec = if isArray spec0 then list2obj spec0 else spec0
    d = {}
    d[key] = nestedType.constructValue build, value, augmentCx(cx)._mkChild key for key,value of spec
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
  constructValue: (build, spec=[], cx)->
    (nestedType.constructValue build, value, augmentCx(cx)._mkChild i for value,i in spec)
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
  constructValue: (build, spec, cx)->
    if spec? then nestedType.constructValue build, spec, augmentCx cx else null
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
  constructValue:(build, spec,cx)->
    if not @target?
      throw new Error "dangling recursive reference"
    @target.constructValue build, spec, augmentCx cx
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
      
module.exports = Type =
  construct:(description)->
    throw new Error "please tell me what you want to construct" if not description?.length
    [head, tail...] = description
    #head is always a functor.
    functor = Type[head+'T']
    throw new Error "bad functor: #{head}" if not functor?
    switch head
      when "dict", "list", "optional"
        # for "modifying" type functors, process tail recursively and
        # pass resulting type as single arg.
        arg = Type.construct tail
        functor.call Type, arg
      when "document"
        # we need to process attribute types recursively
        throw new Error "too many arguments: #{description}" if tail.length > 2
        [attrDescriptions, meta] = tail
        attrs = {}
        attrs[key] = Type.construct attrDescription for key, attrDescription of attrDescriptions
        functor.call Type, attrs, meta
      else
        # otherwise we are at a "leaf" type. In this case the current functor
        # should consume any remaining elements.
        # Check tail length and raise error if it is too long.
        throw new Error "too many arguments: #{description}" if tail.length > functor.length

        # Apply functor to tail.
        functor.apply Type, tail


  opaqueT:opaque
  scalarT:scalar
  documentT:document
  dictT:dict
  listT:list
  optionalT:optional
  nilT:nil
  bottomT:bottom
  refT:ref
