describe "The Transformation to ES Mappings", ->
  esMapper = require "../src/es-mapper"
  TransformToMapping = require "../src/transform-to-mapping"
  mockT = (m)->
    meta: -> m
    metaTree: (combine)->combine

  source = undefined
  sink = undefined
  beforeEach ->
    sink = Sink()
    source = Source [
      _type: mockT es:type:'A'
      _data: type: 'X'
    ,
      _type: mockT es:type_attr:'type'
      _data: type: 'B'
    ]
  it "expects duplex input and produces mappings", ->
    source
      .pipe new TransformToMapping
      .pipe sink
    expect(sink.promise).to.eventually.eql [
      A: esMapper
    ,
      B: esMapper
    ]

  it "allows overriding the mapping type via option", ->
    source
      .pipe new TransformToMapping overrides:type_attr:'type'
      .pipe sink
      
    expect(sink.promise).to.eventually.eql [
      X: esMapper
    ,
      B: esMapper
    ]
  it "allows customizing the default mapping type for document (types) that do not provide one", ->
    source = Source [
      _type: mockT {}
      _data: {}
    ,
      _type: mockT es:type_attr:'type'
      _data: type: 'B'
    ]

    source
      .pipe new TransformToMapping defaults:type:'A'
      .pipe sink

    expect(sink.promise).to.eventually.eql [
      A: esMapper
    ,
      B: esMapper
    ]

  it "applies sensible defaults if no mapping type was specified", ->
    source = Source [
      _type: mockT {}
      _data: {type:'A'}
    ,
      _type: mockT {}
      _data: {}
    ]
    source
      .pipe new TransformToMapping
      .pipe sink
    expect(sink.promise).to.eventually.eql [
      A: esMapper
    ,
      project: esMapper
    ]
