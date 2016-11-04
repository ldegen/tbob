
module.exports = merge = (objs...)->
  q={}
  q[key]=value for key,value of o when typeof value isnt "undefined" for o in objs
  q
{isArray} = require "util"
isObject = (o)->
  typeof o is "object" and not isArray o
merge.deep = (objs...)->
  q={}
  for o in objs
    for key, value of o when typeof value isnt "undefined"
      if isObject(q[key]) and isObject value 
        q[key] = merge.deep q[key], value
      else
        q[key] = value

  q

