describe "The Bob Transform", ->
  BobTransform = require "../src/bob-transform"
  sink = undefined
  scenarioNo = undefined
  world = ->
  MockBob = ()->
    scenarioNo++
    build: (args...)->["Scenario #{scenarioNo}", args...]
    type: (args...)->["Scenario #{scenarioNo}", "type", args...]
    metaTree: (args...)->["Scenario #{scenarioNo}", "metaTree", args...]

  beforeEach ->
    scenarioNo=0
    sink = Sink()

  describe "in scenario mode", ->
    it "treats each chunk of input as a description of a separate scenario, containing an arbitrary number of (named) documents",->
      Source [
        p1: [
          "Projekt"
          "ab_gesperrt"
          title: "SFB 42: Space Shuttle"
        ]
        p2: [
          "Projekt"
          "rahmenprojekt"
        ]
      ,
        p1: ["Projekt"]
      ]
        .pipe BobTransform world, dsl:MockBob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        p1: ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        p2: ["Scenario 1", "Projekt", "rahmenprojekt"]
      ,
        p1: ["Scenario 2", "Projekt"]
      ]

  describe "in document mode", ->
    source = undefined
    beforeEach ->
      source = Source [
        ["Projekt", "ab_gesperrt", title: "SFB 42: Space Shuttle"]
        ["Projekt", "rahmenprojekt"]
        ["Projekt"]
      ]
    it "treats input chunks as document specs all belonging to the same scenario", ->
      source
        .pipe BobTransform world, dsl:MockBob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        ["Scenario 1", "Projekt", "rahmenprojekt"]
        ["Scenario 1", "Projekt"]
      ]

    it "optionaly includes type info", ->
      source
        .pipe BobTransform world, dsl:MockBob, interleaveTypes: true
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        _type: ["Scenario 1", "type", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        _data: ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
      ,
        _type: ["Scenario 1", "type", "Projekt", "rahmenprojekt"]
        _data: ["Scenario 1", "Projekt", "rahmenprojekt"]
      ,
        _type: ["Scenario 1", "type", "Projekt"]
        _data: ["Scenario 1", "Projekt"]
      ]

