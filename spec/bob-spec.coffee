describe 'Bob', ->
  Bob = require '../src/bob'
  merge = require 'deepmerge'
  it 'is provides an API similar to Rosie for defining factories', ->
    bob = Bob  ->
      @factory 'Entry', ->
        @sequence 'id'
        @attr 'type', 'SPECIAL_TYPE'
        @attr 'key', [ 'id' ], (id) -> 'KEY_' + id

    expect(bob.build('Entry')).to.eql
      id: 1
      type: 'SPECIAL_TYPE'
      key: 'KEY_1'


  it 'raises an Error if you try to invent new attributes', ->
    bob = Bob  ->
      @factory 'Thing', ->
        @sequence 'id'
          .attr 'foo', 'bar'

    expect(->bob.build 'Thing', bar: 'baz').to.throw Bob.BadAttributeError, /bar/

  it 'raises an Error if you refer to an undefined factory', ->

    bob = Bob  ->
      @factory 'Thing', ->
        @sequence 'id'
        @attr 'foo', 'bar'

    expect(->bob.build 'NoThing').to.throw Bob.NoFactoryByThatNameError, /NoThing/

  # Note: not so much 'traits' as a programming language paradigm but 'traits' as in common English
  it 'supports traits', ->
    bob = Bob  ->
      @factory 'Thing', ->
        @sequence 'id'
          .attr 'foo', 'bar'
          .attr 'bang', 'baz'
        @trait 'with_big_bang', ->
          @attr 'bang','big'

        @trait 'with_small_foo', -> 
          @attr 'foo', 'small'

    thing = bob.build 'Thing', 'with_big_bang', 'with_small_foo', id: 42
    expect(thing).to.eql
      id:42
      bang:"big"
      foo:'small'

  it "automatically adds trait attributes to the base factory if necessary", ->
    bob = Bob  ->
      @factory 'Thing', ->
        @sequence 'id'
          .attr 'foo', 'bar'
        @trait 'with_big_bang', ->
          @attr 'bang','big'
          @attr 'foo', "fum"
          @attr 'blob', 42


    thing = bob.build 'Thing', bang: 'bug'
    expect(thing).to.eql
      id:1
      bang:"bug"
      foo:"bar"
      blob:null
  
  it "provides an API for defining complex attributes via factories", ->
    bob = Bob ->
      @factory 'Document', ->
        @nested 'title', 'Bilingual', de: "deutscher Titel"
        @nested 'abstract', 'Bilingual', 'empty', en: "There is only an English abstract."

      @factory 'Bilingual', ->
        @attr 'de', 'deutscher Inhalt'
        @attr 'en', 'English content'
        @trait 'empty', ->
          @attr 'de', null
          @attr 'en', null

    expect(bob.build 'Document', title:de:"De Equo").to.eql
      title:
        de: "De Equo"
        en: "English content"
      abstract:
        de: null
        en:"There is only an English abstract."


  it "provides an API for programatically defining defaults for complex attributes", ->
    bob = Bob ->
      @factory 'Document', ->
        @nested 'title', 'Bilingual', 'empty', de: "Mein Leben"
        @nested 'abstract', 'Bilingual', 'empty', ['title', 'abstract'], (title, abstract)->
          de:"Abstract zu '#{title.de ? title.en}': #{abstract.de ? "(k.A.)"}"
          en:"Abstract for '#{title.en ? title.de}': #{abstract.en ? "(n.a.)"}"

      @factory 'Bilingual', ->
        @attr 'de', 'deutscher Inhalt'
        @attr 'en', 'English content'
        @trait 'empty', ->
          @attr 'de', null
          @attr 'en', null

    expect(bob.build 'Document', abstract:en:'There is only an English abstract.').to.eql
      title:
        de: "Mein Leben"
        en: null
      abstract:
        en:"Abstract for 'Mein Leben': There is only an English abstract."
        de:"Abstract zu 'Mein Leben': (k.A.)"


  it "provides an API for defining a list of complex attributes", ->
    bob = Bob ->
      @factory 'Document', ->
        @list 'beteiligungen', 'Beteiligung', [
          ['verstorben', 'intern', rolle: "GGA"]
          rolle: "PAN"
        ]
      @factory 'Beteiligung', ->
        @sequence 'id'
        @attr 'rolle', "YEP"
        @attr 'visible', true
        @attr 'active', true
        @trait 'verstorben', ->
          @attr 'visible', false
          @attr 'active', false
        @trait 'intern', ->
          @attr 'visible', false
    expect(bob.build 'Document').to.eql
      beteiligungen:[
        id:1
        rolle: 'GGA'
        active: false
        visible: false
      ,
        id:2
        rolle: 'PAN'
        active: true
        visible: true
      ]
    expect(bob.build 'Document', beteiligungen:[
      rolle:'GGA'
      ['verstorben', id:25]
      'intern'
    ]).to.eql
      beteiligungen:[
        id:3
        rolle:'GGA'
        active:true
        visible:true
      ,
        id:25
        active:false
        visible:false
        rolle: 'YEP'
      ,
        id:4
        active:true
        visible:false
        rolle: 'YEP'
      ]

  it "provides an API for defining complex attributes inline", ->
    bob = Bob ->
      @factory 'Document', ->
        @nested 'title', ->
          @attr 'de', "deutscher Titel"
          @attr 'en', "English title"
    
    expect(bob.build 'Document').to.eql
      title:
        de: "deutscher Titel"
        en: "English title"

