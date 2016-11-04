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
    absoluteTraitNames = traitNames.map (tn)->"$world$/"+factoryName+"/"+tn
    ["$world$/"+factoryName, absoluteTraitNames...]


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
    cx.root = cx
    cx.root = cx.root.parent while cx.root.parent?

    # apply context to directives exposed in the facade.
    # Note that type expressions are always included.
    cx.facade[key] = directive cx, key for key, directive of merge typeExpressions, facade
    parent.children[name] = cx if parent?
    cx


  inlineType = (cx, body, wrapper)->
    traits: (attrName)->
      nestedCx = mk_cx "$"+attrName+"$", cx,
        attr: attrDirective
        extend: extendDirective
      
      body.call nestedCx.facade

      opts=
        deps:(nestedCx.store "extend", "list") ? []
        alias: nestedCx.name
        resolveGlobal:lookupTrait
        attributes: nestedCx.store "attr"
        parent: cx.path.join "/"
        context: nestedCx.path.join "/"

      trait = Trait opts
      cx.store "inline", attrName, trait
      # Inline traits, although anonymous, must be referrable via global symbol lookup.
      # This is a technical necessity with the current implementation as it allows us
      # to symbolic backreferences to "parent" traits which can be lazily resolved on demand.
      # 
      # The parent links are important to allow for local aliasing and quasi-lexical 
      # scope chains. (think: recursive data structures!)
      cx.root.store "factory", (nestedCx.path.join "/"), trait
      [trait]
    type: (leaf)->if wrapper? then wrapper leaf else leaf


  refTypeExpr = (cx)->(factoryName, traitNames...)->
    traits: -> variant factoryName, traitNames...
    type:(leaf)->leaf
  skalarTypeExpr = (kind)->(cx)->
    traits:-> null
    type: ->scalarT kind
  nestedTypeExpr = (wrappingType)->(cx)->(nested)->
    if typeof nested is "function"
      inlineType cx, nested, wrappingType
    else
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
    match "s,f,a,f", (attrName, body, dependencies, fillStrategy)->
      typeExpr = inlineType cx, body
      cx.store "attr", attrName,
        deps:dependencies
        fill:fillStrategy
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,o,a,f", (attrName, typeExpr, dependencies, fillStrategy)->
      cx.store "attr", attrName,
        deps:dependencies
        fill:fillStrategy
        type: typeExpr.type
        traits: typeExpr.traits attrName
    match "s,f,.?", (attrName, body, fillSpec) ->
      typeExpr = inlineType cx, body
      cx.store "attr", attrName,
        deps: []
        fill: -> fillSpec
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
    match "s", (attrName)->
      attrBuilder cx, attrName
    match ".*", (args...)-> throw new Error("wrong signature for @attr: #{args}")

  attrBuilder = (cx,name)->
    opts = {}
    cx.store "attr", name, opts
    meta: (metadata)->
      opts.meta=metadata
      this
    type: SigMatch (match)->
      match "o", (typeExpr)->
        opts.type= typeExpr.type
        opts.traits= typeExpr.traits name
        this
      match "f", (body)->
        typeExpr = inlineType cx, body
        opts.type= typeExpr.type
        opts.traits= typeExpr.traits name
        this
      match ".*", (args...)-> throw new Error("wrong signature for @attr.this")
    fill: SigMatch (match)->
      match "a,f", (dependencies, fillStrategy)->
        opts.deps = dependencies
        opts.fill = fillStrategy
        this
      match ".", (fillSpec)->
        opts.deps=[]
        opts.fill= -> fillSpec
        this
      match ".*", (args...)-> throw new Error("wrong signature for @attr.fill")

  extendDirective = (cx)->(baseName, traitNames...)->
    deps = (cx.store "extend", "list") ? []
    deps.push (variant baseName, traitNames...)...
    cx.store "extend", "list", deps
    
  metaDirective = (cx)->(metadata)->
    cx.store "meta", name, value for name,value of metadata

  traitDirective = (factoryCx)->(traitName, body)->
    traitCx = mk_cx traitName, factoryCx,
      attr: attrDirective

    body.call traitCx.facade

    opts=
      alias: traitName
      resolveGlobal:lookupTrait
      attributes: traitCx.store "attr"
      meta: traitCx.store "meta"
      deps: [factoryCx.path.join "/"]
      parent: factoryCx.path.join "/"
      context: traitCx.path.join "/"

    trait = Trait opts
    factoryCx.store "trait", traitName, trait
    # factory-specific traits are made available as toplevel factories
    factoryCx.root.store "factory", (traitCx.path.join "/"), trait

  factoryDirective = (worldCx) -> (factoryName, body)->
    factoryCx = mk_cx factoryName, worldCx,
      attr: attrDirective
      trait: traitDirective
      extend: extendDirective
      meta: metaDirective

    body.call factoryCx.facade
    attributes = factoryCx.store "attr"
    traits = factoryCx.store "trait"
    for traitName, trait of traits

      # make sure attributes introduced in factorory-specific triats are
      # included in the owning factory.
      for attrName, _ of trait.attributes()
        # the most general type is "optional opaque". It contains any value, including nil.
        # TODO: it would be more intuitive if we could actually compute a least upper bound
        # from all concrete types used in the traits. One way to do this would be to introduce
        # union types.
        attributes[attrName] ?= type:optionalT opaqueT()

    opts=
      deps:(factoryCx.store "extend", "list") ? []
      resolveGlobal:lookupTrait
      attributes: attributes
      alias: factoryName
      meta: factoryCx.store "meta"
      context: factoryCx.path.join "/"
    worldCx.store "factory", (factoryCx.path.join "/"), Trait opts


  worldCx = mk_cx "$world$",null, factory: factoryDirective
  body.call worldCx.facade
  namedTraits = {}
  for globalName, trait of worldCx.store "factory"
    namedTraits[globalName] = trait
    

  #console.error "namedTraits", Object.keys namedTraits
  sequence: (factoryName, traitNames...)->
    absoluteTraitNames = variant factoryName, traitNames...
    traits = absoluteTraitNames
      .map (name)->
        trait = lookupTrait name
        if not trait?
          throw new Error "failed to resolve trait #{name}"
        trait
    Trait.sequence traits
  trait: (name)->lookupTrait "$world$/"+name
