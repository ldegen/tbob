describe "The DSL", ->
  dsl = require "../src/dsl"
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

    #TODO Baustellg
    xit "allows to define nested document types inline through 'anonymous' traits", ->
      @factory "Projekt", ->
        @attr "beteiligungen", @list ->
          @attr "perId"
          @attr "aktive", true

  it "builds a world with a build function", ->

      world = dsl ->
        @factory "Beteiligung", ->
          @attr "perId"
          @trait "verstorben", ->
            @attr "aktiv", false
        @factory "Projekt", ->
          @attr "ehemalige",  @list @ref "Beteiligung", "verstorben"
      doc1 = world.build "Beteiligung", "verstorben", perId:12
      expect(doc1).to.eql
        perId:12
        aktiv:false

