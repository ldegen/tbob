Factory = require('rosie').Factory
module.exports = (configure) ->

  bind = (obj)->(name)->return obj[name].bind obj

  # creates a new scenario context
  #
  # The context will be the object refered to by `this`
  # within the callback passed into the Bob constructor.
  scenarioContext = (definitions)->
    factory: (name,body)->
      factory = definitions[name] = new Factory()
      factory.name = name
      factory.traits = {}
      body.call factoryContext(factory)

  # create a new factory context
  #
  # The created context will be the object refered to by `this`
  # within the callback passed to the `factory` directive (see above).
  factoryContext = (factory)->
    f = bind factory
    attr: f "attr"
    option: f "option"
    sequence: f "sequence"
    extend: f "extend"
    trait: (name, body)->
      factory.traits[name] = body
      factory

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



  factories = {}

  configure.call scenarioContext factories
  isArray = require('util').isArray

  variantName = (factoryName, traitNames=[])->[factoryName,traitNames...].join ':'

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

  build: (factoryName, traitNames..., opts={}) ->
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

