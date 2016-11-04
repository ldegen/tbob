describe "Types", ->
  merge = require "../src/merge"
  {opaqueT, scalarT, documentT, dictT, listT, optionalT, nilT, bottomT, refT, construct } = require "../src/type"
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

    it "can carry metadata for itself and its arguments", ->
      other = documentT {
        boom: opaqueT()
        baz: documentT {oink:opaqueT()},
          self: 
            fump: 13
            torf: 0
          attributes: oink: stuff: "good"
      },
        self: foo:42
        attributes:
          boom: bar:21
          baz: 
            knarz:3
            torf: 1
      expect(other.meta()).to.eql foo:42
      expect(other.meta "boom").to.eql bar:21
      expect(other.meta "baz").to.eql
        fump: 13
        knarz: 3
        torf: 1
      expect(other.meta "baz","oink").to.eql stuff:"good"
      expect(other.metaTree()).to.eql
        _self:
          foo:42
        _attrs:
          boom:
            _self:
              bar:21
          baz:
            _self:
              fump:13
              knarz:3
              torf:1
            _attrs:
              oink:
                _self:
                  stuff: "good"

    it "builds meta-documents via bottom-up traversal with custom reduction", ->
      other = documentT {
        boom: opaqueT()
        baz: documentT {oink:opaqueT()},
          self: 
            fump: 13
            torf: 0
          attributes: oink: stuff: 59
      },
        self: foo:42
        attributes:
          boom: bar:21
          baz: 
            knarz:3
            torf: 1
      combine = (self, attrs, trees)-> merge.deep self, attrs, trees()
      expect(other.metaTree combine).to.eql
        foo:42
        boom:
          bar:21
        baz:
          knarz:3
          fump:13
          torf:0
          oink:stuff:59


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



  describe "A Recursive Type", ->
    s = t = undefined
    beforeEach ->
      t=documentT
          head: opaqueT()
          tail: optionalT refT "some symbol"
      s=documentT
          head: scalarT "number"
          tail: documentT
            head: scalarT "string"
            tail: optionalT refT "some symbol"

    it "can only be constructed indirectly by referencing a containing type", ->
      t2 = t.applySubst ->t
      expect(t2.attrs.tail.nestedType.structure()).to.equal "recursive"
      expect(t2.attrs.tail.nestedType.target).to.equal t2
      expect(t2.describe()).to.eql [
        'document'
      ,
        head: ['opaque']
        tail: ['optional', 'recursive', 2]
      ]

    it "can decide membership for finite instances", ->
      t2 = t.applySubst ->t
      doc =
        head:1
        tail:
          head:2
          tail:
            head:3
            tail:null
      notDoc =
        head:1
        tail:
          tail:
            head:3
            tail:null

      expect(t2.contains doc).to.be.true
      expect(t2.contains notDoc).to.be.false
    it "correctly detects specializations if they have a matching recursive structure", ->
      t2 = t.applySubst -> t
      s2 = t.applySubst -> s

      #console.log "t2", JSON.stringify t2.describe(), null, "  "
      #console.log "s2", JSON.stringify s2.describe(), null, "  "
      expect(t2.includes s2).to.be.true
      expect(s2.includes t2).to.be.false

    it "is accepted as specialization of a non-recursive type with matching structure", ->
      finite = documentT
        head: opaqueT()
        tail: optionalT documentT
          head: opaqueT()
          tail: optionalT documentT
            head: opaqueT()
            tail: optionalT opaqueT()
      t2 = t.applySubst -> t
      expect(opaqueT().includes t2).to.be.true
      expect(finite.includes t2).to.be.true
      expect(t2.includes finite).to.be.false #no, because beyond the first three
                                             #elms, the structure is not specified!
  describe "any type", ->
    it "can be constructed from a description", ->
      t0 = construct [
        "document"
      ,
        key: ['scalar', 'string']
        children: ['list', 'ref', 'foobar']
      ,
        self: es: dynamic: false
        attributes: key: es: index:'analyzed'
      ]

      t = t0.applySubst -> t0

      expect(t.describe()).to.eql [
        "document"
      ,
        key: ['scalar', 'string']
        children: ['list', 'recursive', 2]
      ,
        self: es: dynamic: false
        attributes: key: es: index:'analyzed'
      ]

