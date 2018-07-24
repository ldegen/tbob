module.exports = ({trait, sequence}, buildOptions)->
  SigMatch = require "./signature-matcher"
  esMapper = require "./es-mapper"
  merge = require "./merge"

  # see #13: issue an deprecation warning for onlyFillDerivedAttributes

  if buildOptions?.onlyFillDerivedAttributes
    console.error "WARNING: the use of the `-d` command line option (or equivalently the `onlyFillDerivedAttributes` API-Option) is deprecated. Please see https://github.com/ldegen/tbob/issues/13"

  buildCx = (factoryName,traitNames, fillSpec, world)->
    merge buildOptions,
      factoryName:factoryName
      traitNames:traitNames
      fillSpec:fillSpec
      world: world
      type: sequence(factoryName, traitNames...).type()

  trait: trait
  sequence: sequence
  docCount: (factoryName, traitNames...)->
    [...,last] = (sequence factoryName, traitNames...).traits
    last.docCount
  metaTree: (args...)->
    @type(args...).metaTree
  type: SigMatch (match)->
    doType= (factoryName, traitNames, fillSpec)->
      sequence factoryName, traitNames...
        .type()
    match "s,s*,a?", (factoryName, traitNames, fillSpec=[])->doType.call this, factoryName, traitNames, fillSpec
    match "s,s*,o?", (factoryName, traitNames, fillSpec={})->doType.call this, factoryName, traitNames, fillSpec
    match ".*", ->
      throw new Error "don't know what to do"
  esMapping: (args...)->
    @type args...
      .metaTree esMapper
  build: SigMatch (match)->
    doBuild= (factoryName, traitNames, fillSpec)->
      sequence factoryName, traitNames...
        .factory()
        .build fillSpec, buildCx factoryName, traitNames, fillSpec, this
    match "s,s*,a?", (factoryName, traitNames, fillSpec=[])->doBuild.call this, factoryName, traitNames, fillSpec
    match "s,s*,o?", (factoryName, traitNames, fillSpec={})->doBuild.call this, factoryName, traitNames, fillSpec
    match ".*", ->
      throw new Error "don't know what to do"
