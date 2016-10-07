module.exports = (name, desc={})->
  Type = require "./type"
  Trait = require "./trait"
  plainSemantics =(factory,name,deps,fill)->
    factory.attr name, deps, fill
  optionSemantics =(factory,name,deps,fill)->
    factory.option name, deps, fill
  sequenceSemantics = (factory, name,deps,fill)->
    # need to flip first two args, because apply code expects first arg to be self ref
    factory.sequence name, deps, (pos,args...) -> fill args[0],pos, args[1...]...

  semantics = switch desc.apply ? "plain"
    when "plain" then plainSemantics
    when "option" then optionSemantics
    when "sequence" then sequenceSemantics
    else desc.apply
  if typeof semantics isnt "function"
    throw  new Error "The Value of the `apply`-option must be 'plain', 'option', 'sequence' or a function"
  deps = desc.deps ? []
  fill = desc.fill ? -> if sequence()? then {} else null #as a special exception, default doc specs to {} rathern than null.
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
  type =->
    if typeof desc.type is "function"
      desc.type(leafType())
    else
      desc.type ? leafType()

  apply: (factory)->
    build = (fillSpec)->
      seq = sequence()
      if seq? then seq.factory().build(fillSpec) else fillSpec

    semantics factory, name, [name,deps...], (self,attrs...)->
      fillSpec = if self? and not (name in deps) then self else fill attrs...
      type().constructValue build, fillSpec

        
  deps: ->deps
  type: type
  traits: ()->
  sequence: sequence

