describe "Our customized Factory", ->
  Factory = require "../src/factory"
  f = undefined
  beforeEach ->
    f = new Factory()

  describe "at build time", ->
    it "expects options and attribute values interleaved in a single dict", ->
      f.attr "foo",["bar"], (bar)->2*bar
      f.option "bar"
      expect(f.build bar:2).to.eql foo:4

    it "can pass a build context object to fill strategies callbacks", ->
      f.attr "foo",[], ()->@bar
      expect(f.build {},{bar:4}).to.eql foo:4

  describe "during factory construction", ->
    it "can define a custom transformation for buildCx objects", ->
      f = new Factory (buildCx)->bar: buildCx.bang
      f.attr "foo",[], ()->@bar
      expect(f.build {},{bang:4}).to.eql foo:4
    
    it "can define a post-processing callback", ->
      trace = []
      f.after (args...)->
        trace.push
          cx:this
          args:args

      f.attr "foo"
      f.attr "bar", ["bar"], (bar)->bar+2
      doc = f.build {foo:1,bar:2}, {baz:3}
      expect(trace).to.eql [
        cx:
          baz:3
        args: [ #instance
          foo:1
          bar:4
        , # all attribute values
          foo:1
          bar:4
        , # fillSpec
          foo:1
          bar:2
        ]
      ]

