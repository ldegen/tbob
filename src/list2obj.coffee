isArray = require("util").isArray
module.exports = list2obj = (list)->
  return list if not isArray list
  obj = undefined
  if list.length == 0
    obj = {}
  else
    [key, val, rest...] = list
    obj = list2obj rest
    obj[key] = val
  obj

