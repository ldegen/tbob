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
  fillDeps = desc.fillDeps ? desc.deps ? []

  #as a special exception, default doc specs to {} rathern than null.
  fill = desc.fill ? -> if sequence()? then {} else null

  # if no derive strategy is specified, we use identity.
  # For this to work, the default derive strategy depends on the attribute itself.
  deriveDeps = desc.deriveDeps ? if desc.derive? then [] else [ name ]
  derive = desc.derive ? (v)->(v) 

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
    #
    # Also note that our dependencies *will* typically contain duplicates.
    # In particular, we list the deps of the fill and derive strategies separately.
    # This should not be a problem.
    semantics factory, name, [name, fillDeps..., deriveDeps...], (override,attrs...)->

      attrIsDerived = desc?.meta?.derived
      containingTypeIsDerived = @type?.meta()?.derived

      fillAttrs = attrs.slice 0, fillDeps.length
      deriveAttrs0 = attrs.slice fillDeps.length
      fillResult =
        # If an explicit value (a.k.a. override) is given, use it...
        # ... UNLESS there is a fill strategy that lists the attribute itself as dependency.
        # In the latter case, we assume the fill strategy explicitly wishes to transform even explicit values.
        if override? and not (name in fillDeps) or @disableFillStrategies
          # if an override for this attribute was given, and if the fill
          # strategy does *not* explicitly handle this, we
          # ignore the fill strategy completely and give preference to
          # the override
          override
        # otherwise fill strategies are enabled and there either is no explicit value (override), or the fill strategy
        # asks to handle it. So... call the fill strategy.
        # However, we try to respect the (now deprecated) `onlyFillDereivedAttributes` option as good as possible.
        else if (attrIsDerived or containingTypeIsDerived or not @onlyFillDerivedAttributes)
          try
            fill.call this, fillAttrs...
          catch e
            throw new ErrorWithContext e,
              attribute: name
              context: desc.context
              message: "Fill-Strategy for attribute #{name} raised an exception."

      # If the derive strategy depends on the attribute itself, it should consider the
      # result of the fill strategy as input for the attribute. We first do a rough precondition check:
      # If there is input for the current attribute, then the derive strategy *must* list it 
      # as a dependency. Otherwise raise an error so the user knows that something weird is going on.

      
      if fillResult? and desc.derive? and not (name in deriveDeps)
        throw new ErrorWithContext new Error("You cannot provide input for a derived attribute unless you explicitly specify the attribute itself as dependency."),
          attribute: name
          context: desc.context
          message: "Conflicting values for attribute '#{name}'"
      
      # replace our own value in the attributes passed to the derive strategy with the fill result.
      deriveAttrs = deriveAttrs0.map (val, i)-> if name is deriveDeps[i] then fillResult else val
      try
        deriveResult = derive.call this, deriveAttrs...
      catch e
        throw new ErrorWithContext e,
          attribute: name
          context: desc.context
          message: "Derive-Strategy for attribute #{name} raised an exception."
      

      try
        childCx =  BuildContext(this)._mkChild name
        val = type().constructValue build, deriveResult, childCx
      catch e
        throw new ErrorWithContext e,
          attribute: name
          context: desc.context
          message: "Cannot construct value for attribute '#{name}'"
      val


  deps: ->[fillDeps..., deriveDeps...]
  meta: ->desc.meta ? {}
  type: type
  traits: ()->
  sequence: sequence

