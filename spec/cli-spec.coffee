describe "The Command Line Interface", ->
  {isArray} = require "util"
  {Transform} = require "stream"
  Promise = require "bluebird"
  {WritableBulk} = require "elasticsearch-streams"
  TransformToBulk = require "../src/transform-to-bulk"
  TransformToMapping = require "../src/transform-to-mapping"
  BulkIndexSink = require "../src/bulk-index-sink"
  PutMappingSink = require "../src/put-mapping-sink"
  mkdir = Promise.promisify require "mkdirp"
  rmdir = Promise.promisify require "rimraf"
  fs = require "fs"
  Path = require "path"
  Cli0 = require "../src/cli"
  Cli = undefined
  crypto = require "crypto"
  sink = undefined
  mockProcess = undefined
  tmpDir = undefined
  homeDir = undefined
  tbobDir = undefined
  worldDir = undefined
  subDir = undefined
  cli = undefined
  alternativeWorldDir = undefined
  alternativeSubDir=undefined
  alternativeWorldFile = undefined
  pipeline =  (args...)->
    args.reduce (a0,b0)->
      a = if isArray a0 then pipeline a0... else a0
      b = if isArray b0 then pipeline b0... else b0
      a.pipe b
  beforeEach  ->
    tmpDir = tmpFileName()
    homeDir = Path.join tmpDir, "home"
    tbobDir = Path.join homeDir, "tbob"
    worldDir = Path.join tbobDir, "world"
    subDir = Path.join worldDir, "subdir"

    alternativeWorldDir = Path.join tmpDir, "world"
    alternativeWorldFile = Path.join tmpDir, "single-file-world.js"
    alternativeSubDir = Path.join alternativeWorldDir, "subdir"

    mockProcess = (argv,input)->
      stdin:Source [input]
      env:TBOB_HOME: homeDir
      argv:["/path/to/node", "/path/to/main", argv...]
    mockTBobTransform = (worldDescription, opts)->
      t = new Transform
        objectMode:true
        transform: (chunk,enc,done)->
          @chunks.push chunk
          @push chunk
          done()
      t.chunks = []
      t.opts = opts
      t.worldDescription = worldDescription
      t
    Cli = (args...)->Cli0 mockProcess( args...),
      TBobTransform: mockTBobTransform
    sink = Sink()

    mkdir subDir
      .then mkdir alternativeSubDir

  afterEach ->
    rmdir tmpDir

  it "expects input to be NDJSON by default", ->
    cli = Cli ["-y"], """
    {"p1":["Projekt","ab_gesperrt",{"title":"SFB 42: Space Shuttle"}], "p2":["Projekt","rahmenprojekt"]}
    {"p1":["Projekt"]}
    """
    pipeline cli.input(), sink
    expect(sink.promise).to.eventually.eql [
      p1: [
        "Projekt"
        "ab_gesperrt"
        title: "SFB 42: Space Shuttle"
      ]
      p2: [
        "Projekt"
        "rahmenprojekt"
      ]
    ,
      p1: ["Projekt"]
    ]

  it "also can take a yaml stream as input", ->
    cli = Cli ["-f", "yaml"], """
    %YAML 1.2
    ---
    p1:
      - Projekt
      - ab_gesperrt
      - title: "SFB 42: Space Shuttle"
    p2:
      - Projekt
      - rahmenprojekt
    ...
    %YAML 1.2
    ---
    p1:
      - Projekt
    """

    pipeline cli.input(), sink
    expect(sink.promise).to.eventually.eql [
      p1: [
        "Projekt"
        "ab_gesperrt"
        title: "SFB 42: Space Shuttle"
      ]
      p2: [
        "Projekt"
        "rahmenprojekt"
      ]
    ,
      p1: ["Projekt"]
    ]
  it "supports an alternative yaml format for document mode", ->
    cli = Cli ["-f","yaml2"], """
    %YAML 1.2
    ---
    - Projekt:
        title : "SFB 42 : Space Shuttle"
        id    : 99

    - Person, lebendig:
        name : Onkel Lukas
        id   : 2

    ...
    %YAML 1.2
    ---

    - Projekt:
        title: geht dich gar nichts an
        id: 9
    """
    pipeline cli.input(), sink
    expect(sink.promise).to.eventually.eql [
      ["Projekt", title: "SFB 42 : Space Shuttle", id: 99]
      ["Person", "lebendig", name: "Onkel Lukas", id: 2]
      ["Projekt", title: "geht dich gar nichts an", id: 9]
    ]

  it "also can process newline-delimmited s-expressions, but only in document mode", ->
    cli = Cli ["-f","sexp"], """
    (Projekt ab_gesperrt (id p1 title "SFB 42: Space Shuttle"))
    (Projekt rahmenprojekt (id p2))
    (Projekt (id p3))
    """
    pipeline cli.input(), sink
    expect(sink.promise).to.eventually.eql [
      [ "Projekt", "ab_gesperrt", ["id", "p1", "title", "SFB 42: Space Shuttle"]]
      [ "Projekt", "rahmenprojekt", ["id","p2"]]
      [ "Projekt", ["id","p3"]]
    ]

  describe "When given the -F option", ->
    it "uses a fixed factory for all expressions", ->
      cli = Cli ["-f", "sexp", "-F" , "Projekt"], """
      (id p1 title "SFB 42: Space Shuttle")
      (id p2)
      """
      pipeline cli.input(), sink
      expect(sink.promise).to.eventually.eql [
        [ "Projekt", ["id", "p1", "title", "SFB 42: Space Shuttle"]]
        [ "Projekt", ["id","p2"]]
      ]

    it "also allows to specify traits by giving the -F option more than once", ->
      cli = Cli ["-f", "sexp", "-F" , "Projekt", "-F", "rahmenprojekt"], """
      (id p1 title "SFB 42: Space Shuttle")
      (id p2)
      """
      pipeline cli.input(), sink
      expect(sink.promise).to.eventually.eql [
        [ "Projekt", "rahmenprojekt", ["id", "p1", "title", "SFB 42: Space Shuttle"]]
        [ "Projekt", "rahmenprojekt", ["id","p2"]]
      ]

    xit "can be used with an empty spec", ->
      cli = Cli ["-f", "sexp", "-F" , "Projekt", "-F", "rahmenprojekt"]
      pipeline cli.input(), sink
      expect(sink.promise).to.eventually.eql [
        [ "Projekt", "rahmenprojekt"]
      ]



  it "reads coffee/js files from a well-known directory and constructs a world definition", ->
    fs.writeFileSync (Path.join worldDir, "foo.js"), """
    module.exports = function(){
      this.factory("foo",function(){});
    };
    """

    fs.writeFileSync (Path.join subDir, "bar.coffee"), """
    module.exports = ->
      @factory "bar", ->
    """

    list = []
    mock =
      factory: (name)->
        list.push name

    cli = Cli [], ""

    worldDescription = cli.filter().worldDescription
    worldDescription.call mock

    expect(list).to.eql ["foo","bar"]

  it "can be configured construct world definition from another directory", ->
    fs.writeFileSync (Path.join alternativeWorldDir, "foo.js"), """
    module.exports = function(){
      this.factory("foo",function(){});
    };
    """

    fs.writeFileSync (Path.join alternativeSubDir, "bar.coffee"), """
    module.exports = ->
      @factory "bar", ->
    """

    list = []
    mock =
      factory: (name)->
        list.push name

    cli = Cli ["-w", alternativeWorldDir],""

    worldDescription = cli.filter().worldDescription
    worldDescription.call mock

    expect(list).to.eql ["foo","bar"]

  it "can be configured construct world definition from a single file", ->
    fs.writeFileSync alternativeWorldFile, """
    module.exports = function(){
      this.factory("foo",function(){});
    };
    """

    list = []
    mock =
      factory: (name)->
        list.push name

    cli = Cli ["-w", alternativeWorldFile],""

    worldDescription = cli.filter().worldDescription
    worldDescription.call mock

    expect(list).to.eql ["foo"]

  it "can be configured to only fill attributes that are marked as `derived`", ->
    cli = Cli ['-d'], ""
    expect(cli.filter().opts.options.onlyFillDerivedAttributes).to.equal true

  it "can pass a file with lookup data to the fill strategies et al.", ->
    lookup = foo:bar:42
    lookupFile = Path.join tmpDir, "lookup.json"
    fs.writeFileSync lookupFile, JSON.stringify lookup
    cli = Cli ['-L', lookupFile]
    expect(cli.filter().opts.options.lookup).to.eql lookup

  describe "when asked to produce ES Bulk output", ->
    beforeEach ->
      cli = Cli ['-b'], ""

    it "configures the TBob Transform to include doc types", ->
      expect(cli.filter().opts.mode).to.eql "duplex"

    it "includes a TransformToBulk instance in the output pipeline", ->
      expect(cli.output()[0]).is.an.instanceOf TransformToBulk
      expect(cli.output()[0].opts).to.eql
        defaults:
          id_attr:'id'
          type_attr: 'type'
        overrides:{}

    it "can customize TransformToBulk defaults and overrides", ->
      cli = Cli [
        '-b',
        '-k', 'defaultIdAttr',
        '-y', 'defaultTypeAttr',
        '-x', 'defaultIndexAttr',
        '-i', 'defaultIndex',
        '-t', 'defaultType'
        '-K', 'overrideIdAttr',
        '-Y', 'overrideTypeAttr',
        '-X', 'overrideIndexAttr'
        '-T', 'overrideType',
        '-I', 'overrideIndex'

      ]
      expect(cli.output()[0].opts).to.eql
        defaults:
          id_attr:'defaultIdAttr'
          type_attr: 'defaultTypeAttr'
          index_attr: 'defaultIndexAttr'
          index: 'defaultIndex'
          type: 'defaultType'
        overrides:
          id_attr:'overrideIdAttr'
          type_attr:'overrideTypeAttr'
          index_attr: 'overrideIndexAttr'
          index: 'overrideIndex'
          type: 'overrideType'

  describe "when asked to upload a bulk to ES", ->
    beforeEach ->
      cli = Cli ["-B"]

    it "behaves like above, but uses ES Writeable Bulk Stream as sink", ->
      [tf, ..., sink] = cli.output()
      expect(tf).to.be.an.instanceOf TransformToBulk
      expect(sink).to.be.an.instanceOf BulkIndexSink

  describe "when asked to generate es mappings", ->
    beforeEach ->
      cli = Cli ["-m"]

    it "sets the TBobTransform into 'duplex'-mode", ->
      expect(cli.filter().opts.mode).to.eql "duplex"

    it "uses an TransformToMapping instance in the output chain", ->
      expect(cli.output()[0]).to.be.an.instanceOf TransformToMapping


  describe "when asked to upload Mappings", ->
    beforeEach ->
      cli = Cli ["-M"]

    it "behaves like above, but uses a PutMappingSink as sink", ->
      [tf, ..., sink] = cli.output()
      expect(tf).to.be.an.instanceOf TransformToMapping
      expect(sink).to.be.an.instanceOf PutMappingSink
      expect(sink.opts).to.eql index:"project", reset: false
    it "can tell the Sink to reset the index", ->
      cli = Cli ["-M","-C"]
      [tf, ..., sink] = cli.output()
      expect(tf).to.be.an.instanceOf TransformToMapping
      expect(sink).to.be.an.instanceOf PutMappingSink
      expect(sink.opts).to.eql index:"project", reset:true
    it "can tell the Sink to upload index-level settings", ->
      settingsFile = (Path.join tmpDir, "index-level-settings.coffee")
      fs.writeFileSync settingsFile, """
      module.exports =
        wichtige: einstellung: 42
      """
      cli = Cli ["-M","-S", settingsFile]
      [tf, ..., sink] = cli.output()
      expect(tf).to.be.an.instanceOf TransformToMapping
      expect(sink).to.be.an.instanceOf PutMappingSink
      expect(sink.opts).to.eql index:"project", reset:false, settings:wichtige:einstellung:42


  describe "when using the -p / --pipe option", ->
    it "can pipe documents to a custom nodejs writeable", ->
      transformFile = Path.join tmpDir, "my-transform.coffee"
      fs.writeFileSync transformFile, """
      { Transform } = require "stream"
      module.exports = (lookup)->
        new Transform
          objectMode: true
          transform: (chunk, enc, done)->
            @push wrapped:chunk
            done()
      """
      
      cli = Cli ["-p", transformFile]

      outputChain = cli.output()
      expect(outputChain.length).to.eql 1
      [first,...] = outputChain
      pipeline outputChain, sink

      first.write {oink:42}
      first.write {umf:"tata"}
      first.end()

      expect(sink.promise).to.eventually.eql [
        wrapped:oink:42
      ,
        wrapped:umf: "tata"
      ]

    it "can determines the tbob mode from looking at the provided writable", ->
      transformFile = Path.join tmpDir, "my-transform.coffee"
      fs.writeFileSync transformFile, """
      { Transform } = require "stream"
      module.exports = (lookup)->
        tf = new Transform
          objectMode: true
          transform: (chunk, enc, done)->
            @push wrapped:chunk
            done()
        tf._tbobMode="duplex"
        tf
      """
      
      cli = Cli ["-p", transformFile]
      expect(cli.filter().opts.mode).to.eql "duplex"

    it "passes the output options to the factory", ->
      transformFile = Path.join tmpDir, "my-transform.coffee"
      fs.writeFileSync transformFile, """
      { Transform } = require "stream"
      module.exports = (options)->
        tf = new Transform
          objectMode: true
          transform: (chunk, enc, done)->
            @push options
            done()
        tf
      """
      

      cli = Cli [
        '-k', 'defaultIdAttr',
        '-y', 'defaultTypeAttr',
        '-x', 'defaultIndexAttr',
        '-i', 'defaultIndex',
        '-t', 'defaultType'
        '-K', 'overrideIdAttr',
        '-Y', 'overrideTypeAttr',
        '-X', 'overrideIndexAttr'
        '-T', 'overrideType',
        '-I', 'overrideIndex'
        '-p', transformFile

      ]

      outputChain = cli.output()
      expect(outputChain.length).to.eql 1
      [first,...] = outputChain

      pipeline outputChain, sink
      first.write {oink:42}
      first.end()
      expect(sink.promise).to.eventually.eql [
        defaults:
          id_attr:'defaultIdAttr'
          type_attr: 'defaultTypeAttr'
          index_attr: 'defaultIndexAttr'
          index: 'defaultIndex'
          type: 'defaultType'
        overrides:
          id_attr:'overrideIdAttr'
          type_attr:'overrideTypeAttr'
          index_attr: 'overrideIndexAttr'
          index: 'overrideIndex'
          type: 'overrideType'
      ]

      

  describe "when given non-option arguments", ->
    beforeEach ->
      cli = Cli ["-f","sexp","(Projekt supergrün (id 42))", "(Auto sportlich (id 21))"],
        "Yeah that's right, just ignore me..."

      pipeline cli.input(), sink
    it "feeds them into the input pipeline, ignoring stdin", ->
      expect(sink.promise).to.eventually.eql [
        ["Projekt", "supergrün",["id",42]]
        ["Auto", "sportlich", ["id",21]]
      ]
