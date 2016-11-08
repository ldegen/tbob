describe "The Bulk-Index-Sink", ->
  BulkIndexSink = require "../src/bulk-index-sink"
  MockEsClient = require "./mock-es-client"
  source = undefined
  client = undefined
  sink = undefined

  beforeEach ->
    client = MockEsClient()
    source = Source [
      index: _index:"my_index", _type:"my_type", _id:1
    ,
      foo: 42
    ,
      index: _type: "my_type", _id:2
    ,
      foo: 43
    ]
  it "expects a es-bulk stream uploads it to ES", ->
    sink = new BulkIndexSink client, index: "my_index"
    source
      .pipe sink

    expect(sink.promise).to.be.fulfilled.then ->
      expect(client.calls).to.eql [
        [
          'bulk'
          index: "my_index"
          body: [
            index: _index:"my_index", _type:"my_type", _id:1
          ,
            foo: 42
          ,
            index: _type: "my_type", _id:2
          ,
            foo: 43
          ]
        ]
      ]

    
