module.exports = (process)->

  Transform = require("stream").Transform
  isArray = require("util").isArray
  yaml = require 'js-yaml'
  fs = require 'fs'
  path = require 'path'
  minimist = require "minimist"
  splitLines = require "split"
  splitDocs = require "./lines-to-yaml-docs"
  walkdir = require "walkdir"
  sexp = require "sexp"

  argv = minimist process.argv.slice 2
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
  output = stringify()
  output.pipe process.stdout if process.stdout?
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


