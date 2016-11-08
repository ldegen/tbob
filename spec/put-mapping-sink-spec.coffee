describe "The Put-Mapping-Sink", ->
  PutMappingSink = require "../src/put-mapping-sink"
  MockEsClient = require "./mock-es-client"
  source = undefined
  client = undefined
  sink = undefined

  beforeEach ->
    client = MockEsClient()
    source = Source [
      foo:dynamic:false
    ,
      bar:onkel:"tante"
    ]

  it "uploads incoming chunks as mappings to elasticsearch", ->
    sink = new PutMappingSink client, index: "my_index"
    source
      .pipe sink

    expect(sink.promise).to.be.fulfilled.then ->
      expect(client.calls).to.eql [
        [
          'putMapping'
          index: "my_index"
          type: "foo"
          body: dynamic:false 
        ]
        [
          'putMapping'
          index: "my_index"
          type: "bar"
          body: onkel:'tante'
        ]
      ]

   it "drops and recreates the index if asked to", ->
    sink = new PutMappingSink client, index: "my_index", reset:true
    source
      .pipe sink

    expect(sink.promise).to.be.fulfilled.then ->
      expect(client.calls).to.eql [
        ['deleteIndex', index: "my_index"]
        ['createIndex', index: "my_index"]
        #['putSettings', index: "my_index", body: {importantOption:42}]
        ['putMapping',  index: "my_index", type: "foo", body:dynamic:false]
        ['putMapping', index: "my_index", type: "bar", body:onkel:'tante']
      ]
