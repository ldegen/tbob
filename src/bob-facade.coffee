module.exports = ({trait, sequence})->
  
  SigMatch = require "./signature-matcher"

  buildCx = (factoryName,traitNames, fillSpec, world)->
    factoryName:factoryName
    traitNames:traitNames
    fillSpec:fillSpec
    world: world

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
    match "s,s*,a?", (names..., fillSpec=[])->doType.call this, names..., fillSpec
    match "s,s*,o?", (names..., fillSpec={})->doType.call this, names..., fillSpec
    match ".*", ->
      throw new Error "don't know what to do"
  build: SigMatch (match)->
    doBuild= (factoryName, traitNames, fillSpec)->
      sequence factoryName, traitNames...
        .factory()
        .build fillSpec, buildCx factoryName, traitNames, fillSpec, this
    match "s,s*,a?", (names..., fillSpec=[])->doBuild.call this, names..., fillSpec
    match "s,s*,o?", (names..., fillSpec={})->doBuild.call this, names..., fillSpec
    match ".*", ->
      throw new Error "don't know what to do"
