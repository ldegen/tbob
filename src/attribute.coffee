module.exports = (name, desc={})->
  Type = require "./type"
  Trait = require "./trait"
  semantics = desc.apply ? (factory,name,deps,fill)->
    #console.log "factory", factory
    #console.log "name", name
    #console.log "deps", deps
    #console.log "fill", fill.toString()
    factory.attr name, deps, fill

  deps = desc.deps ? []
  fill = desc.fill ? -> null
  substitute= desc.substitute ? ->null
  sequence= ->
    traitsAndRefs = desc.traits ? []
    if traitsAndRefs.length > 0
      seed = traitsAndRefs.map (traitOrRef)->
        if typeof traitOrRef is "object" 
          traitOrRef 
        else
          trait = substitute traitOrRef
          throw new Error "unresolved trait ref: #{traitOrRef}" if not trait?
          trait
      Trait.sequence seed

  leafType = -> 
    seq = sequence()
    if seq? then seq.type() else Type.opaqueT()

  apply: (factory)->
    semantics factory, name, deps, fill
  deps: ->deps
  type: ()->
    if typeof desc.type is "function"
      desc.type(leafType())
    else
      desc.type ? leafType()

  traits: ()->
  sequence: sequence

