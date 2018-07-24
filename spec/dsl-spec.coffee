describe "The DSL", ->
  dsl = require "../src/dsl"
  Factory = require "../src/factory"
  world=undefined
  describe "when creating factories", ->
    beforeEach ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "foo", 42
    it "represents factories as named traits", ->
      t= world.trait "Projekt"
      expect(t.describe()).to.eql
        label: "Projekt"
        dependencies:[]
        parent:null
        attributes:
          foo: ['opaque']
    it "can attach metadata to factories", ->
      world = dsl ->
        @factory "Projekt", ->
          @meta es:dynamic:false
          @attr "foo", 42
      s=world.sequence "Projekt"
      expect(s.type().describe()).to.eql [
        "document"
      ,
        foo: ['opaque']
      ,
        self:
          es:
            dynamic: false
      ]
    it "allows factories to extend other factories", ->
      world = dsl ->
        @factory "Bilingual", ->
          @attr "de", @string, "deutscher Text"
          @attr "en", @string, "English text"
        @factory "WithKey", ->
          @attr "key", @string, "FOO"
        @factory "LookupEntry", ->
          @extend "Bilingual"
          @extend "WithKey"
          @attr "description", @string, ["key"], (key)->"a description for #{key}"
      s=world.sequence "LookupEntry"
      t=world.trait "LookupEntry"
      expect(t.describe()).to.eql
        label: "LookupEntry"
        dependencies: ["Bilingual","WithKey"]
        parent: null
        attributes:
          description:["scalar","string"]
      expect(s.type().describe()).to.eql [
        "document"
        de:["scalar","string"]
        en:["scalar","string"]
        key:["scalar","string"]
        description:["scalar","string"]
      ]


  describe "when describing factory-specific traits", ->
    beforeEach ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "foo", 42
          @trait "teilprojekt", ->
            @attr "rahmenprojekt", 126
    it "uses a naming convention that includes the factory name", ->
      t = world.trait "Projekt/teilprojekt"
      expect(t.describe()).to.eql
        label: "teilprojekt"
        dependencies:["Projekt"]
        parent: "Projekt"
        attributes:
          rahmenprojekt:['opaque']

    it "makes sure that all attributes introduced in a trait also exist in the parent factory", ->
      t = world.trait "Projekt"
      expect(t.attributes().rahmenprojekt.type().describe()).to.eql ["optional","opaque"]

  describe "when describing attributes", ->
    it "allows adding type constraints on complex attribut by refering to named existing variants", ->
      world = dsl ->
        @factory "Beteiligung", ->
          @attr "perId"
          @trait "verstorben", ->
            @attr "aktiv", false
        @factory "Projekt", ->
          @attr "ehemalige",  @list @ref "Beteiligung", "verstorben"
      t = world.trait "Projekt"
      expect(t.attributes().ehemalige.type().describe()).to.eql [
        "list"
        "document"
        perId: ["opaque"]
        aktiv: ["opaque"]
      ]

    it "allows to define nested document types inline through 'anonymous' traits", ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "beteiligungen", @list ->
            @attr "perId"
            @attr "aktive", true
      t= world
        .trait "Projekt"
      expect(t.describe().attributes.beteiligungen).to.eql [
        "list"
        "document"
        aktive: ["opaque"]
        perId: ["opaque"]
      ]

    it "allows inline traits to extend known variants", ->
      world = dsl ->
        @factory "Beteiligung", ->
          @attr "perId"
          @trait "verstorben", ->
            @attr "aktiv", false
        @factory "Projekt", ->
          @attr "ehemalige", @list ->
            @extend "Beteiligung", "verstorben"
            @attr "rolle", @string, "PAN"

      t= world
          .trait "Projekt"
      expect(t.describe().attributes.ehemalige).to.eql [
        "list"
        "document"
        aktiv: ["opaque"]
        perId: ["opaque"]
        rolle: ["scalar", "string"]
      ]


    it "allows nesting inline traits to arbitrary depth", ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "beteiligungen", @list ->
            @attr "perId"
            @attr "aktive", true
            @attr "deeper", ->
              @attr "and",  ->
                @attr "deeper", @number, 0
      t= world
        .trait "Projekt"
      expect(t.describe().attributes.beteiligungen).to.eql [
        "list"
        "document"
        aktive: ["opaque"]
        perId: ["opaque"]
        deeper: ["document", and: ["document", deeper: ["scalar", "number"]]]
      ]

    it "supports an alternative, more flexible fluent syntax", ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "beteiligungen"
            .fill [{}]
            .type @list ->
              @attr "perId"
                .type @number
                .fill 42
              @attr "aktiv", true
      expect(world.sequence("Projekt").type().describe()).to.eql [
        "document"
        beteiligungen:[
          "list"
          "document"
          perId: ["scalar","number"]
          aktiv: ["opaque"]
        ]
      ]

    it "can define `fill` and `derive` strategies via the fluent syntax", ->
      world = dsl ->
        @factory "Foo", ->
          @attr "bar"
            .fill 21
            .derive ['bar'], (orig)->2 * orig

      t=world.trait "Foo"
      f= new Factory
      t.apply f
      expect(f.build()).to.eql bar: 42
    it "can attach metadata to attributes via the fluent syntax", ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "title"
            .meta es:index:"analyzed"
      expect(world.sequence("Projekt").type().describe()).to.eql [
        "document"
      ,
        title: ["opaque"]
      ,
        attributes: title: es:index:"analyzed"
      ]

    it "can create hidden attributes via the fluent syntax", ->
      world = dsl ->
        @factory "Foo", ->
          @attr "val", @string, ["seed"], (seed)-> "planted "+seed
          @attr "seed"
            .type @string
            .semantics "option"
      trace =  []
      mockFactory =
        attr: (name)->trace.push ['attr',name]
        option: (name)->trace.push ['option', name]
      world.trait("Foo").apply mockFactory
      expect(trace).to.eql [
        ['attr', 'val']
        ['option', 'seed']
      ]







