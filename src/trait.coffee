{refT, documentT} = require "./type"
instances = []
instance = (id0=-1)->
  try
    id = if typeof id0 is "number" then id0 else parseInt id0.toString(), 10
    instances[id]
  catch e
    null

merge = (objs...)->
  q={}
  q[key]=value for key,value of o for o in objs
  q
module.exports=(opts={})->
  Attribute = require "./attribute"
  attrSpecs = opts.attributes ? {}
  parent = opts.parent ? null
  alias = opts.alias ? null
  id=instances.length
  resolveTrait= (symbol)->
    if opts.alias == symbol
      self = instance id
      return self
    if parent? then parent.resolveTrait symbol else instance symbol
  attrs = {}
  for key,value of attrSpecs
    if value instanceof Attribute
      attrs[key] = value
    else
      attrs[key] = Attribute key, merge value, substitute: resolveTrait
  instances[id]=
    id:->id
    toString: ->opts.alias ? "Trait #{id}"
    dependencies: -> opts.deps ? []
    attributes: -> attrs
    apply: (factory)->
      for name, attr of attrs
        attr.apply factory

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

createSequence = (traits)->
  toposort = require "toposort"
  done = {}
  # adds implicit dependencies to ensure traits order
  augment = (t,i,arr)->
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


seqCache = {}
module.exports.sequence = (traits)->
  key = traits.map (t)->t.id()
  seqCache[key] ?= createSequence traits