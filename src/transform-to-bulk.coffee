merge = require "./merge"
Transform = require("stream").Transform
module.exports = class TransformToBulk extends Transform
  constructor:(opts={})->
    @opts=opts
    overrides = opts.overrides ? {}
    defaults = opts.defaults ? {}

    mk_prop = (name, desc)->
      if desc[name] then (data)->desc[name]
      else if desc[name+"_attr"] then (data)->data[desc[name+"_attr"]]

    behaviour = (desc)->
      _id: mk_prop "id", desc
      _index: mk_prop "index", desc
      _type: mk_prop "type", desc
    
    defaultBehaviour = behaviour defaults
    overrideBehaviour = behaviour overrides
    mergeBehaviours = (behaviours...)->
      merged = merge behaviours...
      (data)->
        metadata = {}
        metadata[key] = f? data for key,f of merged
        index:metadata

    super
      objectMode:true
      transform: ({_data, _type},encoding,done)->
        meta = mergeBehaviours defaultBehaviour, behaviour( _type.meta().es ? {} ), overrideBehaviour
        @push meta _data
        @push _data
        done()

