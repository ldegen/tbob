module.exports = (name, desc={})->
  Type = require "./type"
  semantics = desc.apply ? (factory,name,deps,fill)->
    #console.log "factory", factory
    #console.log "name", name
    #console.log "deps", deps
    #console.log "fill", fill.toString()
    factory.attr name, deps, fill

  deps = desc.deps ? []
  fill = desc.fill ? -> null
  leafType = if desc.traitRefs? then Type.refT desc.traitRefs.toString() else Type.opaqueT()

  apply: (factory)->
    semantics factory, name, deps, fill
  type: ()->
    if typeof desc.type is "function"
      desc.type(leafType)
    else
      desc.type ? leafType

