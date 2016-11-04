merge = require "./merge"
module.exports = (root, path...,key, value)->
  throw Error("where shall I put the value?") if not key?
  obj = root
  obj = obj[attr] ?= {} for attr in path
  obj[key]=merge (obj[key] ? {}), value
