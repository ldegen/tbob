isArray = require("util").isArray
opaque = do ->
  t=
    contains: (v)-> v?
    includes: (t)->not t.contains null
  -> t
scalar = do ->
  scalarTypes =
    any:
      structure: 'scalar'
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
      structure: 'scalar'
      contains: (v)->typeof v is "string"
      includes: (t)-> t in [(scalar "string"), bottom() ]
    number:
      structure: 'scalar'
      contains: (v)->typeof v is "number"
      includes: (t)-> t in [(scalar "number"), bottom() ]
    boolean:
      structure: 'scalar'
      contains: (v)->typeof v is "boolean"
      includes: (t)-> t in [(scalar "boolean"), bottom() ]
  (kind="any")->scalarTypes[kind]
document = (attrs)->
  structure: 'doc'
  attrs:attrs
  contains: (obj)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for name, type of attrs
      value = obj[name]
      return false if value is undefined
      return false unless type.contains value
    true
  includes: (t)->
    return true if t.structure is "bottom"
    return false unless t.structure is "doc"
    for name, type0 of attrs
      type1 = t.attrs[name]
      return false unless type1?
      return false unless type0.includes type1
    true

dict = (nestedType)->
  structure: 'dict'
  nestedType:nestedType
  contains: (obj)->
    return false unless obj?
    return false unless typeof obj is "object"
    return false if isArray obj
    for _,value of obj
      return false unless nestedType.contains value
    true
  includes: (t) ->
    return true if t.structure is "bottom"
    return false unless t.structure is "dict"
    nestedType.includes t.nestedType
list = (nestedType)->
  structure: 'list'
  nestedType:nestedType
  contains: (obj)->
    return false unless obj?
    return false unless isArray obj
    for _,value of obj
      return false unless nestedType.contains value
    true
  includes: (t) ->
    return true if t.structure is "bottom"
    return false unless t.structure is "list"
    nestedType.includes t.nestedType
optional = (nestedType)->
      nestedType: nestedType
      structure: 'optional'
      contains: (v)->
        v is null or nestedType.contains v
      includes: (t)->
        switch t.structure
          when "bottom" then true
          when "optional" then nestedType.includes t.nestedType
          when "nil" then true
          else nestedType.includes t
nil = do ->
  n=
    structure: 'nil'
    contains: (v)-> v is null
    includes: (t)->
      switch t.structure
        when "bottom" then true
        when "nil" then true
        when "optional" then t.nestedType.structure is "nil"
        else false
  -> n
bottom = do ->
  b=
    structure: 'bottom'
    contains: -> false
    includes: (t)-> t is b
  -> b


module.exports =
  opaqueT:opaque
  scalarT:scalar
  documentT:document
  dictT:dict
  listT:list
  optionalT:optional
  nilT:nil
  bottomT:bottom
