module.exports = ->
  BOM = '\uFEFF'
  DIRECTIVE = '%'
  COMMENT = '#'
  DIRECTIVES_END = '---'
  DOCUMENT_END = '...'
  Transform = require("stream").Transform
  buf =  []
  state = 'start'

  flushDocument= ->
    if buf.length > 0
      @push buf.join '\n'
      buf = []
  indicator = (line)->
    switch
      when line?.trim()[0] == COMMENT then COMMENT
      when line[0] == DIRECTIVE then DIRECTIVE
      when line.startsWith DIRECTIVES_END then DIRECTIVES_END
      when line.startsWith DOCUMENT_END then DOCUMENT_END
      else "something else"

  transitions=
    start: (line)->
      switch indicator line
        when BOM
          "start"
        when DIRECTIVE, COMMENT
          flushDocument.call this
          "prefix"
        else
          flushDocument.call this
          "document"
    prefix: (line)->
      switch indicator line
        when DIRECTIVE, COMMENT
          "prefix"
        when DIRECTIVES_END
          "document"
        else throw new Error("unexpected Content: #{line}")
    document: (line)->
      switch indicator line
        when DOCUMENT_END
          "suffix"
        else
          "document"
    suffix: (line)->
      switch indicator line
        when DIRECTIVE
          flushDocument.call this
          "prefix"
        when BOM, COMMENT
          "suffix"
        else
          flushDocument.call this
          "document"



  new Transform
    objectMode:true
    transform: (line,encoding,done)->

      next = transitions[state].call this, line
      buf.push line
      state = next ? state
      done()
    flush:(done)->
      flushDocument.call this
      done()
