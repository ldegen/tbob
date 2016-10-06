describe "An Attribute", ->
  {Factory} = require "rosie"
  Attribute = require "../src/attribute"
  {documentT,dictT,listT,scalarT,opaqueT} = require "../src/type"

  f=a=undefined

  beforeEach ->
    f=new Factory()

  it "can be added to a factory", ->
    a = Attribute "foo"
    a.apply f
    expect(f.build()).to.eql foo:null

  it "knows how the attribute value should be filled on a new document", ->
    a = Attribute "foo", fill: ->42
    a.apply f
    expect(f.build()).to.eql foo:42

  it "can depend on other attributes of the same factory", ->
    f.attr "other", 21
    a = Attribute "foo", deps:["other"], fill:(other)->2*other
    a.apply f
    expect(f.build()).to.eql foo:42, other:21

  it "will respect overrides", ->
    foo = Attribute "foo", fill: ->42
    foo.apply f
    expect(f.build foo:21).to.eql foo:21

  it "can be explicitly typed", ->
    t=dictT scalarT "number"
    a = Attribute "foo", type: t
    expect(a.type()).to.equal t

  describe "with non-trivial value type", ->
    Trait = require "../src/trait"

    t0=t1=t2=undefined
    beforeEach ->
      t0 = Trait attributes: barf: opaqueT()
      t1 = Trait deps:[t0], attributes: bang: opaqueT()
      t2 = Trait attributes: boom: opaqueT()

    it "attempts to resolve trait refs and construct a sequence", ->
      a = Attribute "foo", traits: ["a symbol", t2], substitute: ->t1
      expect(a.sequence().traits).to.eql [t0,t1,t2]

    it "can construct its (document) type when given a set of traitRefs", ->
      a = Attribute "foo", traits:[t0,t1]
      expect(a.type().describe()).to.eql [
        'document'
      ,
        barf: ['opaque']
        bang: ['opaque']
      ]

    it "can construct arbitrarily convoluted types", ->
      a= Attribute "foo", traits:[t0,t1], type: (doc)->dictT listT doc
      expect(a.type().describe()).to.eql [
        "dict"
        "list"
        "document"
        barf:['opaque']
        bang:['opaque']
      ]

    xit "will complain, if the type resulting from the traits is not consistent with the specified type", ->
      a= Attribute "foo", traits:["bang"], type: ()->listT documentT
