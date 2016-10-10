module.exports = (worldDefinition, dsl = require("./dsl"))->
  Transform = require("stream").Transform
  tf = new Transform
    objectMode:true
    transform: (scenarioSpec,_,done)->
      scenario =  {}
      world = dsl worldDefinition

      for alias, args of scenarioSpec
        scenario[alias] = world.build args...
      
      @push scenario
      done()

    flush: (done)->done()
