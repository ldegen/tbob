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
    it "allows adding simple type constraints", ->
      world = dsl ->
        @factory "Projekt", ->
          @attr "foo",  (@ref "Beteiligung", "aktiv"), 
