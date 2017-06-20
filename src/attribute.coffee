module.exports = (name, desc={})->
  merge = require "./merge"
  BuildContext = require "./build-context"
  ErrorWithContext = require "./error-with-context"
  Type = require "./type"
  Trait = require "./trait"
  plainSemantics =(factory,name,deps,fill)->
    factory.attr name, deps, fill
  optionSemantics =(factory,name,deps,fill)->
    factory.option name, deps, fill
  sequenceSemantics = (factory, name,deps,fill)->
    throw new Error "sequences are not working correctly yet!"
    # need to flip first two args, because apply
    # code expects first arg to be self ref
    factory.sequence name, deps, (pos,args...) ->
      fill args[0],pos, args[1...]...

  semantics = switch desc.apply ? "plain"
    when "plain" then plainSemantics
    when "option" then optionSemantics
    when "sequence" then sequenceSemantics
    else desc.apply
  if typeof semantics isnt "function"
    throw  new Error "The Value of the `apply`-option must be 'plain',
                      'option', 'sequence' or a function"
  deps = desc.deps ? []
  #as a special exception, default doc specs to {} rathern than null.
  fill = desc.fill ? -> if sequence()? then {} else null
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
    build = (fillSpec, buildCx)->
      seq = sequence()
      if seq?
        seq.factory().build(fillSpec, buildCx)
      else
        fillSpec
    # wrap fill strategy: to be on the safe side we add a dependency
    # to the attribute itself. By convention, rosie will pass overrides
    # given for the attribute itself in the corresponding argument.
    # We use this to control how explicit overrides interact with the
    # fill strategy defined for the attribute
    semantics factory, name, [name,deps...], (override,attrs...)->
      # if an override for this attribute was given, and if the fill
      # strategy does *not* explicitly handle this, we
      # ignore the fill strategy completely and give preference to
      # the override


      attrIsDerived = desc?.meta?.derived
      containingTypeIsDerived = @type.meta()?.derived

      fillSpec =
        if override? and not (name in deps)
          override
        else if attrIsDerived or containingTypeIsDerived or not @onlyFillDerivedAttributes
          fill.call this, attrs...
      try
        childCx =  BuildContext(this)._mkChild name
        val = type().constructValue build, fillSpec, childCx
      catch e
        throw new ErrorWithContext e,
          attribute: name
          context: desc.context
          message: "Cannot construct value for attribute '#{name}'"
      val


  deps: ->deps
  meta: ->desc.meta ? {}
  type: type
  traits: ()->
  sequence: sequence

