describe "The Signature Matcher", ->

  SigMatch = require "../src/signature-matcher"
  f=undefined
  describe "an empty string", ->
    beforeEach ->
      f=(args...)->args
    it "matches an empty argument list", ->
      match = SigMatch [["",f]]
      expect(match()).to.eql []

  describe "s+", ->
    beforeEach ->
      f=(args...)->args
    it "greedily matches a sequence of strings", ->
      match = SigMatch [["s+,s?", f]]
      expect(match "foo", "bar", "baz").to.eql [['foo','bar','baz'],null]
    it "matches a single string", ->
      match = SigMatch [["s+", f]]
      expect(match "foo").to.eql [['foo']]
    it "does not match an empty sequence", ->
      match = SigMatch [["s+,n", f]]
      expect(match 42).to.be.undefined

  describe "n", ->
    beforeEach ->
      f=(args...)->args
    it "matches a single number", ->
      match = SigMatch [["n",f]]
      expect(match 42).to.eql [42]
    it "does not match more than a single numnber", ->
      match = SigMatch [["n",f]]
      expect(match 42, 43).to.be.undefined

  describe "a?", ->
    beforeEach ->
      f=(args...)->args
    it "matches a single array", ->
      match = SigMatch [["a?,n",f]]
      expect(match [1,2],  3).to.eql [[1,2],3]
    it "matches an empty sequence", ->
      match = SigMatch [["a?,n",f]]
      expect(match  3).to.eql [null,3]
    it "greedily matches at most one array", ->
      match = SigMatch [["a?,a?,a?",f]]
      expect(match [1],[2]).to.eql [[1],[2],null]

  describe ".", ->
    it "matches a single attribute", ->
      match = SigMatch [[".",f]]
      expect(match 42).to.eql [42]
      expect(match 42, 32).to.be.undefined
    it "does not match undefined", ->
      match = SigMatch [["s,.",f]]
      expect(match "bla",42).to.eql ["bla",42]
      expect(match "bla").to.be.undefined
  describe ".*", ->
    it "matches anything", ->
      match = SigMatch [[".*",f]]
      expect(match [1],{a:2},"3",4).to.eql [[[1],{a:2},"3",4]]
  describe "o*", ->
    beforeEach ->
      f=(args...)->args
    it "greedily matches a sequence of objects", ->
      match = SigMatch [["o*,o?",f]]
      expect(match {a:1}, {b:2}, {c:3}).to.eql [[{a:1}, {b:2}, {c:3}],null]
    it "matches an empty sequence", ->
      match = SigMatch [["o*,n",f]]
      expect(match 42).to.eql [[], 42]
    it "does *not* match arrays", ->
      match = SigMatch [["o*",f]]
      expect(match [1,2,3]).to.be.undefined
    it "does *not* match functions", ->
      match = SigMatch [["o*",f]]
      expect(match (->)).to.be.undefined

  describe "with several rules", ->
    match = undefined
    beforeEach ->
      f = (x)->(args...)->
        variant:x
        args:args
      match = SigMatch (match)->
        match "s,s+,o?", f('a')
        match "s,s+,a,f", f('b')
        match "s,f", f('c')

    it "executes the action of the first matching rule", ->


      expect(match "foo", "Doc","empty" ).to.eql
        variant: 'a'
        args:[
          "foo"
          ["Doc","empty"]
          null
        ]

      expect(match "foo", "Doc", bar:42).to.eql
        variant: 'a'
        args:[
          "foo"
          ["Doc"]
          {bar:42}
        ]
      fun = ->
      expect(match "foo", "Doc", "trait1","trait2", ["dep1","dep2"], fun).to.eql
        variant: 'b'
        args:[
          "foo"
          ["Doc","trait1","trait2"]
          ["dep1", "dep2"]
          fun
        ]

      expect(match "foo", fun).to.eql
        variant: 'c'
        args: ["foo", fun]
