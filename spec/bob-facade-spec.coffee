describe "The Bob Facade", ->
  Facade = require "../src/bob-facade"
  dsl = require "../src/dsl"

  it "provides a convenient API for building documents", ->
    facade = Facade dsl ->
        @factory "Beteiligung", ->
          @attr "perId"
          @trait "verstorben", ->
            @attr "aktiv", false
        @factory "Projekt", ->
          @attr "ehemalige",  @list @ref "Beteiligung", "verstorben"
      doc1 = facade.build "Beteiligung", "verstorben", perId:12
      expect(doc1).to.eql
        perId:12
        aktiv:false

  it "makes itself and other interesting stuff available to fill strategies", ->
    facade = Facade dsl ->
      @factory "Foo", ->
        @attr "bar", (@optional @opaque), [], ->this
    cx = facade.build("Foo").bar
    expect(cx.fillSpec).to.eql []
    expect(cx.world).to.eql facade
    expect(cx.factoryName).to.eql "Foo"
    expect(cx.traitNames).to.eql []

  it "keeps track of the number of instances created for each trait", ->
    facade = Facade dsl ->
      @factory "Base", ->
        @trait "special", ->
          @attr "foo"
            .fill "42"
      @factory "Other", ->
        @extend "Base"
        @attr "base", ->
          @extend "Base","special"

    facade.build "Base","special"
    facade.build "Other"
    expect(facade.docCount("Base")).to.eql 3
    expect(facade.docCount("Base", "special")).to.eql 2
    expect(facade.docCount("Other")).to.eql 1

  it "can extract an ES mapping for some type", ->
    facade = Facade dsl ->
      @factory "Foo", ->
        @meta es:mapping:dynamic:false
        @attr "id"
          .meta es:mapping:type:"special-type"
        @attr "bar", ->
          @attr "baz"
            .type @string
            .meta es:mapping:index:"analyzed", analyzer: "german"
    expect(facade.esMapping "Foo").to.eql
      dynamic:false
      properties:
        id: stored:false, index:"not_analyzed", type:"special-type"
        bar: properties:
          baz: stored:false, index:"analyzed", analyzer:"german", type: "string"
