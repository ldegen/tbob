module.exports = (body)->
  SigMatch = require "./signature-matcher"
  Trait = require "./trait"
  {optionalT, opaqueT, refT, listT, dictT, scalarT, nilT} = require "./type"
  namedTraits = {}
  lookupTrait = (name)-> namedTraits[name]

  variant = (factoryName, traitNames...)->
    absoluteTraitNames = traitNames.map (tn)->factoryName+"/"+tn
    [factoryName, absoluteTraitNames...]

  refDirective = (factoryName, traitNames...)->
    traits: -> variant factoryName, traitNames...
    type:(leaf)->leaf

  skalarTypeDirective = (kind)->
    traits:-> null
    type: ->scalarT kind
  nestedTypeDirective = (wrappingType)->(nested)->
    traits: nested.traits
    type: (leaf)->wrappingType nested.type leaf
  nilDirective = 
    traits: -> null
    type: -> nilT()
  opaqueDirective = 
    traits: -> null
    type: -> opaqueT()

  attrDirective = (store)-> SigMatch (match)->
    match "s,o,a,f", (attrName, typeExpr, dependencies, fillStrategy)->
      #console.log "attrDirective_1", attrName, typeExpr, dependencies, fillStrategy
      store[attrName]=
        deps:dependencies
        fill:fillStrategy
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,o,.?", (attrName, typeExpr, fillSpec) ->
      #console.log "attrDirective_2", attrName, typeExpr, fillSpec
      store[attrName]=
        deps: []
        fill: -> fillSpec
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,a,f", (attrName, dependencies, fillStrategy)->
      #console.log "attrDirective_3", attrName, dependencies, fillStrategy
      store[attrName]=
        deps: dependencies
        fill: fillStrategy
    match "s,.", (attrName, defaultValue)->
      #console.log "attrDirective_4", attrName, defaultValue
      store[attrName]=
        deps:[]
        fill: -> defaultValue

  traitDirective = (traitStore,inlineStore)->(traitName, body)->
    traitOpts = 
      alias:traitName
      #parent link is inkjekted when parent is build
      deps:[] # deps dito
    body.call traitCx this, traitOpts, inlineStore
    traitStore[traitName] = traitOpts


  factoryDirective = (factoryStore)->(factoryName, body)->
    factoryOpts = 
      alias:factoryName
      parent: resolveTrait: lookupTrait
    traitStore = {} # @trait-directive puts its options here
    inlineStore = {} # inline trait defs put their options here
    body.call factoryCx this, factoryOpts, traitStore, inlineStore

    # make sure all trait attributes exist in factory
    for traitName, traitOpts of traitStore
      for attrName, attrOpts of traitOpts.attributes
        # the most general type is "optional opaque". It contains any value, including nil.
        # TODO: it would be more intuitive if we could actually compute a least upper bound
        # from all concrete types used in the traits. One way to do this would be to introduce
        # union types.
        factoryOpts.attributes[attrName] ?= type:optionalT opaqueT()

    factory = factoryStore[factoryName]=Trait factoryOpts
    for attrName, inlineOpts of inlineStore
      inlineOpts.parent = factory
    for traitName, traitOpts of traitStore
      traitOpts.parent = factory
      traitOpts.deps.push factory
      factoryStore[factoryName+"/"+traitName] = Trait traitOpts

  typeExpressionDirectives = ->
    ref: refDirective
    list: nestedTypeDirective listT
    dict: nestedTypeDirective dictT
    optional: nestedTypeDirective optionalT
    number: skalarTypeDirective "number"
    string: skalarTypeDirective "string"
    boolean: skalarTypeDirective "boolean"
    nil: nilDirective
    opaque: opaqueDirective

  factoryCx = (parent, opts,traitStore, inlineStore)->
    opts.attributes ?= {}
    cx = typeExpressionDirectives(inlineStore)
    cx._prefix=parent._prefix+"/"+opts.alias
    cx.attr= attrDirective opts.attributes
    cx.trait= traitDirective  traitStore
    cx
  traitCx = (parent, opts, inlineStore) ->
    opts.attributes ?= {}
    cx = typeExpressionDirectives(inlineStore)
    cx._prefix=parent._prefix+"/"+opts.alias
    cx.attr= attrDirective opts.attributes
    cx
  worldCx = (store)->
    _prefix:""
    factory: factoryDirective store

  body.call worldCx namedTraits
  trait: lookupTrait
  build: SigMatch (match)->
    match "s,s*,o?", (factoryName, traitNames, fillSpec={})->
      absoluteTraitNames = variant factoryName, traitNames...
      traits = absoluteTraitNames
        .map lookupTrait
      Trait.sequence traits
        .factory()
        .build fillSpec
