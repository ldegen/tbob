
module.exports = merge = (objs...)->
  q={}
  q[key]=value for key,value of o when typeof value isnt "undefined" for o in objs
  q

