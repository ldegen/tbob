describe "Our customized Factory", ->
  rosie = require "rosie"
  Factory = require "../src/factory"
  f = undefined
  beforeEach ->
    f = new Factory()
  xit "is a Rosie Factory", ->
    expect(f).to.be.an.instanceOf rosie.Factory

  it "'s `build()`-Method allows mixing options and attribute values in a single dict", ->
    f.attr "foo",["bar"], (bar)->2*bar
    f.option "bar"
    console.log f.build bar:2
    expect(f.build bar:2).to.eql foo:4
