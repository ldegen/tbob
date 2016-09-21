describe "The Command Line Interface", ->
  Promise = require "bluebird"
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

    mockProcess = (input)=>
      stdin:Source [input]
      env:GEPRIS_HOME: homeDir
    sink = Sink()
    
    mkdir subDir

  afterEach ->
    rmdir homeDir

  it "parses stdin into an object stream suitable as input for a Bob Transform", ->
    cli = Cli mockProcess """
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
    
