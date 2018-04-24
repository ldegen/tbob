describe "ES-Bulk Transformation", ->
  source = undefined
  sink = undefined
  TransformToBulk = require "../src/transform-to-bulk"
  {documentT, scalarT} = require "../src/type"
  beforeEach ->
    source = Source [
      _type: documentT {id: scalarT("number")}, self: es:
        type:'project'
        id_attr: 'id'
        index:'app-test'
      _data:
        id:42
        index: "special-index"
        type: "special-type"

    ,
      _type: documentT {id: scalarT("number")}, self: es:
        type_attr:'type'
        id_attr: 'weirdCustomId'
      _data:
        weirdCustomId:43
        index: "special-index"
        type: "special-type"
    ,
    ]
    sink = Sink()

  it "uses type meta-info to create ES-Bulk Commands", ->
    source
      .pipe new TransformToBulk()
      .pipe sink
    expect(sink.promise).to.eventually.eql [
      index:
        _type: 'project'
        _id: 42
        _index: 'app-test'
    ,
      id:42
      index:'special-index'
      type:'special-type'
    ,
      index:
        _type: "special-type"
        _id: 43
    ,
      weirdCustomId: 43
      type: "special-type"
      index:'special-index'
    ]

  it "can override metadata", ->
    source
      .pipe new TransformToBulk
        override:
          index_attr: "index"
          type: "foo"
          id:1337
      .pipe sink
   expect
      index:
        _type: 'foo'
        _id: 1337
        _index: 'special-index'
    ,
      id:42
      type: "special-type"
      index:'special-index'
    ,
      index:
        _type: 'foo'
        _id: 1337
        _index: 'special-index'
    ,
      weirdCustomId: 43
      type: "special-type"
      index:'special-index'
