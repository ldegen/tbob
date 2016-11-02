# 1 A trait is a set of attribute definitions.

Trait = require "../src/trait"
Attribute = require "../src/attribute"
{Factory} = require "rosie"

{optionalT, opaqueT, scalarT} = Type = require "../src/type"
describe "A Trait", ->


  f=undefined
  beforeEach ->
    f = new Factory()


  it "describes attributes that can be applied to factories", ->
    t=Trait attributes:
      bang:
        fill: ->42
      bum:
        fill: (bang)->2*bang
        deps:["bang"]
    t.apply f
    expect(f.build()).to.eql
      bang: 42
      bum: 84

  it "has an unique identifier", ->
    t = Trait()
    expect(t.id()).to.be.a "number"


describe "A application sequence", ->
  a=b=c=d=e=undefined

  beforeEach ->
    a = Trait deps: [], alias:'a'
    b = Trait deps: [a], alias: 'b'
    c = Trait deps: [a,b], alias: 'c'
    d = Trait deps: [a], alias: 'd'
    e = Trait deps: [], alias: 'e'

  it "contains the net dependencies of a sequence of traits in topological order", ->
    s=Trait.sequence [b,e,d,c]
    expect(s.traits).to.eql [a,b,e,d,c]


  it "is only valid if all dependency and ordering constraints can be fulfilled without closing a cycle", ->
    c_ = Trait deps: [b,a], alias: 'c_'
    mistake = ->Trait.sequence [b,e,d,c_]
    expect(mistake).to.throw

  it "can detect unsafe attribute overrides", ->
    a = Trait attributes:
      foo:type: scalarT "string"
      bar:type: opaqueT
    b = Trait attributes:
      foo:type: scalarT "number"
      bar:type: scalarT "number"
    s = Trait.sequence [a,b]
    expect(s.unsafeOverrides()).to.eql [
      ['foo',a,b]
    ]

  it "can detect attributes with unsatisfied dependencies", ->
    a = Trait attributes:
      foo:
        type: scalarT "string"
        deps: ['baz','bar']
    b = Trait attributes:
      bar:
        type: scalarT "number"
        deps: ['boing']
      baz:
        type: scalarT "number"
    s = Trait.sequence [a,b]
    expect(s.missingAttributes()).to.eql [
      ['boing','bar',b]
    ]
  xit "can detect attribute dependency cycles" #TODO

  it "can construct a document type if all attribute overrides are safe", ->
    a = Trait attributes:
      foo:
        type: scalarT "string"
        deps: ['baz','bar']
    b = Trait attributes:
      bar:
        type: scalarT "number"
        deps: ['baz']
      baz:
        type: scalarT "number"
    s = Trait.sequence [a,b]
    expect(s.type().describe()).to.eql [
      'document'
    ,
      baz: ['scalar', 'number']
      bar: ['scalar', 'number']
      foo: ['scalar', 'string']
    ]
  it "merges metadata from all involved traits", ->
    a = Trait 
      meta:
        fump:4
        fonk:42
      attributes:
        foo:
          type: scalarT "string"
        bar:
          type: scalarT "any"
          meta: 
            boing: 2
            bumm: 3
    b = Trait 
      meta:
        fump:2
        fnord:3
      attributes:
        bar:
          type: scalarT "number"
          meta: 
            bumm:4
            krach:5
        baz:
          type: scalarT "number"
    s = Trait.sequence [a,b]
    expect(s.type().describe()).to.eql [
      'document'
    ,
      baz: ['scalar', 'number']
      bar: ['scalar', 'number']
      foo: ['scalar', 'string']
    ,
      attributes:
        bar:
          boing:2
          bumm:4
          krach:5
      self:
        fump:2
        fonk:42
        fnord:3
    ]
describe "Recursive Structures", ->
  it "can be constructed using local aliasing", ->
    b = Trait
      attributes: foo: type: opaqueT()

    t = Trait
      alias: "con"
      attributes:
        head: type: opaqueT()
        tail:
          type: (w)->optionalT w
          traits: ["con", b]

    s = Trait
      alias: "con"
      attributes:
        head: type: scalarT()
        tail:
          type: (w)->optionalT w
          traits: ["con"]
        foo: type: opaqueT()

    tA = Trait
      .sequence [t]
      .type()

    tB = Trait
      .sequence [s]
      .type()

    #console.log "tA", JSON.stringify tA.describe(), null, " "
    #console.log "tB", JSON.stringify tB.describe(), null, " "
    expect(tA.includes tB).to.be.true
    expect(tB.includes tA).to.be.false
