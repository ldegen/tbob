describe "The tbob Introspection API", ->
  Introspect = require "../src/tbob-introspect"
  dsl = require "../src/dsl"
  introspect = undefined
  beforeEach ->
    introspect = Introspect dsl ->
      @factory "Projekt", ->
        @attr "title", (@ref "Bilingual", "empty"), de: "deutscher Titel", en:"English title"
        @attr "beteiligungen", @list ->
          @attr "personId", @number, 1
          @attr "rolleKey", @string, "PAN"
        @trait "teilprojekt", ->
          @attr "rahmenprojektId", @number, 42
      @factory "Bilingual", ->
        @attr "de", (@optional @string), "deutscher Inhalt"
        @attr "en", (@optional @string), "English content"
        @trait "empty", ->
          @attr "de", @optional @string
          @attr "en", @optional @string

  it "can describe the type of a variant", ->
    type = introspect "Projekt", "teilprojekt"
    expect(type).to.eql [
      "document"
      title:["document", de:["optional","scalar", "string"], en: ["optional", "scalar","string"]]
      beteiligungen:["list", "document", personId: ["scalar","number"], rolleKey: ["scalar","string"]]
      rahmenprojektId:["scalar","number"]
    ]
  it "can "
