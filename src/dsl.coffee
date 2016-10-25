module.exports = (body)->

  SigMatch = require "./signature-matcher"
  Trait = require "./trait"
  {optionalT, opaqueT, refT, listT, dictT, scalarT, nilT} = require "./type"
  namedTraits = undefined
  lookupTrait = (name)-> namedTraits[name]

  merge = (objs...)->
    q={}
    q[key]=value for key,value of o for o in objs
    q

  variant = (factoryName, traitNames...)->
    absoluteTraitNames = traitNames.map (tn)->factoryName+"/"+tn
    [factoryName, absoluteTraitNames...]


  mk_cx =(name, parent, facade)->
    store = {}
    cx=
      name: name
      path: [ (parent?.path ? [])..., name ]
      parent: parent
      facade: {}
      store:(type,name, value)->
        typeStore = store[type] ?= {}
        if value?
          typeStore[name]=value
        else if name?
          typeStore[name]
        else
          typeStore
      children:{}

    # apply context to directives exposed in the facade.
    # Note that type expressions are always included.
    cx.facade[key] = directive cx, key for key, directive of merge typeExpressions, facade
    parent.children[name] = cx if parent?
    cx



  refTypeExpr = (cx)->(factoryName, traitNames...)->
    traits: -> variant factoryName, traitNames...
    type:(leaf)->leaf
  skalarTypeExpr = (kind)->(cx)->
    traits:-> null
    type: ->scalarT kind
  nestedTypeExpr = (wrappingType)->(cx)->(nested)->
    traits: nested.traits
    type: (leaf)->wrappingType nested.type leaf
  nilTypeExpr = (cx)->
    traits: -> null
    type: -> nilT()
  opaqueTypeExpr = (cx)->
    traits: -> null
    type: -> opaqueT()

  typeExpressions =
    ref: refTypeExpr
    list: nestedTypeExpr listT
    dict: nestedTypeExpr dictT
    optional: nestedTypeExpr optionalT
    number: skalarTypeExpr "number"
    string: skalarTypeExpr "string"
    boolean: skalarTypeExpr "boolean"
    nil: nilTypeExpr
    opaque: opaqueTypeExpr

  attrDirective = (cx)-> SigMatch (match)->
    match "s,o,a,f", (attrName, typeExpr, dependencies, fillStrategy)->
      cx.store "attr", attrName,
        deps:dependencies
        fill:fillStrategy
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,o,.?", (attrName, typeExpr, fillSpec) ->
      cx.store "attr", attrName,
        deps: []
        fill: -> fillSpec
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,a,f", (attrName, dependencies, fillStrategy)->
      cx.store "attr", attrName,
        deps: dependencies
        fill: fillStrategy
    match "s,.", (attrName, defaultValue)->
      cx.store "attr", attrName,
        deps:[]
        fill: -> defaultValue

  traitDirective = (factoryCx)->(traitName, body)->
    traitCx = mk_cx traitName, factoryCx,
      attr: attrDirective

    body.call traitCx.facade

    opts=
      alias: traitName
      resolveGlobal:lookupTrait
      attributes: traitCx.store "attr"
      deps: [factoryCx.name]
      parent: factoryCx.name

    factoryCx.store "trait", traitName, Trait opts

  factoryDirective = (worldCx) -> (factoryName, body)->
    factoryCx = mk_cx factoryName, worldCx,
      attr: attrDirective
      trait: traitDirective

    body.call factoryCx.facade
    attributes = factoryCx.store "attr"
    traits = factoryCx.store "trait"
    for traitName, trait of traits
      # factory-specific traits are made available as toplevel factories
      worldCx.store "factory", factoryName+"/"+traitName, trait

      # make sure attributes introduced in factorory-specific triats are
      # included in the owning factory.
      for attrName, _ of trait.attributes()
        # the most general type is "optional opaque". It contains any value, including nil.
        # TODO: it would be more intuitive if we could actually compute a least upper bound
        # from all concrete types used in the traits. One way to do this would be to introduce
        # union types.
        attributes[attrName] ?= type:optionalT opaqueT()

    opts=
      resolveGlobal:lookupTrait
      attributes: attributes
      alias: factoryName
    worldCx.store "factory", factoryName, Trait opts


  worldCx = mk_cx "$world$",null, factory: factoryDirective
  body.call worldCx.facade
  namedTraits = {}
  for globalName, trait of worldCx.store "factory"
    namedTraits[globalName] = trait
    
  trait: lookupTrait
  build: SigMatch (match)->
    match "s,s*,o?", (factoryName, traitNames, fillSpec={})->
      absoluteTraitNames = variant factoryName, traitNames...
      traits = absoluteTraitNames
        .map lookupTrait
      Trait.sequence traits
        .factory()
        .build fillSpec
