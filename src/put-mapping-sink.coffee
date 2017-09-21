{Writable} = require "stream"
{Client} = require "elasticsearch"
Promise = require "bluebird"
module.exports = class PutMappingSink extends Writable
  constructor: (client, opts={})->
    @opts = {index, reset,settings}=opts
    prepared = false
    super 
      objectMode:true
      write: (mappings, enc, done)->
        pass = (f)->(val)->Promise.resolve(f val).then -> val
        prepare = (
          if reset and not prepared
            client.indices.delete index:index, ignore: 404
              .then -> client.indices.create if settings? then {index, body:settings:settings} else {index}
          else if settings? and not prepared
            client.indices.close index:index
              .then -> client.indices.putSettings index:index, body:settings
              .then -> client.indices.open index:index
              .then -> client.cluster.health index:index, level:'indices', waitForStatus:'yellow'
          else 
            Promise.resolve()
        )
        Promise.resolve(prepare)
          .then -> Promise.all (
            for type, mapping of mappings
              client.indices.putMapping index:index, type:type, body:mapping
          )
          .then -> 
            done()

        prepared = true

    # this is very useful for testing
    @promise = new Promise (resolve, reject) =>
      @on "finish", resolve
      @on "error", reject

      
