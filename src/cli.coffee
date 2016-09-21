module.exports = (process)->

  Transform = require("stream").Transform
  yaml = require 'js-yaml'
  fs = require 'fs'
  path = require 'path'
  splitLines = require "split"
  splitDocs = require "./lines-to-yaml-docs"
  walkdir = require "walkdir"


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

  parseYaml = ->
    new Transform
      objectMode:true
      transform: (chunk,encoding, done)->
        @push yaml.safeLoad chunk if chunk?.length
        done()

  input:
    process.stdin
    .pipe splitLines()
    .pipe splitDocs()
    .pipe parseYaml()
  world: ->
    def.call(this) for def in worldDefs


