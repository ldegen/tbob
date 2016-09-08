module.exports = (configure) ->
  Factory = require('rosie').Factory
  definitions = configure(Factory)
  factories = {}
  traits={}
  isArray = require('util').isArray

  addAttributeChecks = (name, factory) ->
    factory.after (obj) ->
      attr = undefined
      value = undefined
      attrs = factory._attrs
      for attr,value of obj
        if not attrs[attr]?
          throw new BadAttributeError(attr, name)
        if typeof value == 'undefined'
          delete obj[attr]
      obj

  postProcess = (name, item) ->
    #It's a Rosie factory
    if item instanceof Factory
      addAttributeChecks name, item
      factories[name] = item
    else if typeof item == 'function'
      traits[name] = item
    else
      #TODO: anything?
      throw new BadDefinitionError(name)


  postProcess name, definition for name,definition of definitions

  build: (factoryName, traitNames..., opts={}) ->
    if typeof opts is "string"
      traitNames = [traitNames...,opts]
      opts = {}

    if not factories[factoryName]?
      if traits[factoryName]?
        throw new NotAFactoryError(factoryName)
      else
        throw new NoFactoryByThatNameError(factoryName)

    for traitName in traitNames
      if not traits[traitName]?
        if factories[traitName]?
          throw new NotATraitError(traitName)
        else
          throw new NoTraitByThatNameError(traitName)

    factory = (options) ->
      factories[factoryName].build options

    builder = traitNames
      .map (name) ->
        traits[name]
      .reduce(
        (f, trait) ->
          (options) ->
            trait options, f
      ,
        factory
      )

    builder opts


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

module.exports.NotATraitError = class NotATraitError extends Error
  constructor: (defName)->
    @name="NotATraitError"
    @message="The name '#{defName}' does not refer to a trait, but to a factory."

module.exports.NotAFactoryError = class NotAFactoryError extends Error
  constructor: (defName)->
    @name="NotAFactoryError"
    @message="The name '#{defName}' does not refer to a factory, but to a trait."
