# coffeelint: disable=max_line_length
describe "An Attribute", ->
  Factory = require "../src/factory"
  Attribute = require "../src/attribute"
  {documentT,dictT,listT,scalarT,opaqueT, optionalT} = require "../src/type"

  f=a=undefined

  beforeEach ->
    f=new Factory()

  it "can be added to a factory", ->
    a = Attribute "foo"
    a.apply f
    expect(f.build(foo:42)).to.eql foo:42

  it "knows how the attribute value should be filled on a new document", ->
    a = Attribute "foo", fill: ->42
    a.apply f
    expect(f.build()).to.eql foo:42

  it "can depend on other attributes of the same factory", ->
    f.attr "other", [], -> 21
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

  describe "when applied in a buildCx with `onlyFillDerivedAttributes: true`", ->
    
    it "will only use its fill strategy if it was annotated as `derived`", ->
      attributes = [
        Attribute "foo",
          fill: -> 42
          type: optionalT opaqueT
        Attribute "bar",
          fill: -> 23
        Attribute "baz",
          fill: -> 4711
          meta: derived: true
      ]

      attr.apply f for attr in attributes

      expect(f.build {bar:12}, onlyFillDerivedAttributes:true).to.eql
        bar: 12
        foo: null
        baz: 4711

  describe "with non-trivial value type", ->
    Trait = require "../src/trait"

    t0=t1=t2=undefined
    beforeEach ->
      t0 = Trait
        attributes: barf:
          type: opaqueT()
          fill: -> "Surprise!"
      t1 = Trait
        deps:[t0],
        attributes: bang:
          type: opaqueT()
          fill: -> "small"
      t2 = Trait
        attributes: boom: type: opaqueT()

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


    it "populates nested documents using an apropriate factory", ->
      a = Attribute "foo", traits:[t0,t1]
      a.apply f
      expect(f.build()).to.eql
        foo:
          barf:"Surprise!"
          bang:"small"

    it "uses the configured fill strategy to create a fill spec by default", ->
      a = Attribute "foo",
        traits:[t0,t1]
        fill: (torf)->
          barf: "doppel-#{torf}"
        deps: ["torf"]
      a.apply f
      f.option "torf", [], -> "gedöhns"
      expect(f.build()).to.eql
        foo:
          barf: "doppel-gedöhns"
          bang:"small"


    it "accepts overrides specs", ->
      a = Attribute "foo",
        traits:[t0,t1]
        fill: (torf)->
          barf: "doppel-#{torf}"
        deps: ["torf"]
      a.apply f
      f.option "torf", [], -> "gedöhns"
      expect(f.build(
        foo: bang: "big"
      )).to.eql
        foo:
          barf: "Surprise!"
          bang:"big"

    it "calls fill strategy even though an override is present, if attribute name is included in deps", ->
      a = Attribute "foo",
        traits:[t0,t1]
        fill: (torf,foo)->
          barf: "#{foo?.bang}-#{torf}"
          bang: foo?.bang
        deps: ["torf","foo"]
      a.apply f
      f.option "torf", [], -> "gedöhns"
      expect(f.build(
        foo: bang: "big"
      )).to.eql
        foo:
          barf: "big-gedöhns"
          bang:"big"

    it "correctly applies dict and list specs", ->
      a = Attribute "foo", traits:[t0,t1], type: (t)->dictT listT optionalT t
      a.apply f
      expect(f.build(
        foo:
          gna: [{},null]
          gnu: [bang:"big"]
      )).to.eql
        foo:
          gna:[
            barf:"Surprise!"
            bang:"small"
          ,
            null
          ]
          gnu:[
            barf: "Surprise!"
            bang: "big"
          ]
