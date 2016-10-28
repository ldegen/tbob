module.exports = (worldDefinition, dsl = require("./dsl"))->
  Transform = require("stream").Transform
  _worldInstance = undefined
  get_world = (forceNew=false)->
    if forceNew
      dsl worldDefinition
    else
      _worldInstance ?= dsl worldDefinition

  tf = new Transform
    objectMode:true
    transform: (spec,_,done)->
      if require("util").isArray spec
        # document mode
        @push get_world().build spec... 
      else
        # scenario mode
        scenario =  {}
        world = get_world true
        for alias, args of spec
          scenario[alias] = world.build args...
        
        @push scenario
      done()

    flush: (done)->done()
