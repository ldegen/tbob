module.exports = (customProps={})->
  merge = require "./merge"
  base =
    path:[]
    parent:null
    key:null
    _mkChild: (key)->
      merge this,
        path:[@path..., key]
        parent: this
        key: key
  merge base, customProps
