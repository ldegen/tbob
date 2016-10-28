{Factory}= require "rosie"
list2obj = require "./list2obj"
module.exports = class MyFactory extends Factory
  constructor: (attrs...)->
    delegatee = new Factory attrs...
    forward = (key,value, self)->
      self[key] = (bttrs...)->value.apply delegatee, bttrs
    for key,value of Factory.prototype
      if typeof value is "function" and key[0] isnt "_"
        forward key, value, this

    @build = (attrsAndOpts0)->
      attrsAndOpts = list2obj attrsAndOpts0
      attrs={}
      opts={}
      for name, value of attrsAndOpts
        if delegatee._attrs[name]?
          attrs[name] = value 
        else if delegatee.opts[name]?
          opts[name] = value 
        else
          throw new Error "you tried to invent a new attribute: #{name}"
      delegatee.build attrs, opts
