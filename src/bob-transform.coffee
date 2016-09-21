module.exports = (worldDefinition, Bob = require "./bob")->
  Transform = require("stream").Transform
  tf = new Transform
    objectMode:true
    transform: (scenarioSpec,_,done)->
      scenario =  {}
      bob = Bob worldDefinition

      for alias, args of scenarioSpec
        scenario[alias] = bob.build args...
      
      @push scenario
      done()

    flush: (done)->done()
