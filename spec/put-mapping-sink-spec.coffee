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
        ['deleteIndex', index: "my_index", ignore:404]
        ['createIndex', index: "my_index"]
        ['putMapping',  index: "my_index", type: "foo", body:dynamic:false]
        ['putMapping', index: "my_index", type: "bar", body:onkel:'tante']
      ]

  it "uploads index-level settings if asked to", ->
    sink = new PutMappingSink client, index: "my_index", reset:true, settings: dolle:"settings"
    source
      .pipe sink

    expect(sink.promise).to.be.fulfilled.then ->
      expect(client.calls).to.eql [
        ['deleteIndex', index: "my_index", ignore:404]
        ['createIndex', index: "my_index", body: settings: dolle: "settings"]
        ['putMapping',  index: "my_index", type: "foo", body:dynamic:false]
        ['putMapping', index: "my_index", type: "bar", body:onkel:'tante']
      ]

  it "can upload settings without reseting the index", ->
    sink = new PutMappingSink client, index: "my_index", reset:false, settings: dolle:"settings"
    source
      .pipe sink

    expect(sink.promise).to.be.fulfilled.then ->
      expect(client.calls).to.eql [
        ['closeIndex', index: "my_index"]
        ['putSettings', index: "my_index", body:dolle:"settings"]
        ['openIndex', index: "my_index"]
        ['clusterHealth', index: "my_index", level:'indices',waitForStatus:'yellow']
        ['putMapping',  index: "my_index", type: "foo", body:dynamic:false]
        ['putMapping', index: "my_index", type: "bar", body:onkel:'tante']
      ]

