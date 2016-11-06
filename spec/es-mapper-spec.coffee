describe "The ES-Mapper", ->
  facade = require "../src/bob-facade"
  dsl = require "../src/dsl"
  mapper = require "../src/es-mapper"
  it "creates an ES Mapping from document meta data", ->
    bob = facade dsl ->
      @factory "Person", ->
        @meta
          es: type: "person"
          mapping: dynamic: false
      
        @attr "name"
          .type @string
          .meta es:mapping:{}
        @attr "name_sort"
          .type @string
          .meta es:mapping:{}
        @attr "plz"
          .type @string
    

      @factory "Projekt", ->
        @meta
          es:
            type: "projekt"
            mapping:
              dynamic:false
        @attr "title"
          .type @optional @string
          .meta es:mapping:{}
        @attr "unwichtig"
          .meta un:"wichtig"
        @attr "persons", @list ->
          @extend "Person"
          @meta es:mapping:properties:
            name:type:"string", index:"not_analyzed"
            plz:type:"string", index:"not_analyzed"
    mapping = bob
      .type "Projekt"
      .metaTree mapper
    expect(mapping).to.eql
        dynamic:false
        properties:
          title:
            type:"string"        # guessed from attribute type
            stored:false         # default
            index:"not_analyzed" # default
          persons:
            properties:
              name:
                type:"string"
                index:"not_analyzed"
              plz:
                type:"string"
                index:"not_analyzed"
      
