instances = []
module.exports=(opts={})->
  Attribute = require "./attribute"
  attrSpecs = opts.attributes ? {}
  attrs = {}
  for key,value of attrSpecs
    attrs[key] = if value instanceof Attribute then value else Attribute key, value
  id=instances.length
  instances[id]=
    id:->id
    toString: ->opts.alias ? "Trait #{id}"
    dependencies: -> opts.deps ? []
    attributes: -> attrs
    apply: (factory)->
      for name, attr of attrs
        attr.apply factory

module.exports.sequence = (traits)->
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
  
  sortedTraits = toposort(edges).reverse()
  traits:sortedTraits
  unsafeOverrides: ->
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

