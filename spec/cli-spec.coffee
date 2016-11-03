describe "The Command Line Interface", ->
  Promise = require "bluebird"
  TransformToBulk = require "../src/transform-to-bulk"
  mkdir = Promise.promisify require "mkdirp"
  rmdir = Promise.promisify require "rimraf"
  fs = require "fs"
  Path = require "path"
  Cli = require "../src/cli"
  sink = undefined
  mockProcess = undefined
  homeDir = undefined
  bobDir = undefined
  worldDir = undefined
  subDir = undefined
  beforeEach  ->
    homeDir = Path.join tmpFileName(@test)
    bobDir = Path.join homeDir, "bob"
    worldDir = Path.join bobDir, "world"
    subDir = Path.join worldDir, "subdir"

    mockProcess = (argv,input)=>
      stdin:Source [input]
      env:GEPRIS_HOME: homeDir
      argv:["/path/to/node", "/path/to/main", argv...]
    sink = Sink()

    mkdir subDir

  afterEach ->
    rmdir homeDir

  it "expects input to be NDJSON by default", ->
    cli = Cli mockProcess ["-y"], """
    {"p1":["Projekt","ab_gesperrt",{"title":"SFB 42: Space Shuttle"}], "p2":["Projekt","rahmenprojekt"]}
    {"p1":["Projekt"]}
    """

    cli.input.pipe sink
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
    cli = Cli mockProcess ["-f", "yaml"], """
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

    cli.input.pipe sink
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

  it "also can process newline-delimmited s-expressions, but only in document mode", ->
    cli = Cli mockProcess ["-f","sexp"], """
    (Projekt ab_gesperrt (id p1 title "SFB 42: Space Shuttle"))
    (Projekt rahmenprojekt (id p2))
    (Projekt (id p3))
    """
    cli.input.pipe sink
    expect(sink.promise).to.eventually.eql [
      [ "Projekt", "ab_gesperrt", ["id", "p1", "title", "SFB 42: Space Shuttle"]]
      [ "Projekt", "rahmenprojekt", ["id","p2"]]
      [ "Projekt", ["id","p3"]]
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

    cli = Cli mockProcess ""

    cli.world.call mock

    expect(list).to.eql ["foo","bar"]
  describe "when asked to produce ES Bulk output", ->
    cli = undefined
    beforeEach ->
      cli = Cli mockProcess ['-b'], ""

    it "configures the Bob Transform to include doc types", ->
      expect(cli.transformOptions).to.eql
        interleaveTypes:true

    it "includes a TransformToBulk instance in the output pipeline", ->
      expect(cli.output).is.an.instanceOf TransformToBulk
      expect(cli.output.opts).to.eql
        defaults:
          id_attr:'id'
          type_attr: 'type'
        overrides:{}

    it "can customize TransformToBulk defaults and overrides", ->
      cli = Cli mockProcess [
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
      expect(cli.output.opts).to.eql
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
