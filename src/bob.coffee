Factory = require('rosie').Factory
module.exports = (configure) ->
  isArray = require("util").isArray
  bind = (obj)->(name)->return obj[name].bind obj
  nestedInline = (containingFactory, attrName, definitions, body)->
    name = containingFactory.name+'$'+attrName
    name = "$"+name if not containingFactory.inline
    factory = definitions[name] = new Factory()
    factory.inline = true
    factory.name = name
    factory.traits = {}
    body.call factoryContext(factory)
    @attr attrName, [attrName], (overrides)->
      #TODO: what about overriding traits?
      build name, overrides
  nestedRef = (attrName, attrFactoryName, attrTraitNames..., dependencies, createOverrides )->
    @attr attrName, dependencies, (args...)->
      overrides = createOverrides args...
      #TODO: what about overriding traits?
      doc=build attrFactoryName, attrTraitNames..., overrides
      doc


  nested = (factory,definitions)->( name, factoryAndTraits..., dependencies, defaultValue)->
    switch
      when factoryAndTraits.length == 0 and not defaultValue? and (typeof dependencies is "function")
        nestedInline.call this, factory, name, definitions, dependencies
      when not isArray(dependencies) and (typeof defaultValue is "object")
        factorySpec =  [factoryAndTraits...,dependencies]
        body = (override)->override ? defaultValue
        nestedRef.call this, name, factorySpec..., [name], body
      when factoryAndTraits.length > 0 and isArray(dependencies) and (typeof defaultValue is "function")
        nestedRef.call this, name, factoryAndTraits..., dependencies, defaultValue
      else
        throw new InvalidUseOfDslError name, factory.name, [
          "@nested '#{name}', {function containing inline definitions}"
          "@nested '#{name}', {factory name}, [{trait name}...], [{object with overrides}]"
          "@nested '#{name}', {factory name}, [{trait name}...], {array of dependencies}, {function for creating overrides}"
        ]

  listRef = (factory, attrName, attrFactoryName, dependencies, createElementSpecs)->
    @attr attrName, dependencies, (args...)->
      elementOverrides = createElementSpecs args...
        .map (spec)->if isArray(spec) then spec else [spec]
        .map ([traitNames0..., overrides0],i)->
          switch
            when not overrides0? and traitNames0.length is 1 and typeof traitNames[0] is "object"
              traitNames=[]
              overrides=traitNames0[0]
            when typeof overrides0 is "string"
              traitNames=[traitNames0...,overrides0]
              overrides = {}
            when typeof overrides0 is "object"
              traitNames=traitNames0
              overrides = overrides0
            else
              throw new InvalidUseOfDslError attrName+"[#{i}]", factory.name, [
                "An element can be specified as an object of overrides"
                "An element can be specified as a single trait name"
                "An element can be specified as an array of trait names and an object of overrides as optional last element."
                "An element can be specified as both, an empty object or an empty array"
              ]
          
          build attrFactoryName, traitNames..., overrides ? {}


  list = (factory)->( attrName, attrFactoryName, dependencies, elementSpecs)->
    if typeof attrName isnt "string" or typeof attrFactoryName isnt "string"
      throw new Error("Cannot use @list without attribute name and factory")
    switch
      when not elementSpecs? and isArray(dependencies)
        defaultElementSpecs = dependencies
        listRef.call this, factory, attrName, attrFactoryName, [attrName], (elementSpecOverrides)->
          elementSpecOverrides ? defaultElementSpecs
      when isArray(dependencies) and typeof elementSpecs is "function"
        listRef.call this, factory, attrName, attrFactoryName, dependencies, elementSpecs
      else
        throw new InvalidUseOfDslError attrName, factory.name, [
          "@list '#{attrName}', {factory name}, [{array of element specs}]"
          "@list '#{attrName}', {factory name}, {array of dependencies}, {function for creating element specs}"
        ]
  # creates a new world context
  #
  # The context will be the object refered to by `this`
  # within the callback passed into the Bob constructor.
  worldContext = (definitions)->
    factory: (name,body)->
      factory = definitions[name] = new Factory()
      factory.name = name
      factory.traits = {}
      body.call factoryContext(factory,definitions)

  # create a new factory context
  #
  # The created context will be the object refered to by `this`
  # within the callback passed to the `factory` directive (see above).
  factoryContext = (factory,definitions)->
    f = bind factory
    attr: f "attr"
    option: f "option"
    sequence: f "sequence"
    extend: f "extend"
    trait: (name, body)->
      factory.traits[name] = body
      body.call updateBaseContext(factory)
      factory
    nested: nested factory, definitions
    list: list factory, definitions
  
  # create a new trait context
  #
  # The created context will be the object refered to by `this`
  # within the callback passed to the `trait` directive (see above).
  #
  # Note that traits are not allowed to use `extend` or `trait`.
  traitContext = (factory)->
    f = bind factory
    attr: f "attr"
    option: f "option"
    sequence: f "sequence"


  # used in trait definitions to add missing attributes to the
  # base factory.
  updateBaseContext = (factory)->
    attr: (name)->
      factory.attr name, null if not factory._attrs[name]?
    option: (name)->
      factory.option name, null if not factory.options[name]?
    sequence: (name)->
      factory.attr name, null if not factory._attrs[name]?


  factories = {}

  configure.call worldContext factories

  variantName = (factoryName, traitNames=[])->factoryName+"("+traitNames.join(',')+")"

  factoryForVariant = (factoryName, traitNames)->
    factories[variantName(factoryName,traitNames)] ?= createFactoryForVariant(factoryName,traitNames)

  createFactoryForVariant = (baseFactoryName, traitNames)->

    baseFactory = factories[baseFactoryName]
    if not baseFactory?
      throw new NoFactoryByThatNameError(baseFactoryName)
    for traitName in traitNames
      if not baseFactory.traits[traitName]?
        throw new NoTraitByThatNameError(baseFactoryName,traitName)

    factory = new Factory().extend baseFactory
    factory.name = variantName baseFactoryName, traitNames
    traitNames
      .map (traitName)->baseFactory.traits[traitName]
      .forEach (trait)->trait.call traitContext(factory)

    factory

  build = (factoryName, traitNames..., opts={}) ->
    if typeof opts is "string"
      traitNames = [traitNames...,opts]
      opts = {}


    factory = factoryForVariant factoryName, traitNames

    # we allow users to specify options and attribues
    # in a single object. We have to separate them
    # so Rosie can process them.

    attributes={}
    options={}
    for name,value of opts
      if factory._attrs[name]?
        attributes[name]=value
      else if factory.opts[name]?
        options[name]=value
      else
        throw new BadAttributeError name, factory.name

    factory.build attributes, options

  build: build

module.exports.BadAttributeError = class BadAttributeError extends Error
  constructor: (attrName, factoryName)->
    @message= "You tried to introduce an unknown attribute '#{attrName}' when using factory '#{factoryName}'"
    @name = "BadAttributeError"

module.exports.NoFactoryByThatNameError = class NoFactoryByThatNameError extends Error
  constructor: (defName)->
    @name="NoFactoryByThatNameError"
    @message="No factory was defined with the name '#{defName}'."

module.exports.NoTraitByThatNameError = class NoTraitByThatNameError extends Error
  constructor: (defName)->
    @name="NoTraitByThatNameError"
    @message="No trait was defined with the name '#{defName}'."

module.exports.InvalidUseOfDslError = class InvalidUseOfDslError extends Error
  constructor: (attrName, factoryName, validAlternatives)->
    @name = "InvalidUseOfDslError"
    @message = """
    Invalid use of DSL when defining '#{factoryName}.#{attrName}'. 
    The following call signatures are supported:

    #{validAlternatives.join '\n'}
    """
