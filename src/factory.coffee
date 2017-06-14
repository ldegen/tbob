toposort = require "toposort"
list2obj = require "./list2obj"
identity = (x)->x
module.exports = class MyFactory
  constructor: (cxTransform=identity)->
    attrOrder = null
    edges=[]
    attrs={}
    hooks=
      after:[]

    @after = (hook)->
      hooks.after.push hook
    @option = (name, deps, fill)->
      @attr name, deps, fill, true

    @attr = (name, deps=[name], fill=identity, hidden=false)->
      attrs[name] =
        name: name
        deps: deps
        fill: fill
        hidden:hidden
      edges.push [dep, name] for dep in deps when dep != name #ignore trivial cycle
      attrOrder = null
    @build = (fillSpec0={}, buildCx=null)->
      # since we *know* that we build a document (not a list, scalar, etc),
      # we conclude that the fillSpec should be a dict.
      # For convenience (think s-expressions!) we
      # support lists of alternating keys and values.
      fillSpec = list2obj fillSpec0
      for name, value of fillSpec when not attrs[name]?
        throw new Error "you tried to invent a new attribute: #{name}"
      keys = Object.keys attrs
      # determine order in which attribute values are to be filled.
      if not attrOrder?
        attrOrder = toposort.array keys, edges

      # create a build context
      cx = cxTransform buildCx

      instance = {}
      attributeValues = {}
      # fill all attribute values
      for attrName in attrOrder
        attr = attrs[attrName]
        fillArgs = (attr.deps ? []).map (depName)->
          if attrName == depName
            # mimic rosies behaviour for trivial cycles
            fillSpec[depName]
          else
            attributeValues[depName]

        attrValue= attr.fill.apply cx, fillArgs
        attributeValues[attrName] = attrValue
        instance[attrName] = attrValue unless attr.hidden

      hook.call cx, instance, attributeValues, fillSpec for hook in hooks.after
      instance
