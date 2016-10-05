isArray = require("util").isArray
opaque = do ->
  t=
    structure: -> 'opaque'
    describe: -> ['opaque']
    contains: (v)-> v?
    includes: (t, resolve)->not t.contains null, resolve
  -> t
scalar = do ->
  scalarTypes =
    any:
      describe: ->['scalar','any']
      structure: -> 'scalar'
      contains: (v)->
        (typeof v) in ["string", "boolean", "number"]
      includes: (t)-> t in [
        scalar "string"
        scalar "boolean"
        scalar "number"
        scalar "any"
        bottom() 
      ]
    string:
      describe: -> ['scalar','string']
      structure: ->'scalar'
      contains: (v)->typeof v is "string"
      includes: (t)-> t in [(scalar "string"), bottom() ]
    number:
      describe: -> ['scalar','number']
      structure: -> 'scalar'
      contains: (v)->typeof v is "number"
      includes: (t)-> t in [(scalar "number"), bottom() ]
    boolean:
      describe: -> ['scalar','boolean']
      structure: -> 'scalar'
      contains: (v)->typeof v is "boolean"
      includes: (t)-> t in [(scalar "boolean"), bottom() ]
  (kind="any")->scalarTypes[kind]
document = (attrs)->
  structure: -> 'doc'
  attrs:attrs
  describe: (resolve)->
    d = {}
    d[key] = value.describe(resolve) for key,value of attrs
    ['document', d]
  contains: (obj,resolve)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for name, type of attrs
      value = obj[name]
      return false if value is undefined
      return false unless type.contains value,resolve
    true
  includes: (t,resolve)->
    return true if t.structure(resolve) is "bottom"
    return false unless t.structure(resolve) is "doc"
    for name, type0 of attrs
      type1 = t.attrs[name]
      return false unless type1?
      return false unless type0.includes type1,resolve
    true

describeNested = (resolve)-> 
  nested = @nestedType.describe(resolve)
  [@structure(resolve), nested...]

dict = (nestedType)->
  describe: describeNested
  structure: ->'dict'
  nestedType:nestedType
  contains: (obj,resolve)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for _,value of obj
      return false unless nestedType.contains value,resolve
    true
  includes: (t,resolve) ->
    return true if t.structure(resolve) is "bottom"
    return false unless t.structure(resolve) is "dict"
    nestedType.includes t.nestedType, resolve
list = (nestedType)->
  structure: -> 'list'
  describe: describeNested
  nestedType:nestedType
  contains: (obj,resolve)->
    return false unless obj?
    return false unless isArray obj
    for _,value of obj
      return false unless nestedType.contains value,resolve
    true
  includes: (t,resolve) ->
    return true if t.structure(resolve) is "bottom"
    return false unless t.structure(resolve) is "list"
    nestedType.includes t.nestedType, resolve
optional = (nestedType)->
  nestedType: nestedType
  structure: -> 'optional'
  describe: describeNested
  contains: (v,resolve)->
    v is null or nestedType.contains v, resolve
  includes: (t, resolve)->
    switch t.structure(resolve)
      when "bottom" then true
      when "optional" then nestedType.includes t.nestedType, resolve
      when "nil" then true
      else nestedType.includes t,resolve
nil = do ->
  n=
    structure:-> 'nil'
    describe: ->['nil']
    contains: (v)-> v is null
    includes: (t,resolve)->
      switch t.structure(resolve)
        when "bottom" then true
        when "nil" then true
        when "optional" then t.nestedType.structure(resolve) is "nil"
        else false
  -> n
bottom = do ->
  b=
    structure: ->'bottom'
    describe: ->['bottom']
    contains: -> false
    includes: (t)-> t is b
  -> b
ref = (symbol)->
  structure: (resolve0)->
    [target, resolve] = resolve0?(symbol) ? [null, null]
    target?.structure(resolve) ? 'ref'
  symbol: symbol
  describe: (resolve0)->
    [target, resolve] = resolve0?(symbol) ? [null, null]
    target?.describe(resolve) ? ['ref', symbol]
  contains: (v,resolve)->
    resolution = resolve0?(symbol) ? [null, null]
    throw new Error "unresolved symbol #{symbol}" if not resolution?
    [target, resolve] = resolution
    target.contains(v, resolve)
  includes: (t,resolve)->
    resolution = resolve0?(symbol) ? [null, null]
    throw new Error "unresolved symbol #{symbol}" if not resolution?
    [target, resolve] = resolution
    target.includes(v, resolve)

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
