{refT, documentT} = require "./type"
Factory = require "./factory"
instances = []
instance = (id0=-1)->
  try
    id = if typeof id0 is "number" then id0 else parseInt id0.toString(), 10
    instances[id]
  catch e
    null
#debug = (args...) -> debug args...
debug = ->
merge = (objs...)->
  q={}
  q[key]=value for key,value of o for o in objs
  q
Trait=(opts={})->
  Attribute = require "./attribute"
  attrSpecs = opts.attributes ? {}
  attrs = {}
  alias = opts.alias ? null
  id=instances.length

  parent = ()->
    symbol = opts.parent ? null
    debug "resolving parent", symbol
    resolveGlobal symbol

  dependencies = ()->
    deps = opts.deps ? []
    debug "resolving dependencies", deps
    deps.map resolveLocal

  resolveGlobal= (symbol)->
    return symbol if not symbol? or typeof symbol is "object"
    debug "resolve global", symbol
    obj=opts.resolveGlobal? symbol
    debug "resolved (global): ", symbol, obj
    obj

  resolveLocal= (symbol)->
    return symbol if not symbol? or typeof symbol is "object"
    debug "resolve local", symbol
    if opts.alias == symbol
      self = instance id
      debug "resolved (via local alias): ",symbol, self
      return self

    obj = parent()?.resolveLocal? symbol 
    if obj?
      debug "resolved (via parent):", symbol, obj
      return obj

    obj = instance symbol 
    if obj?
      debug "resolved (via id-match):", symbol, obj
      return obj
    
    obj = resolveGlobal symbol
    if obj?
      debug "resolved (via global lookup):", symbol, obj
      return obj

    debug "not resolved:", symbol

  for key,value of attrSpecs
    if value instanceof Attribute
      attrs[key] = value
    else
      attrs[key] = Attribute key, merge value, substitute: resolveLocal

  instances[id]=
    id:->id
    resolveLocal: resolveLocal
    label:->opts.alias ? id
    toString: ->opts.alias ? "Trait #{id}"
    dependencies: dependencies
    attributes: -> attrs
    apply: (factory)->
      for name, attr of attrs
        attr.apply factory
    describe: ->
      label: @label()
      dependencies: @dependencies().map (d)->d.label()
      parent: parent()?.label?() ? null
      attributes: do ->
        obj={}
        obj[name] = attr.type().describe() for name,attr of attrs
        obj

unsafeOverrides= (sortedTraits)->
  unsafe=[]
  attrs={}
  for trait in sortedTraits
    for attrName, attr of trait.attributes()
      prev=attrs[attrName]
      if prev? and not prev.attr.type().includes attr.type()
        unsafe.push [attrName, prev.trait, trait]
      attrs[attrName] =
        trait:trait
        attr:attr
  unsafe

missingAttributes= (sortedTraits) ->
  missing=[]
  attrs={}
  for trait in sortedTraits
    for attrName, attr of trait.attributes()
      attrs[attrName] =
        trait:trait
        attr:attr
  for name,definition of attrs
    for dep in definition.attr.deps()
      if not attrs[dep]?
        missing.push [dep,name,definition.trait]
  missing

typeCache = {}
typeForSeq = (traits)->
  key = traits.map (t)->t.id()
  if not typeCache[key]?
    # This looks like a copy paste error BUT IT IS CORRECT.
    # The first assignment will put a temporary type into cache.
    # This will ensure termination in case of recursive structures
    # It will also cause a refT to end up in the right place.
    # The second assignment will replace the temporary
    # entry once the structure is completely build.
    # A final substitution on the type will create the
    # (desired!) cycle in the type structure.
    typeCache[key] = refT key
    typeCache[key] = createTypeForSeq traits
    typeCache[key] = typeCache[key].applySubst (s)->typeCache[s]
  typeCache[key]

createTypeForSeq = (sortedTraits)->

  unsafe = unsafeOverrides(sortedTraits)
  if unsafe.length > 0
    throw new Error "unsafe overrides: #{unsafe.toString()}"

  attrTypes={}
  for trait in sortedTraits
    for attrName, attr of trait.attributes()
      attrTypes[attrName] = attr.type()
  documentT attrTypes

seqCache = {}
sequence = (traits)->
  key = traits.map (t)->t.id()
  seqCache[key] ?= createSequence traits
createSequence = (traits)->
  toposort = require "toposort"
  done = {}
  # adds implicit dependencies to ensure traits order
  augment = (t,i,arr)->
    if typeof t.id isnt "function"
      debug "t", t
    id:t.id()
    trait: t
    pre: if i>0 then [t.dependencies()...,arr[i-1]] else t.dependencies().slice()
  todo = traits
    .map augment
    .reverse()
  while todo.length >0
    v = todo.pop()
    if not done[v.id]?
      done[v.id] =v
      debug "children", v.trait.dependencies()
      children = v.trait.dependencies()
        .map augment
        .reverse()
      todo.push children...

  edges = []
  for _, v of done
    for d in v.pre
      edges.push [v.trait,d]
  if edges.length  > 0
    sortedTraits = toposort(edges).reverse()
  else
    sortedTraits = [v.trait] for _,v of done

  resolve = (symbol)->
    traits=symbol.toString()
      .trim()
      .split ','
      .map instance
    return null if null in traits
    seq = module.exports.sequence traits


  traits:sortedTraits
  type: -> typeForSeq sortedTraits
  unsafeOverrides: -> unsafeOverrides sortedTraits
  missingAttributes: -> missingAttributes sortedTraits
  factory: -> 
    factoryForTraits sortedTraits
  


factoryCache = {}
factoryForTraits = (sortedTraits)->
  key = sortedTraits.map (t)->t.id()
  factoryCache[key] ?= createFactory sortedTraits
createFactory = (sortedTraits)->
  factory = new Factory
  trait.apply factory for trait in sortedTraits
  factory
  
module.exports = Trait
module.exports.sequence = sequence

