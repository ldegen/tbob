module.exports = (body)->
  SigMatch = require "./signature-matcher"
  Trait = require "./trait"
  {optionalT, opaqueT} = require "./type"
  namedTraits = {}
  lookupTrait = (name)-> namedTraits[name]

  attrDirective = (store)-> SigMatch (match)->
    match "s,a,f", (attrName, dependencies, fillStrategy)->
      store[attrName]=
        dependencies: dependencies
        fillStrategy: fillStrategy
    match "s,.", (attrName, defaultValue)->
      store[attrName]=
        dependencies:[]
        fillStrategy: -> defaultValue

  traitDirective = (traitStore)->(traitName, body)->
    traitOpts = 
      alias:traitName
      #parent link is inkjekted when parent is build
      deps:[] # deps dito
    body.call traitCx this, traitOpts
    traitStore[traitName] = traitOpts

  factoryDirective = (factoryStore)->(factoryName, body)->
    factoryOpts = 
      alias:factoryName
      parent: resolveTrait: lookupTrait
    traitStore = {}
    body.call factoryCx this, factoryOpts, traitStore

    # make sure all trait attributes exist in factory
    for traitName, traitOpts of traitStore
      for attrName, attrOpts of traitOpts.attributes
        # the most general type is "optional opaque". It contains any value, including nil.
        # TODO: it would be more intuitive if we could actually compute a least upper bound
        # from all concrete types used in the traits. One way to do this would be to introduce
        # union types.
        factoryOpts.attributes[attrName] ?= type:optionalT opaqueT()

    factory = factoryStore[factoryName]=Trait factoryOpts
    for traitName, traitOpts of traitStore
      traitOpts.parent = factory
      traitOpts.deps.push factory
      factoryStore[factoryName+"/"+traitName] = Trait traitOpts

  factoryCx = (parent, opts,traitStore)->
    opts.attributes ?= {}
    attr: attrDirective opts.attributes
    trait: traitDirective  traitStore
  traitCx = (parent, opts) ->
    opts.attributes ?= {}
    attr: attrDirective opts.attributes
  worldCx = (store)->
    factory: factoryDirective store

  body.call worldCx namedTraits
  trait: lookupTrait
