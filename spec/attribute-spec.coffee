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
    it "can construct its (document) type when given a set of traitRefs", ->
      a = Attribute "foo", traitRefs:["bang","baz"]
      expect(a.type().describe()).to.eql ["ref",'bang,baz']

    it "can construct arbitrarily convoluted types", ->
      a= Attribute "foo", traitRefs:["bang","baz"], type: (doc)->dictT listT doc
      expect(a.type().describe()).to.eql ["dict","list","ref","bang,baz"]

    xit "will complain, if the type resulting from the traits is not consistent with the specified type", ->
      a= Attribute "foo", traitRefs:["bang"], type: ()->listT documentT

