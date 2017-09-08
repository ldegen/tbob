module.exports = (worldDefinition, opts={})->
  dsl =  require "./dsl"
  facade = require "./tbob-facade"
  createWorld = opts.world ? (world, worldOptions)-> facade (dsl world), worldOptions
  mode = opts.mode ? "document"
  preprocess = opts.preprocess ? (chunk)->chunk
  Transform = require("stream").Transform
  _worldInstance = undefined
  get_world = (forceNew=false)->
    if forceNew
      createWorld worldDefinition, opts.options
    else
      _worldInstance ?= createWorld worldDefinition, opts.options

  tf = new Transform
    objectMode:true
    transform: (spec0,_,done)->
      spec = preprocess spec0
      if spec?
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
