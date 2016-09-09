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

