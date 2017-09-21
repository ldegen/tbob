Promise = require "bluebird"
module.exports = mockEsClient = ->
  resolve = (callback, value={})->
    if callback?
      callback null, value, 200
    else
      Promise.resolve value
  calls = []
  calls:calls
  bulk: (data, callback)->
    calls.push ['bulk',data]
    resolve callback
  cluster:
    health: (data,callback)->
      calls.push ['clusterHealth', data]
      resolve callback
  indices:
    putMapping: (data,callback)->
      calls.push ['putMapping', data]
      resolve callback
    getSettings: (data, callback)->
      calls.push ['getSettings', data]
      resolve callback, importantOption:42
    putSettings: (data, callback)->
      calls.push ['putSettings', data]
      resolve callback
    create: (data, callback)->
      calls.push ['createIndex', data]
      resolve callback
    delete: (data, callback)->
      calls.push ['deleteIndex', data]
      resolve callback
    close: (data, callback)->
      calls.push ['closeIndex', data]
      resolve callback
    open: (data, callback)->
      calls.push ['openIndex', data]
      resolve callback
