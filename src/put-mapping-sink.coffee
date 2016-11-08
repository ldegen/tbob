{Writable} = require "stream"
{Client} = require "elasticsearch"
Promise = require "bluebird"
module.exports = class PutMappingSink extends Writable
  constructor: (client, opts={})->
    @opts = {index, reset}=opts
    prepared = false
    super 
      objectMode:true
      write: (mappings, enc, done)->
        pass = (f)->(val)->Promise.resolve(f val).then -> val
        prepare = if reset and not prepared
          client.indices.getSettings index:index
            .then pass -> client.indices.delete index:index
            .then pass -> client.indices.create index:index
            .then (settings) -> client.indices.putSettings body:settings, index:index
        else Promise.resolve()
        prepare
          .then -> Promise.all (
            for type, mapping of mappings
              parameters =
                index: index
                type: type
                body: mapping
              prepare.then -> client.indices.putMapping parameters
          )
          .then -> done()
        prepared = true

    # this is very useful for testing
    @promise = new Promise (resolve, reject) =>
      @on "finish", resolve
      @on "error", reject

      
