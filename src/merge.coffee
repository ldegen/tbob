
module.exports = merge = (objs...)->
  q={}
  q[key]=value for key,value of o for o in objs
  q
