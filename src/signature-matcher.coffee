module.exports = (ruleSpecs0)->
  isArray = require("util").isArray
  matchingPrefixLength = (test, elms)->
    return i for elm,i in elms when not test(elm)
    elms.length

  splitAt = (i,arr)->[arr[...i], arr[i...]]

  typeTest = (type)->
    switch type
      when 's' then (x)->typeof x is "string"
      when 'n' then (x)->typeof x is "number"
      when 'b' then (x)->typeof x is "boolean"
      when 'o' then (x)->(typeof x is "object") and x? and not isArray(x)
      when 'f' then (x)->typeof x is "function"
      when 'a' then (x)->isArray x
      when '.' then (x)->typeof x isnt "undefined"
      else throw new Error "Don't know how to test for type '#{type}'"

  matcher = (type, multiplicity='')->
    test = typeTest type
    m = switch multiplicity
      when '' #exactly one
        ([arg,args...])-> [arg,args] if test arg
      when '?' # zero or one
        ([arg,args...])->
          if test arg
            [arg,args]
          else if arg?
            [null, [arg,args...]]
          else
            [null, args]
      when '+' # one or more
        (args)->
          len = matchingPrefixLength test, args
          splitAt len, args if len > 0
      when '*' # zero or more
        (args)->
          len = matchingPrefixLength test, args
          splitAt len, args
      else throw new Error "What do you mean - '#{type}','#{multiplicity}'?"
    m.label=type+multiplicity
    m

  matchersFromString = (s)->
    return [] if s.trim().length == 0
    matcher(type,multiplicity) for [type, multiplicity] in s.split ','

  rule = (matchers, action)->(args)->

    rest = args
    result = []
    for matcher in matchers
      match = matcher rest
      if not match?
        return false
      else
        [consumed, rest] = match
        result.push consumed
    if rest.length > 0
      return false
    -> action.apply this, result

  if typeof ruleSpecs0 is "function"
    ruleSpecs = []
    ruleSpecs0 (str,action)->ruleSpecs.push [str,action]
  else 
    ruleSpecs = ruleSpecs0
    
  rules=(rule(matchersFromString(s), action) for [s,action] in ruleSpecs)

  (args...)->
    for rule in rules
      action = rule args
      return action.apply this if action



