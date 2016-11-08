{Transform} = require "stream"
esMapper = require "./es-mapper"
module.exports = class TransformToMapping extends Transform
  constructor: (opts={})->
    super
      objectMode:true
      transform: ({_type, _data},enc,done)->
        mapping = _type.metaTree esMapper
        extractType = ({type, type_attr}={})->
          if type_attr? then (_data[type_attr] ? type) else type

        mappingType = 
            (extractType opts.overrides )   ?
            (extractType _type.meta()?.es)  ?
            (extractType opts.defaults)     ?
            extractType type:'project', type_attr:'type'
        @push "#{mappingType}": mapping
        done()
