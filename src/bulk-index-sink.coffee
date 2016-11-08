{Client} = require "elasticsearch"
{WritableBulk} = require "elasticsearch-streams"
Promise = require "bluebird"
module.exports = class BulkIndexSink extends WritableBulk
  constructor: (client, {index})->
    
    bulkExec = (bulkCmds, callback) ->
      client.bulk {
        index: index
        body: bulkCmds
      }, callback

    super  bulkExec
    # this is very useful for testing
    @promise = new Promise (resolve, reject) =>
      @on "close", resolve
      @on "error", reject
