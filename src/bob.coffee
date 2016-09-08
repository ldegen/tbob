module.exports = (configure) ->
  Factory = require('rosie').Factory
  factories = configure(Factory)
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
    else if typeof item == 'function'
      #TODO: anything?
    else
      #TODO: anything?


  postProcess name, factory for name,factory of factories

  build: (chainSpec, opts) ->
    chain = undefined
    factory = undefined
    traits = undefined
    if isArray(chainSpec)
      #it's an array of names
      chain = chainSpec
    else if typeof chainSpec == 'string'
      #it is a string containing a single name or a comma-separated list of names
      chain = chainSpec.split(/\s*,\s*/)

    factory = (options) ->
      factories[chain[0]].build options

    builder = chain
      .slice(1)
      .map (name) -> factories[name]
      .reduce(
        (f, trait) ->
          (options) ->
            trait options, f
      ,
        factory
      )

    builder opts

