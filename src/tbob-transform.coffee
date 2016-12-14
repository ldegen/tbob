module.exports = (worldDefinition, opts={})->
  dsl =  require "./dsl"
  facade = require "./tbob-facade"
  createWorld = opts.world ? (world)-> facade dsl world
  mode = opts.mode ? "document"
  Transform = require("stream").Transform
  _worldInstance = undefined
  get_world = (forceNew=false)->
    if forceNew
      createWorld worldDefinition
    else
      _worldInstance ?= createWorld worldDefinition

  tf = new Transform
    objectMode:true
    transform: (spec,_,done)->
      switch mode
        when "duplex"
          world = get_world()
          @push 
            _type: world.type spec...
            _data: world.build spec...
        when "document"
          @push get_world().build spec... 
        when "type"
          @push get_world().type spec... 
        when "scenario"
          scenario =  {}
          world = get_world true
          for alias, args of spec
            scenario[alias] = world.build args...
          @push scenario
        else
          throw new Error "no such mode: #{mode}"
      done()

    flush: (done)->done()
