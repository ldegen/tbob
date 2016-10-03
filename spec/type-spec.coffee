describe "Types", ->
# A type is a class (as in set-theory) of values. Or rather: it is a predicate over values.
# In our domain, we only consider predicates of one of the following forms:
#
#   a) The value is opaque, meaning: we don't know or care about its structure
#
#   b) The value is of some scalar type (string, boolean, numnber).
#
#   c) The value is a document with *at least* the following attributes: a1, a2, ..., an.
#      Each attribute is a pair (name_i, type_i) with name_i != name_j for i!=j.
#      The value for attribute a_i is consistent with type_i.
#
#   d) The value is a dictionary and all entries are of type t.
#
#   e) The value is a list and all elements are of type t.
#
#   f) The value is of a given type, or it is nil (i.e. absent).
#   
#   g) The value is nil (i.e.: absent).
#

  {opaqueT, scalarT, documentT, dictT, listT, optionalT, nilT, bottomT } = require "../src/type"
  describe "a) The opaque type", ->

    t = opaqueT()
    it "contains all values, but not null", ->
      expect(t.contains "foo").to.be.true
      expect(t.contains 42).to.be.true
      expect(t.contains {foo:42}).to.be.true
      expect(t.contains [1,[2],{foo:42}]).to.be.true

    it "does not contain null", ->
      expect(t.contains null).to.be.false

    it "includes itself", ->
      expect(t.includes opaqueT()).to.be.true


  describe "b) The scalar type", ->
    any = scalarT()
    it "contains all scalar values", ->
      expect(any.contains "bla").to.be.true
      expect(any.contains 42).to.be.true
      expect(any.contains {foo:42}).to.be.false

    it "does not contain null", ->
      expect(any.contains null).to.be.false

    it "is included in the opaque type", ->
      expect(opaqueT().includes scalarT()).to.be.true

  describe "b) Any particular scalar type",->
    num = scalarT("number")
    it "contains values of the matching scalar type", ->
      expect(num.contains "bla").to.be.false
      expect(num.contains 42).to.be.true

    it "is included in the general scalar type", ->
      expect(scalarT().includes num).to.be.true

    it "is included in the opaque type", ->
      expect(opaqueT().includes num).to.be.true

  describe "c) A document type", ->
    d = documentT
        foo: scalarT "number"
        bang: documentT
          big: scalarT "boolean"
    it "contains objects that have the attributes described and possible more", ->
      expect(d.contains
        foo: 42
        bang:big:false
      ).to.be.true
      expect(d.contains
        foo:54
        umf:
          yes:["no"]
        bang:
          big:true
          bar:"baz"
      ).to.be.true
      expect(d.contains
        foo:65
        bang:
          big: "dunno"
      ).to.be.false

    it "does not contain null", ->
      expect(d.contains null).to.be.false

    it "is included in the opaque type", ->
      expect(opaqueT().includes d).to.be.true

    it """is included in another doc type if for any attribute a₀ in the other doc type 
          there is a matching attribute `a₁` in this doc type such that
          - the name of a₀ and a₁ are the same and
          - the type of a₀ contains that of a₁'
       """, ->
      other = documentT
          bang: documentT
            big: scalarT()
      expect(other.includes d).to.be.true

      other = documentT
          bang: opaqueT()
      expect(other.includes d).to.be.true

      other = documentT
          boom: opaqueT()
      expect(other.includes d).to.be.false
  describe "d) A dictionary type", ->

    d = dictT documentT foo: scalarT "number"
    
    it "contains objects where all property values are of a known type", ->

      expect(d.contains
        honk:foo:1
        boost:
          foo:2
          bar: false
      ).to.be.true
      expect(d.contains
        arf: foo: 1
        barf: 13
      ).to.be.false

    it "contains the empty object", ->
      expect(d.contains {}).to.be.true

    it "does not contain null", ->
      expect(d.contains null).to.be.false

    it "does not contain arrays",->
      expect(d.contains []).to.be.false

    it "includes another dict if its own nested type contains the other nested type", ->
      d0 = dictT documentT foo: scalarT()
      expect(d0.includes d).to.be.true
      d0 = dictT documentT foo: scalarT(), bar:opaqueT()
      expect(d0.includes d).to.be.false

    it "does not include list types, even if the nested type would match", ->
      d0 = dictT scalarT()
      d1 = listT scalarT "boolean"
      expect(d0.includes d1).to.be.false


  describe "e) A list type", ->

    d = listT documentT foo: scalarT "number"

    it "contains arrays where all property values are of a known type", ->

      expect(d.contains [
        foo:1
      ,
        foo:2
        bar: false
      ]).to.be.true
      expect(d.contains [
        foo: 1
      ,
        13
      ]).to.be.false

    it "contains the empty array, but not null", ->
      expect(d.contains []).to.be.true
    
    it "does not contain null", ->
      expect(d.contains null).to.be.false

    it "includes another list if its own nested type contains the other nested type", ->
      d0 = listT documentT foo: scalarT()
      expect(d0.includes d).to.be.true
      d0 = listT documentT foo: scalarT(), bar:opaqueT()
      expect(d0.includes d).to.be.false

    it "does not include dict types, even if the nested type would match", ->
      d0 = listT scalarT()
      d1 = dictT scalarT "boolean"
      expect(d0.includes d1).to.be.false

  describe "f) An optional type", ->

    d = optionalT scalarT "number"

    it "contains all values of the nested type", ->
      expect(d.contains 42).to.be.true
      expect(d.contains "ssss").to.be.false

    it "also contains null", ->
      expect(d.contains null).to.be.true

    it "includes the nested type", ->
      expect(d.includes scalarT "number").to.be.true

    it "is not included in the nested type", ->
      expect(scalarT("number").includes d).to.be.false

    it "is not included in the opaque type", ->
      expect(opaqueT().includes d).to.be.false

    it "is included in the optional opaque type (everything is, btw)", ->
      expect(optionalT(opaqueT()).includes d).to.be.true

    it "includes another optional type if the nested type includes the other nested type", ->
      expect(optionalT(scalarT()).includes d).to.be.true

  describe "g) The null-type", ->

    t = nilT()

    it "contains null", ->
      expect(t.contains null).to.be.true
    it "does not contains anything else", ->
      expect(t.contains "foo").to.be.false
      expect(t.contains 42).to.be.false
      expect(t.contains {foo:42}).to.be.false
      expect(t.contains [1,[2],{foo:42}]).to.be.false
    it "is not included in the opaque type", ->
      expect(opaqueT().includes t).to.be.false
    it "is included in any optional type", ->
      expect(optionalT(scalarT()).includes t).to.be.true

    it "is equivalent to the optional null type", ->
      expect(optionalT(t).includes t).to.be.true
      expect(t.includes optionalT t).to.be.true
  #
  # There are types that are impossible to fulfill (at least by a finite value).
  # We simply use ⊥ or bottom to refer to any of these types.
  # This is added for completeness, i am not sure if we need it at all.
  #
  describe "z) The bottom-Type", ->
    t = bottomT()
    it "contains nothing", ->
      expect(t.contains "foo").to.be.false
      expect(t.contains 42).to.be.false
      expect(t.contains {foo:42}).to.be.false
      expect(t.contains [1,[2],{foo:42}]).to.be.false
      expect(t.contains null).to.be.false
    it "is included in every type", ->
      expect(opaqueT().includes t).to.be.true
      expect(scalarT("boolean").includes t).to.be.true
      expect(optionalT(documentT foo: scalarT("number")).includes t).to.be.true


  # We define a partial order on types.

