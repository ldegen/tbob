describe 'Bob', ->
  Bob = require '../src/bob'
  merge = require 'deepmerge'
  it 'is a simple wrapper around rosie\'s Factory API', ->
    bob = Bob (Factory) ->
      f = new Factory()
        .sequence 'id'
        .attr 'type', 'SPECIAL_TYPE'
        .attr 'key', [ 'id' ], (id) -> 'KEY_' + id

      Entry: f

    expect(bob.build('Entry')).to.eql
      id: 1
      type: 'SPECIAL_TYPE'
      key: 'KEY_1'


  it 'raises an Error if you try to invent new attributes', ->
    bob = Bob (Factory) ->
      Thing:
        new Factory()
          .sequence 'id'
          .attr 'foo', 'bar'

    expect(->bob.build 'Thing', bar: 'baz').to.throw Bob.BadAttributeError, /bar/

  it 'raises an Error if you refer to an undefined factory', ->

    bob = Bob (Factory) ->
      Thing:
        new Factory()
          .sequence 'id'
          .attr 'foo', 'bar'

    expect(->bob.build 'NoThing').to.throw Bob.NoFactoryByThatNameError, /NoThing/


  it 'supports traits (a.k.a. variants or mixins)', ->
    bob = Bob (Factory) ->
      Thing:
        new Factory()
          .sequence 'id'
          .attr 'foo', 'bar'
          .attr 'bang', 'baz'
      with_big_bang: (options, next) ->
          next merge bang: 'big' , options

    thing = bob.build 'Thing', 'with_big_bang', foo: 'balla'
    expect(thing).to.eql
      id:1
      bang:"big"
      foo:'balla'

  it 'explains what you did wrong when you try to use a factory as a trait', ->
    bob = Bob (Factory) ->
      Thing:
        new Factory()
          .sequence 'id'
          .attr 'foo', 'bar'
      NoTrait:
        new Factory()
    expect(->bob.build 'Thing','NoTrait').to.throw Bob.NotATraitError, /NoTrait/

  it 'explains what you did wrong when you try to use a trait as a factory', ->
    bob = Bob (Factory) ->
      Thing:
        new Factory()
          .sequence 'id'
          .attr 'foo', 'bar'
      NoThing: (opts, next)-> next opts
    expect(->bob.build 'NoThing').to.throw Bob.NotAFactoryError, /NoThing/
