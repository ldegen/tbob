xdescribe "The Builder", ->

  Factory = require "rosie"
  Builder = require "../src/builder"
  {Type,Trait,Attribute,Variant,SequenceAttribute,ListAttribute} = Builder
  build = undefined

  beforeEach ->
    build = Builder Factory

  xdescribe "The Model", ->
    it "provides a shortcut API to add attributes to a type", ->
      projekt = new Type "Projekt"
        .add new SequenceAttribute "id"
        .add new ListAttribute "beteiligungen", new Type "Beteiligung"
      expect(projekt.describe()).to.eql
        name:"Projekt"
        super: null
        attributes:
          id:
            name:"id"
            structure:"sequence"
            nestedVariant: null
          beteiligungen:
            name:"beteiligungen"
            structure: "list"
            nestedVariant: ["Beteiligung"]
        traits:['t0']

    it "adds all attributes defined in traits to t0", ->
      projekt = new Type "Projekt"
      projekt
        .trait "foo"
        .add new Attribute "bang",[],->1
        .add new Attribute "baz",[],->2
      projekt
        .trait "bar"
        .add new Attribute "bang",[],->10
        .add new Attribute "baz",[],->20
      expect(projekt.describe()).to.eql
        name:"Projekt"
        super: null
        attributes:
          baz:
            name:"baz"
            structure:"opaque"
            nestedVariant:null
          bang:
            name:"bang"
            structure:"opaque"
            nestedVariant:null
        traits:["t0","foo","bar"]


    it "detects conflicting attribute types", ->
      projekt = new Type "Projekt"
      projekt
        .trait "foo"
        .add new Attribute "bang"
      mistake = ->
        projekt.add new ListAttribute "bang", new Type "Egal"

      expect(mistake).to.throw /conflict/i


  describe "Factory and Object Creation", ->

    it "supports inheritance of attributes and traits", ->
      base = new Type "Base"
      base.add new SequenceAttribute "id"
      base
        .trait "big_bang"
        .add new Attribute "bang",[], ->"big"

      special = new Type "Special", new Variant base
      special
        .trait "ultra"
        .add new Attribute "style",[], ->"ultra"

      bigSpecial = new Type "BigSpecial", new Variant special, ["big_bang", "ultra"]


