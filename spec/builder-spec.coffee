describe "The Builder", ->
  
  Factory = require "rosie"
  Builder = require "../src/builder"
  {Type,Trait,Attribute,Variant} = Builder
  build = undefined

  beforeEach ->
    build = Builder Factory
  it "lets me describe the world using meta-model classes", ->
    projekt = new Type "Projekt" 
    t0 = projekt.traitDefinitions.t0
    
