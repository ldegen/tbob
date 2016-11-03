module.exports = (process)->
  # need to register coffeescript compiler so world can be described in coffeescript
  # even if bob itself is compiled to plain old javascript
  #
  # TODO: be a good node.js citizen and make this an optional requirement.
  require "coffee-script/register"
  Transform = require("stream").Transform
  WritableBulk = require('elasticsearch-streams').WritableBulk
  EsClient = require('elasticsearch').Client
  TransformToBulk = require "./transform-to-bulk"
  isArray = require("util").isArray
  yaml = require 'js-yaml'
  fs = require 'fs'
  path = require 'path'
  minimist = require "minimist"
  splitLines = require "split"
  splitDocs = require "./lines-to-yaml-docs"
  walkdir = require "walkdir"
  sexp = require "sexp"

  argv = minimist process.argv.slice(2), boolean:['b','B']
  GEPRIS_HOME = process.env.GEPRIS_HOME


  if not GEPRIS_HOME?
    throw new Error("Please set the environment variable GEPRIS_HOME")

  bobDir =  path.join GEPRIS_HOME, 'bob'
  worldDir = path.join bobDir, 'world'
  stat = fs.statSync worldDir

  if not stat.isDirectory()
    throw new Error("Please create a directory for your factory definitions at #{worldDir}")

  worldDefs = []
  walkdir.sync worldDir, (file, stat)->
    if (path.extname(file) in ['.coffee', '.js']) and stat.isFile()
      def = require file
      worldDefs.push def

  if worldDefs.length ==0
    #throw new Error("No factory definitions found in #{worldDir}")
    console.warn "No factory definitions found in #{worldDir}"



  parseSexp = ->
    new Transform
      objectMode: true
      transform: (chunk, encoding, done)->
        if chunk?.trim().length > 0
          spec = sexp chunk
          @push spec
        done()

  parseJson = ->
    new Transform 
      objectMode:true
      transform: (chunk, encoding, done)->
        @push JSON.parse chunk if chunk.trim().length>0
        done()

  parseYaml = ->
    new Transform
      objectMode:true
      transform: (chunk,encoding, done)->
        @push yaml.safeLoad chunk if chunk?.trim().length > 0
        done()

  stringify = ->
    new Transform
      objectMode:true
      transform: (chunk, encoding, done)->
        if chunk?
          @push JSON.stringify(chunk)+"\n"
        else
          console.log "chunk undefined?"
        done()
  createEsSink = (host, index) ->
    client = new EsClient
      host: host
      keepAlive: false

    bulkExec = (bulkCmds, callback) ->
      client.bulk {
        index: index
        body: bulkCmds
      }, callback

    ws = new WritableBulk bulkExec
    ws.on 'close', -> client.close()
    ws

  output = undefined
  if argv.B
    host = argv.h ? argv.H ? 'http://localhost:9200'
    index = argv.i ? argv.I ? 'project'
    output = createEsSink host, index
  else
    output = stringify()
    output.pipe process.stdout if process.stdout?

  bobOptions = {}

  if argv.b or argv.B
    bobOptions.interleaveTypes=true
    bulkOptions=
      defaults:
        id_attr:'id'
        type_attr:'type'
      overrides:{}
    customize = (target,hash)->
      target[name] = value for name,value of hash when value?
    customize bulkOptions.defaults,
      id_attr: argv.k
      type_attr: argv.y
      index_attr: argv.x
      index: argv.i
      type: argv.t
    customize bulkOptions.overrides,
      id_attr: argv.K
      type_attr: argv.Y
      index_attr: argv.X
      index: argv.I
      type: argv.T

    tf = new TransformToBulk bulkOptions
    tf.pipe output
    output = tf

  input: switch argv.f
      when "yaml"
        process.stdin
        .pipe splitLines()
        .pipe splitDocs()
        .pipe parseYaml()
      when "sexp"
        process.stdin
        .pipe splitLines()
        .pipe parseSexp()
      else
        process.stdin
        .pipe splitLines()
        .pipe parseJson()
  output: output
  world: ->
    def.call(this) for def in worldDefs
  transformOptions: bobOptions

