module.exports = (process, { TBobTransform, TransformToBulk, TransformToMapping, BulkIndexSink, PutMappingSink}={})->
  # need to register coffeescript compiler so world can be described in coffeescript
  # even if tbob itself is compiled to plain old javascript
  #
  # TODO: be a good node.js citizen and make this an optional requirement.
  require "coffee-script/register"
  {Readable, Transform} = require "stream"
  {Client} = require "elasticsearch"
  TBobTransform ?= require "./tbob-transform"
  TransformToBulk ?= require "./transform-to-bulk"
  TransformToMapping ?= require "./transform-to-mapping"
  BulkIndexSink ?= require "./bulk-index-sink"
  PutMappingSink ?= require "./put-mapping-sink"
  isArray = require("util").isArray
  yaml = require 'js-yaml'
  fs = require 'fs'
  path = require 'path'
  minimist = require "minimist"
  Automist = require "automist"

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
  automist = Automist readme
  argv = toCamelCase minimist process.argv.slice(2), automist.options()
  if argv.manpage
    process.stdout.write automist.manpage()
    process.exit 0
  if argv.help
    process.stderr.write automist.help()
    process.exit -1
  worldDir = undefined
  if argv.world?
    worldDir = argv.world
  else
    TBOB_HOME = process.env.TBOB_HOME
    if not TBOB_HOME?
      throw new Error("Please set the environment variable TBOB_HOME
                       or use -w to tell me were your factory definitions are located")

    tbobDir =  path.join TBOB_HOME, 'tbob'
    worldDir = path.join tbobDir, 'world'

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

  parseYaml2 = ->
    new Transform
      objectMode:true
      transform: (chunk,encoding, done)->
        list = yaml.safeLoad chunk if chunk?.trim().length > 0
        for obj in list
          for key, value of obj
            names = key.split /[,\s]+/
            @push [names..., value]
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

  tbobOptions = {
    mode: switch
      when argv.bulk or argv.uploadBulk then "duplex"
      when argv.mapping or argv.uploadMapping then "duplex"
      else "document"
    onlyFillDerivedAttributes: argv.onlyFillDerived
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
      when "yaml2" then [
        source
        splitLines()
        splitDocs()
        parseYaml2()
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
  filter: -> TBobTransform worldDescription, tbobOptions
  pipeline: ->
    [
      @input()...
      @filter()
      @output()...
    ]

