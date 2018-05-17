put = require "./deep-put"
merge = require "./merge"
simpleTypes = [
  "string"
  "long"
  "integer"
  "short"
  "byte"
  "double"
  "float"
  "date"
  "boolean"
]
module.exports = (self, attrs, subtrees)->
  tree = {}
  defaults = (attrName)=>
    type = @attrs[attrName]
    type = type.nestedType while type.nestedType?
    defs = 
      index:"not_analyzed"
      store:false
    if type.structure() is "scalar"
      kind = type.describe()[1]
      defs.type = switch kind
        when "number" then "integer"
        when "any", "string" then "string"
        else kind
    defs
        
          
  for name,subtree of subtrees()
    put tree, 'properties', name, subtree if Object.keys(subtree).length >0
  for name, meta of attrs when meta.es?.mapping
    t = meta.es.mapping.type
    if not t or t in simpleTypes
      put tree, 'properties', name, (merge (defaults name), meta.es.mapping)
    else
      put tree, 'properties', name, meta.es.mapping
  
  merge tree, self?.es?.mapping
