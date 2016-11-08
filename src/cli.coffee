module.exports = (process, { BobTransform, TransformToBulk, TransformToMapping, BulkIndexSink, PutMappingSink}={})->
  # need to register coffeescript compiler so world can be described in coffeescript
  # even if bob itself is compiled to plain old javascript
  #
  # TODO: be a good node.js citizen and make this an optional requirement.
  require "coffee-script/register"
  {Readable, Transform} = require "stream"
  {Client} = require "elasticsearch"
  BobTransform ?= require "./bob-transform"
  TransformToBulk ?= require "./transform-to-bulk"
  TransformToMapping ?= require "./transform-to-mapping"
  BulkIndexSink ?= require "./bulk-index-sink"
  PutMappingSink ?= require "./put-mapping-sink"
  isArray = require("util").isArray
  yaml = require 'js-yaml'
  fs = require 'fs'
  path = require 'path'
  minimist = require "minimist"
  automist = require "automist"

  splitLines = require "split"
  splitDocs = require "./lines-to-yaml-docs"
  walkdir = require "walkdir"
  sexp = require "sexp"
  toCamelCase = (x)->
    if typeof x is "string"
      x.replace /\W+(\w)/g, (_,c)->c.toUpperCase()
    else
      o={}
      o[toCamelCase key]=value for key,value of x
      o

  readme =  yaml.load fs.readFileSync path.join __dirname, '..', 'README.yaml'
  argv = toCamelCase minimist process.argv.slice(2), automist readme
  if argv.help
    process.stdout.write automist.help readme
    process.exit -1
  worldDir = undefined
  if argv.world?
    worldDir = argv.world
  else
    GEPRIS_HOME = process.env.GEPRIS_HOME
    if not GEPRIS_HOME?
      throw new Error("Please set the environment variable GEPRIS_HOME or use -w to tell me were your factory definitions are located")

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

  worldDescription = -> def.call this for def in worldDefs

  Source = (chunks,opts0) ->
    opts = opts0 ? objectMode: true
    input = new Readable opts
    input.push chunk for chunk in chunks
    input.push(null)
    input

  empty = ->
    r = new Readable objectMode:true
    r.push null
    r

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

  output = undefined

  bobOptions = {
    mode: switch
      when argv.bulk or argv.uploadBulk then "duplex"
      when argv.mapping or argv.uploadMapping then "duplex"
      else "document"
  }

  bulkOptions=
    defaults:
      id_attr:'id'
      type_attr:'type'
    overrides:{}
  customize = (target,hash)->
    target[name] = value for name,value of hash when value?
  customize bulkOptions.defaults,
    id_attr: argv.defaultIdAttr
    type_attr: argv.defaultTypeAttr
    index_attr: argv.defaultIndexAttr
    index: argv.defaultIndex
    type: argv.defaultType
  customize bulkOptions.overrides,
    id_attr: argv.overrideIdAttr
    type_attr: argv.overrideTypeAttr
    index_attr: argv.overrideIndexAttr
    index: argv.overrideIndex
    type: argv.overrideType
  input: ->
    source = (
      if argv._.length == 0
        process.stdin
      else
        Source argv._.map (chunk)->chunk+"\n"
    )


    switch argv.format
      when "yaml" then [
        source
        splitLines()
        splitDocs()
        parseYaml()
      ]
      when "sexp" then [
        source
        splitLines()
        parseSexp()
      ]
      else [
        source
        splitLines()
        parseJson()
      ]
  output: ->
    chain = []
    host = argv.esUrl ? 'http://localhost:9200'
    index = argv.defaultIndex ? argv.overrideIndex ? 'project'

    if argv.bulk or argv.uploadBulk
      chain.push new TransformToBulk bulkOptions
    else if argv.mapping or argv.uploadMapping
      chain.push new TransformToMapping bulkOptions
    if argv.uploadBulk
      client = new Client host:host, keepAlive=false
      sink = new BulkIndexSink client, index:index
      sink.promise.finally -> client.close()
      chain.push sink
    else if argv.uploadMapping
      client = new Client host:host, keepAlive=false
      sink = new PutMappingSink client, index:index, reset:argv.clearIndex
      sink.promise.finally -> client.close()
      chain.push sink
    else
      chain.push stringify(), process.stdout
    chain
  filter: -> BobTransform worldDescription, bobOptions
  pipeline: ->
    [
      @input()...
      @filter()
      @output()...
    ]

